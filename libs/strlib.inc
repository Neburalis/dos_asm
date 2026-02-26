; =============================================================================
; strlib.inc  -  Standard string library functions
;
; Functions:
;   strlen    - calculate length of null-terminated string
;   strchr    - find first occurrence of character in string
;   strnchr   - find first occurrence of character within N bytes
;   strcmp    - compare two null-terminated strings
;   strncmp   - compare up to N bytes of two strings
;   htoi      - convert hex ASCII string to 16-bit unsigned integer
;   itoh      - convert 16-bit unsigned integer to hex ASCII string
;   atoi      - convert decimal ASCII string to signed 16-bit integer
;   itoa      - convert signed 16-bit integer to decimal ASCII string
;   parse_psp - tokenize PSP command line in-place, return separator count
;
; Calling convention: register-based (no stack args)
;
; Usage in main file:
;   INCLUDE strlib.inc
; =============================================================================

IF 0
; ============= STRLEN ========================================================

; Function to calculate length of a null-terminated string
;
; C equivalent:
;   size_t strlen(const char *str)
;
; Algoritohm:
;   Scan ES:DI forward for null byte with REPNE SCASB.
;   Recover length from the change in CX.
;
;   length = ~(CX_after - 0xFFFF) - 1
;          = ~(-(length+2))        - 1
;          = (length+1)            - 1
;          = length
;
; IN:
;   ES:SI = pointer to null-terminated string
; OUT:
;   AX = number of characters before null terminator
; EXP:
;   DirFlag is forward (0)
; DESTR:
;   CX, DI
;
strlen PROC
        push es

        push ds
        pop  es                 ; es = ds  (scan string through ES:DI)

        mov  di, si             ; di = scan pointer  (SI preserved)

        xor  ax, ax             ; al = 0  (search value: null terminator)
        mov  cx, 0FFFFh         ; cx = -1 (scan up to 65535 bytes)

        repne scasb             ; while (cx-- && es:[di++] != 0) {}

        ; After scan, CX = 0xFFFF - (length + 1)
        ;                        = -(length + 2)  in two's complement
        xchg ax, cx             ; ax = -(length+2);  cx = 0
        not  ax                 ; ax = length + 1
        dec  ax                 ; ax = length

        pop  es
        ret
strlen ENDP


; ============= STRCHR ========================================================

; Function to find first occurrence of a character in a string
;
; C equivalent:
;   char *strchr(const char *str, int c)
;
; Note: null terminator is a valid search target.
;       strchr(str, 0) returns a pointer to the terminating null of str.
;
; IN:
;   DS:SI = pointer to null-terminated string
;   BL = character to search for
; OUT:
;   AX = offset of first occurrence of BL in string
;   AX = 0 (NULL) if character not found
; EXP:
;   DirFlag is forward (0)
; DESTR:
;   SI  (SI advances through the string)
;
strchr PROC

@@loop:
        lodsb                   ; al = ds:[si++]

        cmp  al, bl             ; al == search char?
        je   @@found

        and  al, al             ; al == 0  (end of string)?
        jnz  @@loop

        ; not found — return NULL
        xor  ax, ax             ; ax = 0
        ret

@@found:
        lea  ax, [si-1]         ; ax = si - 1 = pointer to matched character
        ret
strchr ENDP


; ============= STRNCHR =======================================================

; Function to find first occurrence of a character within at most N bytes
;
; C equivalent:
;   char *strnchr(const char *str, int c, size_t maxlen)
;
; Note: null terminator is a valid search target (BL = 0).
;       Stops at the first null byte OR after maxlen bytes, whichever comes first.
;       If maxlen == 0, returns NULL immediately without examining any bytes.
;
; IN:
;   DS:SI = pointer to null-terminated string
;   BL    = character to search for
;   CX    = maximum number of bytes to examine
; OUT:
;   AX = offset of first occurrence of BL in string
;   AX = 0 (NULL) if character not found within maxlen bytes
; EXP:
;   DirFlag is forward (0)
; DESTR:
;   AX, CX, SI  (SI advances through the string)
;
strnchr PROC

        and  cx, cx             ; maxlen == 0?
        jz   @@notfound         ;   yes: trivially not found

