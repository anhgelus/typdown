//! Based on https://github.com/zeon256/minimal-typst-svg-renderer
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use typst::diag::Warned;

use crate::world::MinimalWorld;

use typst_layout::PagedDocument;

mod world;

pub fn compile(content: &str) -> String {
    let world = MinimalWorld::new(content);
    let Warned { output, warnings } = typst::compile::<PagedDocument>(&world);

    if !warnings.is_empty() {
        eprintln!("Warnings: {:?}", warnings);
    }

    let doc = output.expect("Error compiling typst");
    let page = doc.pages().first().expect("empty doc");

    typst_svg::svg(
        page,
        &typst_svg::SvgOptions {
            render_bleed: false,
            pretty: false,
        },
    )
}

pub fn escape_math(content: &str) -> String {
    content.replace("$", r"\$").replace("\n", r"\ ")
}

unsafe fn convert_call(source: *const c_char, f: fn(&str) -> String) -> *const c_char {
    unsafe {
        let res = f(CStr::from_ptr(source).to_str().unwrap());
        CString::new(res).unwrap().into_raw()
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn generateSVG(source: *const c_char) -> *const c_char {
    unsafe { convert_call(source, compile) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn freeString(res: *mut c_char) {
    unsafe {
        drop(CString::from_raw(res));
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn escapeMath(source: *const c_char) -> *const c_char {
    unsafe { convert_call(source, escape_math) }
}
