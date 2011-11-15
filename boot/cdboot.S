; CD Bootloader for seanOS
;
; finds and loads stage2 (/boot/stage2)
; Also populates appropriate bytes in stage2 with kernel loc and info
;
; Has to parse ISO 9660

;--------------------------------------------------------
; Environment Variables
;--------------------------------------------------------
SEC_SIZE   equ 0x0800           ; size of sector on CD (2kib)
DIR_LOC    equ 0x7C00+SEC_SIZE  ; where we're loading dirs, etc
STAGE2     equ 0x0600           ; where we're putting stage2 in memory
STACK_LOC  equ STAGE2
KERN_LBA	 equ STAGE2+8					; where stage2 wants to find kernel info
KERN_SIZE	 equ KERN_LBA+4
SECT_SIZE  equ KERN_SIZE+4      ; to tell stage2 about sector size


[bits 16]                 ; using 16 bit assembly
[org 0x7C00]              ; standard location of bootloader
start: 
			; set up segments, stack
			; save dl register (boot drive ID)
			; long jump to enforce 0x00:0x7C00
			; get disk parameters?
			; parse filesystem to find /boot/stage2
			; double check size of file
			; load stage2 to 0x600?
			; jump there

			cli										; no interrupts
      jmp   0x00:real_start	; enforces addressing model
real_start:
			xor		ax, ax				; set segment registers
      mov   ds, ax
      mov   es, ax
      mov   ss, ax				; set up stack
      mov   sp, STACK_LOC ; starts just under stage2
      push  dx            ; save the boot drive just in case

			mov		si,st_loaded	; notify user that we've loaded
			call  putstr

			; so now we begin the task of finding PVD
			; descriptors start at 0x10
			; load one (2kib) sector
			; check first byte to see if it's 1 (id of PVD)
			; if so, next
			; if it's not, if it's 255 we have a problem
			;				and this should NEVER happen
			;				because there has to be a PVD
			; if neither, move on

			mov		ah, 0x41			; lets see if we support 
			mov		bx, 0x55AA    ; int13 extensions for LBA 
			int		0x13
			jnc		.pvdload      
			mov		si,ext_fail   ; we don't.  Should implement CHS
			call	putstr		    ; but that's old, and I'm not interested
			jmp		.end          ; in that just yet.  Someday

.pvdload:	
      mov   si,st_ldpvd     ; status message
      call  putstr 
      call  load_pvd  
      cmp   al,0          ; check error msg
      jne   .fail 
      mov   si,success
      call  putstr 
       
			; load the path table
      mov   si, st_ldpt
      call  putstr
      call  load_pt
      cmp   ax,0
      jnz   .fail
      mov   si, success
      call  putstr

      ; load the boot directory  
      mov   si, st_ldboot 
      call  putstr
			call  load_boot
      cmp   ax,0
      jnz   .fail
      mov   si,success
      call  putstr 

      ; load stage2
      mov   si,st_ldstg2
      call  putstr
      call  load_stage2
      cmp   ax,0
      jnz   .fail
      mov   si,success
      call  putstr

			; okay, so stage 2 is loaded to memory.  
			; before we jump, we have to tell stage2 kernel params	


			; find kernel
			mov		si, st_findkern
			call	putstr
			call	find_kernel
			cmp		ax, 0
			jnz		.fail
			mov		si,success
			call	putstr
     
			; Now we're ready to jump to stage 2!
			jmp		STAGE2
.fail:mov		si, fail
			call	putstr
