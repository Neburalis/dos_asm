.model tiny
.code
.386
locals @@

org 100h

INCLUDE utils.inc

; ============= Window geometry ================================================
WIN_ROW     equ 1           ; top row (0-based)
WIN_COL     equ 63          ; left col (0-based)
WIN_W       equ 11          ; total width  including borders
WIN_H       equ 15          ; total height including borders
WIN_BYTES   equ WIN_W * WIN_H * 2          ; buffer size in bytes

WIN_VSTART  equ (WIN_ROW * 80 + WIN_COL) * 2   ; video offset of top-left cell
WIN_STRIDE  equ (80 - WIN_W) * 2               ; per-row gap in video memory

FRAME_ATTR  equ 4Eh         ; yellow on red     — border
FILL_ATTR   equ 0Fh         ; bright white on black — interior

; ============= Hex display macros ============================================
;
; ToHexDigit: convert nibble in BL (0–15) to ASCII hex char in BL.
; IN:
;   BL - reg to show
; DESTR:
;   BL
ToHexDigit MACRO
    add bl, '0'
    cmp bl, '9'+1
    jl  $+5             ;  7C 03     — skip add bl,7 when already a digit
    add bl, 7           ;  80 C3 07  — bridge '9' -> 'A' for values 10–15
ENDM

; WriteRegHex: write AX as 4 hex chars into buf in memory.
; IN:
;   AX - reg to show
; EXP:
;   ES:DI - pointer where need to draw
; DESTR:
;   BL, DI
;
WriteRegHex MACRO reg_row
    mov di, offset draw_buf + ((reg_row) * WIN_W + 5) * 2
    rol ax, 4
    mov bl, al
    and bl, 0Fh
    ToHexDigit
    mov byte ptr es:[di], bl
    add di, 2
    rol ax, 4
    mov bl, al
    and bl, 0Fh
    ToHexDigit
    mov byte ptr es:[di], bl
    add di, 2
    rol ax, 4
    mov bl, al
    and bl, 0Fh
    ToHexDigit
    mov byte ptr es:[di], bl
    add di, 2
    rol ax, 4
    mov bl, al
    and bl, 0Fh
    ToHexDigit
    mov byte ptr es:[di], bl
ENDM

; WriteAllRegs: snapshot all saved regs from INT stack frame into draw_buf.
; EXP:
;   BP  - frame pointer
;   ES  - segment of draw_buf
; DESTR: AX, BX, CX, DI, SI
;
; Stack layout (9 regs × 2 = 18 bytes + HW INT frame 6 bytes = 24 total):
;   BP+0=ES  BP+2=DS  BP+4=BP  BP+6=DI  BP+8=SI
;   BP+10=DX BP+12=CX BP+14=BX BP+16=AX
;   BP+18=IP BP+20=CS BP+22=FLAGS   SP_orig=BP+24
;
WriteAllRegs MACRO
    jmp @@wr_code
@@wr_table:
    dw 16, 14, 12, 10, 8, 6, 4, 24, 2, 0, 0FFFEh, 20, 18
@@wr_code:
    mov bx, offset @@wr_table
    mov di, offset draw_buf + (1 * WIN_W + 5) * 2  ; row 1, col 5
    mov cx, 13
@@wr_loop:
    mov si, [bx]                    ; SI = frame offset (or sentinel)
    add bx, 2
    mov ax, [bp+si]                 ; load reg value; junk for sentinels, overwritten below
    cmp si, 0FFFFh                  ; SP: overwrite with BP+24
    jne @@wr_not_sp
    mov ax, bp
    add ax, 24
@@wr_not_sp:
    cmp si, 0FFFEh                  ; SS: overwrite with SS
    jne @@wr_write
    mov ax, ss
@@wr_write:
    push cx                         ; save outer counter
    mov cx, 4                       ; 4 hex nibbles per register
@@wr_nibble:
    rol ax, 4
    mov bl, al
    and bl, 0Fh
    ToHexDigit
    mov byte ptr es:[di], bl
    add di, 2
    loop @@wr_nibble
    pop cx
    add di, WIN_W * 2 - 8           ; advance DI to next row (22 - 4*2 = 14)
    loop @@wr_loop
ENDM

