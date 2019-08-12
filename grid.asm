; grid.asm
;
; grid manipulation functions

.def	pceX =	r18	; a0
.def	pceY =	r19	; a1
.def	pce0 =	r20	; a2
.def	pce1 =	r21	; a3
.equ	PLAYFIELD_ROWS	= 22
.equ	GRID_ROWS	= 24

.dseg
grid:			; Tower already built goes here
	.byte	48	; 24 rows, 2 bytes/row
grid_buffer:
	.byte	48	; Buffer for drawing tower + curr piece
.cseg

.include "mem.asm"

; Merge piece & grid into grid_buffer
; in	piece, grid
; mod	a0,w,Y
; out	grid_buffer
grid_buffer_draw:
	ldi	a0,GRID_ROWS*2
	ldi	ZH,high(grid)
	ldi	ZL,low(grid)
	ldi	YH,high(grid_buffer)
	ldi	YL,low(grid_buffer)
	rcall	memcpyYZ

	; Draw piece
	LDIZ	piece
	ld	a0,Z+
	ld	a1,Z+
	rcall	piece_parse; a0 = x, a1 = y, a2:a3 = shape
	
	ldi	YH,high(grid_buffer)
	ldi	YL,low(grid_buffer)
	ADDY	pceY	; Skip to first row occupied by piece
	ADDY	pceY	; (add twice: 2 bytes per row)
	
	mov	b0,pce0	; Draw 1st row of shape
	andi	b0,0xf0
	rcall	grid_buffer_drawrow

	mov	b0,pce0	; Draw 2nd row of shape
	swap	b0
	andi	b0,0xf0
	rcall	grid_buffer_drawrow

	mov	b0,pce1	; Draw 3rd row of shape
	andi	b0,0xf0
	rcall	grid_buffer_drawrow

	mov	b0,pce1	; Draw 4th row of shape
	swap	b0
	andi	b0,0xf0
	rcall	grid_buffer_drawrow

	ret

; Draw one row (4 bits) onto grid_buffer + advance &Y to next row
; in:	Y (grid_buffer), a0 (pceX), b0 (shape)
; mod:	w, b0, b1
; out:	Y (grid_buffer)
grid_buffer_drawrow:
	clr	b1	; Make sure this b1 doesn't draw anything extra
	mov	w,a0

	tst	w
	breq	PC+5	; (loop end)
	dec	w
	LSR2	b0,b1	; 2 PC instructions
	rjmp	PC-5	; (loop again)

	ld	w,Y	; Draw left half
	or	w,b0
	st	Y+,w

	ld	w,Y	; Draw right half
	or	w,b1
	st	Y+,w
	
	ret

; Test if piece is colliding with grid, and set GREG_COLLISION appropriately
; in:	Z (piece)
; out:	GREG_COLLISION
grid_test_collision:
	ld	a0,Z+
	ld	a1,Z+
	rcall	piece_parse

	ldi	YH,high(grid)
	ldi	YL,low(grid)
	ADDY	pceY	; Skip to first row occupied by piece
	ADDY	pceY	; (add twice: 2 bytes per row)
	
	mov	b0,pce0	; Test 1st row of shape
	andi	b0,0xf0
	rcall	grid_testrow

	mov	b0,pce0	; Test 2nd row of shape
	swap	b0
	andi	b0,0xf0
	rcall	grid_testrow

	mov	b0,pce1	; Test 3rd row of shape
	andi	b0,0xf0
	rcall	grid_testrow

	mov	b0,pce1	; Test 4th row of shape
	swap	b0
	andi	b0,0xf0
	rcall	grid_testrow

	ret

