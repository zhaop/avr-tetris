; leds.asm
;
; Interface to the low-level HT1624 driver.

.include "ht1624.asm"

; mod	w
.macro	REVERSE	; dst,src
	ldi	w,8
reverse_lp:
	ror	@1
	rol	@0
	dec	w
	brne	reverse_lp
.endmacro

leds_init:
	rcall	ht_init
	ret

; Redraw the entire thing on our LED matrix
leds_draw_ui:

	rcall	ht_startdata

	LDIX	ui

	ldi	w,24		; For each of the 24 rows
	push	w

_leds_draw_ui_0:
	pop	w
	tst	w
	breq	_leds_draw_ui_end; (loop end)
	dec	w
	push	w

	ld	a1,X+
	REVERSE	a0,a1
	push	a0		; This half gets drawn later
	
	ld	a1,X+
	REVERSE	a0,a1
	ldi	b0,1<<7
	rcall	ht_writebits

	pop	a0		; (screwy screen drawing logic)
	ldi	b0,1<<7
	rcall	ht_writebits

	rjmp	_leds_draw_ui_0

_leds_draw_ui_end:
	rcall	ht_enddata

	ret

; Flash the entire matrix panel (soft)
; Good choice for line clears
; mod	w,a0
leds_flash:
	CA	ht_sendcmd,HT_CMD_PWM14
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM13
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM12
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM13
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM14
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM15
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM14
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM13
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM12
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM13
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM14
	rcall	leds_wait_medium
	CA	ht_sendcmd,HT_CMD_PWM15
	ret

; Flash the entire matrix panel 4x (stronger)
; Good choice for game over
; mod	w,a0
leds_flash_strong:
	CA	ht_sendcmd,HT_CMD_PWM14
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM11
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM08
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM11
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM14
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM11
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM08
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM11
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM14
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM11
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM08
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM11
	rcall	leds_wait_long
	CA	ht_sendcmd,HT_CMD_PWM14
	ret

; Fade out using PWM (~0.375s)
; mod	w
leds_fadeout_fast:
	ldi	a0,HT_CMD_PWM15
	rcall	ht_sendcmd

	ldi	w,14		; Loop 14 times

	tst	w
	breq	PC+6		; (loop again)
	dec	w
	dec	a0
	rcall	leds_wait_short
	rcall	ht_sendcmd
	rjmp	PC-6		; (loop end)

	ret

; Fade in using PWM (~0.375s)
; mod	w
leds_fadein_fast:
	ldi	a0,HT_CMD_PWM01
	rcall	ht_sendcmd

	ldi	w,14		; Loop 14 times

	tst	w
	breq	PC+6		; (loop again)
	dec	w
	inc	a0
	rcall	leds_wait_short
	rcall	ht_sendcmd
	rjmp	PC-6		; (loop end)

	ret

; Fade in using PWM (~0.75s)
; mod	w
leds_fadein_slow:
	ldi	a0,HT_CMD_PWM01
	rcall	ht_sendcmd

	ldi	w,14		; Loop 14 times

	tst	w
	breq	PC+6		; (loop again)
	dec	w
	inc	a0
	rcall	leds_wait_long
	rcall	ht_sendcmd
	rjmp	PC-6		; (loop end)

	ret

; Wait slightly less than 49 ms
; mod	u
leds_wait_long:
	push	w	; Save w (nice when used inside loops)
	ldi	w,0xff
	rcall	leds_wait
	pop	w
	ret

; Wait slightly less than 20 ms
leds_wait_medium:
	push	w
	ldi	w,0x68
	rcall	leds_wait
	pop	w
	ret

; Wait slightly less than 10 ms
leds_wait_short:
	push	w
	ldi	w,0x34
	rcall	leds_wait
	pop	w
	ret

; Configurable wait period
; in	w (multiples of 191 us)
; mod	u,w
leds_wait:
	push	w
	ldi	w,0xff
	mov	u,w
	pop	w
	dec	u
	brne	PC-1	; Inner loop
	dec	u	; Adjustment for outer loop
	dec	w
	brne	PC-4	; Outer loop
	ret
