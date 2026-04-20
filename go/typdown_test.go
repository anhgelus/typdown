package typdown

import "testing"

func TestParse(t *testing.T) {
	res, err := Parse("hello world")
	if err != nil {
		t.Fatal(err)
	}
	if res != `<p>hello world</p>` {
		t.Errorf("invalid result: %s", res)
	}
}
