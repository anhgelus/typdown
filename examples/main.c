#include <stdlib.h>
#include <stdio.h>
#include <stdint.h>
#include <typdown.h>

void foo(char *v) {
    Document doc = parseTypdown(v);
    if (doc.errors != NULL) {
        for (int i = 0; i < doc.errors_len; i++) {
            struct Document_Error error = doc.errors[i];
            printf("cannot parse '%s', error: %s (%d)\n", v, getErrorString(error.code), error.code);
            printf("line %d: ", error.location.line);
            for (int j = error.location.beg; j < error.location.end; j++)
                printf("%c", v[j]);
            printf("\n");
        }
        Document_free(doc);
        return;
    }
    uint8_t code;
    char *res = Document_renderHTML(doc.root, &code);
    if (code != 0) {
        printf("cannot render '%s', error: %s (%d)\n", v, getErrorString(code), code);
        Document_free(doc);
        return;
    }
    printf("%s\n", res);
    free(res);
    Document_free(doc);
}

int main() {
    // valid
    foo("hello world");
    foo("he*ll*o world");
    foo("# he*ll*o world");

    // invalid
    foo("hello *world");
    return 0;
}
