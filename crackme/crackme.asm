.model tiny
.code
locals @@

org 100h

Start:
    mov  dx, OFFSET PROMPT
    mov  ah, 09h
    int  21h

    call compare_password

    jc   print_granted       ; CF=1 → совпало

    mov  dx, OFFSET FAIL_MSG
    jmp  print_and_exit

print_granted:
    mov  dx, OFFSET OK_MSG

print_and_exit:
    mov  ah, 09h
    int  21h
    mov  ah, 4Ch
    int  21h

;─────────────────────────────────────────────────────
compare_password:
    sub  sp, 10                 ; SP -= 10, buf = SS:[SP]

    ; Read the password BYTE by byte using INT 21h AH=01h
    ; WITHOUT a length limit—that's the vulnerability!
    mov  di, sp
read_loop:
    mov  ah, 01h
    int  21h                    ; read character in AL
    cmp  al, 0Dh                ; Enter?
    je   read_done
    mov  [di], al               ; write to buf
    inc  di                     ; next
    jmp  read_loop              ; unlimited

read_done:
    mov  byte ptr [di], 0

    ; Empty Line
    mov  ah, 02h
    mov  dl, 0Dh
    int  21h
    mov  dl, 0Ah
    int  21h

compare:
    ; Compare with the password
    mov  si, OFFSET PASSWORD
    mov  di, sp
cmp_loop:
    mov  al, [si]
    mov  bl, [di]
    cmp  al, bl
    jne  cmp_fail
    or   al, al
    jz   cmp_ok                 ; both zeros - matched
    inc  si
    inc  di
    jmp  cmp_loop
cmp_ok:
    add  sp, 10
    stc                      ; CF=1 — correct
    ret

cmp_fail:
    add  sp, 10
    clc                      ; CF=0 — incorrect
    ret

PASSWORD  db  'secret', 0
PROMPT    db  'Enter password: $'
OK_MSG    db  'Access granted$'
FAIL_MSG  db  'Access denied$'

END Start