; Stage2 Bootloader
; FS Agnostic
; Expects a stage1 or install utility to fill in kernloc, kernsize, sectsize
; 
; Loads kernel to KERNEL and jumpts into it

[bits 16]                 ; using 16 bit assembly
[org 0x0600]    

;--------------------------------------------------------
; Environment Variables
;--------------------------------------------------------
KERNEL_LOC    equ 0x1000
KERNEL        equ 0x100000

start: 
      jmp    real_start

      times 8-($-$$) db 0
kernloc   dd  0      ; LBA offset
kernsize  dd  0      ; size in SECTORS
sectsize  dd  0      ; size of a sector on drive in dl

real_start:  

      mov    si, st_loaded
      call  putstr
      
      mov    si, st_chkkern
      call  putstr
      cmp    dword [kernloc], 0
      jz    .fail
      cmp    dword [kernsize], 0
      jz    .fail
      mov    si, success
      call  putstr

      ; Enable A20 so we can access > 1mb of ram
      mov    si, st_a20        
      call  putstr
      call  enablea20      ; call the a20 enabler
      cmp   ax,0           ; did we succeed?
      jnz   .fail          ; if ax is nonzero, no
      mov    si, success 
      call  putstr

      ; load kernel into memory
      mov    si, st_ldkern 
      call  putstr
      call  loadkernel
      cmp   ax, 0
      jnz   .fail
      mov    si, success
      call  putstr
      
      ; Load GDT  
      mov    si, st_gdt 
      call  putstr
      lgdt  [gdt_desc]    
      mov    si, success
      call  putstr

      ; Switch to pmode
      mov    si, st_pmode
      call  putstr
      mov   eax, cr0      ; get current val
      or    al, 1         ; set that bit
      mov   cr0, eax      ; write it back
      
      jmp   0x10:start_pmode ; jump to clear pipeline of non-32b inst

.fail:mov    si, fail
      call  putstr 
