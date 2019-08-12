; game.asm
;
; Handles drawing the UI, keeping score, etc.

.cseg

; Timer 0 compare match interrupt
; out	greg
t0comp:
	push	w		; Save w
	in	_sreg,SREG	; Save SREG
	
	GREG_SE	GREG_TICK

	out	SREG,_sreg	; Restore SREG
	pop	w		; Restore w
	reti

; Extend timer by at most 0.125s
; mod	w,a0
.equ	LOCK_DELAY = 0x10	; By steps of 1/128 seconds
timer_extend:
	in	w,OCR0
	in	a0,TCNT0
	sub	w,a0	; w = OCR0 - TCNT0
	subi	w,LOCK_DELAY
	brpl	PC+3	; Branch if w >= LOCK_DELAY
	subi	a0,LOCK_DELAY
	out	TCNT0,a0; TCNT -= 0x20
	ret

; Resets timer
; mod	w
timer_reset:
	OUTI	TCNT0,0x00
	ret

; Play 3... 2... 1... (game_start!)
; mod	Z
game_launch:
	LDIZ	2*bmp_launch1
	rcall	launch_item

	LDIZ	2*bmp_launch2
	rcall	launch_item

	LDIZ	2*bmp_launch3
	rcall	launch_item

	rjmp	game_start

; Show one launch sequence item on LED matrix
; Lasts ~0.8 seconds
; in	Z (program-memory location)
; mod	w,a0,X,Z
launch_item:
	rcall	draw_bmp
	rcall	leds_fadein_fast
	WAIT_MS	630
	rcall	leds_fadeout_fast
	ret

; Draw one fullscreen static image (must be 16 wide & 10 high)
; in	Z (program-memory location)
; mod	w,a0,X,Z
draw_bmp:
	LDIX	ui	; Blank entire screen
	ldi	w,48
	ldi	a0,0x00

	tst	w
	breq	PC+4
	dec	w
	st	X+,a0
	rjmp	PC-4

	LDIX	ui+14	; Start near the vertical middle
	ldi	w,20

	tst	w
	breq	PC+6
	dec	w
	lpm
	st	X+,r0
	adiw	zh:zl,1
	rjmp	PC-6
	
	rcall	draw_ui
	ret

; Initialize memory for game loop
; in	a0 (starting level)
; mod	x, a0, a1, a2
game_start:
	OUTI	TCCR0,0b00001110 ; prescaler = 1/256
	OUTI	TIMSK,1<<OCIE0	; Activate timer0 interrupt
	OUTI	OCR0,112

	rcall	piece_init
	rcall	keys_init
	rcall	score_init

	ldi	XH,high(grid)	; Load grid
	ldi	XL,low(grid)
	ldi	a0,22		; Top 22 rows first
	ldi	a1,0b11100000	; Left half
	ldi	a2,0b00000111	; Right half

	st	X+,a1
	st	X+,a2
	dec	a0
	breq	PC+2		; (loop end)
	rjmp	PC-4		; (loop again)

	ldi	a1,0b11111111	; Bottom 2 rows (wall)
	st	X+,a1
	st	X+,a1
	st	X+,a1
	st	X+,a1

	lds	b0,level_select	; Get to the requested starting level

	cpi	b0,1		; level_select-- until we get to one
	breq	PC+4		; (loop end)
	dec	b0
	rcall	level_up
	rjmp	PC-4		; (loop again)

	rcall	score_display

	rcall	grid_buffer_draw; grid_buffer := grid + piece
	rcall	ui_render

	rcall	leds_fadein_fast

	rjmp	game

