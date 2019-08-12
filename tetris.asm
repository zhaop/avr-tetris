; tetris.asm
;
; Main file for the Tetris project.

.include "m103def.inc"
.include "macros.asm"
.include "definitions.asm"

.dseg
level_select:
	.db	1	; Stores level selection in menu
ui:
	.byte	48	; Buffer for the final interface

.cseg
.org 0x00
	jmp	reset
.org OC0addr
	rjmp	t0comp
.org 0x30

.include "greg.asm"
.include "piece.asm"
.include "grid.asm"
.include "keys.asm"
.include "leds.asm"
;.include "sram.asm"
.include "lcd.asm"
.include "printf.asm"
.include "score.asm"
.include "game.asm"
.include "sound.asm"
.include "eeprom.asm"


reset:
	LDSP	RAMEND

	OUTI	DDRB,0xff	; Set LEDs as output
	OUTI	DDRD,0x00	; Set buttons as input
	OUTI	DDRE,0xff	; Set speaker as output	sei

	rcall	LCD_init
	rcall	LCD_clear
	rcall	LCD_home

	rcall	leds_init
	rcall	keys_init
	
	OUTI	ASSR,1<<AS0
	sei
	nop

	rjmp	menu_init_firststart
; Almost identical to menu_init, plays extra sound
menu_init_firststart:
	LDIZ	2*bmp_logo
	rcall	draw_bmp

	rcall	leds_fadein_slow

	rcall	LCD_home
	PRINTF	LCD
	.db	CR,"   Welcome to   ",LF,"     Tetris     ",0

	LDIZ	korobeiniki*2
	rcall	play_intro

	ldi	w,1
	sts	level_select,w	; Stores starting level
	rcall	draw_logo_level
	rcall	menu_draw_start

	rjmp	menu_start

menu_init:
	LDIZ	2*bmp_logo
	rcall	draw_bmp

	rcall	leds_fadein_slow

	ldi	w,1
	sts	level_select,w	; Stores starting level
	rcall	draw_logo_level
	rcall	menu_draw_start
	
	rjmp	menu_start

play_intro:
	in	w,PIND
	sbis	16,BTN_HOLD
	ret
	lpm
	adiw	zl,1	; load note to play
	tst	r0	; increment pointer z
	brne	PC+2
	ret
	mov	a0,r0	; move note to a0
	ldi	b0,30	; load play duration (50*2,5ms = 125 ms)
	rcall	sound	; play the sound
	rjmp	play_intro

; Manage the Start page
; mod	w
menu_start:
	rcall	keys_process

	call	rand1		; Run random generator (seed random)

	KEYS_PRESS	BTN_RIGHT
	brtc	PC+2
 	rjmp	menu_highscore 	; Highscore page

	KEYS_PRESS	BTN_SOFT_DROP
	brtc	PC+2		; Increase level setting
	rcall	menu_start_inc

	KEYS_PRESS	BTN_HARD_DROP
	brtc	PC+2		; Decrease level setting
	rcall	menu_start_dec

	KEYS_PRESS	BTN_PAUSE
	brtc	PC+3
	rcall	leds_fadeout_fast
	rjmp	game_launch	; Launch into the game

	rcall	draw_logo_level
	rcall	menu_draw_start

	rjmp	menu_start

; Increment level selection
menu_start_inc:
	lds	a0,level_select
	INC_CYC	a0,1,15
	sts	level_select,a0
	ret

; Decrement level selection
menu_start_dec:
	lds	a0,level_select
	DEC_CYC	a0,1,15
	sts	level_select,a0
	ret

; Redraw LCD text
menu_draw_start:
	lds	a0,level_select
	rcall	LCD_home
	PRINTF	LCD		; Display text
	.db	CR,"Start          >",LF
	.db	"Level ",FDEC,a,"         ",0
	ret

