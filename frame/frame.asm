.model tiny
.code
.386
locals @@

org 100h


; ============= MACRO ========================================================+

VideoMemorySeg 	equ 0b800h
INCLUDE debug.inc

exit0 MACRO
	mov ax, 4c00h
	int 21h
ENDM


; ============= video_mem_offset ==============================================

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
	mov al, dh						; al = y
	mov ah, 80d						; ah = 80  (columns per row)
	mul ah							; ax = y * 80  (row start, in characters)
	mov bx, dx						; bx = dx  (copy DX to extract DL cleanly)
	xor bh, bh						; bh = 0 -> bx = dl = x
	add ax, bx						; ax = y * 80 + x  (cell index)
	shl ax, 1						; ax *= 2  (each cell = 1 byte char + 1 byte attr)
ENDM

; =============================================================================


; ============= MAIN ========================================================

Start:

	mov ax, VideoMemorySeg
	mov es, ax

	; mov bx, offset frameChars

	; xor bx, bx			; bx = 0, comment because on start its 0

	; mov al, '$'
	mov ah, 4eh

	mov dh, 5d
	mov dl, 2d

	mov bl, ds:[80h]	; bl = PSP[80h] = command-line length (includes leading space before args)
	add bl, 3d			; bl = frame width: cmd-len + left border + right border + 1 padding
	mov bh, 5d			; bh = frame height = 5 rows

	BkPt

	call PrintFrame

; 	inc dh
; 	inc dl
;
; 	mov al, 176d
;
; 	sub bl, 2d
; 	sub bh, 2d
;
; 	call PrintFrame
;
; 	inc dh
; 	inc dl

	; call PrintCMDLine

	exit0

; =============================================================================


; ============= PrintCharAt ===================================================

; Function to print symbol AL (color in AH) on screen at coordinates in DX
;
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
;	AL = symbol
;	AH = attribute
; OUT:
; 	-
; EXP:
;	ES = b800h
; DESTR:
;	BX
;
PrintCharAt PROC
	push ax
	video_mem_offset

	mov bx, ax						; bx = ax
	pop ax

	mov word ptr es:[bx], ax
	; es:[bx] = al (char),  es:[bx+1] = ah (attr)  — little-endian word write

	ret
PrintCharAt ENDP


; ============= PrintHLine ====================================================

; Function to print a horizontal line of CX symbols starting at coordinates DX with symbol AX
;
; Direction-aware: CLD -> left-to-right (DI += 2 per char),  STD -> right-to-left (DI -= 2 per char)
;
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
;	AL = symbol
;	AH = attribute
; 	CX = count of symbols
; OUT:
;	-
; EXP:
;	ES = b800h
; DESTR:
; 	BX, CX, DI
;
PrintHLine PROC
	push ax
	video_mem_offset

	mov di, ax
	pop ax

	rep stosw						; while (cx--) es[di += 2] = ax

	ret
PrintHLine ENDP


; ============= PrintVLine ====================================================

; Function to print a vertical line of CX symbols starting at coordinates DX with symbol AX
;
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
;	AL = symbol
;	AH = attribute
; 	CX = count of symbols
; OUT:
;	-
; DESTR:
; 	BX, CX, DI
;
PrintVLine PROC
	push ax
	video_mem_offset

	mov di, ax
	pop ax

	@@loop:							; while (cx--) { es:[di] = ax;  di += 160 (next row) }
		mov word ptr es:[di], ax
		add di, 160d				; 80 columns × 2 bytes/column = 160 bytes per row
		dec cx

		; cmp cx, 0
	jne @@loop

	ret
PrintVLine ENDP


; ============= PrintIVLine ===================================================

; Function to print a vertical line of CX symbols going upward from starting coordinates DX
;
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
;	AL = symbol
;	AH = attribute
; 	CX = count of symbols
; OUT:
;	-
; DESTR:
; 	BX, CX, DI
;
PrintIVLine PROC
	push ax
	video_mem_offset

	mov di, ax
	pop ax

	@@loop:							; while (cx--) { es:[di] = ax;  di -= 160 (prev row) }
		mov word ptr es:[di], ax
		sub di, 160d				; 80 columns × 2 bytes/column = 160 bytes per row
		dec cx

		; cmp cx, 0
	jne @@loop

	ret
PrintIVLine ENDP


; ============= PrintFrame ====================================================

