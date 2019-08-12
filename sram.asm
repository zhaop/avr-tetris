; sram.asm
;
; sram_canvas related functions

; Draw entire UI inside SRAM
; in	piece,grid_buffer,sram_canvas
; mod	X, Y, a0, a1, a2, w
.dseg
sram_canvas_spacer:
	.byte	5	; Squeeze some space so the canvas starts on a new row
sram_canvas:
	.byte	384	; 24 rows * 16 columns

.cseg
SRAM_draw_ui:
	ldi	YH,high(sram_canvas)
	ldi	YL,low(sram_canvas)
	
	ldi	XH,high(ui)	; Skip drawing top 2 rows (4 bytes)
	ldi	XL,low(ui)
	ldi	a0,48	; 22 rows * 2 8-bit bytes per 16-bit byte
SRAM_loop1:
	ldi	a1,8	; 8 bits
	ld	a2,X+
SRAM_loop2:
	lsl	a2
	ldi	w,' '
	brcc	PC+2
	ldi	w,'O'
	st	Y+,w	; Draw character
	dec	a1	; Advance tile
	breq	PC+2
	rjmp	SRAM_loop2
	
	dec	a0
	breq	PC+2
	rjmp	SRAM_loop1

	ret
