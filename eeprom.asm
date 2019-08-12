; file	eeprom.asm
; copyright (c) 2000-2002 R.Holzer

eeprom_store:
; in	xh:xl	EEPROM address
;	a0	EEPROM data byte to store

	sbic	EECR,EEWE	; skip if EEWE=0 (wait it EEWE=1)
	rjmp	PC-1		; jump back to previous address
	out	EEARL,xl	; load EEPROM address low
	out	EEARH,xh	; load EEPROM address high
	out	EEDR,a0		; set EEPROM data register
	brie	eeprom_cli	; if I=1 then temporarily disable interrupts
	sbi	EECR,EEMWE	; set EEPROM Master Write Enable
	sbi	EECR,EEWE	; set EEPROM Write Enable
	ret
eeprom_cli:
	cli
	sbi	EECR,EEMWE
	sbi	EECR,EEWE
	sei
	ret

eeprom_load:
; in	xh:xl	EEPROM address
; out	a0	EEPROM data byte to load
	sbic	EECR,EEWE
	rjmp	PC-1
	out	EEARL,xl
	out	EEARH,xh
	sbi	EECR,EERE
	in	a0,EEDR
	ret
