exit0 MACRO
	mov ax, 4c00h
	int 21h
ENDM


; ============= take_resident_and_shutdown ====================================
;
; Macro for resident
;
; EXP:
;   EOP in the end of program to calc size of program
;
tras0 MACRO
    mov ax, 3100h
    mov dx, offset EOP  ; size of program
    shr dx, 4           ; size in paragraphs ; 1 paragraph = 16 byte
    inc dx              ; the size may not be divided entirely
    int 21h
ENDM


VideoMemorySeg  equ 0b800h
; ============= video_mem_offset ===============================================
;
; Macro to compute video memory offset from DX coordinates
;
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
; OUT:
;	AX = offset
; DESTR:
;	BX
;
video_mem_offset MACRO
	mov al, dh					; al = y
	mov ah, 80d					; ah = 80 (columns per row)
	mul ah						; ax = y * 80  (row start, in characters)
	mov bx, dx					; bx = dx  (copy DX to extract DL cleanly)
	xor bh, bh					; bh = 0 -> bx = dl = x
	add ax, bx					; ax = y * 80 + x  (cell index)
	shl ax, 1					; ax *= 2  (each cell = 1 byte char + 1 byte attr)
ENDM