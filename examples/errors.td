# This document shows how errors are handled by typdown and its CLI

In this line, there is *a modifier that is _not closed*.

> Basically, same *here.
> But not here hehe

:::info Invalid callout
This callout *should be* invalid
::: due to this line

Aktually,
```valid but invalid because it is empty
```

:::
The callout is valid, but it's content is not
```
because it can't have a code block!
```
:::
