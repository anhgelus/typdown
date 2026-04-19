#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include "typdown.h"

void foo(char *v) {
    uint8_t code;
    char *res = parse(v, &code);
    if (code == 0) {
        printf("%s\n", res);
        free(res);
    } else printf("cannot parse '%s', error: %s (%d)\n", v, getErrorString(code), code);
}

int main() {
    // valid
    foo("hello world");
    foo("he*ll*o world");
    foo("# he*ll*o world");

    // invalid
    foo("hello *world");
    foo("# hello :::");
    return 0;
}
