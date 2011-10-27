; This is the bootloader for my OS!
; single stage.  probably need to expand eventually
;
; Currently:
;     enables A20 bit
;     loads a simple GDT (code and data sel overlap)
;     loads the kernel (assuming it immediately follows bootsector) to 1mb
;     switches to pmode
;     sets up simple stack from 90000h-9FFFFh (65kb)
;     jumps to the kernel image to give control
;
[bits 16]                 ; using 16 bit assembly
[org 0x7C00]              ; standard location of bootloader

main: 
      cli                 ; don't get interrupted while booting!
      
      ; Enable A20 so we can access > 1mb of ram
      push  statusa20        
      call  putstr
      add   sp, 2        
      call  enablea20     ; call the a20 enabler
      cmp   ax,0          ; did we succeed?
      jz    .a20succeed   ; if zero was returned, we did 
      .a20fail:           ; otherwise, no
      push  statusf
      call  putstr
      add   sp,2
      jmp   .end          ; quit now 
      .a20succeed:        ; A20 enabled!
      push  statusd
      call  putstr
      add   sp,2

      push  statusgdt     ; load GDT into memory
      call  putstr
      add   sp,2
			call	loadgdt
			cmp		ax,0
			jz		.gdtsucceed
			.gdtfail:
			push	statusf
			call	putstr
			add		sp, 2
			jmp		.end
			.gdtsucceed:
			push	statusd
			call	putstr
			add		sp,2

      push  ds            ; switch to unreal mode
      mov   eax,cr0       ; because we need to put kernel at 1mb 
      or    al,1          ; basically, switch to pmode 
      mov   cr0, eax
      mov   bx, 08h       ; load a selector 
      mov   ds, bx   
      and   al,0xFE
      mov   cr0,eax       ; switch back to "unreal"
      pop   ds            ; restore segment


      push  statuskern    ; load kernel into memory
      call  putstr
      add   sp,2
      call  loadkernel
      cmp   ax,0
      jz    .kernsucceed
      .kernfail:
      push  statusf
      call  putstr
      add   sp,2
      jmp   .end
      .kernsucceed:
      push  statusd
      call  putstr
      add   sp,2
      
	
      push  statuspmode   ; Switch to pmode
      call  putstr
      add   sp,2
      mov   eax, cr0      ; get current val
      or    al,   1       ; set that bit
      mov   cr0, eax      ; write it back
      
      jmp   10h:start_pmode ; jump to clear pipeline of non-32b inst
      
      .end:
      hlt                 ; Something foul happened :(
      jmp   .end          ; just in case we get woken up
     

;------------------------------------------------------------
; Subroutines 
;------------------------------------------------------------

; putstr 
; this is a function to print a string to the screen in BIOS
; prints the string found at memory addres in edx
; basically useless, proves the bootloader is working
; also served as good practice for assembly :)  
putstr:
        push  bp              ; saving original base pointer
        mov   bp, sp          ; setting local base pointer  
        push  bx              ; save modified registers
        push  dx
        mov   ah, 0Eh         ; tells bios to print on int 10
        mov   bh, 00h         ; page number
        mov   bl, 07h         ; color (not applicable here)
                              ;      b/c not in graphic mode
        mov   dx, [ebp+4]     ; load the address of the string 
.next:  mov   al,[edx]        ; load character
        cmp   al,0            ; see if the char is null
        je    .done           ; if so, fix stack and ret 
        int   0x10            ; if not, print char  
        inc   dx              ; increment pointer
        jmp   .next           ; do it again
.done:  pop   dx              ; restore dx
        pop   bx              ; restore bx
        pop   bp              ; restore original base pointer
        ret


; enablea20
; function to enable the a20 gate on a processor
; allows access to greater range of memory
; input: none
; output: (in ax) 0 on success, 1 on failure
enablea20:
          call  wait_for_kbd_in   ; wait for kbd to clear

          mov   al, 0D0h          ; command to read status
          out   64h, al

          call  wait_for_kbd_out  ; wait for kbd to have data

          xor   ax, ax            ; clear ax 
          in    al, 60h           ; get data from kbd
          push  ax                ; save value
          
          call  wait_for_kbd_in   ; wait for keyboard to clear
          mov   al, 0D1h          ; command to write status
          out   64h, al
          call  wait_for_kbd_in   ; wait for keyboard to clear
          pop   ax                ; get the old value 
          or    al, 00000010b     ; flip A20 bit
          out   60h, al           ; write it back

          call  wait_for_kbd_in   ; double check that it worked
          mov   al, 0D0h          ; same process as above to read 
          out   64h, al
          
          call  wait_for_kbd_out
          xor   ax,ax
          in    al, 60h
          bt    ax, 1             ; is the A20 bit enabled?
          jc    .success
          
          mov   ax, 1             ; code that we failed
          jmp   .return 
         
          .success:
          mov   ax, 0             ; code that we succeeded
  
          .return:  
          ret 

