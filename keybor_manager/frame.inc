; ============= PrintFrame ====================================================
;
; Draws a bordered rectangle into a target segment.
;
; IN:
;	ES  = target segment (0B800h for video; CS for a compact buffer)
;	DH  = Y  top row   (0–24 for video; 0 for buffer origin)
;	DL  = X  left col  (0–79 for video; 0 for buffer origin)
;	BH  = height  total rows including borders (>= 2)
;	BL  = width   total cols including borders (>= 2)
;
; GLOBAL VARS (read via DS):
;	drawCols — columns per row in target   (80 for video, WIN_W for buffer)
;	drawBase — byte offset added to DI     (0 for video, offset buf for buffer)
;	frameChars[9], frameAttr, fillAttr
;
; DESTR: AX, CX, SI, DI, DirFlag
;
PrintFrame PROC
	cld

	; --- DI = drawBase + (DH * drawCols + DL) * 2 ---
	; mul ah is 8×8→16-bit: DX is untouched, keeping DL available afterward.
    push bx
	mov al, dh
	mov ah, [drawCols]
	mul ah					; ax = DH * drawCols
	mov bx, dx
	xor bh, bh				; bx = DL
	add ax, bx
	shl ax, 1				; ax = (DH * drawCols + DL) * 2
	add ax, [drawBase]
    pop bx
	mov di, ax

	mov ah, [frameAttr]

	; --- Top row ---
	mov al, [frameChars]		; TL corner
	stosw
	mov al, [frameChars+1]		; top border
	xor ch, ch
	mov cl, bl
	sub cx, 2
	rep stosw
	mov al, [frameChars+2]		; TR corner
	stosw

	; Row advance = (drawCols - width) * 2
	; (0 for a compact buffer where drawCols == width; 160-w*2 for video)
	xor ah, ah
	mov al, [drawCols]
	sub al, bl
	shl ax, 1
	mov si, ax

	; --- Middle rows: height-2 iterations ---
	mov cl, bh
	xor ch, ch
	sub cx, 2

@@mid_loop:
	add di, si

	mov al, [frameChars+3]		; left border
	mov ah, [frameAttr]
	stosw

	mov al, [frameChars+4]		; fill char
	mov ah, [fillAttr]
	push cx
	xor ch, ch
	mov cl, bl
	sub cx, 2
	rep stosw
	pop cx

	mov al, [frameChars+5]		; right border
	mov ah, [frameAttr]
	stosw

	loop @@mid_loop

	; --- Bottom row ---
	add di, si
	mov ah, [frameAttr]
	mov al, [frameChars+6]		; BL corner
	stosw
	mov al, [frameChars+7]		; bottom border
	xor ch, ch
	mov cl, bl
	sub cx, 2
	rep stosw
	mov al, [frameChars+8]		; BR corner
	stosw

	ret
PrintFrame ENDP

; ============= FillFrame =====================================================
;
; Fill a rectangular region with a character, preserving existing attributes.
;
; IN:
;	ES  = target segment
;	DH  = Y, DL = X, BH = height, BL = width
;	AL  = fill char
;
; GLOBAL VARS (read via DS): drawCols, drawBase
;
; OUT:  -
; DESTR: AX, CX, SI, DI, DirFlag
;
FillFrame PROC
	cld

	; --- DI = drawBase + (DH * drawCols + DL) * 2 ---
	; Save AL (fill char) and BX (height:width) across the offset computation.
	push ax bx
	mov al, dh
	mov ah, [drawCols]
	mul ah
	mov bx, dx
	xor bh, bh
	add ax, bx
	shl ax, 1
	add ax, [drawBase]
	mov di, ax
	pop bx					; restore BH=height, BL=width
	pop ax					; restore AL=fill char

	; Row advance = (drawCols - width) * 2  (use CX as scratch, reset after)
	xor ch, ch
	mov cl, [drawCols]
	sub cl, bl
	shl cx, 1
	mov si, cx

	mov cl, bh
	xor ch, ch				; cx = height (outer loop)

@@row_loop:
	push cx
	xor ch, ch
	mov cl, bl				; cx = width (inner loop)
@@col_loop:
	mov ah, es:[di+1]		; preserve existing attribute byte
	stosw
	loop @@col_loop
	add di, si
	pop cx
	loop @@row_loop

	ret
FillFrame ENDP


; ============= PrintString ===================================================
;
; Print a null-terminated string at screen coordinates DX.
; Treats 0Ah as a line break: advances DH, resets DL to original column.
;
; IN:
;	ES    = target segment
;	DH    = Y, DL = X  (DL restored on each line break)
;	DS:SI = null-terminated string
;	AH    = color attribute
;
; GLOBAL VARS (read via DS): drawCols, drawBase
;
; OUT:  -
; DESTR: AX, BX, DI, SI, DH, DirFlag
;
PrintString PROC
	push ax					; save AH across offset computation
	mov al, dh
	mov ah, [drawCols]
	mul ah
	mov bx, dx
	xor bh, bh
	add ax, bx
	shl ax, 1
	add ax, [drawBase]
	mov di, ax
	pop ax

	cld

@@loop:
	lodsb
	test al, al
	jz @@done
	cmp al, 0Ah
	je @@newline
	stosw
	jmp @@loop

@@newline:
	inc dh					; next row; DL unchanged = same starting column
	push ax
	mov al, dh
	mov ah, [drawCols]
	mul ah
	mov bx, dx
	xor bh, bh
	add ax, bx
	shl ax, 1
	add ax, [drawBase]
	mov di, ax
	pop ax
	jmp @@loop

@@done:
	ret
PrintString ENDP

; ============= Draw surface parameters =======================================
;
; For VGA text video memory (ES = 0B800h):
;   drawCols = 80,  drawBase = 0             (default — video mode)
;
; For a compact window buffer (ES = CS):
;   drawCols = WIN_W,  drawBase = offset draw_buf
;   Pass DH=0, DL=0 so the frame fills the buffer from its very first cell.

drawCols    db  80      ; columns per row in target surface
drawBase    dw  0       ; byte offset added to the computed DI
