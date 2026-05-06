#pragma once
#include <stdint.h>
#include <stdlib.h>

struct Document_Error {
    uint8_t code;
    struct {size_t beg; size_t end; size_t line;} location;
};

struct CDocument {
    void *root;
    struct Document_Error *errors;
    size_t errors_len;
};

typedef struct CDocument Document;

char * getErrorString(uint8_t);

Document parseTypdown(char *);
void Document_free(Document);
char * Document_renderHTML(void *, uint8_t *);
