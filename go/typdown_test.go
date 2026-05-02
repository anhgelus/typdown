package typdown

import "testing"

func TestParse(t *testing.T) {
	res, err := Parse("hello world")
	if err != nil {
		t.Fatal(err)
	}
	defer res.Deinit()
	got, err := res.RenderHTML()
	if err != nil {
		t.Fatal(err)
	}
	if got != `<p>hello world</p>` {
		t.Errorf("invalid result: %s", got)
	}
}
