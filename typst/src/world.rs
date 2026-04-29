//! Based on https://github.com/zeon256/minimal-typst-svg-renderer

use std::path::PathBuf;

use typst::Library;
use typst::LibraryExt;
use typst::World;
use typst::diag::{FileError, FileResult};
use typst::foundations::{Bytes, Datetime};
use typst::syntax::{FileId, Source};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst_kit::fonts::Fonts;

/// Main interface that determines the environment for Typst.
pub struct MinimalWorld {
    /// The content of a source.
    source: Source,

    /// The standard library.
    library: LazyHash<Library>,

    /// Metadata about all known fonts.
    book: LazyHash<FontBook>,

    /// Metadata about all known fonts.
    fonts: Vec<Font>,
}

impl MinimalWorld {
    pub fn new(source: impl Into<String>) -> Self {
        let (fonts, book) = Self::load_fonts();

        Self {
            library: LazyHash::new(Library::default()),
            book: LazyHash::new(book),
            fonts: fonts,
            source: Source::detached(source),
        }
    }

    fn load_fonts() -> (Vec<Font>, FontBook) {
        let mut searcher = Fonts::searcher();
        searcher.include_system_fonts(true);

        let mut fonts = Vec::new();
        let mut book = FontBook::new();
        for font in searcher.search().fonts {
            book.push(font.get().unwrap().info().clone());
            fonts.push(font.get().unwrap());
        }
        (fonts, book)
    }
}

impl World for MinimalWorld {
    /// Standard library.
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    /// Metadata about all known Books.
    fn book(&self) -> &LazyHash<FontBook> {
        &self.book
    }

    /// Accessing the main source file.
    fn main(&self) -> FileId {
        self.source.id()
    }

    /// Accessing a specified source file (based on `FileId`).
    fn source(&self, id: FileId) -> FileResult<Source> {
        if id == self.source.id() {
            Ok(self.source.clone())
        } else {
            Err(FileError::NotFound(PathBuf::new()))
        }
    }

    /// Accessing a specified file (non-file).
    fn file(&self, _id: FileId) -> FileResult<Bytes> {
        Err(FileError::NotFound(PathBuf::new()))
    }

    /// Accessing a specified font per index of font book.
    fn font(&self, id: usize) -> Option<Font> {
        self.fonts.get(id).cloned()
    }

    /// Get the current date.
    ///
    /// Optionally, an offset in hours is given.
    fn today(&self, _offset: Option<i64>) -> Option<Datetime> {
        None
    }
}
