.model tiny
.code
.386
locals @@

org 100h

; INCLUDE debug.inc
; INCLUDE utils.inc
; Debug			equ 1

start:
    mov ax, cs
    mov [back_place + 2], ax

    mov ax, offset back
    mov [back_place], ax

    mov  si, offset copied_code     ; DS:SI = наш код


    ; jmp setup
after_setup:

    mov  ax, 7777h
    mov  es, ax
    mov  di, 8888h                ; ES:DI = 7777:8888

    mov  cx, copied_code_size       ; сколько байт копировать
    cld
    rep  movsb                      ; копируем строковой командой
    ; while (cx--) { ES:[DI++] = DS:[SI++] }

    ; === FAR JMP [copied_code_p]:[copied_code_p + 2] ===
    push [copied_code_p + 2]
    push [copied_code_p]
    retf

back:

    mov ax, 4c00h
	int 21h

copied_code:

    ; mov  ah, 01h
    ; int 21h

    mov ax, 1111h
    mov ax, 0000h

    jmp $-6

    ; === FAR JMP [back_place]:[back_place + 2] ===
    push ds:[back_place + 2]
    push ds:[back_place]
    retf


copied_code_end:

copied_code_size  equ copied_code_end - copied_code
copied_code_place equ copied_code - start
back_place        dw 0, 0
copied_code_p     dw 8888h, 7777h

EOP:                    ; End Of Program    ; to calc len with offset EOP
end Start
