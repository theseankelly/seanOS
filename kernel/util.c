#include "util.h"
#include "kernel.h"

// global row/col variables
unsigned long CROW = 0;
unsigned long CCOL = 0;

unsigned char* VIDMEM = (unsigned char *)0xB8000;
unsigned long VIDSIZE = 25*80*2;

void kclrscreen()
{
	unsigned long i=0;
	while( i < VIDSIZE ) 	
	{
		VIDMEM[i++] = ' ';
		VIDMEM[i++] = STD_TXT;
	}
	CROW=0;
	CCOL=0;
}

void kprintf(char* msg)
{
	unsigned long i=0;
	unsigned long vid_ptr=CROW*80+CCOL;
	while(msg[i]!=0)
	{
		VIDMEM[vid_ptr++]=msg[i++];
		VIDMEM[vid_ptr++]=STD_TXT;
	}
	CCOL=i;
}



