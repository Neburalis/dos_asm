# keybor_manager

An educational project exploring direct keyboard I/O polling in DOS. Reads raw PS/2 scancodes from port `60h` and displays them live in video memory, exiting on Escape.

## What It Does

- Sets `ES = B800h` (text-mode video memory)
- Positions the write cursor at the start of **row 3** (`BX = 480`)
- Continuously reads port `60h` (PS/2 keyboard data port) into `AL`
- Writes `AX` (scancode + attribute `4Eh`) directly to video memory
- Wraps back to the start of row 3 when the full line is filled
- Exits via `INT 21h / AX=4C00h` when `AL == 01h` (Escape make code)

## Internal Routines

| Routine / Macro | Description |
|-----------------|-------------|
| `exit0` (macro) | Calls `INT 21h / AX=4C00h` to exit to DOS |
| `BkPt` (macro)  | Inserts `INT 3h` breakpoint if `Debug == 1` |
| `vskip` (macro) | Inserts four `NOP` bytes (`90909090h`) if `Debug == 1` |
| `Next` (label)  | Main polling loop — reads port, writes scancode, checks exit |

## Build

```
tasm /la test.asm
tlink /t test.obj
test.com
```

## Data

```asm
VideoMemorySeg  equ 0B800h  ; CGA/VGA color text-mode segment
                             ; AH = 4Eh  → yellow on red attribute
                             ; Row 3 occupies offsets 480–639 (160 bytes)
```

> `debug.inc` must be present in the same directory. Set `Debug equ 0` to strip breakpoints from the build.
