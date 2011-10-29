; First stage of bootloader
;	Targeted for CD booting
;

[bits 16]                 ; using 16 bit assembly
[org 0x7C00]              ; standard location of bootloader

DIR_LOC equ 0x7C00+0x0800	; where we're loading dirs, etc
STAGE2	equ	0x0600

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
      mov   sp, 0x7C00		; starts just below us

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

			mov		ah, 0x41			; lets see if we support extensions
			mov		bx, 0x55AA
			int		0x13
			jnc		.pvdload	
			mov		si,ext_fail
			call	putstr		
			jmp		.end

.pvdload:	
      mov   si,st_pvd
      call  putstr 
      call  load_pvd  
      cmp   al,0
      je    .pvdloaded
      mov   si,fail
      call  putstr
      jmp   .end

.pvdloaded:
      mov   si,success
      call  putstr 
       


			; now we have the PVD
			; load the 


.end:
      hlt                 ; Something foul happened :(
      jmp   .end          ; just in case we get woken up
     

;------------------------------------------------------------
; Subroutines 
;------------------------------------------------------------

; load_pvd
; 16 bit, real mode
; Locates the Primary Volume Descriptor on an ISO 9660 Disc
; input:      none
; output:     al = 0 on success, nonzero on failure
; destroyed:  none
load_pvd:
          ; load a 2kib sector to 0x7C00+0x0800 = 0x8400

					; Load values into the DAP
         	mov		byte [numsect],0x01
					mov		word [lbaoff],DIR_LOC
					mov		word [lbaseg],ds
					mov		dword [lbanum],0x10 
					
					; set up for int 13
					mov		si, DAP
					mov		ah, 0x42
					int		0x13
					jnc		.success
					mov		al,1
					jmp		.done
.success:
          mov   al, 0
.done:		ret 


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
				
				
;------------------------------------------------------------
; Data
;------------------------------------------------------------

; Disk Address Packet
; (data structure used by int13 ah=42)
DAP:
					db		0x10			; size of this packet
					db		0					; always zero
numsect:	dw		0					; number of sectors to transfer
lbaoff:		dw		0					; segment and offset in mem
lbaseg:		dw		0
lbanum:		dd		0					; lba to read
lbanum2:	dd		0					; extra space for lba offset


; Strings for printing status
st_loaded					db	'seanOS Bootloader',13,10,0
st_pvd            db  'Loading Primary Volume Descriptor...',0
success           db  'Done',13,10,0
fail              db  'Fail',13,10,0
ext_fail					db	'BIOS does not support int13 Extensions',0


; end-of-file standard bootloader stuff
;  has to be 1 sector (2kib)
;  has to end with 55AA
times 2046-($-$$) db 0      ; pad with zeros
dw 0xAA55	                  ; write bootsector sig

