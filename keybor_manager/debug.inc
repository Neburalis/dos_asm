Debug			equ 1

BkPt MACRO
	IF Debug
		int 03h
	ENDIF
ENDM

vskip MACRO
	IF Debug
		dd 90909090h
	ENDIF
ENDM
