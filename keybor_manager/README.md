# showreg

An educational project that installs a floating register-display overlay as a DOS TSR. Press **Ctrl+/** to toggle the window on and off; it continuously shows the CPU register snapshot captured at interrupt time.

## INT 08h Handler — Timer

Fires every ~18.2 ms. When the window is visible:

1. **Integrity check**: walks each cell of the window in video memory; if a cell differs from `draw_buf`, saves the foreign value to `save_buf` and restores `draw_buf` over it. Keeps the window on top even when other programs write to the screen.
2. **Register snapshot**: reads saved register values off the interrupt stack frame and updates the hex digits in `draw_buf` in place.
3. **Blit**: copies `draw_buf` → video memory.

## INT 09h Handler — Keyboard

Reads scancode from port `60h` before BIOS can acknowledge it, then chains to the original handler.

- Tracks **Left Ctrl** (`1Dh` make / `9Dh` break) in `ctrl_down`
- Tracks **/** (`35h` make / `B5h` break) in `slash_down` (auto-repeat guard)
- On **Ctrl+/ press**:
  - **Show**: snapshot current video window area → `save_buf`; write register values into `draw_buf`; blit `draw_buf` → video; set `window_visible = 1`
  - **Hide**: copy `save_buf` → video; set `window_visible = 0`

## Stack Frame Layout (both handlers)

After `push ax bx cx dx si di bp ds es` (18 bytes) + CPU hardware frame (IP, CS, FLAGS = 6 bytes):

| `[BP+N]` | Register |
|----------|----------|
| `[BP+0]` | ES |
| `[BP+2]` | DS |
| `[BP+4]` | BP |
| `[BP+6]` | DI |
| `[BP+8]` | SI |
| `[BP+10]` | DX |
| `[BP+12]` | CX |
| `[BP+14]` | BX |
| `[BP+16]` | AX |
| `[BP+18]` | IP |
| `[BP+20]` | CS |
| `[BP+22]` | FLAGS |
| `BP + 24` | SP (original) |

## Macros

| Macro | Description |
|-------|-------------|
| `ToHexDigit` | Converts nibble in `BL` (0–15) to ASCII hex char in-place; no labels, safe for multiple expansions in the same PROC |
| `WriteRegHex row` | Writes `AX` as 4 hex characters into `draw_buf` at interior column 4 of the given row (0-based within buffer) |

## Routines (from `frame.inc`)

| Routine | Description |
|---------|-------------|
| `PrintFrame` | Draws double-line border into `draw_buf`; configured by `drawCols`/`drawBase` globals |
| `PrintString` | Prints null-terminated string supporting `0Ah` newlines; configured by `drawCols`/`drawBase` |

## Resident Data

| Symbol | Purpose |
|--------|---------|
| `old_int08_ptr` | Saved INT 08h vector (offset + segment) |
| `old_int09_ptr` | Saved INT 09h vector (offset + segment) |
| `window_visible` | `1` while window is displayed, `0` while window is hidden |
| `ctrl_down` | `1` while Left Ctrl is physically held |
| `slash_down` | `1` while `/` is held (prevents auto-repeat toggling) |
| `frameChars` | 9-byte double-line corner/edge character table |
| `string` | Multiline label text printed into the frame at init |
| `save_buf` | Screen snapshot beneath the window (`WIN_W × WIN_H × 2` bytes) |
| `draw_buf` | Authoritative window contents — source of truth for integrity checks and blits |

## Build

```
tasm /la /Ipath/to/folder/libs/ showreg.asm
tlink /t showreg.obj
showreg.com
```

> you should replace path/to/folder/ with the correct path to the repository (In my case: `/IS:\DOC\DOS_ASM\LIBS\`).