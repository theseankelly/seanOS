; First stage of bootloader
;	Targeted for CD booting
;

;--------------------------------------------------------
; Environment Variables
;--------------------------------------------------------
SEC_SIZE   equ 0x0800           ; size of sector on CD (2kib)
DIR_LOC    equ 0x7C00+SEC_SIZE  ; where we're loading dirs, etc
STAGE2     equ 0x0600           ; where we're putting stage2 in memory

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
      mov   sp, 0x7C00		; starts just below us
                          ; or should we put it under stage2 in advance??

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
      mov   si,st_pvd     ; status message
      call  putstr 
      call  load_pvd  
      cmp   al,0          ; check error msg
      je    .pvdloaded
      mov   si,fail
      call  putstr
      jmp   .end

.pvdloaded:
      mov   si,success
      call  putstr 
       
			; THINGS TO CONSIDER
			; 1) Do we want to keep the PVD around?
			;			Nah
			; 2) Do we want to keep the PT around?
			;			Not really, kernel will be in /boot as well
			; 
			; so overall flow:
			; 1) Load PVD
			; 2) Load PT (can override PVD)
			; 3) Scan PT for /boot
			; 4) Load /boot (can override PT)
			; 5) Find stage2, load it to mem
			; 6) Find kernel, put its stats in memory somewhere
			; 7) Jump to stage2
			;
			; Advantages: stage2 doesn't need to parse ISO9660
			; 						because it just knows where to find
			;							the kernel
			;			
			;							This also means stage2 should be boot 
			;							media agnostic?  (if it supports LBA)			


			; now we have the PVD
			; load the table
      
      ; Code to load the path table 
			mov		bx,DIR_LOC								; PVD loc
			add		bx,132										; offset to size of PT
      mov   eax,[ds:bx]								; size (bytes)
			shr		eax,11										; bytes -> blocks
			add		ax,1											; adjust for precision
      mov		word [numsect],ax
			mov		word [destoff], DIR_LOC
			mov		word [destseg], ds
			mov		bx,DIR_LOC
			add		bx,140
			mov		eax,[ds:bx]
			mov		dword [lbanum], eax
			mov		si, DAP
			mov		ah,0x42
			int		0x13

.end: sti
      hlt 	; Something foul happened :(
    	jmp		.end 

;------------------------------------------------------------
; Subroutines 
;------------------------------------------------------------


; load_sectors
; 16 bit, real mode
; Loads a specified number of sectors from a drive to memory
; Uses LBA format, so int13 extensions need to be available
; to call this
;	input:			Drive to read from in dl	
;							LBA number in eax
;							Number of sectors in bx
;							Dest base in ds
;							Dest offset in cx	
;	output:			ah has 0 on success, or int13 error code
;	destroyed:	si
load_sectors:
          		mov		word [numsect], bx
							mov		word [destoff], cx
							mov		word [destseg], ds
							mov		dword [lbanum], eax
							; set up for int 13
							mov		si, DAP			; address of packet
							mov		ah, 0x42		; function number
							int		0x13				; execute!
							jc		.done
							mov		ah, 0x00
.done:				ret

; find_boot
;	16 bit, real mode
; Searches path table to find boot directory
; input:			Assumes PT is loaded at DIR_LOC
; output:			LBA of /boot in <reg>
;							Size of /boot in <reg>
; destroyed:	none (not true)
find_boot:
						; load first directory
						; check if length = 4
						; if not, move to next dir
						; if so, do a string comparison
						; if no match, next dir
						; if match, return
						; Do we check for end of PT, or assume boot
						; is present???
						;		I think we can assume safely because otherwise
						;		this CD wouldn't boot
						ret



; load_pvd
; 16 bit, real mode
; Locates the Primary Volume Descriptor on an ISO 9660 Disc
; input:      none
; output:     al = 0 on success, nonzero on failure
; destroyed:  none
load_pvd:
          mov   eax, 0x0010 ; lba offset to read

					; Load values into the DAP
          mov		word [numsect], 0x01
					mov		word [destoff],  DIR_LOC
					mov		word [destseg],  ds
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
destoff:	dw		0					; segment and offset in mem
destseg:	dw		0
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