; Function to print a rectangular frame, characters taken from array in DataSegment
;
; IN:
;	DH   = Ystart (0-24)
;	DL   = Xstart (0-80)
;	BH   = Height
;	BL   = Width
;	frameChars	- array of chars to print frame
;	frameAttr	- color attribute for frame
;	fillAttr	- color attribute for frame fill
; OUT:
;	-
; EXP:
;	ES = b800h
; DESTR:
; 	AX, CX, DX, DI
;	DirFlag
;
;
; Logic of function in C:
;
; //  frameChars[9]:
; //    [0]= [1]=═ [2]=╗
; //    [3]=║           [5]=║
; //    [6]=╚ [7]=═ [8]=╝
; //  frameAttr  - color attribute of frame
; //  fillAttr   - color attribute of fill (unused in current function)
;
; void print_frame(byte x,				byte y,
;                  byte width,			byte height,
;                  byte frame_chars[9],
;                  byte frame_attr,		byte fill_attr)
; {
;	 // Fill background
;	 fill_frame(x+1, y+1, height-2, width-2, frame_chars[4], fill_attr);
;
;    // Upper left corner
;    print_char_at(x, y, frame_chars[0], frame_attr);
;
;    // Upper horizontal  (X+1 .. X+width-2)
;    print_hline(x + 1, y, width - 2, frame_chars[1], frame_attr);
;
;    // Left vertical  (Y+1 .. Y+height-2)
;    print_vline(x, y + 1, height - 2, frame_chars[3], frame_attr);
;
;    // Right vertical
;    print_vline(x + width - 1, y + 1, height - 2, frame_chars[5], frame_attr);
;
;    // Lower horizontal
;    print_hline(x + 1, y + height - 1, width - 2, frame_chars[7], frame_attr);
;
;    // Lower right corner
;    print_char_at(x + width - 1, y + height - 1, frame_chars[8], frame_attr);
;
;    // Lower left corner
;    print_char_at(x, y + height - 1, frame_chars[6], frame_attr);
;
;    // Upper right corner
;    print_char_at(x + width - 1, y, frame_chars[2], frame_attr);
;
;	 // Print args
;	 print_cmd_args(x + 2, y + 2, argc, argv);
; }
;
PrintFrame PROC
	push bp
	mov bp, sp
	; Stack frame after next two pushes:
	;   [bp-2] = BX  (BH = height,  BL = width)
	;   [bp-4] = DX  (DH = Y,       DL = X    )
	;   [bp]   = saved BP
	;   [bp+2] = return address

	push bx
	push dx

	; fill_frame(x+1, y+1, height-2, width-2, frameChars[4], fillAttr)
	mov ah, [fillAttr]
	mov al, [frameChars + 4]
	push ax					; 3rd arg: fill char (al) / attr (ah)

	mov ah, bh
	mov al, bl
	sub ah, 2				; height - 2
	sub al, 2				; width - 2
	push ax					; 2nd arg: height-2 (->bh), width-2 (->bl)

	mov ah, dh
	mov al, dl
	inc ah					; y + 1
	inc al					; x + 1
	push ax					; 1st arg: y+1 (->dh), x+1 (->dl)

	call FillFrame			; clobbers AX BX CX DX DI ES;

	; FillFrame clobbered BX and DX — restore from stack frame
	mov bx, [bp - 2]		; bx = saved BX  (BH = height, BL = width)
	mov dx, [bp - 4]		; dx = saved DX  (DH = Y,      DL = X    )

	mov cx, [bp - 2]	; cx = [BH:BL] = [height:width]
	xor ch, ch		    ; ch = 0 -> cx = cl = BL = width
	sub cx, 2			; cx = width - 2  (inner horizontal line length, excl. corners)

	mov al, [frameChars]
	mov ah, [frameAttr]

	call PrintCharAt

	inc dl				; dl = X + 1
	; -> position: (X+1, Y)

	mov al, [frameChars + 1]

	cld
	call PrintHLine

	mov cx, [bp - 2]	; cx = [BH:BL] = [height:width]
	mov cl, ch			; cl = CH = BH = height  (move height down into CL)
	xor ch, ch			; ch = 0 -> cx = height
	sub cx, 2			; cx = height - 2  (inner vertical line length, excl. corners)

	dec dl				; dl = X
	inc dh				; dh = Y + 1
	; -> position: (X, Y+1)

	mov al, [frameChars + 3]

	call PrintVLine

	; Navigate from (X, Y+1) to the start of the lower horizontal line.
	; CX still holds [height:width] from the load above.
	mov cx, [bp - 2]	; cx = [BH:BL] = [height:width]
	add dh, ch			; dh = (Y+1) + height
	add dl, cl			; dl = X     + width

	sub dh, 2			; dh = Y + height - 1  (bottom row)
	sub dl, 2			; dl = X + width  - 2  (rightmost inner col; STD prints leftward)
	; -> position: (X+width-2, Y+height-1)

	xor ch, ch			; ch = 0 -> cx = cl = BL = width
	sub cx, 2			; cx = width - 2  (inner horizontal line length, excl. corners)

	mov al, [frameChars + 7]

	std
	call PrintHLine

	mov cx, [bp - 2]	; cx = [BH:BL] = [height:width]
	mov cl, ch			; cl = CH = BH = height  (move height down into CL)
	xor ch, ch			; ch = 0 -> cx = height
	sub cx, 2			; cx = height - 2  (inner vertical line length, excl. corners)

	inc dl				; dl = X + width - 1  (right column)
	dec dh				; dh = Y + height - 2  (one row above bottom)
	; -> position: (X+width-1, Y+height-2);  PrintIVLine draws upward

	mov al, [frameChars + 5]

	call PrintIVLine

	; PrintIVLine left DH at Y+1 — advance back down to bottom row
	inc dh				; dh = Y + height - 1
	; -> position: (X+width-1, Y+height-1)

	mov al, [frameChars + 8]

	call PrintCharAt

	push dx					; save DX = (X+width-1, Y+height-1)

	mov dl, [bp - 4]		; dl = original X  ([bp-4] = low byte of saved DX = saved DL)
	mov al, [frameChars + 6]

	call PrintCharAt		; lower-left corner at (X, Y+height-1)

	pop dx					; restore DX = (X+width-1, Y+height-1)

	mov dh, [bp - 3]		; dh = original Y  ([bp-3] = high byte of saved DX = saved DH)
	mov al, [frameChars + 2]

	call PrintCharAt

	pop dx					; dx = original start (DH = Y, DL = X)  — first push dx above
	add dh, 2				; dh = Y + 2  (skip top border row + one padding row)
	add dl, 2				; dl = X + 2  (skip left border col + one padding col)

	call PrintCMDLine		; print command-line args inside the frame

	pop bx

	pop bp
	ret