; wait_for_kbd_in
; checks to see whether keyboard controller can be written to
wait_for_kbd_in:
          in    al, 64h          ; read the port
          bt    ax, 1            ; see if bit 1 is 0 or not
          jc    wait_for_kbd_in  ; if it isn't, loop
          ret   

; wait_for_kbd_out
; checks to see whether keyboard controller can be written to
wait_for_kbd_out:
          in    al, 64h          ; read the port
          bt    ax, 0            ; see if bit 0 is 1 or not
          jnc   wait_for_kbd_out  ; if it isn't, loop
          ret  

;	loadgdt 
; loads the gdt
loadgdt: 
				xor		ax, ax						; clear ax
				mov		ds, ax						; clear ds - base of descriptor
				lgdt	[gdt_desc]				; load the gdt
				mov		ax, 0							; setup return success
				ret

; loadkernel
; loads kernel to 1mb mark (0x100000)
; BIOS can't write above 1mb, so we have to write to 0x1000
; and then move it up to 0x100000 (because we're in unreal mode)
;
; So naturally, this procedure requires that we be in unreal mode before entering.
; Could use this to load 
loadkernel:
            reset_drive:        ; have to reset the drive
            mov   ah,0
            int   13h
            or    ah,ah 
            jnz   reset_drive   ; if errorcode (ah) is not zero, try again
            mov   ax, 0
            mov   es, ax        ; base addr is zero, we're in real
            mov   ebx, 1000h    ; place to load kernel - has to be in realmem
            mov   ah, 02h       ; command to read
            mov   al, 02h       ; number of sectors to read
            mov   ch, 0         ; cylinder
            mov   cl, 02h       ; sector to start (addr starts at 1)
            mov   dh, 0         ; disk head
                                ; dl = drive, already set by bios
            int   13h           ; do it!
            or    ah, ah        ; check to see if we succeeded
            jz    .succeed
            mov   ax,1
            jmp  .end
            .succeed:
            mov   esi,00001000h   ; now we move it to 1mb
            mov   edi,00100000h   ; we can do this, because of unreal mode!
            mov   ax,ds           ; moving with a base of ds b/c in real mode
            mov   es,ax
            mov   cx,256          ; 256*4 = 1024bytes
            a32 rep movsd         ; 'a32' tells it to use esi/edi instead of si/di
            mov   ax,0            ; error code = success
            .end:
            ret

; start_pmode
; label in 32bit assembly used in the far jump to clear pipeline for switching from
; real16bit to protected32bit mode
[BITS 32]
start_pmode:
            mov ax, 08h         ; need to load data segment into ds/ss
            mov ds, ax
            mov ss, ax
            mov esp, 090000h    ; move stack pointer to 090000h, gives us a 65kb stack
                                ; this is probably a weird place for a stack long term
            jmp 10h:100000h     ; jump to kernel loaded at 1mb

;----------------------------------------------------------
; Data
; GDT
gdt:      dq 	0									      ; need a null segment
          dw  0FFFFh, 0, 9200h, 0CFh  ; data
          dw  0FFFFh, 0, 9A00h, 0CFh  ; code
gdt_end:
gdt_desc:
					dw	gdt_end - gdt - 1       ; first word is expected to be size of gdt-1
					dd	gdt                     ; then the gdt address

; Strings for printing status
statusd           db  'Done',13,10,0
statusf           db  'Fail',13,10,0
statusa20         db  'Enabling A20...',0
statusgdt         db  'Loading GDT...',0
statuskern        db  'Loading Kernel...',0
statuspmode				db  'Switching to PMode...',0

; end-of-file standard bootloader stuff
;  has to be 512 bytes
;  has to end with 55AA
times 510-($-$$) db 0      ; pad with zeros
dw 0xAA55                  ; write bootsector sig