.end: sti
      hlt 	; Something foul happened :(
    	jmp		.end 

;------------------------------------------------------------
; Subroutines 
;------------------------------------------------------------

; load_pvd
; 16 bit, real mode
; Locates the Primary Volume Descriptor on an ISO 9660 Disc
; input:      none
; output:     al = 0 on success, nonzero on failure
; destroyed:  ax, si
load_pvd:
          mov   eax, 0x0010 ; lba offset to read

					; Load values into the DAP

          mov		word [numsect], 0x01
					mov		word [destoff], DIR_LOC
					mov		word [destseg], ds
.loadsec: mov		dword [lbanum], eax
					; set up for int 13
					mov		si, DAP			; address of packet
					mov		ah, 0x42		; function number
					int		0x13				; execute!
					jc		.done				; if carry is set, error
          cmp   byte [ds:DIR_LOC],0x01    ; found the PVD
          jz    .success
          cmp   byte [ds:DIR_LOC],0xFF    ; reached end of descriptors
          jz    .fail
          inc   eax               ; go read the next one
          jmp   .loadsec 

.fail:    mov   al, 1
          jmp   .done

.success:
          mov   al, 0
.done:		ret 



; load_pt
; 16 bit, real mode
; Loads the path table to DIR_LOC
; Assumes the PVD is already loaded at this same spot
; (overrides PVD in memory, we don't need it)
; input:
; output:     ax=0 on success, nonzero on failure
; destroyed:  ax, si
load_pt:
        mov   eax,[ds:DIR_LOC+132]			; PT size (bytes)
        shr		eax,11										; bytes -> blocks (divide by 2k)
        add		ax,1											; add one in case it was < 2k
        mov		word [numsect], ax        ; number of sectors to read
        mov		word [destoff], DIR_LOC   ; place to put them
        mov		word [destseg], ds
        mov		eax,[ds:DIR_LOC+140]      ; LBA of PT
        mov		dword [lbanum], eax
        mov		si, DAP                   ; address of packet
        mov		ah,0x42                   ; function number
        int		0x13                      ; perform read
        jc    .done
        mov   ax, 0x00
.done:  ret



; load_boot
;	16 bit, real mode
; Searches path table to find and load boot directory
; assumes:    PT is loaded at DIR_LOC
;             Boot directory is present on media (otherwise wouldn't have gotten here
; input:			non
; output:			/boot is loaded to DIR_LOC
; destroyed:	ax, bx, cx, si, di
;
; Design notes:   This is specific to "/boot".  To generalize to load_dir:
;                   1) Have input values for dir name and dir length (easy)
;                   2) Save the len of PT and check if exceeded it (moderate)
;                   3) Modify to return error if dir not found (easy)
;                   4) Don't override path table with dir (hard-ish)
;                         (because no use for general function if path table is gone)
;                 Reasons why I didn't do this:
;                   1) We won't need to load any other directories in loader/real mode
;                   2) Name of boot dir is hard coded, not configurable
;                   3) No need to keep path table around after this is loaded
load_boot:
						mov		bx, DIR_LOC				; current dir offset
.parsedir:	cmp		byte [ds:bx], 4		; check length
						jz		.strchk
.nextent:   xor   al, al            ; build offset to next PT entry in al
            add   al, 8             ; offset to dir name
            add   al, [ds:bx]       ; length of dir name
            bt    word [ds:bx],0    ; determine if name is odd or even 
            jnc   .even
            add   al, 1             ; odd.  there's one extra byte of padding
.even:      add   bl, al            ; add the offset
            jmp		.parsedir         ; parse this new dir

            ; need to compare strings 
            ; use cmpsb in a loop that terminates after length of string (not null terminated)
            ; if at any point they aren't equal, jmp .nextdir
            ; if no failures after the length of string, we've found boot dir!
.strchk:    mov   cx, 4             ; length of dir 
            mov   si, boot_dir      ; name of boot dir
            mov   di, bx            ; put offset to current dir name in di
            add   di, 8
            call  strcmp
            cmp   ax,0
            jnz   .nextent          ; not a match, next dir entry

            ; now we've found the dir!  Load it to memory.
.endloop:   mov   word [numsect], 0x01    ; safe to assume /boot fits into 2kib...
            mov   word [destoff], DIR_LOC ; yes, overwriting PT
            mov   word [destseg], ds
            mov   eax, [ds:bx+2]          ; offset to lba num in PT
            mov   dword [lbanum], eax     ; lba offset    
					  mov   si, DAP                 ; address of packet
            mov   ah, 0x42                ; function number
            int   0x13                    ; do it.	
            jc   .done
            mov   ax,0 
            ;mov		al, [ds:bx+8]			; put first letter in al (for dbg purposes)
.done:      ret


; load_stage2
; 16 bit, real mode
; Loads second stage to STAGE2
; assumes:    boot directory loaded at DIR_LOC
;             stage2 filename is at stage2_name (and is correct)
; input:      none
; output:     ax=0 on success, nonzero on failure
; destroyed:  ax, bx, cx, si, di
load_stage2:
            mov   bx, DIR_LOC     ; current dir record
.parsedir:  cmp   byte [ds:bx+32], stage2_name_len+2 ; check length
            jnz   .nextdir

.strchk:    mov   cx, stage2_name_len		; use strcmp on name
            mov   si, stage2_name
            mov   di, bx
            add   di, 33								; offset to name
            call  strcmp
            cmp   ax,0
            jz   	.found
         
.nextdir:  	xor		ax,ax									; move to next entry
						mov		al, byte [ds:bx]			
						add   bx, ax
            jmp   .parsedir
          

