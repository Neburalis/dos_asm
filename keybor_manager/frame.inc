; ============= PrintFrame ====================================================
;
; Draws a bordered rectangle directly into VGA text memory.
;
; IN:
;	ES  = 0B800h    video segment  (caller sets once, not modified here)
;	DH  = Y         top row        (0-24)
;	DL  = X         left col       (0-79)
;	BH  = height    total rows including borders  (>= 2)
;	BL  = width     total cols including borders  (>= 2)
;
; DATA (read from .data segment):
;	frameChars[9] — border/fill characters:
;		[0]=TL corner   [1]=top border  [2]=TR corner
;		[3]=left border [4]=fill char   [5]=right border
;		[6]=BL corner   [7]=bot border  [8]=BR corner
;	frameAttr — color attribute byte for all border characters
;	fillAttr  — color attribute byte for interior fill
;
; DESTR:
;   AX, CX, SI, DI
;   DirFlag
;
PrintFrame PROC
	cld

	; --- Compute DI = video memory offset of top-left corner ---
    push bx
	video_mem_offset			; IN: DH=Y, DL=X  OUT: AX=(DH*80+DL)*2
    pop bx
	mov di, ax

	mov ah, [frameAttr]

	; --- Top row ---

	mov al, [frameChars]		; [0] TL corner
	stosw						; es:[di+=2] = ax

	mov al, [frameChars+1]		; [1] top border
	xor ch, ch
	mov cl, bl
	sub cx, 2					; cx = width - 2
	rep stosw					; write top border chars

	mov al, [frameChars+2]		; [2] TR corner
	stosw
	; DI now sits width*2 bytes past the top-left corner

	; Precompute row advance: 160 - width*2
	; After writing a full row of width chars the cursor is width*2 bytes past
	; the row's left col; adding (160 - width*2) steps it to the same col on
	; the next row (160 = 80 cols * 2 bytes/cell).
	xor ch, ch
	mov cl, bl
	shl cx, 1					; cx = width * 2
	mov si, 160
	sub si, cx					; si = 160 - width*2

	; --- Middle rows: height-2 iterations ---
	mov cl, bh
	xor ch, ch
	sub cx, 2					; cx = height - 2

@@mid_loop:
	add di, si					; advance DI to left border of next row

	mov al, [frameChars+3]		; [3] left border
	mov ah, [frameAttr]
	stosw

	mov al, [frameChars+4]		; [4] fill char
	mov ah, [fillAttr]
	push cx						; save row loop counter
	xor ch, ch
	mov cl, bl
	sub cx, 2					; cx = width - 2
	rep stosw					; fill interior
	pop cx						; restore row loop counter

	mov al, [frameChars+5]		; [5] right border
	mov ah, [frameAttr]
	stosw

	loop @@mid_loop

	; --- Bottom row ---
	add di, si					; same advance (si = 160 - width*2, still valid)

	mov ah, [frameAttr]

	mov al, [frameChars+6]		; [6] BL corner
	stosw

	mov al, [frameChars+7]		; [7] bottom border
	xor ch, ch
	mov cl, bl
	sub cx, 2					; cx = width - 2
	rep stosw

	mov al, [frameChars+8]		; [8] BR corner
	stosw

	ret
PrintFrame ENDP

; ============= FillFrame =====================================================
;
; Fill a rectangular region with a character, preserving existing attributes.
;
; IN:
;	ES  = 0B800h    video segment  (caller sets once, not modified here)
;	DH  = Y         top row        (0-24)
;	DL  = X         left col       (0-79)
;	BH  = height    number of rows (>= 1)
;	BL  = width     number of cols (>= 1)
;	AL  = fill char
;
; OUT:  -
; DESTR: AX, CX, SI, DI
;        DirFlag
;
FillFrame PROC
	cld

	; --- Compute DI = video memory offset of top-left corner ---
	push bx
	video_mem_offset			; IN: DH=Y, DL=X  OUT: AX=(DH*80+DL)*2  DESTR: BX
	pop bx
	mov di, ax

	; Precompute row advance: 160 - width*2
	xor ch, ch
	mov cl, bl
	shl cx, 1					; cx = width*2
	mov si, 160
	sub si, cx					; si = 160 - width*2

	mov cl, bh
	xor ch, ch					; cx = height (outer loop)

@@row_loop:
	push cx						; save row counter
	xor ch, ch
	mov cl, bl					; cx = width (inner loop)
@@col_loop:
	mov ah, es:[di+1]			; read existing attribute byte
	stosw						; write AL (char) + AH (preserved attr), DI += 2
	loop @@col_loop
	add di, si					; advance DI to same column on next row
	pop cx						; restore row counter
	loop @@row_loop

	ret
FillFrame ENDP


; ============= PrintString ===================================================
;
; Print a null-terminated string at screen coordinates DX.
; Treats \n (5Ch) as a line break: advances DH by one row,
; resets DL to the original starting column, and continues printing.
;
; IN:
;	ES    = 0B800h    video segment  (caller sets once, not modified here)
;	DH    = Y         start row      (0-24)
;	DL    = X         start col      (0-79)  — restored on each '\' line break
;	DS:SI = pointer to null-terminated string
;	AH    = color attribute
;
; OUT:  -
; DESTR: AX, BX, DI, SI, DH
;        DirFlag
;
PrintString PROC
	push ax						; save AH (color attr) across video_mem_offset
	video_mem_offset			; IN: DH=Y, DL=X  OUT: AX=(DH*80+DL)*2  DESTR: BX
	mov di, ax
	pop ax						; restore AH; AL will be overwritten by lodsb

	cld

@@loop:
	lodsb						; al = ds:[si++]
	test al, al
	jz @@done
	cmp al, 0Ah				; line break?
	je @@newline
	stosw						; es:[di+=2] = ax  (char + attr)
	jmp @@loop

@@newline:
	inc dh						; next row; DL = original X (never modified)
	push ax						; save AH
	video_mem_offset			; recompute DI for new row, same column
	mov di, ax
	pop ax						; restore AH
	jmp @@loop

@@done:
	ret
PrintString ENDP