; Game loop: process input, process flags, repeat
; in	PIND
; mod	a0
game:
	GREG_RESET	1<<GREG_TICK | 1<<GREG_NO_HOLD | 1<<GREG_REDRAW

	; Process new key presses
	rcall	keys_process

	KEYS_PRESS	BTN_LEFT
	brtc	PC+2
	rcall	press_left

	KEYS_PRESS	BTN_RIGHT
	brtc	PC+2
	rcall	press_right

	KEYS_PRESS	BTN_ROT_LEFT
	brtc	PC+2
	rcall	press_rot_left

	KEYS_PRESS	BTN_ROT_RIGHT
	brtc	PC+2
	rcall	press_rot_right

	KEYS_PRESS	BTN_SOFT_DROP
	brtc	PC+2
	rcall	press_soft_drop

	KEYS_PRESS	BTN_HARD_DROP
	brtc	PC+2
	rcall	press_hard_drop

	KEYS_PRESS	BTN_HOLD
	brtc	PC+2
	rcall	press_hold

	KEYS_PRESS	BTN_PAUSE
	brtc	PC+2
	rcall	press_pause

	GREG_LD	GREG_TICK
	brtc	PC+2
	rcall	game_tick

	GREG_LD	GREG_GAME_OVER
	brtc	PC+2
	rjmp	game_over

	GREG_LD	GREG_REDRAW	; If flag set, redraw everything
	brtc	regame
	GREG_CL	GREG_REDRAW
	rcall	grid_buffer_draw
	rcall	ui_render

regame:	rjmp	game

; Coming back from the pause menu
game_resume:
	OUTI	TCCR0,0b00001110 ; Set prescaler = 1/256
	
	rcall	score_display

	rcall	leds_fadeout_fast
	rcall	ui_render
	rcall	leds_fadein_fast

	rjmp	game

; mod	w
press_left:
	CXY	piece_left,piece,piece_try
	rcall	try_move

	GREG_LD	GREG_COLLISION
	brts	PC+2
	rcall	timer_extend

	ret
	
; mod	w
press_right:
	CXY	piece_right,piece,piece_try
	rcall	try_move
	
	GREG_LD	GREG_COLLISION
	brts	PC+2
	rcall	timer_extend
	
	ret
	
; mod	w
press_rot_left:
	GREG_SE	GREG_CHECK_KICK
	CXY	piece_rot_left,piece,piece_try
	rcall	try_move
	
	GREG_LD	GREG_COLLISION
	brts	PC+2
	rcall	timer_extend
	
	ret

; mod	w
press_rot_right:
	GREG_SE	GREG_CHECK_KICK
	CXY	piece_rot_right,piece,piece_try
	rcall	try_move
	
	GREG_LD	GREG_COLLISION
	brts	PC+2
	rcall	timer_extend
	
	ret

; mod	w
press_soft_drop:
	CXY	piece_down,piece,piece_try
	rcall	try_move

	GREG_LD	GREG_COLLISION
	brts	PC+2		; If success, score points.
	rcall	score_soft_drop
	ret

; mod	w,X,Y, ...
; FIXME: Infinite loop when PAUSE & HARD_DROP & ROT_LEFT & LEFT pressed simultaneously
press_hard_drop:

	GREG_CL	GREG_COLLISION
	CXY	piece_down,piece,piece_try; Just go down until we're there
	rcall	try_move
	
	GREG_LD	GREG_COLLISION
	brts	PC+3			; We're there (at the bottom)
	rcall	score_hard_drop
	rjmp	press_hard_drop

	rcall	timer_reset
	GREG_SE	GREG_TICK
	ret

press_hold:
	rcall	piece_swap_hold
	ret

press_pause:
	OUTI	TCCR0,0x00	; prescaler = 1/256

	rcall	leds_fadeout_fast
	
	LDIZ	2*bmp_pause
	rcall	draw_bmp

	rcall	leds_fadein_fast
	
	rjmp	menu_pause
	ret

