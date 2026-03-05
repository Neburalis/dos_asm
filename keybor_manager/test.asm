.model tiny
.code
.386
locals @@

org 100h

INCLUDE debug.inc
INCLUDE utils.inc
Debug			equ 1


; ============= MAIN ==========================================================

Start:
    mov ax, 1111h
    mov bx, 2222h
    mov cx, 3333h
    mov dx, 4444h
    mov si, 5555h
    mov di, 6666h
    mov bp, 7777h
    push 9999h
    pop es
    mov sp, 8888h

    mov  ah, 01h
    int  21h

    exit0

; =============================================================================


EOP:                    ; End Of Program    ; to calc len with offset EOP
end Start
