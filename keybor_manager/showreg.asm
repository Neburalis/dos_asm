.model tiny
.code
.386
locals @@

org 100h

INCLUDE utils.inc
INCLUDE debug.inc
Debug			equ 1

; --- Minimal demo entry point ---
; Remove / replace with your own caller.
Start:
	mov ax, VideoMemorySeg
	mov es, ax				; ES = B800h

	mov dh, 5				; Y = top row 5
	mov dl, 10				; X = left col 10
	mov bh, 7				; height = 7 rows
	mov bl, 40				; width  = 40 cols

	call PrintFrame

	add dh, 2
	add dl, 2
    mov si, offset string

    call PrintString

	exit0

; =============================================================================

INCLUDE frame.inc


; ============= DATA ===========================================================
.data
DATA

; Border/fill character set — double-line box drawing style
;   [0]='╔'  [1]='═'  [2]='╗'
;   [3]='║'  [4]=' '  [5]='║'
;   [6]='╚'  [7]='═'  [8]='╝'
frameChars  db  0C9h, 0CDh, 0BBh, 0BAh, 020h, 0BAh, 0C8h, 0CDh, 0BCh

frameAttr   db  04Eh    ; yellow (14) on red (4)    — border color
fillAttr    db  03Eh    ; yellow (14) on black (0)  — interior fill color

string      db "Some null terminated string", 0Ah, "with", 0Ah, "multiline", 0h;

EOP:
end Start
