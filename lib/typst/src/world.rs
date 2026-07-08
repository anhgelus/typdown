//! Based on https://github.com/zeon256/minimal-typst-svg-renderer

use std::path::PathBuf;

use typst::Library;
use typst::LibraryExt;
use typst::World;
use typst::diag::{FileError, FileResult};
use typst::foundations::Duration;
use typst::foundations::{Bytes, Datetime};
use typst::syntax::{FileId, Source};
use typst::text::{Font, FontBook};
use typst::utils::LazyHash;
use typst_kit::fonts;
use typst_kit::fonts::FontStore;

/// Main interface that determines the environment for Typst.
pub struct MinimalWorld {
    /// The content of a source.
    source: Source,
    /// The standard library.
    library: LazyHash<Library>,
    /// Metadata about all known fonts.
    fonts: FontStore,
}

impl MinimalWorld {
    pub fn new(source: impl Into<String>) -> Self {
        let mut fonts = FontStore::new();

        fonts.extend(fonts::system());

        #[cfg(feature = "embedded-fonts")]
        fonts.extend(fonts::embedded());

        Self {
            library: LazyHash::new(Library::default()),
            fonts: fonts,
            source: Source::detached(source),
        }
    }
}

impl World for MinimalWorld {
    /// Standard library.
    fn library(&self) -> &LazyHash<Library> {
        &self.library
    }

    /// Metadata about all known Books.
    fn book(&self) -> &LazyHash<FontBook> {
        &self.fonts.book()
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
        self.fonts.font(id)
    }

    /// Get the current date.
    ///
    /// Optionally, an offset in hours is given.
    fn today(&self, _offset: Option<Duration>) -> Option<Datetime> {
        None
    }
}
