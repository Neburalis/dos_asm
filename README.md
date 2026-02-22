# DOS x86 Assembly Projects

Educational projects for learning x86 assembly and low-level DOS programming. Built using **Turbo Assembler (TASM)** inside a DOSBox-X environment.

## Projects

| Project | Description |
|---------|-------------|
| [frame](frame/) | Draw a bordered frame with text directly to video memory (B800h) |

## Build Environment

- **DOSBox-X** v2026.01.02
- **Turbo Assembler** (TASM) — assembler
- **Turbo Linker** (TLINK) — linker
- **Video mode** — 80×25 color text (VGA), segment B800h

## Building a Project

Inside DOSBox, navigate to the project folder and run:

```
tasm /la <source>.asm
tlink /t <source>.obj
<source>.com
```

The `/la` flag generates a listing file; `/t` produces a `.COM` (tiny model) executable.