@@loop:
        lodsb                   ; al = ds:[si++]

        cmp  al, bl             ; al == search char?
        je   @@found

        and  al, al             ; al == 0  (end of string)?
        jz   @@notfound

        loop @@loop             ; cx--; if cx != 0 goto @@loop

@@notfound:
        xor  ax, ax             ; ax = 0 (NULL)
        ret

@@found:
        lea  ax, [si-1]         ; ax = si - 1 = pointer to matched character
        ret
strnchr ENDP


; ============= STRCMP ========================================================

; Function to compare two null-terminated strings
;
; C equivalent:
;   int strcmp(const char *str1, const char *str2)
;
; Algorithm:
;   1. Measure str2 length including null  ->  CX
;   2. Compare CX bytes of str1 vs str2 with REPE CMPSB
;   3. Return signed difference of last compared byte pair
;
; The null is included in the comparison count so that a string that
; terminates before the other is correctly ordered (e.g. "ab" < "abc").
;
; IN:
;   DS:SI = pointer to str1
;   ES:DI = pointer to str2
; OUT:
;   AX = 0    if str1 == str2
;   AX < 0    if str1 <  str2
;   AX > 0    if str1 >  str2
; EXP:
;   DirFlag is forward (0)
; DESTR:
;   BX, SI, DI
;
strcmp PROC
        push es

        push ds
        pop  es                 ; es = ds  (both strings in data segment)

        xor  ax, ax             ; al = 0      (search for null terminator)
        mov  cx, 0FFFFh         ; cx = -1     (scan up to 65535 bytes)

        ; Measure str2 (REPNE SCASB uses ES:DI)
        repne scasb             ; while (cx-- && es:[di++] != 0) {}

        not  cx                 ; cx = str2_length + 1  (bytes to compare, null included)
        sub  di, cx             ; di = original str2 pointer  (undo scan advance)

        ; Compare str1 (DS:SI) vs str2 (ES:DI) for CX bytes
        repe cmpsb              ; while (cx-- && ds:[si++] == es:[di++]) {}

        ; Compute signed difference of last compared byte pair.
        ; Zero-extend to 16 bits for correct unsigned char comparisons
        ; (plain CBW would sign-extend 0x80..0xFF to negative, giving wrong result).
        mov  al, [si-1]         ; al = last str1 byte
        mov  bl, [di-1]         ; bl = last str2 byte  (es == ds, so DS:[di-1] is valid)
        xor  ah, ah             ; zero-extend AL -> AX
        xor  bh, bh             ; zero-extend BL -> BX
        sub  ax, bx             ; ax = str1_byte - str2_byte  (signed 16-bit result)

        pop  es
        ret
strcmp ENDP


; ============= STRNCMP =======================================================

; Function to compare up to N bytes of two strings
;
; C equivalent:
;   int strncmp(const char *str1, const char *str2, size_t maxlen)
;
; Algorithm:
;   1. Scan str2 for null within maxlen bytes  ->  actual compare count in CX
;      (if null found at position K < maxlen, compare K+1 bytes including null;
;       if null not found, compare maxlen bytes)
;   2. Compare CX bytes of str1 vs str2 with REPE CMPSB
;   3. Return signed difference of last compared byte pair
;   If maxlen == 0: always returns 0 (equal, no bytes examined)
;
; IN:
;   DS:SI  = pointer to str1
;   ES:DI  = pointer to str2
;   CX  = maximum number of bytes to compare
; OUT:
;   AX = 0    if strings are equal within CX bytes
;   AX < 0    if str1 <  str2
;   AX > 0    if str1 >  str2
; EXP:
;   DirFlag is forward (0)
; DESTR:
;   BX, CX, SI, DI
;
strncmp PROC
        push es

        push ds
        pop  es                 ; es = ds  (both strings in data segment)

        and  cx, cx             ; maxlen == 0?
        jz   @@equal            ;   yes: trivially equal

        mov  bx, cx             ; bx = maxlen  (saved)
        xor  ax, ax             ; al = 0        (search for null)

        ; Scan str2 for null, at most maxlen bytes (REPNE SCASB uses ES:DI)
        repne scasb             ; while (cx-- && es:[di++] != 0) {}

        sub  bx, cx             ; bx = maxlen - remaining = bytes consumed in scan
                                ;      (includes the null byte if it was found)
        mov  cx, bx             ; cx = actual comparison length

        sub  di, cx             ; di = original str2 pointer  (undo scan advance)

        ; Compare str1 (DS:SI) vs str2 (ES:DI) for CX bytes
        repe cmpsb              ; while (cx-- && ds:[si++] == es:[di++]) {}

        ; Compute signed difference of last compared byte pair
        mov  al, [si-1]         ; al = last str1 byte
        mov  bl, [di-1]         ; bl = last str2 byte
        xor  ah, ah             ; zero-extend AL -> AX
        xor  bh, bh             ; zero-extend BL -> BX
        sub  ax, bx             ; ax = str1_byte - str2_byte

        pop  es
        ret

