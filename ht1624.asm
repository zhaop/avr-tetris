; ht1624.asm
;
; Low-level LED matrix write-only driver
; 
; ht_init
; ht_sendcmd
; ht_startdata
; ht_writebits
; ht_enddata

.equ	HT_CS	= 0
.equ	HT_WR	= 2
.equ	HT_DATA	= 4

.equ	HT_CMD_SYSDIS	= 0x00 ; 0000 0000
.equ	HT_CMD_SYSEN	= 0x01 ; 0000 0001
.equ	HT_CMD_LEDOFF	= 0x02 ; 0000 0010
.equ	HT_CMD_LEDON	= 0x03 ; 0000 0011
.equ	HT_CMD_BLKON	= 0x09 ; 0000 1001
.equ	HT_CMD_SLVMD	= 0x10 ; 0001 0000
.equ	HT_CMD_MSTMD	= 0x14 ; 0001 0100
.equ	HT_CMD_COMS11	= 0x2c ; 0010 1100
.equ	HT_CMD_PWM01	= 0xa0
.equ	HT_CMD_PWM02	= 0xa1
.equ	HT_CMD_PWM03	= 0xa2
.equ	HT_CMD_PWM04	= 0xa3
.equ	HT_CMD_PWM05	= 0xa4
.equ	HT_CMD_PWM06	= 0xa5
.equ	HT_CMD_PWM07	= 0xa6
.equ	HT_CMD_PWM08	= 0xa7
.equ	HT_CMD_PWM09	= 0xa8
.equ	HT_CMD_PWM10	= 0xa9
.equ	HT_CMD_PWM11	= 0xaa
.equ	HT_CMD_PWM12	= 0xab
.equ	HT_CMD_PWM13	= 0xac
.equ	HT_CMD_PWM14	= 0xad
.equ	HT_CMD_PWM15	= 0xae
.equ	HT_CMD_PWM16	= 0xaf

; Call this before starting a transmission
.macro	HT_START
	cbi	PORTB,HT_CS
.endmacro

; Call this after transmission is done
.macro	HT_STOP
	sbi	PORTB,HT_CS
.endmacro

; Call this for each and every bit to send to the thingiemagig
.macro	HT_SENDBIT0	; bit_to_send
	cbi	PORTB,HT_WR	; Set WR-barre to 0
	cbi	PORTB,HT_DATA	; Set DATA to 0
	sbi	PORTB,HT_WR	; Set WR-barre to 1
.endmacro

; Call this for each and every bit to send to the thingiemagig
.macro	HT_SENDBIT1	; bit_to_send
	cbi	PORTB,HT_WR	; Set WR-barre to 0
	sbi	PORTB,HT_DATA	; Set DATA to 1
	sbi	PORTB,HT_WR	; Set WR-barre to 1
.endmacro

; Set all PORTB pins to output
ht_init:
	ldi	w,0xff
	out	DDRB,w

	HT_STOP
	CA	ht_sendcmd,HT_CMD_SYSDIS
	CA	ht_sendcmd,HT_CMD_COMS11
	CA	ht_sendcmd,HT_CMD_MSTMD
	CA	ht_sendcmd,HT_CMD_SYSEN
	CA	ht_sendcmd,HT_CMD_LEDON
	CA	ht_sendcmd,HT_CMD_PWM16

	ret

; Envoie log2(b0) bits au HT, high bits first (!)
; in	a0 (séquence de bits à envoyer), b0 (1<<firstbit)
; mod	w,b0
ht_writebits:
	tst	b0
	breq	_ht_wb_end
	mov	w,b0
	and	w,a0	; w = a0 & b0
	breq	_ht_wb0
	HT_SENDBIT1
	lsr	b0
	rjmp	ht_writebits
_ht_wb0:
	HT_SENDBIT0
	lsr	b0
	rjmp	ht_writebits
_ht_wb_end:
	ret
	
; Send a command code to LED matrix
; in	a0 (commande 8 bits)
; mod	---
ht_sendcmd:
	push	w	; Save changed registers
	push	b0

	HT_START

	push	a0
	CAB	ht_writebits,0b100,1<<2
	pop	a0

	ldi	b0,1<<7
	rcall	ht_writebits
	HT_SENDBIT0	; Don't care
	HT_STOP

	pop	b0	; Restore registers
	pop	w

	ret

	
; Call this before starting successive writes
ht_startdata:
	HT_START
	CAB	ht_writebits,0b101,1<<2
	CAB	ht_writebits,0x00,1<<6
	ret

; Call this when successive writes are finished
ht_enddata:
	HT_STOP
	ret

; LED matrix test subroutine
ht_test:	 
	ldi	a0,0xff
	push	a0
_ht_test_lp:
	HT_START
	CAB	ht_writebits,0b101,1<<2
	pop	a0
	dec	a0
	push	a0
	ldi	b0,1<<6
	rcall	ht_writebits		; ADDR0
	CAB	ht_writebits,0xf0,1<<7	; DATA
;	WAIT_MS	50
	
	HT_STOP
	rjmp	_ht_test_lp
	
	pop	a0		; Code will never reach this, but oh whatever
	ret