; ============= Start ==========================================================
Start:
    ; --- Save and install INT 08h (timer) ---
    mov ax, 3508h
    int 21h
    mov word ptr cs:[old_int08_ptr],   bx
    mov word ptr cs:[old_int08_ptr+2], es

    push cs
    pop ds
    mov ax, 2508h
    mov dx, offset NewInt08h
    int 21h

    ; --- Save and install INT 09h (keyboard) ---
    mov ax, 3509h
    int 21h
    mov word ptr cs:[old_int09_ptr],   bx
    mov word ptr cs:[old_int09_ptr+2], es

    push cs
    pop ds
    mov ax, 2509h
    mov dx, offset NewInt09h
    cli
    int 21h
    sti

    ; --- Draw frame into draw_buf ---
    push cs
    push cs
    pop ds                          ; DS = CS (for drawCols/drawBase/frameChars)
    pop es                          ; ES = CS (draw_buf lives here)

    mov byte ptr [drawCols], WIN_W
    mov word ptr [drawBase], offset draw_buf

    mov dh, 0
    mov dl, 0
    mov bh, WIN_H
    mov bl, WIN_W
    call PrintFrame

    mov dh, 1                       ; title at buffer row 1, col 2
    mov dl, 2
    mov si, offset string
    mov ah, FILL_ATTR
    call PrintString

    tras0

; ============= NewInt08h ======================================================
; Timer interrupt: if window is visible, compare video memory vs draw_buf and
; refresh any cell that was overwritten by another program (save the foreign
; value into save_buf so that hide restores the latest background).

NewInt08h PROC
    test byte ptr cs:[window_visible], 1
    jz @@chain

    push ax bx cx dx si di bp ds es

	cld

    push cs
    pop ds                          ; DS = CS (our segment)

    mov si, offset draw_buf         ; DS:SI -> draw_buf  (sequential)
    mov bx, offset save_buf         ; DS:BX -> save_buf  (sequential, DS=CS)

    mov ax, VideoMemorySeg
    mov es, ax                      ; ES = B800h
    mov di, WIN_VSTART              ; ES:DI -> window top-left

    mov dh, WIN_H                   ; outer loop: row counter
@@rows:
    push di                         ; save video row start
    mov cx, WIN_W                   ; inner loop: column counter
@@cols:
    mov ax, es:[di]                 ; ax = current video cell
    cmp ax, [si]                    ; == draw_buf reference?
    je @@same
    mov [bx], ax                    ; save_buf[i] <- video[i]  (foreign char)
    mov ax, [si]                    ; ax = draw_buf[i]
    mov es:[di], ax                 ; video[i] <- draw_buf[i]  (restore window)
@@same:
    add si, 2
    add bx, 2
    add di, 2
    loop @@cols

    pop di
    add di, 160                     ; advance DI to next video row  (80*2)
    dec dh
    jnz @@rows

	mov bp, sp
    push cs
    pop es                          ; ES = CS (draw_buf lives here)

    WriteAllRegs

	push cs
    pop ds                          ; DS = CS (our segment)

    mov si, offset draw_buf         ; DS:SI -> draw_buf  (sequential)
    mov bx, offset save_buf         ; DS:BX -> save_buf  (sequential, DS=CS)

    mov ax, VideoMemorySeg
    mov es, ax                      ; ES = B800h
    mov di, WIN_VSTART              ; ES:DI -> window top-left

    mov dh, WIN_H                   ; outer loop: row counter
@@blit:
    mov cx, WIN_W
    rep movsw
    add di, WIN_STRIDE
    dec dh
    jnz @@blit

    pop es ds bp di si dx cx bx ax

@@chain:
    jmp dword ptr cs:[old_int08_ptr]    ; tail-call: original does the IRET
NewInt08h ENDP

; ============= NewInt09h ======================================================
; Keyboard interrupt: detect Ctrl + / to show/hide the window.
;
; Show (first press):
;   1. Copy video window area -> save_buf
;   2. Copy draw_buf -> video
;
; Hide (second press):
;   1. Copy save_buf -> video

