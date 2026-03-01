.model tiny
.code
.386
locals @@

org 100h

VideoMemorySeg 	equ 0b800h
INCLUDE debug.inc

; ============= MACRO =========================================================

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

; =============================================================================


; ============= MAIN ==========================================================

Start:
    ; Save old INT 09h vector before replacing it
    mov ax, 3509h
    int 21h                             ; ES:BX = old handler address
    mov word ptr cs:[old_int09_ptr],   bx
    mov word ptr cs:[old_int09_ptr+2], es

    ; Install new INT 09h handler

    push cs
    pop ds
    mov ax, 2509h
    mov dx, offset NewInt09h
    cli ; to prevent UB from occurring when a key is pressed while modifying the interrupt table
    int 21h
    sti

    tasr0

; =============================================================================


; ============= NewInt09h =====================================================

NewInt09h PROC
    push ax bx cx si ds es

    in al, 60h
    mov cl, al                          ; CL = scancode for the rest of the handler

    pushf
    call dword ptr cs:[old_int09_ptr]

    ; --- Alt press / release ---
    cmp cl, 1dh                         ; Left Ctrl make
    je  @@alt_press
    cmp cl, 1dh or 80h                  ; Left Ctrl break
    je  @@alt_release

    ; --- H release: check before the ctrl_down guard so it fires even if
    ;     Alt was released before H (Press Alt, Press H, Release Alt, Release H)
    cmp cl, 28h or 80h                  ; " break
    je  @@h_release

    ; --- H press: only while Alt is currently held ---
    test byte ptr cs:[ctrl_down], 1
    jz  @@done

    cmp cl, 28h                         ; " make
    je  @@h_press
    jmp @@done

@@alt_press:
    or  byte ptr cs:[ctrl_down], 1
    jmp @@done

@@alt_release:
    and byte ptr cs:[ctrl_down], 0FEh
    jmp @@done

@@h_press:
    or  byte ptr cs:[ctrl_c_down], 1
    push cs
    pop ds
    mov si, offset msg_pressed
    mov ax, VideoMemorySeg
    mov es, ax
    mov bx, (80 * 12 + 30) * 2
    mov ah, 0Fh
@@press_loop:
    mov al, byte ptr [si]
    test al, al
    jz @@done
    mov es:[bx], ax
    add bx, 2
    inc si
    jmp @@press_loop

@@h_release:
    test byte ptr cs:[ctrl_c_down], 1   ; only respond if we saw the press
    jz  @@done
    and byte ptr cs:[ctrl_c_down], 0FEh
    push cs
    pop ds
    mov si, offset msg_released
    mov ax, VideoMemorySeg
    mov es, ax
    mov bx, (80 * 12 + 30) * 2
    mov ah, 0Fh
@@release_loop:
    mov al, byte ptr [si]
    test al, al
    jz @@done
    mov es:[bx], ax
    add bx, 2
    inc si
    jmp @@release_loop

@@done:
    pop es ds si cx bx ax
    iret

NewInt09h ENDP

; =============================================================================

old_int09_ptr   dw 0, 0     ; offset, segment of original INT 09h
ctrl_down        db 0        ; 1 when Left Ctrl is held
ctrl_c_down      db 0        ; 1 while Ctrl + ' is physically down

; Messages are the same length (12 chars) so they fully overwrite each other.
msg_pressed     db "You pressed ", 0   ; 11 visible + 1 trailing space
msg_released    db "You released", 0

EOP:                    ; End Of Program    ; to calc len with offset EOP
end Start
