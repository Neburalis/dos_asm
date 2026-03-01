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

; Algoritohm in C:
; psp += 2;
;
; // Parse params
; do {
; 	if (*psp == '-') {
; 		++psp;
; 		switch (*psp) {
; 			case 'b':
; 				psp += 1;
; 				background = htoi(psp);
; 				break;
; 			case 'f':
; 				psp += 1;
; 				framecolor = htoi(psp);
; 				break;
; 			case 't':
; 				psp += 1;
; 				textcolor = htoi(psp);
; 				break;
;			case 's':
;				psp += 1;
;				if (*psp == '*') {
;					strcpy(frameChars, psp);
;					break;
;				}
;				uint8_t style = *psp - '0';
;				if (style > 3) break;
;				strcpy(frameChars, styleTable + 9*style);
;				break;
; 			default:
; 				break;
; 		}
; 	}
; 	else break;
; } while (*psp != 0);
;
; printFrame();
; PrintLine(psp);

	mov ax, VideoMemorySeg
	mov es, ax

	; === Parse command-line flags: -b <attr>  -f <attr>  -t <attr> ===
	mov si, 82h				; si -> first arg char in raw PSP

ArgLoop:
	cmp  byte ptr ds:[si], 0	; end of token stream?
	je   ArgDone
	cmp  byte ptr ds:[si], '-'	; flag token?
	jne  ArgDone

	inc  si					; si -> flag char
	mov  al, ds:[si]		; al = flag char
	inc  si 				; si -> start of value token (e.g. "4E")

	cmp  al, 'b'
	je   FlagB
	cmp  al, 'f'
	je   FlagF
	cmp  al, 't'
	je   FlagT
	cmp  al, 's'
	je   FlagS
	jmp  ArgDone			; unknown flag -> stop, treat rest as text

FlagB: ; backgrount attr
	call htoi				; AX = attribute value,  SI -> space after value
	mov  [fillAttr], al
	inc  si					; si -> next flag or text
	jmp  ArgLoop

FlagF: ; frame attr
	call htoi
	mov  [frameAttr], al
	inc  si
	jmp  ArgLoop

FlagT: ; text attr
	call htoi
	mov  [textAttr], al
	inc  si
	jmp  ArgLoop

FlagS: ; Standard styles: 0=spaces, 1=single-line, 2=double-line, 3=hearts
	lodsb				; mov al, ds:[si] ; inc si
	cmp al, '*'
	jne @@s_default
; s_custom
	mov di, offset frameChars
	mov cx, 9

@@sloop:
	lodsb 				; mov al, ds:[si] ; inc si
	mov [di], al
	inc di
	dec cx
	jnz @@sloop
	inc si				; skip trailing space -> next token
	jmp ArgLoop

@@s_default:
	sub  al, '0'		; ASCII digit -> integer
	cmp  al, 3
	ja   @@s_skip		; out of range -> ignore
	xor  ah, ah
	mov  bl, 9
	mul  bl				; ax = style * 9  (byte offset into styleTable)
	add  ax, offset styleTable	; ax = &styleTable[style]
	mov  bx, ax
	mov  di, offset frameChars
	mov  cx, 9
@@s_copy:
	mov  al, [bx]
	mov  [di], al
	inc  bx
	inc  di
	loop @@s_copy
@@s_skip:
	inc  si				; skip trailing space -> next token
	jmp  ArgLoop

ArgDone:
	; SI = pointer to text token in raw PSP (space-separated, CR-terminated)

	; === Set up frame dimensions ===
	mov bl, ds:[80h]		; bl = PSP cmd-line length (includes leading space)
	add bx, 82h
	sub bx, si
	mov bh, 5d				; bh = frame height = 5 rows
	add bl, 3d				; bl = frame width: cmd-len + borders + padding

	; === Set up frame position ===

	BkPt

	mov al, bl
	shr al, 1
	mov dl, 40d
	sub dl, al
	mov dh, 5d

	BkPt

	push si					; save text pointer across PrintFrame
	call PrintFrame			; draw borders and fill

	pop  si					; restore text pointer
	add  dh, 2				; dh = Y + 2  (inside-frame row: skip top border + padding row)
	add  dl, 2				; dl = X + 2  (inside-frame col: skip left border + padding col)
	mov  ah, [textAttr]
	call PrintLine			; print text inside the frame

	exit0

; =============================================================================

INCLUDE strlib.inc

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

; Draws a bordered rectangle directly into VGA text memory. All rendering is
; inline using rep stosw; no helper procedure calls.
;
; IN:
;	DH   = Ystart (0-24)
;	DL   = Xstart (0-80)
;	BH   = Height (>= 2)
;	BL   = Width  (>= 2)
;	frameChars	- 9-byte array: TL, top, TR, L, fill, R, BL, bot, BR
;	frameAttr	- color attribute for border characters
;	fillAttr	- color attribute for interior fill
; OUT:
;	-
; EXP:
;	ES = b800h
; DESTR:
;	AX, CX, SI, DI
;	DirFlag
;
PrintFrame PROC
	cld

	; --- Compute DI = video memory offset of top-left corner ---
	push bx
	video_mem_offset			; IN: DH=Y, DL=X  OUT: AX=(DH*80+DL)*2  DESTR: BX
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
	rep stosw

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


; ============= PrintLine ===================================================

; Print a string at screen coordinates DX, stopping at any control char (< 20h)
; Handles both null-terminated strings and raw PSP args (CR-terminated).
;
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
;	DS:SI = pointer to string (null / CR / any ctrl-char terminated)
;	AH    = color attribute
; OUT:
;	-
; EXP:
;	ES = b800h
; DESTR:
;	AX, BX, DI, SI
;   DirFlag
;
PrintLine PROC
	push ax
	video_mem_offset

	mov di, ax
	pop ax

	cld

	@@loop:
		lodsb				; al = ds:[si++]
		cmp al, 20h			; stop at any control char (null, CR, etc.)
		jb @@done
		stosw				; es:[di+=2] = ax  (al = char, ah = attr)
	jmp @@loop

	@@done:
	ret
PrintLine ENDP

; =============================================================================


; ============= DATA SEGMENT ==================================================
.data
DATA

frameChars	db 0c9h, 0cdh, 0bbh, 0bah, 020h, 0bah, 0c8h, 0cdh, 0bch
frameAttr	db 4eh
fillAttr	db 0eh
textAttr	db 0eh

; styleTable: 4 rows × 9 bytes  (style chars: TL, T, TR, L, fill, R, BL, B, BR)
styleTable:
	db 020h,020h,020h,020h,020h,020h,020h,020h,020h	; 0: no frame (spaces)
	db 0DAh,0C4h,0BFh,0B3h,020h,0B3h,0C0h,0C4h,0D9h	; 1: single-line
	db 0C9h,0CDh,0BBh,0BAh,020h,0BAh,0C8h,0CDh,0BCh	; 2: double-line
	db 003h,003h,003h,003h,020h,003h,003h,003h,003h	; 3: hearts

end Start
