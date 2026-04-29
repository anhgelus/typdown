# typst library

This folder contains a Rust library used to compile typdown's typst components.
We cannot write it in Zig, because there are no existing C bindings for typst.

## Build example

```shell
$ cargo build
$ gcc example.c -o example -ltypdown_typst -L./target/debug
$ LD_LIBRARY_PATH=./target/debug ./example
```
