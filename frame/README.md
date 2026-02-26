# frame

An educational project exploring direct video memory access in DOS. Draws a rectangular bordered frame on screen by writing directly to CGA/VGA video memory (segment `B800h`).

## Usage

```
FRAME [-b <attr>] [-f <attr>] [-t <attr>] [text]
```

*All arguments are read from the PSP command-line buffer at `DS:80h`. Flags must precede the text.*

| Flag | Controls | Default |
|------|----------|---------|
| `-b <attr>` | Fill (background) color attribute | `0Eh` — yellow on black |
| `-f <attr>` | Frame border color attribute | `4Eh` — yellow on red |
| `-t <attr>` | Text color attribute | `0Eh` — yellow on black |

`<attr>` is a two-digit hex value (e.g. `1F` for white on blue). Parsed by `htoi` from `strlib.inc`.

## What It Does

- Sets `ES = B800h` (text-mode video memory)
- Parses optional `-b`, `-f`, `-t` color flags from the PSP command line
- Determines frame width from the remaining text length
- Draws a double-line box (╔═╗ / ║ ║ / ╚═╝) using box-drawing characters (CP437)
- Fills the interior with the fill character and `fillAttr`
- Prints the text string inside the frame using `textAttr`
- Frame is horizontally centered on the 80-column screen

## Internal Routines

| Routine | Description |
|---------|-------------|
| `video_mem_offset` (macro) | Converts (col, row) → byte offset in video memory (`y*160 + x*2`) |
| `PrintCharAt` | Write a single character+attribute at (col, row) |
| `PrintHLine` | Write N characters horizontally (uses `rep stosw`); direction-aware (CLD/STD) |
| `PrintVLine` | Write N characters downward (stride = 160 bytes/row) |
| `PrintIVLine` | Write N characters upward (stride = −160 bytes/row) |
| `PrintFrame` | Draw a complete rectangular frame with corners, edges, and filled interior |
| `FillFrame` | Fill a rectangle with a given character+attribute (Pascal calling convention, `ret 6`) |
| `PrintLine` | Write a string to video memory, stopping at any control character (< `20h`) |

## Build

```
tasm /la frame.asm
tlink /t frame.obj
frame.com [text]
```

Requires `strlib.inc` (for `htoi`) and `debug.inc` on the include path.

## Data

```asm
frameChars  db 0C9h, 0CDh, 0BBh, 0BAh, 020h, 0BAh, 0C8h, 0CDh, 0BCh
;              ╔      ═      ╗     ║  (fill)  ║      ╚     ═     ╝
frameAttr   db 4Eh   ; yellow on red   (overridden by -f)
fillAttr    db 0Eh   ; yellow on black (overridden by -b)
textAttr    db 0Eh   ; yellow on black (overridden by -t)
```
