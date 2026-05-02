package typdown

// #cgo LDFLAGS: -L${SRCDIR}/zig-out/lib -ltypdown
// #include <stdlib.h>
// #include "typdown.h"
import "C"
import (
	"errors"
	"html/template"
	"unsafe"
)

var (
	codeErrors = map[uint8]error{
		1: errors.New("out of memory"),
		2: ErrInvalidUtf8,
		3: ErrNotSupported,
		4: ErrModifierNotClosed,
		5: ErrInvalidTitleContent,
		6: ErrIllegalPlacement,
		7: ErrInvalidLink,
	}
	ErrInvalidUtf8         = errors.New("invalid UTF-8")
	ErrNotSupported        = errors.New("feature not supported")
	ErrModifierNotClosed   = errors.New("modifier not closed")
	ErrInvalidTitleContent = errors.New("invalid title content")
	ErrIllegalPlacement    = errors.New("illegal placement")
	ErrInvalidLink         = errors.New("invalid link")
)

type Document struct {
	ptr unsafe.Pointer
}

func Parse(content string) (*Document, error) {
	code := C.uchar(0)
	conv := C.CString(content)
	raw := C.typdown_parse(conv, &code)
	defer C.free(unsafe.Pointer(conv))
	if code > 0 {
		err := codeErrors[uint8(code)]
		if code == 1 {
			panic(err)
		}
		return nil, err
	}
	return &Document{raw}, nil
}

func (d *Document) Deinit() {
	C.typdown_free(d.ptr)
}

func (d *Document) RenderHTML() (template.HTML, error) {
	code := C.uchar(0)
	raw := C.typdown_renderHTML(d.ptr, &code)
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
