# typdown

typdown is a markup language that looks like Markdown, but with a better syntax.

It can be compiled into HTML, Markdown (CommonMark), typst or PDF.

## Bindings

typdown is written in Zig, but you can choose almost any languages to work with typdown files.

Of course, you can use typdown with Zig:
```zig
// build.zig
const typdown = b.dependency("typdown", .{
    .optimize = optimize,
    .target = target,
}).module("typdown");
exe.root_module.addImport("typdown", typdown);
```

Zig can easily interop with C.
See `examples/main.c` for an example.

And you can integrate the C ABI in almost any languages!
Example bindings for Go are in `go/`.
There is a `build.zig` to illustrate how to create one for your project.
