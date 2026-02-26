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

DATA MACRO
	IF Debug
		db 'DATA'
	ENDIF
ENDM