; Test one row for collision with existing grid + advance &Y to next row
; in:	Y (grid), a0 (pceX), b0 (shape row)
; mod:	w, b0, b1
; out:	GREG_COLLISION if 1
grid_testrow:
	clr	b1	; Make sure this b1 doesn't test anything extra
	mov	w,a0

	tst	w
	breq	PC+5	; (loop end)
	dec	w
	LSR2	b0,b1	; 2 PC instructions
	rjmp	PC-5	; (loop again)

	ld	w,Y+	; Test left half
	and	w,b0
	brne	_grid_testrow_collides; Break if collision

	ld	w,Y+	; Test right half
	and	w,b1
	brne	_grid_testrow_collides; Break if collision

	ret
_grid_testrow_collides:
	GREG_SE	GREG_COLLISION
	ret

; "Bake" piece into grid (actually copy grid_buffer into grid)
; in	grid_buffer
; mod	Y,Z
; out	grid
grid_bake:
	ldi	a0,GRID_ROWS*2
	ldi	ZH,high(grid_buffer)
	ldi	ZL,low(grid_buffer)
	ldi	YH,high(grid)
	ldi	YL,low(grid)
	rcall	memcpyYZ

	ret

; Looks for filled lines in grid
; (start at bottom since most filled lines are at bottom)
; in	grid
; mod	u,w,X
; out	T (0 if there are no full lines, 1 if there is at least one full line)
grid_has_full:
	clt

	LDIX	grid
	adiw	xh:xl,PLAYFIELD_ROWS	; Point to right after bottom-right half
	adiw	xh:xl,PLAYFIELD_ROWS	; and work our way upwards-leftwards
	ldi	w,PLAYFIELD_ROWS

_grid_hf_0:
	tst	w
	brne	PC+2
	ret				; Done: no filled lines

	dec	w
	ld	u,-X
	com	u			; If line filled, ~u = 0
	breq	PC+2			; Branch if left-half is filled
	rjmp	_grid_hf_0

	ld	u,-X
	com	u
	brne	_grid_hf_0	; Continue if right-half is filled

	set				; Done: has filled lines
	ret

; Removes filled lines in grid
; in	grid
; mod	u,w,a0,Y
; out	grid
grid_clear_lines:		; First, push unfilled rows
	ldi	w,PLAYFIELD_ROWS
	clr	u			; Counts how many lines cleared
	
	ldi	a1,0b11100000		; Left wall
	ldi	a2,0b00000111		; Right wall
	LDIY	grid

_grid_cl_lp0:			; Loop about 22 times (over w)
	tst	w
	brne	PC+2
	rjmp	_grid_cl_1
	dec	w

	ldd	a0,Y+0			; Check whether full line or not
	com	a0
	brne	_grid_cl_unfull	; Branch if left-half not filled
	ldd	a0,Y+1
	com	a0
	breq	_grid_cl_full	; Branch if right-half filled
_grid_cl_unfull:
	ld	a0,Y
	push	a0			; Push entire row
	st	Y+,a1			; then draw left + right walls
	ld	a0,Y
	push	a0
	st	Y+,a2
	rjmp	_grid_cl_lp0
_grid_cl_full:
	inc	u
	st	Y+,a1			; Draw left + right walls
	st	Y+,a2
	rjmp	_grid_cl_lp0

_grid_cl_1:			; Pop stack back into grid_buffer
	ldi	w,PLAYFIELD_ROWS
	sub	w,u

_grid_cl_lp1:			; Loop about {22 - lines_cleared} times
	tst	w
	brne	PC+2
	rjmp	_grid_cl_2
	dec	w

	pop	a0
	st	-Y,a0
	pop	a0
	st	-Y,a0
	rjmp	_grid_cl_lp1

_grid_cl_2:			; Increase score (if applicable)
	mov	w,u
	tst	w
	brne	PC+2
	ret				; Done: no lines were cleared

	cpi	w,4
	brlt	PC+3
	rcall	score_tetris
	ret

	cpi	w,3
	brlt	PC+3
	rcall	score_triple
	ret

	cpi	w,2
	brlt	PC+3
	rcall	score_double
	ret

	cpi	w,1
	brlt	PC+3
	rcall	score_single
	ret
