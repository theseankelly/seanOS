// main kernel function
//
#include "util.h"

void kmain(){
	char* msg1 = "Hello, Kernel!\nThis is a very long string\r\n";
	char* msg2 = "The idea is to check to see how the kernel handles printing a very long string, but now also to test the boundaries of memory.  We want a kernel image that's bigger than 1024.  I think this did it.\r\n";
	kclrscreen();
	kprintf(msg1);
	kprintf("End of msg1 \r\n");
	kprintf(msg2);
	kprintf("Hi!\n");
	
}
