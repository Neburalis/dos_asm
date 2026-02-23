.model tiny
.code
.386
locals @@

org 100h

VideoMemorySeg 	equ 0b800h
INCLUDE debug.inc

exit0 MACRO
	mov ax, 4c00h
	int 21h
ENDM


Start:
    push VideoMemorySeg
    pop es

    mov bx, (80d * 3) * 2

    mov ah, 4eh
Next:
    in al, 60h
    mov es:[bx], ax
    add bx, 2

    cmp bx, (80d * 4) * 2 ; Fill all line
    jne Cond

    mov bx, (80d * 3) * 2

Cond:
    cmp al, 1
    jne Next

    exit0

end Start