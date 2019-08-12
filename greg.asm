; greg.asm
;
; Macros and definitions to use the Game REGister

.dseg
greg:
	.byte	1

.cseg

.equ	GREG_NO_HOLD	= 5	; Last piece came from a hold
.equ	GREG_GAME_OVER	= 4	; Set when game is lost
.equ	GREG_CHECK_KICK	= 3	; This move requires checking for wall/floor kicks
.equ	GREG_TICK	= 2	; Advance game one tick (block falls, etc)
.equ	GREG_COLLISION	= 1	; Store collision detection results
.equ	GREG_REDRAW	= 0	; Means grid_buffer should be redrawn

; Sets a bit in the greg (5 cycles)
; in	bit
; mod	w
.macro	GREG_SE ; bit
	lds	w,greg
	ori	w,1<<@0
	sts	greg,w
.endmacro

; Clears a bit in the greg (5 cycles)
; in	bit
; mod	w
.macro GREG_CL ; bit
	lds	w,greg
	andi	w,~(1<<@0)
	sts	greg,w
.endmacro

; Loads a bit in the greg into sreg bit T (3 cycles)
; in	bit
; mod	w
; out	T
.macro	GREG_LD	; bit
	lds	w,greg
	bst	w,@0
.endmacro

; Clears a part of greg (5 cycles)
; mod	w
.macro	GREG_RESET ; mask (1 for keep, 0 for delete)
	lds	w,greg
	andi	w,@0
	sts	greg,w
.endmacro

; Resets the entire greg
greg_init:
	GREG_RESET	0x00
	ret