@@equal:
        xor  ax, ax             ; ax = 0  (equal)
        pop  es
        ret
strncmp ENDP
ENDIF


; ============= HTOI ==========================================================

; Function to convert a hex ASCII string to a 16-bit unsigned integer
;
; C equivalent:
;   uint16_t htoi(const char *str)
;
; Accepts uppercase (A-F) and lowercase (a-f) hex digits.
; Stops at the first non-hex character or null terminator.
; No "0x" / "0X" prefix expected — raw hex digits only.
; Overflow silently wraps to 16 bits.
;
; IN:
;   DS:SI = pointer to hex ASCII string
; OUT:
;   AX = 16-bit unsigned value
;   SI = points to the first non-hex character (or null terminator)
; EXP:
;   DirFlag is forward (0)
; DESTR:
;   BX
;
htoi PROC
        xor  bx, bx             ; bx = result accumulator

@@loop:
        lodsb                   ; al = ds:[si++]

        and  al, al
        jz   @@done_undo        ; null terminator -> stop

        sub  al, '0'
        jb   @@done_undo        ; below '0' -> invalid

        cmp  al, 9
        jbe  @@got_nibble       ; '0'..'9' -> nibble 0..9

        ; Check uppercase

        sub  al, 'A' - '0'      ; shift: 'A'->0, 'F'->5
        jb   @@done_undo        ; '9' < char < 'A' -> invalid

        cmp  al, 5
        jbe  @@hex              ; 'A'..'F' -> nibble 0..5

        ; Check downcase

        sub  al, 'a' - 'A'      ; shift: 'a'->0, 'f'->5
        jb   @@done_undo        ; 'F' < char < 'a' -> invalid

        cmp  al, 5
        ja   @@done_undo        ; beyond 'f' -> invalid

@@hex:
        add  al, 10             ; A..F / a..f -> 10..15

@@got_nibble:
        shl  bx, 4              ; bx <<= 4\
        xor  ah, ah             ; zero-extend AL -> AX
        or   bx, ax             ; bx |= nibble

        jmp  @@loop

@@done_undo:
        dec  si                 ; undo lodsb: SI -> first non-hex char / null
        mov  ax, bx             ; ax = result
        ret
htoi ENDP


; ============= ITOH ==========================================================

; Function to convert a 16-bit unsigned integer to a 4-digit uppercase hex string
;
; C equivalent:
;   void itoh(uint16_t value, char *buf)
;   (buf must be at least 5 bytes: 4 hex digits + null terminator)
;
; Always emits exactly 4 uppercase hex digits + null terminator.
; No "0x" / "0X" prefix is written.
;
; IN:
;   AX    = 16-bit value to convert
;   ES:DI = pointer to output buffer (>= 5 bytes)
; OUT:
;   ES:DI buffer filled: 4 uppercase hex digits + null terminator
;   DI    = original DI + 5  (points one past the null terminator)
; EXP:
;   sizeof es:di >= 5
; DESTR:
;   BX, CX, DI
;
itoh PROC
        push ax                 ; preserve caller's AX
        push cx

        mov  cx, 4              ; emit 4 nibbles, high -> low

@@loop:
        rol  ax, 1              ; bring next high nibble to bits 3..0
        rol  ax, 1              ; (four 1-bit ROLs for 8086 compatibility)
        rol  ax, 1
        rol  ax, 1

        mov  bl, al
        and  bl, 0Fh            ; isolate nibble (0..15)

        cmp  bl, 9
        jbe  @@decimal
        add  bl, 'A' - 10       ; 10..15 -> 'A'..'F'
        jmp  @@store

@@decimal:
        add  bl, '0'            ; 0..9   -> '0'..'9'