NewInt09h PROC
    push ax bx cx dx si di bp ds es

    in al, 60h                      ; read scancode before BIOS can ACK keyboard
    mov cl, al                      ; CL = scancode for the rest of this handler

    ; --- Left Ctrl make / break ---
    cmp cl, 1Dh                     ; Left Ctrl make
    je @@ctrl_press
    cmp cl, 1Dh or 80h              ; Left Ctrl break = 9Dh
    je @@ctrl_release

    ; --- / break: clear slash_down (checked before ctrl guard so it always fires) ---
    cmp cl, 35h or 80h              ; / break = B5h
    je @@slash_release

    ; --- / press: only while Ctrl is held, no auto-repeat ---
    test byte ptr cs:[ctrl_down], 1
    jz @@done

    cmp cl, 35h                     ; / make
    jne @@done

    test byte ptr cs:[slash_down], 1    ; already pressed? (auto-repeat guard)
    jnz @@done

    or byte ptr cs:[slash_down], 1      ; mark / as down

    ; Toggle: show or hide
    test byte ptr cs:[window_visible], 1
    jnz @@hide

    ; ==== Show window ====
    ; 0. Snapshot register values into draw_buf before blitting.
    mov bp, sp
    push cs
    pop es                          ; ES = CS (draw_buf lives here)

    WriteAllRegs

    ; 1. Copy video -> save_buf (ES = CS already)
    cld
    mov di, offset save_buf         ; ES:DI -> save_buf (sequential)
    mov ax, VideoMemorySeg
    mov ds, ax                      ; DS = B800h
    mov si, WIN_VSTART              ; DS:SI -> video window top-left
    mov dh, WIN_H
@@show_v2s:
    mov cx, WIN_W
    rep movsw                       ; DS:SI (video) -> ES:DI (save_buf)
    add si, WIN_STRIDE
    dec dh
    jnz @@show_v2s

    ; 2. Copy draw_buf -> video
    push cs
    pop ds                          ; DS = CS (draw_buf lives here)
    mov si, offset draw_buf         ; DS:SI -> draw_buf (sequential)
    mov ax, VideoMemorySeg
    mov es, ax                      ; ES = B800h
    mov di, WIN_VSTART              ; ES:DI -> video window top-left
    mov dh, WIN_H
@@show_d2v:
    mov cx, WIN_W
    rep movsw                       ; DS:SI (draw_buf) -> ES:DI (video)
    add di, WIN_STRIDE
    dec dh
    jnz @@show_d2v

    mov byte ptr cs:[window_visible], 1
    jmp @@done

@@hide:
    ; ==== Hide window: copy save_buf -> video ====
    cld
    push cs
    pop ds                          ; DS = CS (save_buf lives here)
    mov si, offset save_buf         ; DS:SI -> save_buf (sequential)
    mov ax, VideoMemorySeg
    mov es, ax                      ; ES = B800h
    mov di, WIN_VSTART              ; ES:DI -> video window top-left
    mov dh, WIN_H
@@hide_s2v:
    mov cx, WIN_W
    rep movsw                       ; DS:SI (save_buf) -> ES:DI (video)
    add di, WIN_STRIDE
    dec dh
    jnz @@hide_s2v

    mov byte ptr cs:[window_visible], 0
    jmp @@done

@@ctrl_press:
    or byte ptr cs:[ctrl_down], 1
    jmp @@done

@@ctrl_release:
    and byte ptr cs:[ctrl_down], 0FEh
    and byte ptr cs:[slash_down], 0FEh
    jmp @@done

@@slash_release:
    and byte ptr cs:[slash_down], 0FEh

@@done:
    pop es ds bp di si dx cx bx ax
	jmp dword ptr cs:[old_int09_ptr]
NewInt09h ENDP

INCLUDE frame.inc

; ============= Resident data ==================================================

; Frame character and attribute tables — read by PrintFrame via DS
frameChars  db  0C9h, 0CDh, 0BBh, 0BAh, 020h, 0BAh, 0C8h, 0CDh, 0BCh
frameAttr   db  FRAME_ATTR
fillAttr    db  FILL_ATTR

old_int08_ptr   dw 0, 0     ; offset, segment of original INT 08h
old_int09_ptr   dw 0, 0     ; offset, segment of original INT 09h
window_visible  db 0        ; 1 while window is on screen
ctrl_down       db 0        ; 1 while Left Ctrl is physically held
slash_down      db 0        ; 1 while / is physically held (auto-repeat guard)

string          db "ax 0000", 0Ah, "bx 0000", 0Ah, "cx 0000", 0Ah, "dx 0000", 0Ah, \
                   "si 0000", 0Ah, "di 0000", 0Ah, "bp 0000", 0Ah, "sp 0000", 0Ah, \
                   "ds 0000", 0Ah, "es 0000", 0Ah, "ss 0000", 0Ah, "cs 0000", 0Ah, \
                   "ip 0000", 0

save_buf        db WIN_BYTES dup(0)     ; snapshot of screen under our window
draw_buf        db WIN_BYTES dup(0)     ; reference copy of what we drew

EOP:
end Start