; Manage the Highscore page
menu_highscore:
	rcall	keys_process

	KEYS_PRESS	BTN_LEFT
	brtc	PC+2
 	rjmp	menu_start 	; Start page

	LDIX	maxlevel
	rcall	eeprom_load
	mov	b0,a0
	
	rcall	highscore_load

	rcall	LCD_home
	PRINTF	LCD		; Display text
	.db	CR,"< Highscore     ",LF
	.db	FDEC4,a," (L",FDEC,b,")          ",0,0

	rcall	draw_logo_level
	
	rjmp	menu_highscore

; Manage the Continue page
menu_pause:
	rcall	keys_process

	KEYS_PRESS	BTN_PAUSE
	brtc	PC+2
	rjmp	game_resume

	KEYS_PRESS	BTN_RIGHT
	brtc	PC+2
 	rjmp	menu_quit	; Quit page

	rcall	LCD_home
	PRINTF	LCD		; Display text
	.db	CR,"Continue       >",LF
	.db	"                ",0,0

 	rjmp	menu_pause
	
; Manage the Quit page
menu_quit:
	rcall	keys_process

	KEYS_PRESS	BTN_PAUSE
	brtc	PC+2
	rjmp	menu_start

	KEYS_PRESS	BTN_LEFT
	brtc	PC+2
 	rjmp	menu_pause	; Pause page

	rcall	LCD_home
	PRINTF	LCD		; Display text
	.db	CR,"< Quit          ",LF
	.db	"                ",0,0

 	rjmp 	menu_quit

; Fill logo with current level
draw_logo_level:

	LDIZ	bmp_logo*2; Redraw unfilled logo
	rcall	draw_bmp

	lds	w,level_select
	CLR2	a0,a1
	
	tst	w	; Construct a level mask
	breq	PC+6
	dec	w
	sec		; Rotate carry into level mask
	ROR2	a0,a1	; 2 PC instructions
	rjmp	PC-6

	LDIZ	mask_logo*2
	LDIX	ui+16	; Start drawing from 16th row
	ldi	w,8	; Only 8 rows to fill
	
	tst	w
	breq	PC+15
	dec	w
	lpm
	and	r0,a0
	adiw	zh:zl,1	; Increment Z
	ld	u,X
	or	r0,u
	st	X+,r0
	lpm
	and	r0,a1
	adiw	zh:zl,1
	ld	u,X
	or	r0,u
	st	X+,r0
	rjmp	PC-15
	
	rcall	draw_ui
	ret

mask_logo:	; 8x16
.db	0b00111111,0b11111110
.db	0b00111111,0b11111110
.db	0b00111111,0b11111110
.db	0b00111111,0b11111110
.db	0b00000011,0b11100000
.db	0b00000011,0b11100000
.db	0b00000011,0b11100000
.db	0b00000011,0b11100000

korobeiniki:
.db	mi3,mi3,mi3,mi3,si2,si2,do3,do3,re3,re3,mi3,re3,do3,do3,si2,si2
.db	la2,la2,la2,la2,la2,la2,do3,do3,mi3,mi3,mi3,mi3,re3,re3,do3,do3
.db	si2,si2,mi2,mi2,si2,si2,do3,do3,re3,re3,re3,re3,mi3,mi3,mi3,mi3
.db	do3,do3,do3,do3,la2,la2,la2,la2,la2,la2,si2,si2,si2,si2,do3,do3
.db	do3,re3,re3,re3,re3,re3,fa3,fa3,la3,la3,la3,la3,so3,so3,fa3,fa3
.db	mi3,mi3,mi3,mi3,mi3,mi3,do3,do3,mi3,mi3,mi3,mi3,re3,re3,do3,do3
.db	si2,si2,si2,si2,si2,si2,do3,do3,re3,re3,re3,re3,mi3,mi3,mi3,mi3
.db	do3,do3,do3,do3,la2,la2,la2,la2,la2,la2,la2,la2,la2,la2,la2,la2
.db	0
