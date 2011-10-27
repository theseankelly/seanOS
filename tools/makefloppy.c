#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>

#define FLPIMG "os.img"

#define BUFFER_SIZE 512

#define IMAGE_SIZE 1474560

int main(int argc, char **argv)
{
  // loop index
  unsigned long i; 
  
  // file names
  FILE *flp;
  FILE *readfrom;

  
  // buffer/variables for reading
  char buffer[BUFFER_SIZE];
  size_t bytes_read = 0;
  size_t bytes_written = 0; 
  size_t total_bytes_written = 0;
  
  // param checking
  if( argc < 2 )
  {
    printf("Need to specify at least one file to copy...");
    exit(-1);
  }


  // open and check the image file
  flp = fopen(FLPIMG,"r+"); // allows writing without discarding original file
  if(flp == 0)
  {
    // try to create the file and then open it again
    system("dd if=/dev/zero of=os.img bs=1474560 count=1");
    flp = fopen(FLPIMG,"r+");
    if(flp == 0)
    {
      printf("Error opening %s: %s\n",FLPIMG,strerror(errno));
      exit(-1);
    }
  } 
 
  // loop through all input files
  // write them to a floppy image
  for(i=1; i<argc; i++)
  {
    readfrom = fopen(argv[i],"r");
    if(readfrom == 0)
    {
      printf("Error opening file: %s\n",strerror(errno));
      printf("Skipping %s...\n",argv[i]);
      break;
    }

    // read contents of file
    // if we're not exceeding the size of the floppy, write to output
    // if end of input file, done
    do
    {
      bytes_read = fread(buffer, 1, BUFFER_SIZE, readfrom);
      total_bytes_written+=bytes_read;
      if(total_bytes_written > IMAGE_SIZE)
      {
        printf("Error, size exceeds floppy capacity...aborting (%s)\n",argv[i]);
        exit(-1);
      }
      bytes_written = fwrite(buffer, 1, bytes_read, flp);
      if( bytes_read != bytes_written )
      {
        printf("Error, bytes written (%d) doesn't match bytes read (%d)...aborting (%s)\n",bytes_written,bytes_read, argv[i]);
        exit(-1);
      } 
    } while( bytes_read > 0);
    // close the file and go to the next one
    fclose(readfrom);
  } 
  // need some magic here to enforce the floppy size

  // close out the image file 
  fclose(flp); 

  printf("Success, %d bytes written\n",total_bytes_written);
  return 0;
}
