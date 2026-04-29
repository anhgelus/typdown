//! Based on https://github.com/zeon256/minimal-typst-svg-renderer

use typst::layout::PagedDocument;
use typst_svg::svg_frame;

use crate::world::MinimalWorld;

mod world;

pub fn compile() {
    let content = include_str!("../../template.typ");
    let world = MinimalWorld::new(content);

    let res = typst::compile::<PagedDocument>(&world);

    if !res.warnings.is_empty() {
        eprintln!("Warnings: {:?}", res.warnings);
    }

    let doc = res.output.expect("Error compiling typst");

    let svg = svg_frame(&doc.pages[0].frame);
    println!("{}", svg)
}