.end: sti
      hlt                 ; Something foul happened :(
      jmp   .end          ; just in case we get woken up
     

;------------------------------------------------------------
; Subroutines 
;------------------------------------------------------------
      
; enablea20
; 16bit, real mode
; function to enable the a20 gate on a processor
; (allows access to greater range of memory)
; assumes:    none
; input:      none
; output:     ax=0 on success, nonzero on failure
; destroyed:  ax
enablea20:
          call  wait_for_kbd_in   ; wait for kbd to clear

          mov   al, 0xD0          ; command to read status
          out   0x64, al

          call  wait_for_kbd_out  ; wait for kbd to have data

          xor   ax, ax            ; clear ax 
          in    al, 0x60          ; get data from kbd
          push  ax                ; save value
          
          call  wait_for_kbd_in   ; wait for keyboard to clear
          mov   al, 0xD1          ; command to write status
          out   0x64, al
          call  wait_for_kbd_in   ; wait for keyboard to clear
          pop   ax                ; get the old value 
          or    al, 00000010b     ; flip A20 bit
          out   0x60, al          ; write it back

          call  wait_for_kbd_in   ; double check that it worked
          mov   al, 0xD0          ; same process as above to read 
          out   0x64, al
          
          call  wait_for_kbd_out
          xor   ax,ax
          in    al, 0x60
          bt    ax, 1             ; is the A20 bit enabled?
          jc    .success
          
          mov   ax, 1             ; code that we failed
          jmp   .return 
         
.success: mov   ax, 0             ; code that we succeeded
.return:  ret


; wait_for_kbd_in
; 16 bit, real mode
; checks to see whether keyboard controller can be written to
; assumes:    none
; input:      none
; output:     none
; destroyed:  ax
wait_for_kbd_in:
          in    al, 0x64         ; read the port
          bt    ax, 1            ; see if bit 1 is 0 or not
          jc    wait_for_kbd_in  ; if it isn't, loop
          ret   


; wait_for_kbd_out
; 16 bit, real mode
; checks to see whether keyboard controller has data to read
; assumes:    none
; input:      none
; output:     none
; destroyed:  ax
wait_for_kbd_out:
          in    al, 0x64         ; read the port
          bt    ax, 0            ; see if bit 0 is 1 or not
          jnc   wait_for_kbd_out ; if it isn't, loop
          ret  


; loadkernel
; 16 bit, real mode
; loads kernel to specified location(s) KERNEL_LOC and KERNEL
; KERNEL_LOC is the place in < 1mb of memory to cache kernel
; KERNEL is the place in upper memory where the kernel will live
; (BIOS can't write above 1mb, so we have to write to KERNEL_LOC
; and then move it up to KERNEL - works because we're in unreal mode)
; assumes:    We're in unreal mode, kernel can fit in lower memory
; input:      none
; output:     ax = 0 on success, nonzero on fail    
; destroyed:  eax, bx, cx, esi, edi 
loadkernel:
            mov    eax, [kernsize]             ; set up DAP
            mov    word [numsect], ax
            mov    eax, [kernloc]
            mov    dword [lbanum], eax
            mov    word [destoff], KERNEL_LOC  ; load to < 1mb
            mov    word [destseg], ds  
            mov    si, DAP
            mov    ah, 0x42
            int    0x13            ; do the read
            jc    .done
						
						; now we have to move to > 1mb 
						call  unrealmode			; setup unreal mode
						mov   esi,KERNEL_LOC  ; place we're moving from
            mov   edi,KERNEL      ; place we're moving to
            
           	xor		ecx, ecx 				; clear ecx; used by a32 movsb
            mov   bx, [kernsize]  ; loop variable - # of sectors
.loop:    	mov   cx, [sectsize]  ; number of bytes to transfer (1 sector)
            a32   rep movsb       ; copies # of bytes in cx, increments esi and edi
                                  ; 'a32' tells it to use esi/edi instead of si/di
            dec   bx              ; i-- 
            jnz   .loop
            
            mov   ax,0            ; error code = success
.done:      ret

; unrealmode
; 16 bit, real mode
; Function that sets up unreal mode
; Assumes:		In real mode at start
; 						GDT properly set up at gdt_desc
;	Input:			none
; Output:			none
; Destroyed:	none (except segment caches)
unrealmode:      
			lgdt  [gdt_desc]    ; load the gdt
			
      push  ds            ; save original segments
			push	es
     	push	ss
			mov   eax, cr0      
      or    al,1          ; switch to pmode
      mov   cr0, eax
      mov   bx, 0x08      ;load a selector
      mov   ds, bx
			mov		es, bx
			mov		ss, bx   
      and   al, 0xFE			; switch back to (un)real
      mov   cr0, eax      
     	pop		ss						; restore real mode segments	
			pop		es 
			pop   ds            
			ret


; putstr
;  16 bit, real mode
;  Prints a null terminated string to screen
; input:       string address to be in si
; output:     none
; destroyed:  ax, bx
putstr:
        mov    ah, 0x0E    ; function for printing
        mov    bh, 0x00    ; page number
        mov    bl, 0x07    ; color  
        
.ldchr: lodsb              ; put a byte of the string into al
        cmp    al, 0
        je     .done       ; if it's null/zero, all done
        int    0x10        ; do the print
        jmp    .ldchr      ; go to next char  
  
.done:  ret


; start_pmode
; label in 32bit assembly used in the far jump to clear pipeline for switching from
; real16bit to protected32bit mode
[BITS 32]
start_pmode:
            mov ax, 0x08        ; need to load data segment into ds/ss
            mov ds, ax
            mov ss, ax
            mov esp, 0x090000   ; move stack pointer to 090000h, gives us a 65kb stack
                                ; this is probably a weird place for a stack long term
            jmp 0x10:KERNEL     ; jmp to kernel!

;----------------------------------------------------------
; Data
;----------------------------------------------------------

; Disk Address Packet
; (data structure used by int13 ah=42)
DAP:
          db    0x10       ; size of this packet
          db    0          ; always zero
numsect   dw    0          ; number of sectors to transfer
destoff   dw    0          ; segment and offset in mem
destseg   dw    0
lbanum    dd    0          ; lba to read
lbanum2   dd    0          ; extra space for lba offset


; GDT
gdt:      dq   0                           ; need a null segment
          dw  0xFFFF, 0, 0x9200, 0x00CF  ; data
          dw  0xFFFF, 0, 0x9A00, 0x00CF  ; code
gdt_end:
gdt_desc:
          dw  gdt_end - gdt - 1       ; first word is expected to be size of gdt-1
          dd  gdt                     ; then the gdt address

; Strings for printing status
st_loaded         db  'seanOS 2nd Stage Bootloader',13,10,0
st_chkkern        db  'Checking Kernel Info................',0
st_a20            db  'Enabling A20........................',0
st_gdt            db  'Loading GDT.........................',0
st_ldkern         db  'Loading Kernel......................',0
st_pmode          db  'Switching to PMode..................',0
; Success and fail strings;
success           db  'Done',13,10,0
fail              db  'Fail',13,10,0
