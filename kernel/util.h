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
/* void kclrscreen
 *		no args
 *		returns nothing
 *
 * 		Clears the screen from kernel.  Just writes
 * 		spaces of color STD_TXT to the whole thing
 */

void kprintf(char* msg);
/* void kprintf(char* msg)
 * 		char* msg is a string to print to the screen
 * 							assumes null terminated
 * 							can have \n and \r for new line and CR
 * 		returns nothing
 *
 * 		Prints the string to screen and updates CROW,
 * 		CCOL acordingly. Wraps around to top of screen
 * 		if the video pointer exceeds to size of memory
 * 		Handles escape characters \r and \n but none others
 *
 * 		Future plans: Could handle wrap around more 
 * 		intelligently.  Also doesn't have support for other
 * 		escape characters, or the ability to print formatted 
 * 		strings like C's printf. 
 */  

void update_cursor(unsigned long CROW, unsigned long CCOL);
/* void update_cursor(unsigned long CROW, unsigned long CCOL)
 * 		unsigned long CROW: current row
 * 		unsigned long CCOL: current column
 * 		returns nothing
 *
 * 		Updates the system's cursor position to specified 
 * 		row and column using port calls in assembly
 */

#endif
