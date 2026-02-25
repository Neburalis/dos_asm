; =============================================================================
; strlib.inc  -  Standard string library functions
;
; Functions:
;   strlen  - calculate length of null-terminated string
;   strchr  - find first occurrence of character in string
;   strnchr - find first occurrence of character within N bytes
;   strcmp  - compare two null-terminated strings
;   strncmp - compare up to N bytes of two strings
;   htoi     - convert hex ASCII string to 16-bit unsigned integer
;   itoh     - convert 16-bit unsigned integer to hex ASCII string
;
; Calling convention: register-based (no stack args)
;
; Usage in main file:
;   INCLUDE strlib.inc
; =============================================================================


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
