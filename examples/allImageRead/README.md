# allImageRead — the verification harnesses

Fifteen small programs. They are not demos of what the template *looks* like; they are how the
template was proved to be correct, and they can be re-run whenever it changes.

Everything here needs the myImage files on the redirection path — `ImageClass.inc`,
`ImageClass.clw` and `imgcore.c`. They already sit in `clarion12\accessory\libsrc\win`
if myImage was deployed; otherwise copy them from `templates/myImage/` (ANSI, CRLF).

`.exe`, `.lib`, `.dll` and `.obj` are gitignored, so rebuild before you run.

---

## `airwin` — the canvas on a window

A full ABC application carrying **both** window placements at once, so one build proves both:

| control | template | source |
|---|---|---|
| `?Pic1` | `allImageRead` procedure extension | a **base64** string in memory |
| `?AirCanvas` | `allImageReadCanvas` control template | a **URL** |

It also exercises the parts that are easy to get wrong: two canvases on one window (so the event
equates and the wheel hook must not collide), a per-canvas touch-up (the canvas rotates 90° and caps
its longest side at 2000px), the status bar in two different zones, and the full right-click menu.

Rebuild it from the TXA — the `.app` is not committed, because a TXA is text and diffable:

```
ClarionCL -win -au -ai airwin.app airwin.txa      # create the .app
ClarionCL -win -au -ag airwin.app                 # generate the source
MSBuild airwin.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
```

The generated source is committed too (`airwin.clw`, `AIRWIN001.CLW`, …) so a change in the template
shows up as a readable diff without anyone having to run AppGen.

## `rpttest` — the canvas in a report band

The band half of the same template, lifted out of a generated application: the global readers, the
`Air:Band` routine the template writes, a `REPORT` with an `IMAGE` in its `DETAIL`, and a `PRINT`.
It exists because a report procedure needs a primary table before ABC will generate cleanly, and
that would have dragged a dictionary into the harness for no gain. This compiles the *emitted* code
instead — which is the part worth proving.

```
MSBuild rpttest.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
```

## `d2dtest` — the GPU canvas, and what it is worth

Builds `d2dcanvas.c`, makes a 2400x1800 test card with ImageClass, uploads it to the GPU, and then
times the two ways of zooming. Both numbers go in the window title.

```
MSBuild d2dtest.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
```

It attaches to a **REGION created at run time** — the same construct the canvas builds over its IMAGE
control — so what it proves is what the template actually does.

Measured on this machine:

```
D2DTest OK img=2400x1800 view=624x464 GPU300=251cs CPU10=675cs
```

- **GPU: 300 frames actually drawn in 2.51 s = 8.4 ms a frame.**
- **CPU (what the template does today): 10 zoom steps in 6.75 s = 675 ms a step.**

**About 80x per zoom step** — and the GPU figure does not move when the picture gets bigger, because
the work is a 3x2 matrix, while the CPU figure grows with every pixel. Note `d2c_PaintNow` exists
only so this measurement is honest: `d2c_SetView` alone just invalidates, and timing *that* would
have flattered the GPU by measuring nothing.

## `hwndtest` — does a Clarion control own a window?

The question the whole GPU design rests on. It prints `PROP:Handle` for the window, its client area,
an IMAGE, a REGION, and a REGION made at run time with `CREATE(0,CREATE:Region,...)`. Every one of
them is a real HWND, which is why Direct2D can render into the canvas control itself instead of
fighting Clarion for the window's WM_PAINT.

## `proctest` / `hooktest` / `addrtest` — three questions about callbacks

- **`proctest`** — is `PROP:WndProc` a real window procedure, or a Clarion-managed hook slot? It
  prints Clarion's answer beside `GetWindowLongA`'s for both a window and a control. They match, so
  it is a genuine subclass and chaining through it is correct.
- **`hooktest`** — the wheel hook on its own, with a driver that sends `WM_CLOSE`. If the window
  shuts down, the callback is chaining; if it sits there, it is swallowing messages.
- **`addrtest`** — two modules, one procedure, and `ADDRESS()` taken in each:

  ```
  AddrTest program=12587276 member=12587072 DIFFERENT
  ```

  `ADDRESS(procedure)` does **not** answer the same thing in a MEMBER module as in the program
  module. A template writes its callback into the program module but its wiring into a member
  module, so the template never takes that address any more — it asks a helper in the owning module
  to install the hook. (What is verified here is that the values differ, not what the member-side
  value does if you use it; the safe route costs nothing either way.)

## A warning about `airwin` as a *runtime* test

