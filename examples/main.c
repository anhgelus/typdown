#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <typdown.h>

void foo(char *v) {
    struct typdown_Document doc = typdown_parse(v);
    if (doc.errors != NULL) {
        for (int i = 0; i < doc.errors_len; i++) {
            struct typdown_Error error = doc.errors[i];
            printf("cannot parse '%s', error: %s (%d)\n", v, typdown_getErrorString(error.code), error.code);
            printf("%d to %d ", error.location.beg, error.location.end);
            for (int j = error.location.beg; j < error.location.end; j++)
                printf("%c", v[j]);
            printf("\n");
        }
        typdown_free(doc);
        return;
    }
    uint8_t code;
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
    foo("# hello :::");
    return 0;
}
