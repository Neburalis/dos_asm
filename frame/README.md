# frame

An educational project exploring direct video memory access in DOS. Draws a rectangular bordered frame on screen by writing directly to CGA/VGA video memory (segment `B800h`).

## Usage

```
FRAME [text]
```

*Text and frame parameters are read from the PSP command-line buffer at `DS:80h`.*

## What It Does

- Sets `ES = B800h` (text-mode video memory)
- Reads the command-line length from `DS:[80h]` to determine frame width
- Draws a double-line box (╔═╗ / ║ ║ / ╚═╝) using box-drawing characters (CP437)
- Frame color attribute: `4Eh` — yellow on red background

## Internal Routines

| Routine | Description |
|---------|-------------|
| `calc_offset` (macro) | Converts (col, row) -> byte offset in video memory |
| `PrintCharAt` | Write a single character+attribute at (col, row) |
| `PrintHLine` | Write N characters horizontally (uses `rep stosw`) |
| `PrintVLine` | Write N characters downward (stride = 160 bytes/row) |
| `PrintIVLine` | Write N characters upward |
| `PrintFrame` | Draw a complete rectangular frame |
| `PrintCMDLine` | Write the raw command-line string to video memory |

## Build

```
tasm /la frame.asm
tlink /t frame.obj
frame.com [text]
```

## Data

```asm
frameChars  db 0C9h, 0CDh, 0BBh, 0BAh, 020h, 0BAh, 0C8h, 0CDh, 0BCh
;              ╔      ═      ╗     ║  (fill)  ║      ╚     ═     ╝
frameAttr   db 4Eh   ; yellow on red
fillAttr    db 0Eh   ; yellow on black
```
