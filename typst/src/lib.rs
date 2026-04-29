//! Based on https://github.com/zeon256/minimal-typst-svg-renderer
use std::ffi::{CString, CStr};
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

#[unsafe(no_mangle)]
pub extern "C" fn typst_generateSVG(source: *const c_char) ->  *const c_char {
    unsafe {
        let res = compile(CStr::from_ptr(source).to_str().unwrap());
        CString::new(res).unwrap().into_raw()
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn typst_freeSVG(res: *mut c_char) {
    unsafe {
        drop(CString::from_raw(res));
    }
}
