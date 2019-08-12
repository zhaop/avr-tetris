; random.asm
;
; Generates random numbers and pieces

.dseg
lfsr:			; Linear feedback shift register
	.byte	2	; Left: low bit, right: high bit

.cseg
; Seed random with initial value
; in	a1:a0
rand_seed:
	STS2	lfsr,a1,a0
	ret

; Return a random number between 0 and 1 using a 16-bit LFSR
; in	lfsr
; mod	w,a0,a1,lfsr
rand1:
	LDS2	a1,a0,lfsr	; lfsr:	a0 := low bit | a1 := high bit

	ldi	w,0x00
	EORB	w,0,a0,0,a0,2	; w := b16 ^ b14
	EORB	w,0, w,0,a0,3	; w ^= b13
	EORB	w,0, w,0,a0,5	; w ^= b11

	bst	w,0		; C := T := w(0)
	clc
	brtc	PC+2
	sec

	ROR2	a1,a0
	STS2	lfsr,a1,a0
	ret

; Return a 3-bit random number in range 0 thru 7
; in	lfsr
; mod	w,a0,a1,lfsr
; out	b0
rand3:
	ldi	b0,0x00
	rcall	rand1
	brtc	PC+2
	ori	b0,1<<0
	rcall	rand1
	brtc	PC+2
	ori	b0,1<<1
	rcall	rand1
	brtc	PC+2
	ori	b0,1<<2
	ret

; Return a 3-bit random number in range 0 thru a0
; in	a0
; mod	w,a0,a1,lfsr
; out	b0
randi3:
	push	a0
	rcall	rand3
	pop	a0
	cp	a0,b0
	brge	PC+2	; Branch if a0 >= b0
	rjmp	randi3
	ret

