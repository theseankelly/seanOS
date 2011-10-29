#include "kernel.h"
#include "util.h"
#include "io.h"

// global row/col variables
unsigned long CROW = 0;
unsigned long CCOL = 0;

// global video memory related variables
unsigned char* VIDMEM = (unsigned char *)0xB8000;  // should be CONST but then i can't change values at address
unsigned long VIDSIZE = 25*80*2;

// function to clear the screen
// writes a space in gray-on-black font to whole screen
void kclrscreen()
{
	unsigned long i=0;				// start from beginning
	while( i < VIDSIZE ) 			// for the whole thing, write space and color
	{
		VIDMEM[i++] = ' ';
		VIDMEM[i++] = STD_TXT;
	}
	CROW=0;										// reset row and col
	CCOL=0;
	update_cursor(CROW,CCOL);	// reset the cursor
}

void kprintf(char* msg)
{
	unsigned long i=0; 											// pointer to message
	unsigned long vid_ptr=CROW*80*2+CCOL*2; // translate row/col into inline pointer
	while(msg[i]!=0)
	{
		if(msg[i]=='\n')
		{
			vid_ptr+=80*2;		// newline, add one row to pointer
			i++;
			continue;
		}
		if(msg[i]=='\r')
		{
			vid_ptr=vid_ptr/(80*2)*(80*2); // use int division go to beginning of line
			i++;
			continue;
		}
		// otherwise, it's a normal character
		VIDMEM[vid_ptr++]=msg[i++];
		VIDMEM[vid_ptr++]=STD_TXT;
		vid_ptr%=(VIDSIZE-1);							// if we've gone too far, wrap around to top
	}
	CROW=vid_ptr/(2*80);						// update row/col
	CCOL=(vid_ptr%(2*80))/2; 				// relative to screen, not size of memory
	update_cursor(CROW,CCOL);		// update cursor
}


void update_cursor(unsigned long row, unsigned long col)
{
	unsigned short position = row*80+col;
  out(0x3D4, 15);
	out(0x3D5, (unsigned char)(position));
	out(0x3D4, 14);
	out(0x3D5, (unsigned char)(position >> 8));
}