@@store:
        mov  es:[di], bl
        inc  di

        loop @@loop             ; cx--; repeat if cx != 0

        mov  byte ptr es:[di], 0 ; null terminator
        inc  di                  ; DI points one past the null

        pop  cx
        pop  ax                 ; restore caller's AX
        ret
itoh ENDP


IF 0
; ============= ATOI ===========================================================

; Function to convert a decimal ASCII string to a signed 16-bit integer
;
; C equivalent:
;   int atoi(const char *str)
;
; Accepts an optional leading '+' or '-' sign followed by decimal digits.
; Stops at the first non-digit character or null terminator.
; No whitespace skipping. Overflow silently wraps to 16 bits.
;
; IN:
;   DS:SI = pointer to decimal ASCII string
; OUT:
;   AX = signed 16-bit integer
;   SI = points to the first non-digit character (or null terminator)
; EXP:
;   -
; DESTR:
;   AX, BX, CX, DX
;
atoi PROC
        xor  bx, bx             ; bx = accumulator
        xor  dh, dh             ; dh = sign flag (0=positive, 1=negative)

        lodsb                   ; peek at first character: possible sign
        cmp  al, '-'
        je   @@minus
        cmp  al, '+'
        je   @@loop             ; consume '+', start reading digits
        dec  si                 ; not a sign: put char back

        jmp  @@loop

@@minus:
        mov  dh, 1              ; flag: negate result at end
                                ; fall through to @@loop
@@loop:
        lodsb                   ; al = ds:[si++]
        xor  ah, ah
        sub  al, '0'
        jb   @@done_undo        ; below '0' -> stop
        cmp  al, 9
        ja   @@done_undo        ; above '9' -> stop

        ; bx = bx * 10 + digit
        ; bx * 10 = (bx << 3) + (bx << 1)
        mov  cx, ax             ; cx = digit
        mov  ax, bx
        shl  ax, 1              ; ax = bx * 2
        shl  bx, 3              ; bx = bx * 8
        add  bx, ax             ; bx = bx * 10
        add  bx, cx             ; bx = bx * 10 + digit

        jmp  @@loop

@@done_undo:
        dec  si                 ; undo lodsb: SI -> first non-digit / null
        and  dh, dh
        jz   @@done
        neg  bx                 ; apply sign

@@done:
        mov  ax, bx
        ret
atoi ENDP


; ============= ITOA ===========================================================

; Function to convert a signed 16-bit integer to a decimal ASCII string
;
; C equivalent:
;   char *itoa(int value, char *buf, 10)
;   (buf must be at least 7 bytes: sign + 5 digits + null terminator)
;
; Produces the shortest representation with no leading zeros.
; Handles the full signed range -32768 .. 32767.
;
; IN:
;   AX    = signed 16-bit integer to convert
;   ES:DI = pointer to output buffer (>= 7 bytes)
; OUT:
;   ES:DI buffer filled with decimal string + null terminator
;   DI    = original DI + written length + 1  (one past the null)
; EXP:
;   AX  (value preserved)
; DESTR:
;   BX, CX, DX, DI
;
itoa PROC
        push ax
        push bx
        push cx
        push dx

        ; Emit '-' and take absolute value for negative numbers
        test ax, ax
        jns  @@abs
        mov  byte ptr es:[di], '-'
        inc  di
        neg  ax                 ; ax = |value|
                                ; note: neg 0x8000 wraps to 0x8000, but
                                ;       0x8000 unsigned = 32768 — correct abs value

@@abs:
        ; Special-case zero (DIV loop would emit nothing)
        test ax, ax
        jz   @@zero

        ; Divide by 10 repeatedly, push remainders (digits) onto stack
        ; in least-significant-first order; pop to write most-significant-first
        mov  bx, 10
        xor  cx, cx             ; cx = digit count

@@div:
        xor  dx, dx             ; zero-extend AX for DIV
        div  bx                 ; AX = AX / 10,  DX = AX % 10  (remainder = next digit)
        push dx                 ; save digit (in reverse order)
        inc  cx
        test ax, ax
        jnz  @@div

@@write:
        pop  dx
        add  dl, '0'
        mov  es:[di], dl
        inc  di
        loop @@write

        jmp  @@null_term

@@zero:
        mov  byte ptr es:[di], '0'
        inc  di

