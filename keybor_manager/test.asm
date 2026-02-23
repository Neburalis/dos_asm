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

tasr0 MACRO
    mov ax, 3100h
    mov dx, offset EOP  ; size of program
    shr dx, 4           ; size in paragraphs ; 1 paragraph = 16 byte
    inc dx              ; the size may not be divided entirely
    int 21h
ENDM

Start:
    push 0
    pop es

    mov bx, 4 * 09h ; 4 - size of cell ; 09 - num of int
    mov ax, cs

    cli ; to prevent UB from occurring when a key is pressed while modifying the interrupt table
    mov word ptr es:[bx], offset NewInt09h
    mov es:[bx+2], ax
    sti

    tasr0

NewInt09h PROC
    push ax bx es

    mov ax, VideoMemorySeg
    mov es, ax

    mov bx, (80d * 3 + 40d) * 2

    mov ah, 4eh

    in al, 60h
    mov es:[bx], ax

    ; blink 7 bit of PPI port B (reset keyboard)
    in al, 61h
    or al, 80h
    out 61, al
    and al, not 80h
    out 61h, al

    ; reset
    mov al, 20h
    out 20h, al

    pop es bx ax
    iret

NewInt09h ENDP

EOP:                    ; End Of Program    ; to calc len with offset EOP
end Start