package typdown

/*
#include <stdlib.h>
#include "typdown.h"
*/
import "C"
import (
	"errors"
	"fmt"
	"html/template"
	"unsafe"
)

var (
	codeErrors = map[uint8]error{
		1:  errors.New("out of memory"),
		2:  ErrInvalidUtf8,
		3:  ErrNotSupported,
		4:  ErrModifierNotClosed,
		5:  ErrInvalidTitleContent,
		6:  ErrIllegalPlacement,
		7:  ErrInvalidLink,
		8:  ErrInvalidImage,
		9:  ErrInvalidCodeBlock,
		10: ErrInvalidCallout,
		11: ErrInvalidMathBlock,
	}
	ErrInvalidUtf8         = errors.New("invalid UTF-8")
	ErrNotSupported        = errors.New("feature not supported")
	ErrModifierNotClosed   = errors.New("modifier not closed")
	ErrInvalidTitleContent = errors.New("invalid title content")
	ErrIllegalPlacement    = errors.New("illegal placement")
	ErrInvalidLink         = errors.New("invalid link")
	ErrInvalidImage        = errors.New("invalid image")
	ErrInvalidCodeBlock    = errors.New("invalid code block")
	ErrInvalidCallout      = errors.New("invalid callout")
	ErrInvalidMathBlock    = errors.New("invalid math block")
)

type Error struct {
	code     uint8
	source   *string
	location ErrorLocation
}

func (e Error) Unwrap() error {
	return codeErrors[uint8(e.code)]
}

func (e Error) Error() string {
	loc := e.location
	return fmt.Sprintf("%s: %s (line %d)", e.Unwrap().Error(), loc.source, loc.line)
}

func (e Error) Is(err error) bool {
	return errors.Is(e.Unwrap(), err)
}

type ErrorLocation struct {
	source string
	line   uint
}

type Document struct {
	Errors []Error
	embed  C.Document
}

func Parse(content string) Document {
	conv := C.CString(content)
	defer C.free(unsafe.Pointer(conv))
	rawDoc := C.parseTypdown(conv)
	doc := Document{embed: rawDoc}
	if rawDoc.errors_len > 0 {
		doc.Errors = make([]Error, rawDoc.errors_len)
		errs := unsafe.Slice(rawDoc.errors, rawDoc.errors_len)
		for i := range rawDoc.errors_len {
			raw := errs[i]
			doc.Errors[i] = Error{
				code:     uint8(raw.code),
				source:   &content,
				location: ErrorLocation{source: content[raw.location.beg:raw.location.end], line: uint(raw.location.line)},
			}
		}
	}
	return doc
}

func (d *Document) Close() {
	C.Document_free(d.embed)
}

func (d *Document) RenderHTML() (template.HTML, error) {
	code := C.uchar(0)
	raw := C.Document_renderHTML(d.embed.root, &code)
	defer C.free(unsafe.Pointer(raw))
	if code > 0 {
		err := codeErrors[uint8(code)]
		if code == 1 {
			panic(err)
		}
		return "", err
	}
	return template.HTML(C.GoString(raw)), nil
}
