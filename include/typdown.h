#pragma once
#include <stdint.h>
#include <stdlib.h>

struct typdown_Error {
    uint8_t code;
    struct {size_t beg; size_t end; size_t line;} location;
};

struct typdown_Document {
    void *root;
    struct typdown_Error *errors;
    size_t errors_len;
};

char * typdown_getErrorString(uint8_t);

struct typdown_Document typdown_parse(char *);
void typdown_free(struct typdown_Document);
char * typdown_renderHTML(void *, uint8_t *);
