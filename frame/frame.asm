.model tiny
.code
.386
locals @@

org 100h

VideoMemorySeg 	equ 0b800h
Debug			equ 1

BkPt MACRO
	IF Debug
		int 03h
	ENDIF
ENDM

Start:

	mov ax, VideoMemorySeg
	mov es, ax

	; mov bx, offset frameChars

	; xor bx, bx			; bx = 0, comment because on start its 0

	mov al, '$'
	mov ah, 4eh

	mov dh, 5d
	mov dl, 2d

	mov bl, ds:[80h]	; bl = len(cl)
	add bl, 3d
	mov bh, 5d

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

	mov ax, 4c00h
	int 21h

; макрос для расчета offset в оперативной памяти
;
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
; OUT:
;	AX = offset
; DESTR:
;	BX
;
calc_offset MACRO
	mov al, dh						; al = y
	mov ah, 80d						; ah = 80
	mul ah							; ax = ah * al
	mov bx, dx						; bx = dx
	xor bh, bh						; bh = 0 ; bx = dl
	add ax, bx						; ax += x
	shl ax, 1						; ax *= 2
ENDM

; функция для вывода символа AL (цвет в AH) на экран по координатам в dx
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
	calc_offset

	mov bx, ax						; bx = ax
	pop ax

	mov word ptr es:[bx], ax		; M[es * 16 + bx] = ah; M[es * 16 + bx + 1] = al

	ret
PrintCharAt ENDP

; функция для вывода горизонтальной линии длинны cx начиная с координат dx из символа ax
;
; можно выводить справа налево если установить DirFlag = down
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
	calc_offset

	mov di, ax
	pop ax

	rep stosw						; while (cx--) es[di += 2] = ax

	ret
PrintHLine ENDP

; функция для вывода вертикальной линии длинны cx начиная с координат dx из символа ax
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
	calc_offset

	mov di, ax
	pop ax

	@@loop:							; while (cx--) es[di] = ax; di += 160
		mov word ptr es:[di], ax
		add di, 160d
		dec cx

		; cmp cx, 0
	jne @@loop

	ret
PrintVLine ENDP

; функция для вывода вертикальной линии снизу вверх заданной длинны
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
	calc_offset

	mov di, ax
	pop ax

	@@loop:							; while (cx--) es[di] = ax; di += 160
		mov word ptr es:[di], ax
		sub di, 160d
		dec cx

		; cmp cx, 0
	jne @@loop

	ret
PrintIVLine ENDP

; функция для вывода прямоугольной рамки, символы берутся из массива в DataSegment
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
PrintFrame PROC
;
; Аналог функции на c:
;
; //  frameChars[9]:
; //    [0]=┌ [1]=─ [2]=┐
; //    [3]=│           [5]=│
; //    [6]=└ [7]=─ [8]=┘
; //  frameAttr  ? атрибут цвета рамки
; //  fillAttr   ? атрибут цвета заливки (пока не используется в данной функции)
;
; void print_frame(byte x,				byte y,
;                  byte width,			byte height,
;                  byte frame_chars[9],
;                  byte frame_attr,		byte fill_attr)
; {
;    // Верхний левый угол ┌
;    print_char_at(x, y, frame_chars[0], frame_attr);
;
;    // Верхняя горизонталь ─  (X+1 .. X+width-2)
;    print_hline(x + 1, y, width - 2, frame_chars[1], frame_attr);
;
;    // Левая вертикаль │  (Y+1 .. Y+height-2)
;    print_vline(x, y + 1, height - 2, frame_chars[3], frame_attr);
;
;    // Правая вертикаль │
;    print_vline(x + width - 1, y + 1, height - 2, frame_chars[5], frame_attr);
;
;    // Нижняя горизонталь ─
;    print_hline(x + 1, y + height - 1, width - 2, frame_chars[7], frame_attr);
;
;    // Нижний правый угол ┘
;    print_char_at(x + width - 1, y + height - 1, frame_chars[8], frame_attr);
;
;    // Нижний левый угол └
;    print_char_at(x, y + height - 1, frame_chars[6], frame_attr);
;
;    // Верхний правый угол ┐
;    print_char_at(x + width - 1, y, frame_chars[2], frame_attr);
; }
;
	push bp
	mov bp, sp

	push bx
	push dx

	mov cx, [bp - 2]	; cx = bx
	xor ch, ch		; ch = 0; cl = bl = width
	sub cx, 2

	mov al, [frameChars]

	call PrintCharAt

	inc dl
	; Start at X+1, Y

	mov al, [frameChars + 1]

	cld
	call PrintHLine

	mov cx, [bp - 2]	; cx = bx
	mov cl, ch		; cl = ch = bh = height
	xor ch, ch		; ch = 0 ; cx = height
	sub cx, 2

	dec dl
	inc dh
	; Start at X, Y+1

	mov al, [frameChars + 3]

	call PrintVLine

	; Go to X+Width-1, Y+Height-1

	mov cx, [bp - 2]	; cx = bx
	add dh, ch		; (y+1) += height
	add dl, cl		; x     += width

	sub dh, 2		; y = Y + height - 1
	sub dl, 2		; x = X + width  - 2

	xor ch, ch		; ch = 0; cl = bl = width
	sub cx, 2

	mov al, [frameChars + 7]

	std
	call PrintHLine

	mov cx, [bp - 2]	; cx = bx
	mov cl, ch		; cl = ch = bh = height
	xor ch, ch		; ch = 0 ; cx = height
	sub cx, 2

	inc dl
	dec dh
	; Start at y = Y + height - 2; x = X + width - 1

	mov al, [frameChars + 5]

	call PrintIVLine

	; at y = Y + height - 1; x = X + width - 1
	inc dh

	mov al, [frameChars + 8]

	call PrintCharAt

	push dx

	mov dl, [bp - 4]	; x = X
	mov al, [frameChars + 6]

	call PrintCharAt

	pop dx

	mov dh, [bp - 3]	; y = Y
	mov al, [frameChars + 2]

	call PrintCharAt

	pop dx

	add dh, 2
	add dl, 2

	call PrintCMDLine

	pop bx

	pop bp
	ret
PrintFrame ENDP

; Функция для заливки прямоугольника
;
; Args in stack, pascal
; IN:
;	stack[0] = line (Y) (0-24)
;	stack[1] = col  (X) (0-80)
;
;
FillFrame PROC
	ret
FillFrame ENDP

; вывести командную строчку по координатам dx, с атрибутом ah
; IN:
;	DH = line (Y) (0-24)
;	DL = col  (X) (0-80)
;	textAttr - color attribute of text
; OUT:
;	-
; DESTR:
; 	-
;
PrintCMDLine PROC
	push di
	push si
	push bx
	push ax

	calc_offset

	mov di, ax
	mov si, 80h

	; xor bx, bx
	mov bl, ds:[si]

	pop ax
	push ax

	dec bl
	add si, 2

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

.data

db 'DATA'

frameChars	db 0c9h, 0cdh, 0bbh, 0bah, 020h, 0bah, 0c8h, 0cdh, 0bch
frameAttr	db 4eh
fillAttr	db 0eh
textAttr	db 0eh

end Start
