// main kernel function
//
#include "util.h"

void kmain(){
	char* msg1 = "Hello, Kernel!";	
	kclrscreen();
	kprintf(msg1);
	kprintf("Hi!");
	
}
