# Makefile for bootloader`

all: cd flp 

cd: cdboot.bin stage2.bin

flp: boot.bin

cdboot.bin: cdboot.S
	nasm -o cdboot.bin cdboot.S

boot.bin: boot.S
	nasm -o boot.bin boot.S

stage2.bin: stage2.S
	nasm -o stage2.bin stage2.S

clean:
	rm -rf *.bin *~