`airwin` is a compile test, not a run test. It is a hand-written ABC application with **no
dictionary**, so `Dictionary.Construct` calls into a stub and the program throws an access violation
on start-up — `EIP=000004C8`, inside ClaRUN — before any of this template's code runs. It does it
with allImageRead switched off entirely, which is how that was established (`try.ps1` flips the
prompts, regenerates, rebuilds and reports "CLEAN" or "THREW", which is how to bisect this kind of
thing quickly). Give it a real dictionary if you want it to run; as it stands it proves that the
generated source compiles and links, which is what it was built for.

## `immtest` — why dragging did nothing

Two REGIONs made at run time over two IMAGEs, one with `PROP:IMM` set and one without, each counting
the mouse events it receives. A driver posts real `WM_LBUTTONDOWN` / `WM_MOUSEMOVE` / `WM_LBUTTONUP`
at both and reads the counts back out of the title:

```
IMM[d1m12u1]   PLAIN[d1m0u0]
```

The plain region gets **MouseDown and nothing else** — which is exactly what a broken drag looks like:
it begins and never moves. The Language Reference is explicit and I had not read it closely enough:
EVENT:MouseMove and EVENT:MouseUp arrive *"on a REGION with the IMM attribute"*, and MouseDown arrives
regardless because it is a synonym for EVENT:Accepted. A region built with `CREATE(0,CREATE:Region,...)`
has no attribute list to carry IMM, so the canvas sets it as a property.

## `frametest` - do frames step, and from which end?

Walks an animated GIF (`accessory\template\win\NYS_FlowGraph.gif`, 100 frames) the way the frame bar
does - one-based on the outside - and hashes a grid of 64 pixels per frame:

```
frames=100  1:872568535  2:1117606317  25:3026226857  50:2470491779  100:1965238500  FRAMES-DIFFER
```

Different hashes mean `LoadFrame` really is changing the picture, and frame 100 loading at all is the
point: **the engine counts frames from ZERO**. `imgcore.c`'s `img_select_frame` rejects anything from
`Frames()` upwards, so a one-based caller fails silently on the last frame and is one out on every other
one. The template calls `LoadFrame(n - 1)` and keeps the numbering a person sees at one.

Note that `.ico` is **not** a frame source: a 21-image icon reports `frames=1`, because GDI+ hands back
the single image it thinks best. Frames come from multi-page TIFF (`FrameDimensionPage`) and animated
GIF (`FrameDimensionTime`).

## `cputime` - where the processor path's time went, and whether the fix is honest

Two questions in one program. First, time a wheel notch as the canvas used to perform it, on a
2400x1800 picture at 400 per cent into a 620x460 frame:

```
clone=1.2cs   zoomWHOLE=890.8cs   crop+fit=1.6cs   savePNG=0.4cs   saveBMP=0.2cs
```

Resampling the whole picture is **99.6 per cent** of it - 8.9 seconds a notch. Everything else,
including the PNG round trip through disk that looked like an obvious culprit, is noise. Worth
remembering before optimising anything by reasoning about it.

Second, and the part that mattered before shipping the fix: does cutting the source rectangle out
FIRST show the same thing? It renders both ways at three pan positions, two of them deep inside the
picture where crop-first only ever touches a small piece of the middle, and hashes 144 pixels of each:

```
old=887cs/step   new=5.3cs/step   identical=3/3 SAME-PICTURE
```

The same picture, 167 times faster. Panning is unaffected in every sense that matters: the original
is never modified - the crop happens on a clone - so the whole picture is always there to pan into,
and each repaint simply cuts a fresh piece.

## `bartest` - can a REGION carry scrollbars, and do they talk back?

A REGION is not born with scrollbars, so this adds `WS_HSCROLL`/`WS_VSCROLL` to one built at run time,
gives the bars a range, subclasses the control and counts what comes back. The driver posts a real
`WM_HSCROLL` (line right) and `WM_VSCROLL` (page down):

```
BarTest hwnd=29886464 hits=2 hpos=16 vpos=20
```

Both messages arrived, and the positions moved by a line and by a page - Windows does not work the new
position out for you, the window procedure has to. The screenshot in `docs/allImageRead-scrollbars.png`
answers the other half: they really are drawn, as the thin Windows 11 thumbs on the right edge and along
the bottom.

## `unittest` / `barround` / `wheelvsbar` - why panning wandered

Panning went wrong the moment it started working, and these three found out why by ruling things out
rather than by staring at the code.

- **`barround`** - write a pan into a scrollbar, read it straight back, over 2843 combinations of zoom
  and position: `mismatched=0 ROUND-TRIPS`. So Windows was not quietly clamping the position somewhere
  else. Not that.
- **`wheelvsbar`** - a control carrying `WS_VSCROLL` might turn a wheel into a scroll message, which
  would make zooming pan as well. Post real wheels at it: `hits=0`. Not that either.