; Process game tick (move down, lock, next piece, clear lines)
game_tick:
	GREG_CL	GREG_TICK

	GREG_CL	GREG_COLLISION	; Clear previous collision flag (we don't need it anymore)
	CXY	piece_down,piece,piece_try
	rcall	try_move

	GREG_LD	GREG_COLLISION	; If collision, we've reached the bottom
	brts	PC+2		; so there's more work to do
	ret

	GREG_CL	GREG_NO_HOLD	; Reactivate hold function

	rcall	grid_buffer_draw; Force redraw before baking
	rcall	grid_bake

	rcall	grid_has_full
	brtc	PC+4
	rcall	ui_render
	rcall	grid_clear_lines
	rcall	leds_flash


	rcall	piece_next
	sts	piece+0,a0
	sts	piece+1,a1

	GREG_CL	GREG_COLLISION
	LDIZ	piece
	rcall	grid_test_collision
	
	GREG_LD	GREG_COLLISION
	brtc	_game_tick_end	; No tower collision, is good
	GREG_SE	GREG_GAME_OVER

_game_tick_end:
	GREG_SE	GREG_REDRAW
	ret

; Validate piece_try; if valid, copy into piece; otherwise, try kicks
; (check out http://tetrisconcept.net/wiki/SRS#Wall_Kicks)
; in	piece_try,grid
; out	piece,GREG_REDRAW
try_move:
	LDIZ	piece_try
	rcall	grid_test_collision

	GREG_LD	GREG_COLLISION
	brtc	_try_move_valid		; If no collision, then it's fine
	GREG_LD	GREG_CHECK_KICK
	brts	_try_move1		; If collision AND check_kick, branch
	rjmp	_try_move_invalid	; Otherwise, return (invalid)

_try_move_valid:
	CX	piece_set,piece_try	; Move is valid, set new piece state
	GREG_SE	GREG_REDRAW
	ret				; For valid moves, subroutine ends here

_try_move1:				; Right-wall kick
	CXY	piece_left,piece_try,piece_try2
	
	GREG_CL	GREG_COLLISION		; Clear previous collision flag
	LDIZ	piece_try2		; Test collision
	rcall	grid_test_collision

	GREG_LD	GREG_COLLISION
	brts	_try_move2		; If collision, try something else
	rjmp	_try_move_kicked
	
_try_move2:				; Left-wall kick
	CXY	piece_right,piece_try,piece_try2

	GREG_CL	GREG_COLLISION		; Clear previous collision flag
	LDIZ	piece_try2		; Test collision again
	rcall	grid_test_collision

	GREG_LD	GREG_COLLISION		; This collision flag is left on
	brts	_try_move3
	rjmp	_try_move_kicked

_try_move3:				; Floor kick
	CXY	piece_up,piece_try,piece_try2

	GREG_CL	GREG_COLLISION		; Clear previous collision flag
	LDIZ	piece_try2		; Test collision again again
	rcall	grid_test_collision

	GREG_LD	GREG_COLLISION
	brts	_try_move_invalid
	rjmp	_try_move_kicked

_try_move_kicked:
	CX	piece_set,piece_try2	; Move is valid, set new (kicked) piece state
	GREG_SE	GREG_REDRAW
	ret

_try_move_invalid:
	ret

; Render the game interface
ui_render:
	LDIX	ui
	ldi	w,0x00
	st	X+,w
	st	X+,w

	lds	w,level		; w := level
	ldi	a0,0x00
	ldi	a1,0x00

	tst	w
	breq	PC+6		; (loop end)
	dec	w
	sec
	ror	a0
	ror	a1
	rjmp	PC-6		; (loop again)

	st	X+,a0
	st	X+,a1
	st	X+,w
	st	X+,w

	ldi	w,0xff
	st	X+,w
	ldi	w,0xf0
	st	X+,w		; Y now on 4th row

	LDIY	grid_buffer+4	; Skip grid_buffer's top 2 rows
	ldi	w,20		; Draw 20 playfield rows
_ui_render_0:
	tst	w
	breq	_ui_render_1	; (loop end)
	dec	w

	ld	a0,Y+
	ld	a1,Y+
	LSL2	a0,a1		; Start at x=2 (left-shift twice)
	LSL2	a0,a1
	andi	a1,0xf0		; Leave blank 4 columns at the right
	st	X+,a0
	st	X+,a1
	rjmp	_ui_render_0	; (loop again)

_ui_render_1:
	LDIX	ui+37		; Draw hold piece frame
	ld	w,X
	ori	w,0x0f
	st	X,w

	lds	a0,piece_queue	; Draw next pieces
	ldi	a1,0x40		; Set rot=1
	rcall	piece_parse
	LDIY	ui+7
	rcall	ui_render_piece

	lds	a0,piece_queue+2
	ldi	a1,0x40
	rcall	piece_parse
	LDIY	ui+17
	rcall	ui_render_piece

	lds	a0,piece_queue+4
	ldi	a1,0x40
	rcall	piece_parse
	LDIY	ui+27
	rcall	ui_render_piece

	lds	a0,piece_hold	; Draw hold piece
	ldi	a1,0x40
	rcall	piece_parse
	LDIY	ui+41
	rcall	ui_render_piece

	rcall	draw_ui
	ret

; Draw a piece onto UI (to the right nibble of byte)
; in	Y (ui location), a2:a3 (shape)
; mod	a0,a1,ui
ui_render_piece:

	mov	a0,a2
	andi	a0,0xf0		; Get piece top row
	swap	a0
	ldd	a1,Y+0
	or	a1,a0
	std	Y+0,a1

	mov	a0,a2
	andi	a0,0x0f		; Get piece 2nd row
	ldd	a1,Y+2
	or	a1,a0
	std	Y+2,a1

	mov	a0,a3
	andi	a0,0xf0		; Get piece 3rd row
	swap	a0
	ldd	a1,Y+4
	or	a1,a0
	std	Y+4,a1

	mov	a0,a3
	andi	a0,0x0f		; Get piece 4th row
	ldd	a1,Y+6
	or	a1,a0
	std	Y+6,a1

	ret

; Display "LOL" on game over screen
game_over:
	OUTI	TIMSK,0x00

	rcall	leds_flash_strong

	LDIX	grid_buffer

	ADIW	xh:xl,4

	ldi	w,0b11100000
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	
	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100111
	st	X+,w
	ldi	w,0b11000111
	st	X+,w


	ldi	w,0b11100000
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	
	ldi	w,0b11100011
	st	X+,w
	ldi	w,0b11000111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00100111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00100111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00100111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00100111
	st	X+,w

	ldi	w,0b11100011
	st	X+,w
	ldi	w,0b11000111
	st	X+,w


	ldi	w,0b11100000
	st	X+,w
	ldi	w,0b00000111
	st	X+,w


	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100100
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	ldi	w,0b11100111
	st	X+,w
	ldi	w,0b11000111
	st	X+,w


	ldi	w,0b11100000
	st	X+,w
	ldi	w,0b00000111
	st	X+,w

	rcall	ui_render

	WAIT_MS	4800

	rcall	leds_fadeout_fast

	rjmp	menu_init

draw_ui:
;	rcall	sram_draw_ui
	rcall	leds_draw_ui
	ret

bmp_launch1:
.db	0b00000011,0b11000000
.db	0b00000100,0b00100000
.db	0b00000000,0b00100000
.db	0b00000000,0b00100000
.db	0b00000000,0b11000000
.db	0b00000000,0b00100000
.db	0b00000000,0b00100000
.db	0b00000000,0b00100000
.db	0b00000100,0b00100000
.db	0b00000011,0b11000000
bmp_launch2:
.db	0b00000011,0b11000000
.db	0b00000100,0b00100000
.db	0b00000000,0b00100000
.db	0b00000000,0b00100000
.db	0b00000000,0b01000000
.db	0b00000000,0b10000000
.db	0b00000001,0b00000000
.db	0b00000010,0b00000000
.db	0b00000100,0b00000000
.db	0b00000111,0b11100000
bmp_launch3:
.db	0b00000000,0b10000000
.db	0b00000011,0b10000000
.db	0b00000000,0b10000000
.db	0b00000000,0b10000000
.db	0b00000000,0b10000000
.db	0b00000000,0b10000000
.db	0b00000000,0b10000000
.db	0b00000000,0b10000000
.db	0b00000000,0b10000000
.db	0b00000011,0b11100000
bmp_pause:
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
.db	0b00001110,0b01110000
bmp_logo:
.db	0b00111111,0b11111110
.db	0b00100000,0b00000010
.db	0b00100000,0b00000010
.db	0b00100000,0b00000010
.db	0b00111110,0b00111110
.db	0b00000010,0b00100000
.db	0b00000010,0b00100000
.db	0b00000010,0b00100000
.db	0b00000010,0b00100000
.db	0b00000011,0b11100000
