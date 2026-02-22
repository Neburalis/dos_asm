.model tiny
.code

org 100h              			; PC = 256;

Start:	mov ah, 09h 			; AH = 9; DOS Fn 09h - puts
	mov dx, offset Hello		; DX = &Hello
	int 21h

	mov ax, 4c00h			; DOS Fn 4ch - exit
	int 21h

Hello	db 0dh, 0ah, 'HELLO WORLD$'

end 	Start