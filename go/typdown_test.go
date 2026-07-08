package typdown

import "testing"

func TestParse(t *testing.T) {
	doc := Parse("hello world")
	for _, err := range doc.Errors {
		t.Error(err)
	}
	if t.Failed() {
		return
	}
	defer doc.Close()
	got, err := doc.RenderHTML()
	if err != nil {
		t.Fatal(err)
	}
	if got != `<p>hello world</p>` {
		t.Errorf("invalid result: %s", got)
	}
}
