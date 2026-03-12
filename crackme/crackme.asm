.model tiny
.code
locals @@

INCLUDE debug.inc
INCLUDE utils.inc
Debug			equ 1

org 100h

; Псевдокод на c:
; void get_pass() {
;     asm push bp
;     asm mov bp, sp
;
;     _sp -= 10; // выделили массив в 10 на стеке (char arr[10])
;
;     do {
;         _al = getchar(); // ah = 01h\n int 21h
;         if (_al == '\r') break; // enter = CRLF, first getchar get CR
;         *_sp = _al; // [VULN 1] нет проверки границ: после 10 символов
;                     // перезаписываем saved BP, затем адрес возврата
;         ++_sp;
;     } while (true);
;
;     _ax = 0; // xor ax, ax
;
;     while(_sp >= _bp - 10) {
;         _bx = _ax << 2; // ax *= 4
;         _ax += _bx;
;         _ax += *_sp;
;         --_sp; // итерируем назад по буферу: hash = hash*5 + char
;
;         // hash = hash * 5 + new_char
;     }
;
;     // return _ax
;
;     asm pop bp
;     return
; }
;
; void grant_access() {
;     print("Access granted");
; }
;
; void deny_access() {
;     print("Access denied");
; }
;
; short correct_pass_hash = 12345;
;
; int main() {
;
;     print_prompt();
;     get_pass(); // возвращает хеш пароля в AX
;
;     if (_ax == correct_pass_hash)  // должно быть: if (_ax == correct_pass_hash)
;         grant_access();
;     else
;         deny_access();
;
;
;     return 0;
; }


; main
Start:
    mov  dx, OFFSET PROMPT
    mov  ah, 09h
    int  21h

    call get_pass           ; hash returned in AX

    cmp  ax, [CORRECT_HASH]
    je   do_grant

    call deny_access
    jmp  done

do_grant:
    call grant_access

done:
    exit0

; grant_access
grant_access PROC
    mov  dx, OFFSET OK_MSG
    mov  ah, 09h
    int  21h
    ret
grant_access ENDP

; deny_access
deny_access PROC
    mov  dx, OFFSET FAIL_MSG
    mov  ah, 09h
    int  21h
    ret
deny_access ENDP

; get_pass — reads password char by char, returns hash in AX
;
; Stack frame:
;   [BP+2]..[BP+3]  return address          <- VULN 1 overwrite target
;   [BP+0]..[BP+1]  saved BP                <- VULN 1 overwrite target
;   [BP-1]..[BP-10] 10-byte input buffer
;
; VULN 1 (stack buffer overflow):
;   No bounds check. Chars 11-12 overwrite saved BP,
;   chars 13-14 overwrite return address.
;   Attack: 12 bytes padding + addr(grant_access) -> bypasses hash check.
;
get_pass PROC
    push bp
    mov  bp, sp
    sub  sp, 10             ; allocate char buf[10] at [BP-10]..[BP-1]

    mov  di, sp             ; DI = buffer start = BP-10

@@read_loop:
    mov  ah, 01h
    int  21h                ; AL = typed character
    cmp  al, 0Dh            ; Enter (CR)?
    je   @@read_done
    mov  [di], al           ; [VULN 1] no bounds check
    inc  di
    jmp  @@read_loop

@@read_done:
    mov  byte ptr [di], 0   ; null-terminate

    ; print CRLF
    mov  ah, 02h
    mov  dl, 0Dh
    int  21h
    mov  dl, 0Ah
    int  21h

    ; Hash: iterate backward from DI (null byte) down to BP-10 (buffer start)
    ; hash = hash * 5 + *DI,  then DI--
    xor  ax, ax             ; hash = 0
    mov  cx, sp             ; CX = buffer start (loop bound)

@@hash_loop:
    cmp  di, cx
    jb   @@hash_done        ; DI < buffer start -> done

    mov  bx, ax
    shl  bx, 2              ; BX = AX * 4
    add  ax, bx             ; AX = AX * 5

    xor  bh, bh
    mov  bl, [di]           ; BX = char at DI (zero-extended)
    add  ax, bx             ; hash += char

    dec  di
    jmp  @@hash_loop

@@hash_done:
    add  sp, 10
    pop  bp

    BkPt

    ret
get_pass ENDP

CORRECT_HASH  dw  20648     ; hash("hello") — correct password is "hello"
PROMPT        db  'Enter password: $'
OK_MSG        db  'Access granted', 0Dh, 0Ah, '$'
FAIL_MSG      db  'Access denied', 0Dh, 0Ah, '$'

END Start
