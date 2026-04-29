//! Based on https://github.com/zeon256/minimal-typst-svg-renderer
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

use typst::layout::PagedDocument;
use typst_svg::svg_frame;

use crate::world::MinimalWorld;

mod world;

pub fn compile(content: &str) -> String {
    let world = MinimalWorld::new(content);

    let res = typst::compile::<PagedDocument>(&world);

    if !res.warnings.is_empty() {
        eprintln!("Warnings: {:?}", res.warnings);
    }

    let doc = res.output.expect("Error compiling typst");

    svg_frame(&doc.pages[0].frame)
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
pub unsafe extern "C" fn typst_generateSVG(source: *const c_char) -> *const c_char {
    unsafe { convert_call(source, compile) }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn typst_freeString(res: *mut c_char) {
    unsafe {
        drop(CString::from_raw(res));
    }
}

#[unsafe(no_mangle)]
pub unsafe extern "C" fn typst_escapeMath(source: *const c_char) -> *const c_char {
    unsafe { convert_call(source, escape_math) }
}
