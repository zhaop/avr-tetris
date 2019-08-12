; score.asm
;
; Manage current score, line clears and level.

.equ	PTS_TETRIS	= 50
.equ	PTS_TRIPLE	= 30
.equ	PTS_DOUBLE	= 20
.equ	PTS_SINGLE	= 10
.equ	PTS_HARD_DROP	= 2	; For each line in a hard drop
.equ	PTS_SOFT_DROP	= 1	; For one soft drop

.equ	LINES_TETRIS	= 8
.equ	LINES_TRIPLE	= 5
.equ	LINES_DOUBLE	= 3
.equ	LINES_SINGLE	= 1

.equ	LINES_PER_LEVEL	= 5

.eseg
highscore:
	.db	0,0,0,0	; 4 bytes, low bytes to the left
maxlevel:
	.db	0	; 1 byte

.dseg

level:
	.byte	1	; Level 1 through 15 (Stored as 0x01 thru 0x0f)
score:
	.byte	4	; Goes up to 4'294'967'296 (left bit has lower exponent?)
lines:
	.byte	1	; Lines left until next level (0 through 75)

.cseg

.macro	SCORE_ADD ; pts
	ldi	b0, low(@0)
	ldi	b1,high(@0)
	rcall	score_adder
.endmacro

.macro	LINE_ADD ; lines
	ldi	a0,@0
	rcall	line_adder
.endmacro

; Initialize score variable
; mod	w
; out	level,score,lines
score_init:
	ldi	w,0x01		; Default level is 1
	sts	level,w

	ldi	w,0x00
	sts	score,  w
	sts	score+1,w
	sts	score+2,w
	sts	score+3,w
	sts	lines,w

	ret

; Add any number (0 thru 65535) of points
; in	b0,b1,score
; mod	a0,a1,a2,a3
; out	score
score_adder:
	lds	a0,score	; LDS4	a3,a2,a1,a0,score
	lds	a1,score+1
	lds	a2,score+2
	lds	a3,score+3

	add	a0,b0		; ADDI4	a3,a2,a1,a0,w
	adc	a1,b1
	brcc	PC+4
	inc	a2
	brne	PC+2
	inc	a3

	sts	score,  a0	; STS4	score,a3,a2,a1,a0
	sts	score+1,a1
	sts	score+2,a2
	sts	score+3,a3

	MOV4	b3,b2,b1,b0,a3,a2,a1,a0

	rcall	highscore_load	; b = score, a = highscore

	CP4	a3,a2,a1,a0,b3,b2,b1,b0	; Update highscores
	brge	_score_adder_0
	MOV4	a3,a2,a1,a0,b3,b2,b1,b0
	rcall	highscore_store

	lds	a0,level
	LDIX	maxlevel
	rcall	eeprom_store

_score_adder_0:
	ret

; Add any number (0 thru 255) of lines & handle the lvel-logic
; in	a0
; mod	a0,a1,w
line_adder:
	lds	a1,lines; a1 := lines
	add	a1,a0
	sts	lines,a1

	lds	w,level		; Detect whether we're ok for level up
	tst	w
	breq	PC+4		; (loop end)
	dec	w
	subi	a1,LINES_PER_LEVEL
	rjmp	PC-4

	tst	a1
	brpl	PC+2		; Branch if enough lines for lvl up
	ret
	
	sts	lines,a1	; Store lines after level up
	rcall	level_up
	ret

; Increment level & accelerate game
; in	level,OCR0
; mod	w,a0,a1
; out	level,OCR0
level_up:
	lds	w,level		; Level up
	inc	w
	sts	level,w

	in	a0,OCR0		; Accelerate
	ldi	a1,16
	sub	a1,w		; a1 := 16 - level
	sub	a0,a1
	out	OCR0,a0
	ret

; Score a tetris
; mod	a0,a1,a2,a3
score_tetris:
	SCORE_ADD	PTS_TETRIS
	LINE_ADD	LINES_TETRIS
	rcall	score_display
	ret

; Score a triple
; mod	a0,a1,a2,a3
score_triple:
	SCORE_ADD	PTS_TRIPLE
	LINE_ADD	LINES_TRIPLE
	rcall	score_display
	ret

; Score a double
; mod	a0,a1,a2,a3
score_double:
	SCORE_ADD	PTS_DOUBLE
	LINE_ADD	LINES_DOUBLE
	rcall	score_display
	ret

; Score a single
; mod	a0,a1,a2,a3
score_single:
	SCORE_ADD	PTS_SINGLE
	LINE_ADD	LINES_SINGLE
	rcall	score_display
	ret

; Score soft-drop line down
; mod	a0,a1,a2,a3
score_soft_drop:
	SCORE_ADD	PTS_SOFT_DROP
	rcall	score_display
	ret

; Score hard-drop line down
; mod	a0,a1,a2,a3
score_hard_drop:
	SCORE_ADD	PTS_HARD_DROP
	rcall	score_display
	ret

; Display score on LCD screen
; mod	a0,a1,a2,a3,X
score_display:
	LDIX	score		; Line 1: Score
	ld	a0,X+
	ld	a1,X+
	ld	a2,X+
	ld	a3,X+

	rcall	LCD_home
	PRINTF	LCD
	.db	CR,FDEC4,a," pts           ",LF,0

	lds	a0,level	; Line 2: Level & lines
	lds	b0,lines

	PRINTF	LCD
	.db	"L",FDEC,a," (",FDEC,b," lines)    ",0,0
	ret

; Load highscore from EEPROM
; in	highscore
; mod	X
; out	a0,a1,a2,a3
highscore_load:
	LDIX	highscore+3
	rcall	eeprom_load
	dec	xl
	mov	a3,a0
	rcall	eeprom_load
	dec	xl
	mov	a2,a0
	rcall	eeprom_load
	dec	xl
	mov	a1,a0
	rcall	eeprom_load	; highscore is inside |a0 a1 a2 a3| now
	ret

; Store number into highscore inside EEPROM
; in	a0,a1,a2,a3
; mod	X
; out	highscore
highscore_store:
	LDIX	highscore
	rcall	eeprom_store
	inc	xl
	mov	a0,a1
	rcall	eeprom_store
	inc	xl
	mov	a0,a2
	rcall	eeprom_store
	inc	xl
	mov	a0,a3
	rcall	eeprom_store
	ret