- **`unittest`** - the one that mattered. Read a control's size in the window's own units and again in
  pixels:

  ```
  units=300x140  pixels=600x280  xscale=2 yscale=2 DIFFERENT-UNITS
  ```

  **A window unit is not a pixel.** `MOUSEX()` and `MOUSEY()` answer in window units - half a pixel each
  way on a default window - while the pan is kept in pixels. Every drag moved the picture at half speed,
  so it slid out from under the pointer, and the scrollbar thumb (driven from the pan, correctly in
  pixels) disagreed with it. The drag now reads the pointer with `PROP:Pixels` switched on.

  This was never a scrollbar bug. The bar simply gave the drag a second opinion, and that is what made
  it obvious.

- **`dragsim`** - and the half of it the units fix did not cure. A drag does not arrive as one movement,
  it arrives as a stream of one- and two-pixel deltas, and the canvas was turning each one into image
  pixels by itself. Simulate that against measuring from where the drag began:

  ```
  z200/s1[want -30  inc 0    anc -30]     incWrong=8
  z500/s3[want -11  inc 0    anc -11]     ancWrong=0
  z200/s3[want -29  inc -19  anc -29]
  ```

  Adding up the deltas is wrong in eight cases out of nine, and usually gives **zero**: at 500 per cent a
  one-pixel move is a fifth of an image pixel, which rounds to nothing, and the remainder is thrown away.
  Sixty of those and the picture has not moved. Anchoring - remembering the pan and the pointer where the
  drag began, and measuring the whole distance every time - is exact in all nine.

## `wheeltest` — does the mouse wheel actually arrive?

The one that earned its keep. Clarion's `EVENT:ScrollUp` / `EVENT:ScrollDown` are **LIST events**
("the user pressed the up arrow", `IMM` only) — they never reach a window or an `IMAGE`, so a first
attempt at wheel zoom silently did nothing. The wheel has to be taken off the window procedure.

`wheeltest` opens a window, hooks `PROP:WndProc`, and turns `WM_MOUSEWHEEL` into four counters —
wheel up, wheel down, and the same two with Ctrl held — which it writes into the **window title**.
`drivewheel.ps1` starts it, sends real `WM_MOUSEWHEEL` messages with `SendMessage`, and reads the
title back, so the whole thing runs without a human touching a mouse:

```
MSBuild wheeltest.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
powershell -File drivewheel.ps1
```

Sending Ctrl+up ×2, Ctrl+down, plain up and plain down must print:

```
title now: AirWheelTest U=1 D=1 CU=2 CD=1
```

That is the proof behind three claims the template makes: a subclassed window procedure sees the
wheel, `POST` from inside that callback reaches the `ACCEPT` loop, and chaining on to the window's
own procedure leaves everything else working.

---

## What is proved, and what is not

| claim | how |
|---|---|
| the template registers and generates for all four placements | `ClarionCL -tr` / `-ag` |
| the generated source compiles and links | `airwin` (window) and `rpttest` (report band), 32-bit MSBuild |
| a Clarion control owns a real HWND | `hwndtest`, including a run-time REGION |
| `PROP:WndProc` is a genuine subclass | `proctest`, against `GetWindowLongA` |
| the wheel arrives, `POST` reaches ACCEPT, chaining survives | `wheeltest` + `drivewheel.ps1`, `hooktest` |
| `ADDRESS()` differs between program and MEMBER modules | `addrtest` |
| Direct2D draws the picture, right colours, right way up | `d2dtest`, screenshot in `docs/` |
| a dragged pan gets MouseMove/MouseUp | `immtest`, IMM against plain, driven by posted mouse messages |
| frames step, and the last one loads | `frametest`, 100-frame GIF, pixel hash per frame |
| crop-first is the same picture, ~167x faster | `cputime`, old against new at three pan positions |
| a REGION can carry working scrollbars | `bartest`, styles added at run time, messages posted at it |
| a window unit is not a pixel | `unittest` - scale 2, which is why dragging wandered |
| a drag must be measured from its anchor | `dragsim` - adding up deltas loses the remainder every move |
| the GPU is ~80x faster per zoom step | `d2dtest`, both paths timed in one run |
| zooming turns about the pointer, not the middle | `d2dtest` prints `spotdrift`: the image pixel under the spot, before and after a step, over 60 combinations of spot, zoom and pan. Anything but `0.000000 PASS` means the pan maths drifts |

**Not proved:** a *generated* application running the GPU canvas end to end. `airwin` compiles but cannot
run (no dictionary), so the GPU path has been exercised through `d2dtest`, which calls the same engine in
the same order the generated code does. The first real run is a live application.