.found:  		; found stage2! 					
           	; must load it to....? 
						mov		eax, [ds:bx+10]				; size of stage2 in bytes
						shr		eax, 11								; convert to sectors
						add		ax, 1									; in case < 1 sector
						mov		word [numsect], ax
						mov		word [destoff], STAGE2
						mov		word [destseg], ds
						mov		eax, [ds:bx+2] 
						mov		dword [lbanum], eax
						mov		si, DAP
						mov		ah, 0x42
						int		0x13	
						jc		.done	
            mov   ax, 0 
.done:			ret


; find_kernel
; 16 bit, real mode
; Finds the LBA of kernel on disc and tells stage2 about it by
; writing size and #lbas to first and second dword in stage2.
; Allows stage2 to be FS agnostic.
; assumes:    boot directory loaded at DIR_LOC
;             kernel filename is at kernel_name (and is correct)
;							stage2 has already been loaded
;							first dword of stage2 = kernel loc
;							second dword of stage2 = kernel size
; input:      none
; output:     ax=0 on success, nonzero on failure
; destroyed:  ax, bx, cx, si, di
find_kernel:
            mov   bx, DIR_LOC     ; current dir record
.parsedir:  cmp   byte [ds:bx+32], kernel_name_len+2 ; check length
            jnz   .nextdir

.strchk:    mov   cx, kernel_name_len		; use strcmp on name
            mov   si, kernel_name
            mov   di, bx
            add   di, 33								; offset to name
            call  strcmp
            cmp   ax,0
            jz   	.found
         
.nextdir:  	xor		ax,ax									; move to next entry
						mov		al, byte [ds:bx]			
						add   bx, ax
            jmp   .parsedir
          
.found:  		; found kernel!
           	; must update the first bytes of stage2 with its loc and size
						mov		eax, [ds:bx+2]				; location
						mov		[ds:KERN_LBA],eax
						mov		eax, [ds:bx+10]				; size in bytes
						shr		eax, 11								; convert to sectors
						add		al, 1
						mov		[ds:KERN_SIZE], eax
            mov   dword [ds:SECT_SIZE], 2048  ; sector size
						mov		ax, 0									; ret val
.done:			ret


; putstr
;	16 bit, real mode
;	Prints a null terminated string to screen
; input: 			string address to be in si
; output: 		none
; destroyed:	ax, bx
putstr:
				mov		ah, 0x0E		; function for printing
				mov		bh,	0x00		; page number
				mov		bl, 0x07		; color	
				
.ldchr:	lodsb							; put a byte of the string into al
				cmp		al, 0
				je		.done 			; if it's null/zero, all done
				int		0x10				; do the print
				jmp		.ldchr			; go to next char	
	
.done:	ret
			

	
; strcmp
; 16 bit, real mode
; compares two strings (assumes equal length)
; input:      str length in cx
;             ptr to str1 in ds:si
;             ptr to str2 in es:di
; output:     ax=0 if equal, nonzero if unequal
; destroyed:  ax, cx
strcmp:
.nxtchar: cmp   cx,0      ; while (cx > 0) 
          jz    .success  ; done w/o failing, match  
          cmpsb 
          jnz   .fail     ; not equal
          dec   cx        ; dec counter
          jmp   .nxtchar  ; move to next char 

.fail:    mov   ax, 1  
          jmp   .done
.success: mov   ax, 0
.done:    ret


				
;------------------------------------------------------------
; Data
;------------------------------------------------------------

; Disk Address Packet
; (data structure used by int13 ah=42)
DAP:
					db		0x10			; size of this packet
					db		0					; always zero
numsect 	dw		0					; number of sectors to transfer
destoff 	dw		0					; segment and offset in mem
destseg 	dw		0
lbanum		dd		0					; lba to read
lbanum2 	dd		0					; extra space for lba offset

; Strings for file names
boot_dir          db  'BOOT'
boot_dir_len      equ $-boot_dir
stage2_name       db  'STAGE2.'				; period due to ISO filename standards
stage2_name_len   equ $-stage2_name
kernel_name       db  'KERNEL.'				; period due to ISO filename standards
kernel_name_len   equ $-kernel_name

; Strings for printing status
st_loaded					db	'seanOS CD Bootloader',13,10,0
st_ldpvd          db  'Loading Primary Volume Descriptor...',0
st_ldpt           db  'Loading Path Table..................',0
st_ldboot         db  'Loading /boot.......................',0
st_ldstg2         db  'Loading stage2......................',0
st_findkern				db	'Finding Kernel......................',0
; Success and fail strings
success           db  'Done',13,10,0
fail              db  'Fail',13,10,0
ext_fail					db	'BIOS does not support int13 Extensions',0


; end-of-file standard bootloader stuff
;  has to be 1 sector (2kib)
;  has to end with 55AA
times 2046-($-$$) db 0      ; pad with zeros
dw 0xAA55	                  ; write bootsector sig

