
; file	puts.asm	; display an ASCII string
.include "m103def.inc"
.include "macros.asm"
.include "definitions.asm"

reset:
	LDSP	RAMEND
	rcall	LCD_init
	rjmp	main
.include "lcd.asm"

str0:
.db	"hello world",0

main:	
	ldi	r16,str0
	ldi	zl, low(2*str0)	; load pointer to string
	ldi	zh,high
	rcall	LCD_putstring	; display string
	rjmp	PC		; infinite loop

LCD_putstring:
; in	z 
	 			; load program memory into r0
	tst	 		; test for end of string
	breq	 
	mov	 		; load argument
	rcall	LCD_putc
	adiw	 		; increase pointer address
	rjmp	 		; restart until end of string
done:	ret