[BITS 32]
[GLOBAL start_kernel]
[EXTERN	kmain]
start_kernel:
    cli
    mov   dword [0b8000h], "K N "
		call	kmain
    mov   dword [0b8000h], "K R "
		
		sti	
.end:hlt
		jmp		.end
;times 1000000 db 0
