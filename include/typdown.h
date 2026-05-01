#pragma once
#include <stdint.h>

char * typdown_getErrorString(uint8_t);

void * typdown_parse(char *, uint8_t *);
void typdown_free(void *);
char * typdown_renderHTML(void *, uint8_t *);