PrintFrame ENDP


; ============= FillFrame =====================================================

; Function to fill rectangle with spaces
;
; Args pushed by caller (Pascal convention — callee cleans with RET 6):
;
;   Stack layout on entry (after PUSH BP / MOV BP,SP inside function):
;   [bp+8] = fill word   (AH = color attr,  AL = fill character)
;   [bp+6] = size word   (BH = height,      BL = width          )
;   [bp+4] = origin word (DH = Y,           DL = X              )
;   [bp+2] = return address
;   [bp]   = saved BP
;
; IN:
;	[bp+4]: DH = line Y (0-24),  DL = col X (0-80)
;	[bp+6]: BH = height,          BL = width
;	[bp+8]: AH = color attribute, AL = fill character
; OUT:
;	-
; EXP:
;	ES = b800h
; DESTR:
;	AX, BX, CX, DX, DI
;
FillFrame PROC
	push bp
	mov bp, sp

	mov dx, [bp+4]				; dh = y,      dl = x
	mov bx, [bp+6]				; bh = height, bl = width
	mov ax, [bp+8]				; ax = fill color

	cld

	@@loop:
		push bx
		mov cl, bl
		call PrintHLine
		pop bx
		inc dh					; advance to next row
		dec bh
	jnz @@loop

	pop bp
	ret 6					; pop 3 caller words (6 bytes) off stack  (Pascal convention)
FillFrame ENDP


; ============= PrintCMDLine ==================================================

; Print command line at coordinates DX, with attribute AH
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
;	textAttr - color attribute of text
; OUT:
;	-
; EXP:
;	ES = b800h
; DESTR:
; 	DirFlag
;
PrintCMDLine PROC
	push di
	push si
	push bx
	push ax

	video_mem_offset

	mov di, ax
	; PSP layout (always at DS:0000 in COM programs):
	;   DS:[80h]  — byte: total command-line length, counting the leading space before args
	;   DS:[81h]  — space character (separator before first arg)
	;   DS:[82h+] — actual argument characters, not null-terminated
	mov si, 80h

	; xor bx, bx
	mov bl, ds:[si]			; bl = PSP[80h] = cmd-line length  (includes leading space)

	pop ax
	push ax

	dec bl					; bl--: subtract the leading space -> bl = number of arg chars
	add si, 2				; si = 82h: skip length byte (80h) and leading space (81h) -> first arg char

	mov ah, [textAttr]
	cld

	@@loop:

		lodsb; al = ds:[si++]
		stosw; es:[di+=2] = ax

		; mov byte ptr es:[di], [textAttr]

		; inc di
		dec bl

		; cmp bx, 0
	jne @@loop

	pop ax
	pop bx
	pop si
	pop di
	ret
PrintCMDLine ENDP

; =============================================================================


; ============= DATA SEGMENT ==================================================

.data

db 'DATA'

frameChars	db 0c9h, 0cdh, 0bbh, 0bah, 020h, 0bah, 0c8h, 0cdh, 0bch
frameAttr	db 4eh
fillAttr	db 0eh
textAttr	db 0eh

end Start
