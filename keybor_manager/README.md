# keybor_manager

An educational project exploring interrupt-driven keyboard handling in DOS. Installs a custom INT 09h handler as a TSR, reads PS/2 scancodes from port `60h`, displays them at a fixed position in video memory, and stays resident.

## What It Does

- Sets `ES = 0` to access the **Interrupt Vector Table**
- Patches IVT entry `4 * 09h` to point to `NewInt09h` (within the current CS)
- Calls `INT 21h / AX=3100h` (**TSR**) to stay resident; size is computed from `offset EOP` rounded up to paragraphs
- On every keypress, `NewInt09h` fires:
  - Reads the scancode from port `60h` into `AL`
  - Writes `AX` (scancode + attribute `4Eh`) to a **fixed cell**: row 3, column 40 (`BX = (80×3 + 40)×2 = 560`)
  - Acknowledges the keyboard by toggling bit 7 of PPI port `61h`
  - Sends **EOI** (`20h -> port 20h`) to the master PIC
  - Returns with `IRET`

## Internal Routines

| Routine / Macro | Description |
|-----------------|-------------|
| `exit0` (macro) | Calls `INT 21h / AX=4C00h` to exit to DOS (defined but unused) |
| `tasr0` (macro) | Terminates and stays resident via `INT 21h / AX=3100h`; calculates resident size in paragraphs using `offset EOP` |
| `BkPt` (macro)  | Inserts `INT 3h` breakpoint if `Debug == 1` |
| `vskip` (macro) | Inserts four `NOP` bytes (`90909090h`) if `Debug == 1` |
| `NewInt09h`     | ISR for INT 09h — reads scancode, updates video memory, resets keyboard, sends EOI |
| `EOP` (label)   | Marks end of resident code for size calculation in `tasr0` |

## Build

```
tasm /la test.asm
tlink /t test.obj
test.com
```

## Data

```asm
VideoMemorySeg  equ 0B800h   ; CGA/VGA color text-mode segment
                              ; AH = 4Eh  -> yellow on red attribute
                              ; Fixed cell: row 3, col 40 -> offset 560 (BX = (80*3+40)*2)
```

> `debug.inc` must be present in the same directory. Set `Debug equ 0` to strip breakpoints from the build.
