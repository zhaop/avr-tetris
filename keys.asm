; keys.asm
;
; Manage key-presses and stuff

.equ	KEYS_MAX_BOUNCES= 36
.equ	BTN_PAUSE	= 7
.equ	BTN_HOLD	= 6
.equ	BTN_HARD_DROP	= 5
.equ	BTN_SOFT_DROP	= 4
.equ	BTN_ROT_LEFT	= 3
.equ	BTN_LEFT	= 2
.equ	BTN_RIGHT	= 1
.equ	BTN_ROT_RIGHT	= 0


.dseg
keys_state:
	.byte	1	; Debounced state
keys_delta:
	.byte	1	; What's changed
keys_index:
	.byte	1
keys_buffer:
	.byte	KEYS_MAX_BOUNCES

.cseg

; Configure portD & initialize variables
; mod	w
keys_init:
	OUTI	DDRD, 0x00	; configure portD to input
	in	w,PIND
	sts	keys_state,w	; keys_state := PIND

	ldi	w,0x00
	sts	keys_delta,w	; keys_delta := 0x00
	sts	keys_index,w

	LDIX	keys_buffer
	ldi	w,KEYS_MAX_BOUNCES
	mov	u,w		; Loop over u
	ldi	w,0xff		; Initialize entire buffer to FF (active-low remember?)

	tst	u
	breq	PC+4		; (loop end)
	dec	u
	st	X+,w
	rjmp	PC-4		; (loop again)

	ret

; On each game tick, process and debounce input keys
keys_process:
	lds	a0,keys_index	; Store current keys into buffer
	ldi	a1,0x00
	LDIX	keys_buffer
	ADD2	xl,xh,a0,a1	; X += index
	in	w,PIND
	st	X,w

	lds	w,keys_index	; Increment index (inside circular buffer)
	INC_CYC	w,0,KEYS_MAX_BOUNCES-1
	sts	keys_index,w

	ldi	a0,0xff		; AND entire buffer to get current state
	LDIX	keys_buffer
	ldi	w,0
	cpi	w,KEYS_MAX_BOUNCES
	brge	PC+5		; (loop end)
	inc	w
	ld	a1,X+
	and	a0,a1
	rjmp	PC-5

	lds	a1,keys_state	; Store results and compute deltas
	eor	a1,a0
	sts	keys_delta,a1
	sts	keys_state,a0

	ret

; Get whether a key was just pushed down
; in	@key
; mod	u,w
; out	T
.macro	KEYS_PRESS; key
	lds	u,keys_state
	com	u		; Active low to high
	lds	w,keys_delta
	and	u,w		; u = keys_state & keys_delta
	bst	u,@0
.endmacro

; Get whether a key is currently pressed
; mod	u
.macro	KEYS_PRESSED; key
	lds	u,keys_state
	com	u
	bst	u,@0
.endmacro

; Get whether a key is currently pressed (without debouncing)
.macro	KEYS_PRESSED_RAW; key
	in	u,PIND
	com	u
	bst	u,@0
.endmacro
