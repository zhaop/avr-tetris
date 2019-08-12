; area51.asm
;
; Test things here (set this as entry file to use)
; Not used in tetris.asm

.include "m103def.inc"
.include "macros.asm"
.include "definitions.asm"

.dseg

.cseg
.org	0x00
	rjmp	reset
.org	0x30

reset:	LDSP	RAMEND
	OUTI	DDRB,0xff	; Set LEDs as output
	OUTI	PIND,0xff	; Active-low buttons off by default
	ldi	yh,high(0x60)
	ldi	yl,low(0x60) 
	clr	w
	com	w
	ldi	_w,high(ramend+1) 
clr_mem_loop:
	st	y+,w
	cpi	yl,low(ramend+1); Compare low byte 
	cpc	yh,_w		; Compare high byte 
	brne	clr_mem_loop
	nop

init:
	rjmp	main

main:
	in	w,PIND
	out	PORTB,w
	rjmp	main

end:	rjmp	end
