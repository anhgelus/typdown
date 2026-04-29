#include "typst.h"
#include <stdio.h>

int main() {
    const char* res = typst_generateSVG("Hello world");
    printf("%s\n", res);
    typst_freeSVG(res);
    return 0;
}
