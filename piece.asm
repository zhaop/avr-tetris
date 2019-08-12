; piece.asm
;
; Piece manipulation and format parsing subroutines
; + piece bitmap definitions

.dseg
piece:
	.byte	2	; xxxx 0ppp rr0y yyyy
piece_try:
	.byte	2	; xxxx 0ppp rr0y yyyy
piece_try2:
	.byte	2	; xxxx 0ppp rr0y yyyy
piece_hold:
	.byte	2	; xxxx 0ppp rr0y yyyy
piece_queue:
	.byte	6	; 3 pieces (right in, left out)

.cseg

.include "random.asm"

; Initialize pieces to default their default value:
; piece: Random piece, rot 0, x = 7, y = 1
; piece_try: piece 0, rot 0, x = 0, y = 0
; piece_hold: piece 8, rot 1, x = 0, y = 0
; mod	a0,a1,b0,X
; out	piece,piece_try,piece_hold
piece_init:
	LDIX	piece_try	; Default empty piece_try
	ldi	a1,0x07
	st	X+,a1
	st	X+,a1
	LDIX	piece_try2	; Default empty piece_try2 too
	st	X+,a1
	st	X+,a1

	LDIX	piece_hold
	ldi	a1,0x07		; Default empty hold piece
	st	X+,a1
	st	X+,a1

	rcall	piece_next	; Generate first piece
	rcall	piece_next	; Generate next 3 pieces (this inits piece_queue)
	rcall	piece_next
	rcall	piece_next
	LDIX	piece		; Store first piece into "piece"
	st	X+,a0
	st	X+,a1
	
	ret

; Try moving piece one cell left
; in	X (source piece), Y (destination piece)
; mod	w
piece_left:
	ld	w,X+
	subi	w,0b00010000	; Ignoring cornercase where x=0 (trust collision detection)
	st	Y+,w

	ld	w,X+
	st	Y+,w

	ret

; Try moving piece one cell right
; in	X (source piece), Y (destination piece)
; mod	w
piece_right:
	ld	w,X+
	ADDI	w,0b00010000
	st	Y+,w

	ld	w,X+
	st	Y+,w

	ret

; Try spinning piece one quarter-turn left (counter-clockwise)
; in	X (source piece), Y (destination piece)
; mod	w
piece_rot_left:
	ld	w,X+
	st	Y+,w

	ld	w,X+
	subi	w,0b01000000
	st	Y+,w

	ret

; Try spinning piece one quarter-turn right (clockwise)
; in	X (source piece), Y (destination piece)
; mod	w
piece_rot_right:
	ld	w,X+
	st	Y+,w

	ld	w,X+
	ADDI	w,0b01000000
	st	Y+,w

	ret

; Try moving piece one cell down
; in	X (source piece), Y (destination piece)
; mod	w
piece_down:
	ld	w,X+
	st	Y+,w

	ld	w,X+
	ADDI	w,0b00000001
	andi	w,0b11011111	; Clear possible carry (bit 5)
	st	Y+,w

	ret

; Try moving piece one cell up
; in	X (source piece), Y (destination piece)
; mod	w
piece_up:
	ld	w,X+
	st	Y+,w

	ld	w,X+
	subi	w,0b00000001	; Ignoring cornercase where y = 0
	st	Y+,w

	ret

; Set current piece as the one indicated by pointer X
; in	X (source piece)
; mod	w
piece_set:
	ld	w,X+
	sts	piece,w
	ld	w,X+
	sts	piece+1,w
	ret

; Put new piece at end of queue, pop next piece out of left end of queue
; mod	w,Y
; out	a0,a1
piece_next:
	LDIY	piece_queue
	ldd	w,Y+1		; Get next piece first and save it
	push	w
	ldd	w,Y+0
	push	w		; (piece pops out in the right order: a0 then a1)

	ldd	w,Y+2		; Shift the rest of the queue
	std	Y+0,w
	ldd	w,Y+3
	std	Y+1,w
	ldd	w,Y+4
	std	Y+2,w
	ldd	w,Y+5
	std	Y+3,w

	rcall	_piece_generate	; Generate new piece
	std	Y+4,a0		; and put it into queue
	std	Y+5,a1

	pop	a0		; "Return" popped piece
	pop	a1

	ret

