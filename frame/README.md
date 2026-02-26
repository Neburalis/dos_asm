# frame

An educational project exploring direct video memory access in DOS. Draws a rectangular bordered frame on screen by writing directly to video memory (segment `B800h`).

## Usage

```
FRAME [-b<attr>] [-f<attr>] [-t<attr>] [-s<style>] text
```

<p>
<details>
  <summary>Click to show examples</summary>
    Without additional params
    <img src="../assets/images/frame-example-kbcr.png" alt="Without additional params">
    Change colors to custom
    <img src="../assets/images/frame-example-kbin.png" alt="Change colors">
    Change style
    <img src="../assets/images/frame-example-kblh.png" alt="Change style">
    Set custom style
    <img src="../assets/images/frame-example-kbqv.png" alt="Custom style">
</details>
</p>

*All arguments are read from the PSP command-line buffer at `DS:80h`. Flags must precede the text.*

All flags are optional.

| Flag | Controls | Default |
|------|----------|---------|
| `-b <attr>` | Fill color attribute | `0Eh` — yellow on black |
| `-f <attr>` | Frame border color attribute | `4Eh` — yellow on red |
| `-t <attr>` | Text color attribute | `0Eh` — yellow on black |
| `-s <style>` | Border style from standard list (see below) | `2` — double-line |

Frame color - attribute for frame (attribute is color of symbols and background)
Fill color - attribute for fill of frame
Text color - attribute for text

`<attr>` is a two-digit hex value (e.g. `1F` for white on blue). Parsed by `htoi` from `strlib.inc`.

### `-s` style values

| Value | Style | Characters |
|-------|-------|------------|
| `0` | No frame | spaces |
| `1` | Single-line | `┌─┐│ │└─┘` |
| `2` | Double-line (default) | `╔═╗║ ║╚═╝` |
| `3` | Hearts | `♥♥♥♥ ♥♥♥♥` |
| `*` | Custom | parse next 9 raw chars (TL T TR L fill R BL B BR)|

## What Code Does

- Sets `ES = B800h` (text-mode video memory)
- Parses optional `-b`, `-f`, `-t`, `-s`, `-o` flags from the PSP command line
- Determines frame width from the remaining text length
- Draws a bordered box using characters from `frameChars` (CP437)
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

styleTable  ; 4 rows × 9 bytes — loaded into frameChars by -s flag
;  0: spaces        (no visible border)
;  1: single-line   ┌─┐│ │└─┘  (CP437: DAh C4h BFh B3h 20h B3h C0h C4h D9h)
;  2: double-line   ╔═╗║ ║╚═╝  (CP437: C9h CDh BBh BAh 20h BAh C8h CDh BCh)
;  3: hearts        ♥♥♥♥ ♥♥♥♥  (CP437: 03h × 8, 20h fill)
```

