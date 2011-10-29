#include "io.h"

void out(unsigned short port, unsigned char data)
{
	// command, registers, output(none) input (eax and edx), destroyed regs
	__asm__("out %%al, %%dx" : : "a" (data), "d" (port) : );
}