; (private) Generate next piece and put inside a0:a1
; mod	w,b0
; out	a0,a1
_piece_generate:
	CA	randi3,0x06	; Give us a random number
	ldi	a0,0x70		; x=7, piece to be determined
	or	a0,b0
	ldi	a1,0x01		; r=0, y=1
	ret

; Swap current piece with hold piece
; or put current piece into hold and get next
; mod	a0,a1,a2,a3
piece_swap_hold:

	GREG_LD	GREG_NO_HOLD	; Last piece was held, so don't allow again
	brtc	PC+2
	ret

	GREG_SE	GREG_NO_HOLD	; Forbid holding immediately after
	rcall	timer_reset
	GREG_SE	GREG_REDRAW

	lds	w,piece_hold
	andi	w,0x0f

	cpi	w,0x07		; Hold is empty?
	breq	_piece_sh_empty
				; Hold not empty: swap current piece with hold
	lds	a0,piece
	andi	a0,0x0f		; Get only piece type
	lds	a2,piece_hold
	andi	a2,0x0f

	ldi	a1,0x40		; a0:a1 goes into hold (set rot=1)
	ori	a2,0x70		; a2:a3 goes into playfield
	ldi	a3,0x01		; (x=7, rot=0, y=1)

	sts	piece_hold+0,a0
	sts	piece_hold+1,a1
	sts	piece+0,a2
	sts	piece+1,a3
	ret
_piece_sh_empty:		; Hold empty: put current piece into hold then get next
	lds	a0,piece
	andi	a0,0x07		; Get only piece type
	ldi	a1,0x40		; (set rot=1)

	sts	piece_hold+0,a0
	sts	piece_hold+1,a1

	rcall	piece_next
	sts	piece+0,a0
	sts	piece+1,a1
	ret

; Get piece info
; xxxx 0ppp rr0y yyyy
; in	a0:a1 (piece)
; mod	w,Z
; out	a0,a1,a2,a3 (a0 = x, a1 = y, a2:a3 = shape)
piece_parse:
	mov	a2,a0	; a2 = a0
	andi	a0,0xf0	; a0: keep only first 4 bits (xxxx)
	swap	a0
	andi	a2,0x07	; a2: keep only last 3 bits (ppp)
	mov	a3,a1	; a1 = a3
	andi	a3,0xc0	; a3: keep only first 2 bits (rr)
	swap	a3
	lsr	a3
	lsr	a3
	andi	a1,0x1f	; a1: keep only last 5 bits (y yyyy)

; (private) Load piece shape
; in	a2,a3 (a2 = p, a3 = r)
; mod	w,Z
; out	a2,a3 (a2:a3 = shape)
_piece_shape:
	ldi	ZH,high(pieces)
	ldi	ZL,low(pieces)
	mov	w,a2

	tst	w
	breq	PC+4	; (loop end)
	adiw	ZH:ZL,4	; Jump to piece (+4 for each piece)
	dec	w
	rjmp	PC-4	; (loop again)

	ldi	w,0
	add	zl,a3	; Jump to rotation
	adc	zh,w
	MUL2Z		; Multiply Z by 2 (to access program memory)
	lpm
	mov	a3,r0
	adiw	zh:zl,1	; Next shape byte
	lpm
	mov	a2,r0	; In program memory the high/low bytes are swapped
	ret

; Bitmaps of all possible pieces and rotations
pieces:			; Each rotation is 16 bits; each piece is 64 bits
	.dw	0x0f00, 0x2222, 0x00f0, 0x4444	; I
	.dw	0x8e00, 0x6440, 0x0e20, 0x44c0	; J
	.dw	0x2e00, 0x4460, 0x0e80, 0xc440	; L
	.dw	0x6600, 0x6600, 0x6600, 0x6600	; O
	.dw	0x6c00, 0x4620, 0x06c0, 0x8c40	; S
	.dw	0x4e00, 0x4640, 0x0e40, 0x4c40	; T
	.dw	0xc600, 0x2640, 0x0c60, 0x4c80	; Z
	.dw	0x0000, 0x0000, 0x0000, 0x0000	; (none)
