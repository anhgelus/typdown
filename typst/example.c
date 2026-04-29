#include "typst.h"
#include <stdio.h>

int main() {
    const char* res = typst_generateSVG("Hello world");
    printf("%s\n", res);
    typst_freeString(res);
    return 0;
}
