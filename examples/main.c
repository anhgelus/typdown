#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <typdown.h>

void foo(char *v) {
    uint8_t code;
    void *doc = typdown_parse(v, &code);
    if (code != 0) {
        printf("cannot parse '%s', error: %s (%d)\n", v, typdown_getErrorString(code), code);
        typdown_free(doc);
        return;
    }
    char *res = typdown_renderHTML(doc, &code);
    if (code != 0) {
        printf("cannot render '%s', error: %s (%d)\n", v, typdown_getErrorString(code), code);
        typdown_free(doc);
        return;
    }
    printf("%s\n", res);
    free(res);
    typdown_free(doc);
}

int main() {
    // valid
    foo("hello world");
    foo("he*ll*o world");
    foo("# he*ll*o world");

    // invalid
    foo("hello *world");
    foo("hello world :::");
    foo("# hello :::");
    return 0;
}