@@null_term:
        mov  byte ptr es:[di], 0 ; null terminator
        inc  di

        pop  dx
        pop  cx
        pop  bx
        pop  ax
        ret
itoa ENDP


; ============= PARSE_PSP ========================================================

; Function to parse the PSP command line into null-terminated tokens in-place
;
; C equivalent:
; int parse_psp() {
;     char *ptr = 0x80; // 80h -
;     uint8_t len = *ptr;
;
;     ptr += 2;
;
;     uint8_t count_of_args = 0;
;
;     char *space = ptr;
;     do {
;         space = strnchr(space, ' ', len);
;
;         if (space != NULL) {
;             *space = '\0';
;             ++count_of_args;
;             ++space;
;         }
;     } while (space != NULL);
;
;     return count_of_args;
; }
;
; Reads the raw command line at PSP offset 80h (length byte) and 82h onward
; (first argument character, after the mandatory leading space at 81h).
; Null-terminates the end of the command line (DS:[81h + len]), then replaces
; each space separator with a null byte in-place, counting separators.
;
; PSP layout (DS = PSP segment; .COM programs have DS == PSP on entry):
;   DS:80h  = byte: count of command-line characters (not including trailing CR)
;   DS:81h  = first character (DOS always writes a leading space here)
;   DS:82h+ = argument text; CR (0Dh) at DS:81h+len is overwritten with null
;
; After this call the command line region starting at DS:82h contains a series
; of null-terminated tokens.  The first token is at DS:82h; each subsequent
; token begins immediately after the null terminator of the previous one.
;
; Return value: number of space separators replaced, NOT the token count.
;   0 separators => at most 1 token (at DS:82h) if the command line was non-empty
;   n separators => n+1 tokens
;
; IN:
;   DS = PSP segment  (.COM programs: DS == PSP on entry)
; OUT:
;   AX = number of space separators replaced with null
; EXP:
;   DirFlag is forward (0)
; DESTR:
;   BX, CX, DX, SI
;
parse_psp PROC
        xor  dx, dx             ; dx = separator count = 0

        ; Read PSP command-line length byte
        mov  si, 80h            ; si -> PSP length byte
        xor  cx, cx
        mov  cl, [si]           ; cx = number of command-line characters
        and  cx, cx             ; empty command line?
        jz   @@done             ;   yes: return 0

        add  si, 2              ; si = 82h  (first argument character)
        dec  cx                 ; remaining = len - 1  (space at 81h accounted for)
        jz   @@done             ; only a space existed -> return 0

        ; Null-terminate the command line at DS:[si + cx] = DS:[82h + (len-1)]
        ;   = DS:[81h + len]  (overwrites the CR byte; PSP is not zero-filled)
        mov  bx, si
        add  bx, cx             ; bx = 82h + (len-1) = CR position
        mov  byte ptr [bx], 0   ; *(ptr + len) = '\0'

        mov  bl, ' '            ; bl = space character  (strnchr preserves BL)

@@loop:
        ; strnchr(DS:SI, ' ', CX) -> AX = pointer to first space, or AX = 0
        ; strnchr destroys: AX, CX, SI
        push cx                 ; save remaining byte count
        push si                 ; save start of current scan window
        call strnchr

        and  ax, ax             ; space found?
        jz   @@restore_done     ;   no: done parsing

        ; Space found at AX.  Restore saved registers.
        pop  si                 ; si = start of scan window
        pop  cx                 ; cx = bytes available when scan started

        ; Subtract bytes consumed (from scan start up to and including the space)
        push ax                 ; save found-space address
        sub  ax, si             ; ax = offset of space from scan start
        inc  ax                 ; ax = bytes consumed (through and including the space)
        sub  cx, ax             ; cx -= bytes consumed
        pop  ax                 ; ax = address of space byte

        mov  byte ptr [ax], 0   ; replace space with null terminator
        inc  dx                 ; ++separator_count

        mov  si, ax
        inc  si                 ; si = one byte past the null (start of next token)

        and  cx, cx             ; any bytes remaining?
        jnz  @@loop             ;   yes: continue search
        jmp  @@done

@@restore_done:
        ; strnchr returned NULL; clean up the two values we pushed
        pop  si                 ; } discard saved scan start
        pop  cx                 ; }   and saved remaining count

@@done:
        mov  ax, dx             ; return value = separator count
        ret
parse_psp ENDP
ENDIF