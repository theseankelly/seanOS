#ifndef UTIL_H
#define UTIL_H

// text colors
#define STD_TXT 0x07

// video memory - should these be #defines?
extern unsigned char* VIDMEM;
extern unsigned long VIDSIZE;

// cursor position
extern unsigned long CROW;
extern unsigned long CCOL;

void kclrscreen();
void kprintf(char* msg);

#endif
