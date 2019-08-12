; mem.asm
;
; Memory manipulation subroutines

; Zeros out the memory in AVR studio (rjmp into here)
avr_studio_reset:		; Clear all memory 
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

; Copy a0 bytes from Z to Y
; in	a0,Y,Z
; mod	w,a0,Y,Z
memcpyYZ:
	ld	w,Z+	; Load byte
	st	Y+,w	; Store byte
	dec	a0
	breq	PC+2	; (loop end)
	rjmp	PC-4	; (loop again)
	ret
