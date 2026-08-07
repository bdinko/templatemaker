# BrowseGrid — the engine, and the proof it draws

`templates/BrowseGrid/d2grid.c` is a grid drawn with **Direct2D and DirectWrite** into an ordinary
Clarion `REGION`. It holds no data: the Clarion side pushes in the rows that are visible and the grid
draws them, which is exactly the shape an ABC browse queue already has.

## `gridtest` — first light

Attaches to a REGION, sets five columns, pushes a page of made-up rows in and paints:

```
MSBuild gridtest.cwproj /p:ClarionBinPath=C:\clarion12\bin /p:Configuration=Debug
powershell -File shot.ps1 -Exe .\gridtest.exe -Prefix GridTest -Out gridshot.png
```

`docs/BrowseGrid-first-light.png` is the result: a dark header with bold titles, banded rows, gridlines,
a selected row, right-aligned numeric columns, text centred down each row, and a frozen first column.
23 rows fill the region exactly, which is `d2g_PageSize()` answering how many fit.

## Smooth scrolling, proved

`docs/BrowseGrid-smooth-scroll.png` is the same grid with `d2g_ScrollY(11)` — half a row. The top record
is **sliced through the middle**, showing only its lower half beneath an intact header. That is the whole
trick: everything below the header is clipped, so the page can be nudged by pixels and only changes
record when a whole row has gone past. Hit testing accounts for the offset, so a click still lands on the
record you pointed at.

## What the engine gives Clarion

| call | for |
|---|---|
| `d2g_Available()` | 0 when Direct2D/DirectWrite are missing, so the caller can fall back |
| `d2g_Attach(hwnd, face, pt)` | take over a REGION's window; returns a handle |
| `d2g_Columns` / `d2g_Column` | how many columns, and each one's width, alignment and title |
| `d2g_Frozen(n)` | columns that stay put while the rest scrolls sideways |
| `d2g_Colours(...)` | background, banding, gridlines, text, header, selection |
| `d2g_Page(first, rows)` + `d2g_Cell(row, col, text)` | push the visible page in |
| `d2g_PageSize()` | how many whole rows fit — what to ask the VIEW for |
| `d2g_HitRow` / `d2g_HitCol` | turn a click into a record and a column |
| `d2g_ScrollY(px)` / `d2g_RowH` | nudge the page by pixels — smooth, not jumpy |
| `d2g_Resize` / `d2g_Repaint` / `d2g_PaintNow` | keep it in step with the window |

## The template, tested on a real browse

`templates/BrowseGrid/BrowseGrid.tpl` is the drop-in: add it to a procedure that already has an ABC
browse, point it at the LIST, and the LIST is hidden with the grid drawn in its place.

It was tested against a **copy of a real application** rather than an invented one — School's
`BrowseStudents`, whose LIST is `?Browse:1` over `Queue:Browse:1`. `add-to-a-real-browse.py` is how:
export the app to a TXA, splice the two `[ADDITION]` blocks in, re-import, generate, compile.

```
ClarionCL -win -au -ax SCHOOL.APP school.txa      # export a COPY, never the original
python add-to-a-real-browse.py                    # splice BrowseGrid in
ClarionCL -win -au -ai bgschool.app school.txa
ClarionCL -win -au -ag bgschool.app
MSBuild bgschool.cwproj /p:ClarionBinPath=C:\clarion12in /p:Configuration=Debug
```

Result: **generates and compiles clean, 0 errors**, whole application. The generated code hides
`?Browse:1`, reads its columns with `PROPLIST:FieldNo` and friends, and reads values with
`WHAT(Queue:Browse:1, fieldno)` — the browse itself is untouched.

Two things that testing caught, which reading would not have:

- **`Queue:Browse` is wrong.** ABC names the first browse queue `Queue:Browse:1`. The prompt default
  said otherwise until a real app said so.
- **A value-returning `#GROUP` cannot be called from an emitted line.** `%bgRgb(%bgCBack)` inside
  generated source is not a call — substitution looks for a symbol of that name and reports
  `Unknown Variable`. Template expressions can call groups; output lines cannot. The BGR-to-RGB
  conversion is an ordinary Clarion function now, `BG_Rgb`, written once by the global extension.

## Two more that only running it found

The grid drew its header and columns correctly and showed **no rows at all**. Two causes, both invisible
to inspection:

- **The refill was unreachable code.** It was embedded in `ThisWindow.TakeEvent` at a high priority, and
  that method *returns* the moment `PARENT.TakeEvent()` comes back:

  ```
    ReturnValue = PARENT.TakeEvent()
      RETURN ReturnValue        <-- returns here
    END
    ReturnValue = Level:Fatal
      IF Grid1:G
        DO BG:Fill:Grid1        <-- generated, compiled, never ran
  ```

  It now hangs off `Reset` — which ABC calls when the browse has refilled — and `TakeNewSelection`, which
  between them cover scrolling, locating, filtering and editing. **A high priority is not "last"; it can
  be past the RETURN.**

- **Hiding the LIST was wrong.** A hidden LIST is one ABC may decide has no rows to show, since it loads
  by the control's visible row count. The LIST is now **covered, not hidden**: it goes on filling its
  queue, counting rows, holding the selection and answering the browse exactly as before, and the region
  simply sits over it — created later, so drawn on top. Same trick allImageRead uses over its IMAGE.

## What to do with the LIST — three wrong answers before the right one

1. **Hide it.** ABC loads a browse by the control's visible row count, so a hidden LIST shows no rows at
   all. The grid drew a header over an empty page.
2. **Leave it where it is.** It repaints straight over the grid the moment it is clicked — two controls
   in one rectangle, both painting, and the one that redraws last wins.
3. **Park it off the window.** Fixed the painting, and lasted until the first resize: ABC's resizer works
   every control's position out from the *design* layout, so it hauled the LIST straight back over the
   grid and the template thought it was still parked.

The right answer is not to move it at all, but to make Windows respect the stacking order.
**`WS_CLIPSIBLINGS`** on the LIST means it cannot paint into the rectangle of a sibling above it; the
region is raised to the top and re-raised on every resize, because a resize can restack them. The LIST
stays exactly where the resizer puts it, doing everything it did before, and simply never appears.

Three attempts, and the first two each looked right until something touched the window.

## Resizing: measure after the resizer, not with it

The grid stayed its old size while the LIST grew. `EVENT:Sized` reaches this template *before* the window
resizer has moved anything, so measuring the LIST there returns the size it used to be — and nothing ever
looks again.

`EVENT:Sized` now just **posts** a private event. That puts the move at the back of the queue, by which
time the resizer has finished and the LIST is the size it is going to be; the region follows it, the
render target is resized to match, and the page is refilled because a taller browse holds more rows. It
needs to know nothing about the resizer, which is the point — any resizer, any priority.

## Scrollbars: one is ours, one is the browse's

The LIST's own scrollbars went off the window with it, so the grid needed its own — but the two
directions are completely different jobs.

- **Sideways is the grid's.** The columns can be wider than the region; nothing in the file changes when
  you slide them. The bar is sized from `d2g_TotalWidth` against `d2g_ViewWidth`, and moving it just sets
  `d2g_ScrollX` and repaints. Windows hides a bar whose page covers its range, so it appears only when
  the columns really are too wide.
- **Downwards is the browse's.** The grid has no idea where it is in the file — only ABC does. So the
  vertical bar is a remote control: a line, a page or an end posts the matching `EVENT:ScrollUp` /
  `PageDown` / `ScrollBottom` at the parked LIST, and a dragged thumb sets `PROP:VScrollPos` and posts
  `EVENT:ScrollDrag` — exactly what the LIST's own bar would have done. The browse refills its queue,
  ABC calls `Reset`, and that is where the grid picks up the new page. Paging, locators and range limits
  therefore behave exactly as they always did.

The thumb is approximate on an ISAM file, because `PROP:VScrollPos` is a nought-to-a-hundred estimate —
the same approximation Clarion's own browse thumb shows, for the same reason: the file cannot say what
its 743,000th record is without counting.

## Frozen columns have to be drawn LAST

Freeze two columns, scroll sideways, and the third slid straight *over* the frozen pair instead of under
them. Two causes, in the same few lines:

- Columns were drawn left to right, so the scrolling ones came **after** the frozen ones and painted on
  top of them. Whatever is drawn last wins.
- Nothing clipped them, so they were free to draw into the frozen strip at all.

Both are fixed together: the scrolling columns are clipped to the right of the frozen block, and the
frozen ones are drawn afterwards, on top, clipped to their own strip. The header, the gridlines and
`d2g_HitCol` all needed the same treatment — a click in the frozen strip must not be measured against the
scroll offset either.

`docs/BrowseGrid-frozen-columns.png` is the harness with two frozen columns scrolled 170px: Customer and
Town intact on the left, Status sliding underneath them and clipped at the seam.

## Dragging a column edge

Grab the edge of a heading and drag: the column follows. Turn it off with **Let the user resize
columns by dragging** on the extension's prompts.

Four things it has to get right, and `edgetest.clw` proves all fifteen assertions behind them:

- **A frozen edge never moves.** Scroll sideways and the frozen columns stay where they are, so their
  edges have to be measured unscrolled. `d2g_HitEdge` checks the frozen strip first, before it looks at
  anything the scroll offset touches.
- **An edge that has slid under the frozen block is not grabbable.** Otherwise you would be dragging a
  column you cannot see. Scrolled 170px, the edge at x=200 belongs to a hidden column — the hit test
  returns nothing there.
- **The drag is anchored, not incremental.** Width is recomputed from where the drag *started*
  (`startW + x - startX`), never accumulated from the last event. Deltas lose their remainder and the
  column creeps away from the pointer — the same bug that made the image pan wander.
- **Releasing off the grid still ends the drag.** No `EVENT:MouseUp` arrives if the button comes up
  outside the region, so each `MouseMove` asks Windows directly whether the button is still down.
  Clarion has no `MOUSEDOWN`; `GetAsyncKeyState` returns a *signed* SHORT with the high bit set while
  held, so "still down" is simply "negative".

The new width is written back to the LIST's `PROPLIST:Width` when the drag ends, so the browse goes on
believing it owns its own columns — anything that reads, saves or rebuilds from them agrees with what
is on screen.

**After updating, force a full rebuild.** `d2grid.c` lives on the redirection path, so Clarion does not
notice it has changed and links the cached `.obj` — which shows up as `Unresolved External _d2g_HitEdge`
rather than as anything obviously to do with the C file.

## A vanishing scrollbar uncovers the list

Resize a column and the old list came back. It is not the write-back to
`PROPLIST:Width` — `clipkeep.clw` puts a region over a list exactly as the template does, writes a
width, and reports `hwnd same clip 1>1 zord 1>1`: the control is not rebuilt, `WS_CLIPSIBLINGS`
survives, and the region is still topmost.

It is the scrollbar. Making a column narrower can drop the total column width below the view, which
**hides the horizontal bar** — and hiding a scrollbar on a child window *grows its client area* by the
bar's height. `clipshot.clw` measures it: `client 183>200`. Seventeen pixels of the region that the
Direct2D render target does not cover, so what shows there is whatever is underneath.

`d2g_Resize` fixes it, and `BG:Bars` now calls it every time it sets the bars. It is guarded in C
against doing anything when the client area has not actually changed, so calling it on every refill
costs a `GetClientRect` and two comparisons.

## Right-click has to be handed back to the browse

The region is on top, so a right-click lands on *it*, not the LIST — and the browse never sees the
click that would raise its Insert/Change/Delete popup.

The region is alerted for `MouseRightUp`, and the click is handed back. **Not** by forwarding the click
itself: the grid's rows and the LIST's rows are not the same height, so the same y picks a different
record. Instead the row is worked out in the grid's own geometry, the LIST is told to select it, and
the browse is sent **`AppsKey`** — "show the menu for what is selected", which needs no coordinates at
all. ABC alerts `AppsKey` on the list alongside `MouseRightUp` and treats the two identically
(`ABBROWSE.CLW:2618`, `QListClass.TakeNewSelection`), so the popup formatter and every item on it
behave as they always did.

The keystroke is sent on a POSTed event rather than immediately, because `SELECT()` does not take
effect until the next ACCEPT cycle — sent in the same breath it would still be sitting on the region.

## Three kinds of scrollbar

**Style** on the extension: *Windows*, *Slim* or *Overlay*.

| | |
|---|---|
| **Windows** | the sideways bar is Windows' own, the downward one drawn. What the grid shipped with. |
| **Slim** | both drawn, thin and flat, in the grid's own colours, no arrow buttons. |
| **Overlay** | both drawn **over** the rows, thinner still, and only while the pointer is on the grid — the data keeps the whole width. |

The vertical bar was always drawn, so this only adds a drawn **horizontal** one, which costs nothing:
scrolling sideways was already the grid's own business either way (see below) — the style only decides
who paints the furniture.

Two things fall out of the overlay that are worth stating. It **reserves no width**, so `barTakes()` and
`barThick()` are deliberately separate questions — how thick to draw, and how much to take out of the
rows, stop being the same number. And it is hover-driven (`EVENT:MouseIn`/`MouseOut` →
`d2g_BarsShow`) rather than timed: a fade needs a timer, and taking a window's `TIMER` for scrollbar
chrome is not a trade worth making.

The subclass on the region stays on for every style, because the **mouse wheel** comes through it too;
only the `WS_HSCROLL` bit is conditional.

`docs/BrowseGrid-slim-bars.png` is the harness in Slim.

## Scrolling sideways has to happen inside Windows' own loop

Drag the horizontal thumb and the columns did not move until you let go, which is no use when the
whole point is to find the column you want.

Dragging a scrollbar thumb puts Windows into a **message loop of its own**, inside `DefWindowProc`.
Clarion's `ACCEPT` gets no turn until the button comes back up, so anything `POST`ed from the scroll
callback simply queues. `tracktest.clw` is the harness that pins this down: the region's window proc
logs every `WM_VSCROLL` it sees and posts an event, and the `ACCEPT` loop logs when it receives one.

Sideways needs nothing from the browse, though — it is the grid's own pixels. So it is done right
there in the callback, synchronously, and **painted immediately** (`d2g_PaintNow`) rather than
invalidated, because an invalidated window would not be repainted until the loop ended either. The
callback finds its grid with `d2g_FromHwnd`, since a scrollbar callback is handed an HWND and nothing
else.

Downwards is not like this and cannot be: it needs records, and only the browse can fetch them. The
vertical thumb still moves the browse when you release it.

## The LIST is made invisible to WINDOWS, not to Clarion

Three fixes in a row failed to stop the LIST painting through the grid: it came back when a new column
width was written to it, and again when it took the focus so the browse could be sent `AppsKey`. Each
time the answer was "put the grid back on top and repaint", and each time another path turned up.

The diagnosis was wrong, not the patches. `WS_CLIPSIBLINGS` was never enough — `novis.clw` reports
`sameparent 1`, so the two controls really are siblings and the clip *should* apply, and `clipkeep.clw`
reports `clip 1>1 zord 1>1`, so the style and the stacking order both survive. The LIST simply paints
by a route that ignores them.

`HIDE()` is not the answer either: ABC works out how many rows to load from the control's own state,
and a hidden browse decides it has none — the very first bug this template had.

But `WS_VISIBLE` is **Windows'** flag, not Clarion's. Strip it off the HWND with `SetWindowLong` and
Windows stops painting and hit-testing the control, while `PROP:Hide`, the queue, the visible-row count
and everything else ABC reads are untouched. `novis.clw` proves all of it in the faithful arrangement —
a SHEET, a TAB, the LIST inside it, the region created the way the template creates it:

    NOVIS sameparent 1 | winvis 1>0 | PROP:Hide 0>0 | recs 20 | px redred

`winvis 1>0` it is gone from Windows, `PROP:Hide 0>0` Clarion still thinks it is there, `recs 20` the
queue is intact, and `px redred` the region stays solid **after `SELECT(?List)`** — the exact action
that produced the ghost row. `BG:Reveal` hands the flag back at Kill, so a window that gives up on the
grid still has a working browse.

## The LIST draws through, so the grid has to be put back

Right-click and the selected row appeared twice — once as the grid draws it, once at a different
height with different column widths. That second one is the LIST's own rendering: `SELECT` gives it
the focus so the browse can be sent `AppsKey`, and taking the focus is exactly what makes a listbox
draw its selection bar.

`WS_CLIPSIBLINGS` stops the LIST *owning* the region's pixels but does not stop it drawing into them,
which is the same thing that happened when a new column width was written back. So there is now one
routine, `BG:Cover`, that puts the region back on top and draws it **this instant** — `d2g_PaintNow`,
not `d2g_Repaint`, because an invalidated window would not be redrawn until the menu closed. It runs
before the menu opens and again afterwards, and at the end of a column drag.

## Colours are prompts, not accidents

The default header is `004A3A2BH`. Clarion colours are `0x00BBGGRR`, so that is RGB(43, 58, 74) — a
dark slate blue, which reads as black at header size. Every colour the grid uses is on the **Look**
tab of the extension: background, banding, gridlines, text, header background and text, selected row
and text.

## The keyboard is the browse's, so give the browse the focus

Arrow keys, PageUp and PageDown, Ctrl-PageUp and Ctrl-PageDown for the two ends — every one of these
is something an ABC browse has always done. None of it is reimplemented here.

A click used to `SELECT` the region, to keep the focus off the LIST. It now selects the **LIST**. That
is only possible because the LIST is invisible to Windows but perfectly alive to Clarion: it can hold
the focus and answer keys while showing nothing. So the arrows, the paging, the two Ctrl-Page ends, the
incremental locator, Insert, Delete and Enter all go on working exactly as they did, unwritten by us.
The region only ever needed the mouse, and a REGION with `PROP:IMM` gets that whether it has the focus
or not.

`novis.clw` cannot prove the keyboard half — `PRESSKEY` does not drive a bare `FROM(Q)` list in a
harness, and the control arm fails the same way (`visible 2>2 | concealed 2>2`), so the probe says
nothing either way. What does prove it is the popup: it works by `SELECT`ing the concealed LIST and
sending it `PRESSKEY(AppsKey)`, and the menu appears. A control that takes the focus and acts on a key
is a control that can be typed at.

## The roller

`WM_MOUSEWHEEL` goes to whatever is under the pointer, which is the region — the LIST underneath is
invisible and cannot be hit — so it is caught on the region's own window proc, alongside the
scrollbars. One notch is three rows, as everywhere else in Windows, capped at thirty so a flicked
wheel is not a page jump.

Unlike a thumb drag there is no modal loop here, so posting is enough: the ACCEPT loop runs between
notches and the browse fetches its records as it always would.

## The drawn page has to follow the selection

Ctrl-PageUp went to the top and selected the first record. Ctrl-PageDown went to the bottom and
selected nothing.

`BG:Fill` always started drawing at queue entry one and stopped when it ran out of room:

    rows = RECORDS(queue)
    fit  = d2g_PageSize(grid) + 1
    IF rows > fit THEN rows = fit.

The grid's rows are taller than the LIST's lines, so the browse loads more records than there is room
to draw, and starting from the top throws the tail away — those records are below the visible area. At
the bottom of the file ABC selects the **last** entry, which was therefore never drawn, so nothing
highlighted. The top never showed the bug because entry one is always drawn, which is exactly why one
key worked and the other did not.

`BG:Fill` now picks a starting point instead of assuming one: if the queue is longer than the grid can
draw and the selection falls past the end of what would be drawn, it starts at `sel - fit` so the
selected record is the last row on screen, clamped so it never runs off either end. `d2g_Page` is told
that starting point, and the selection is set in absolute row numbers, which is what the engine
compares against.

## Making the grid and the browse agree on a page

Keeping the selection in view was not enough — the last record still could not be *seen*, because the
browse and the grid still disagreed about how long a page is. ABC works out how many records to load
from the LIST's height and its **line height**; the grid works out how many it can draw from the
region's height and its **row height**. Two independent numbers for the same thing, and every symptom
above came out of the gap between them.

`PROP:LineHeight` is readable and writable, and it answers in whatever `PROP:Pixels` is set to —
`lineh.clw` measures it: `units 8 pixels 16 | height 120u 240p | rows 15`.

So they are made to agree, in whichever direction the developer chose:

- **Row height 0** (the default): the grid takes the LIST's own line height and draws to it. The browse
  goes on loading exactly the number of records there is room for.
- **Row height set**: the grid uses it, and the LIST is given the same line height, so ABC loads to the
  grid's shape instead.

The header heights are still independent, which can leave the two out by a single row. The
selection-follows-the-page fix above covers that, so nothing disappears.

## The vertical bar is drawn, not Windows'

Sideways worked because scrolling sideways needs nothing from the browse — it could be done inside
Windows' modal drag loop. Downwards cannot: moving the browse needs records, records need ABC, and ABC
needs `ACCEPT`, which is exactly what that loop is holding up. No amount of work on Windows' scrollbar
gets round that.

So the vertical bar is no longer Windows'. `WS_VSCROLL` is gone from the region and the grid draws its
own — trough and thumb, in the grid's own colours. Dragging it is then an **ordinary mouse move**:
`ACCEPT` runs, the browse is told to scroll exactly as its own thumb would tell it, and by the time the
pointer has moved again the records are on screen. The horizontal bar stays Windows', because it works.

Details that matter:

- **The drag is anchored** (`d2g_VGrab`), so the thumb does not jump under the cursor when you take
  hold of it half way down — the same rule as the column drag and the image pan.
- **While dragging, the thumb follows the pointer, not the browse.** `BG:Bars` skips it during a drag,
  or the thumb stutters as ABC's approximate position argues with where you are holding it.
- **Releasing off the grid still ends it** — `GetAsyncKeyState`, as everywhere else.
- **Clicking the trough** pages up or down.

The thumb is a fixed size, because ABC gives one number and only one: `PROP:VScrollPos`, nought to a
hundred. That is the same approximate position Clarion's own browse thumb shows, and for the same
reason — on an ISAM file nothing knows the record count without reading the whole file.

`docs/BrowseGrid-vertical-bar.png` is the harness with the thumb 40% down.

## Why the thumb would not drag

Clicking the trough worked; dragging the thumb did nothing. A trough click needs only
`EVENT:MouseDown`, a drag needs `EVENT:MouseMove` — so the obvious suspect was the focus, which had
just been handed to the LIST for the keyboard. `movefocus.clw` says no: an IMM region gets mouse moves
whether it has the focus or not (`rgn d0m49u0`, `list d1m31u1`).

The real cause is in ABC. `BrowseClass.UpdateThumb` turns the LIST's scrollbar **off** when the browse
was not given a thumb (`ABBROWSE.CLW:1688`), and with it off, writing `PROP:VScrollPos` is ignored. So
every drag wrote a position, read back nought, and ABC's `ScrollDrag` handler saw `VSP <= 1` and went
to the top of the file. Setting `PROP:VScroll` on costs nothing here — the LIST is invisible, so this
is a number being borrowed, not a scrollbar anyone will see.

## A thumb that tells the truth about its size

`RECORDS()` reads the count out of the file header, so it costs nothing to ask. The thumb is then sized
the way every other scrollbar in Windows sizes one: a page against the whole file. Twenty records and
it nearly fills the trough; two million and it is a sliver.

Name the file on the extension's prompts — it defaults to the procedure's primary file. It is a plain
label, deliberately **not** a `FILE` prompt: a `FILE` prompt puts the file into the procedure's
schematic, which changes what AppGen thinks the procedure uses, and that broke an unrelated procedure
in the test app with `Procedure doesn't belong to module`. A template that only wants to *read* a count
has no business changing what the app is made of.

A filtered or range-limited browse will read high, because the count is the file's, not the view's.

The **position** is still ABC's `PROP:VScrollPos` — nought to a hundred, estimated from the key. Making
that honest as well means the grid reading the VIEW itself, which is the outstanding job below.

## Leading has to grow with the type

Two separate faults made big type sit in short rows with its descenders cut off by the row below.

**The row height was being pulled straight back down.** After `d2g_FontSize` grew the rows, the next
thing to run was `BG:Rows` — which reads the row height *off the LIST*. So the grid was told its rows
were 16 pixels again, whatever the font was doing. When the font changes, the **grid** is the one that
knows how tall a row is, so the height now travels the other way: grid to LIST, and the browse reloads
to fit however many rows there is now room for.

**And the leading was a fixed number of pixels.** `pt + 10` is roomy at 9 point and cramped at 24.
It is `pt * 3 / 2 + 6` now, which grows with the type and lands on exactly the same numbers as the old
rule at the default size, so nothing moves for anyone who never touches it.

**Then it happened again**, and the way it failed named the culprit: the *heading* grew and the *rows*
did not. `d2g_FontSize` sets both, and only the row height has anything that reads back off the LIST —
so something was still handing the grid the LIST's 16-pixel line after the font had grown.

Chasing which call ordering did it is the wrong fix, because there are several paths that can set a row
height and any of them can be wrong. `d2g_RowHeight` now **refuses** a height shorter than the type
needs, in the engine, once — and `BG:Rows` sends the clamped value back to the LIST, so the browse
never loads to a height nothing is drawn at.

**And then they grew but never shrank** — a ratchet, and the clamp was only half of why. `BG:Rows`
asks the LIST how tall a row should be, but the LIST's line height is the number *we ourselves pushed
up* the last time the type grew. Asking it again just gets that number back, and the clamp then keeps
it. Two feedback loops pointing the same way.

When the type changes size the **grid** is the authority and the LIST is told — never the other way
round. The font path no longer calls `BG:Rows` at all, and `d2g_FontSize` sets the height outright
rather than through `d2g_RowHeight`, whose clamp is measured against the very thing that just changed.
`BG:Rows` keeps its job: adopting the LIST's height at setup, clamped so nothing can squash the type.

`gridtest.clw` now drives the whole cycle — grow to 18 point, let the LIST try to squash the rows back
to 16, then shrink to 9:

    GridTest grew=33 shrank=19

33 pixels at 18 point (the squash refused), 19 at 9 point (all the way back down).
`docs/BrowseGrid-big-font.png` is that run.

## Ctrl and the roller resize the type

Growing the type without growing the columns is not a bigger grid — it is the same grid with the words
too large for it. Every cell wraps or clips and the headings run into one another. So a zoom scales the
**layout**: the column widths, the group boxes, and every field's place inside its group, including the
original measurements a group resize works from, or the next drag would undo it.

`gridtest.clw` checks it survives the round trip:

    GridTest grew=33 shrank=19 col 150>300>150

A 150-pixel column doubles at 18 point and comes back to exactly 150 at 9.


The same wheel hook checks for `MK_CONTROL` and rebuilds the text formats a point larger or smaller,
6 to 32. The rows grow with the font by the same rule `d2g_Attach` uses, so the LIST is handed the new
line height and the browse reloads — a bigger font fits fewer records, and both sides have to agree on
that or the last rows go missing again.

## Clicking a heading sorts, without any geometry

The grid does not sort anything. ABC's sort-header class reads
`SELF.ListControl{PROPLIST:MouseDownField}` to find out which column was pressed
(`brwext.clw:2926`) — and that property can simply be **written**. So it is set, `EVENT:HeaderPressed`
is posted, and the browse sorts by whatever rule it was already given.

It first went the long way round: post a fake mouse click to the LIST at the x of that column's
heading, computed from `PROPLIST:Width`. That failed, and the way it failed was the clue — a column
could not be sorted until it had been resized once, **bigger or smaller**, which meant the size was
irrelevant and the *act of writing the width* was what mattered.

`mdfield.clw` settles it. On a LIST concealed exactly as the template conceals one:

    MDFIELD set2>2 | HeaderPressed n1 field 2

`set2>2` — the property is writable and reads back. `n1` — **one** header press, the written one. The
posted mouse click that follows raises nothing at all: a window Windows will not paint is a window a
fake click cannot press. Posted messages reach it, but the control does not turn them into a header
press.

So the coordinate arithmetic was never the problem; the whole approach was. Clicking the *edge* of a
heading still resizes and anywhere else sorts, and "edge" is still decided on the mouse coming up
rather than going down — the grab margin reaches four pixels either side of every boundary, including
the seam at the end of the frozen block, so a heading against one of those would otherwise have every
click swallowed by a resize that goes nowhere.

A small arrow marks the sorted column, and the heading's text is shortened to keep clear of it. It is
four one-pixel rows rather than a triangle path — there is no geometry sink here, and at that size the
steps do not show. `docs/BrowseGrid-sort-mark.png` is the harness with Town sorted ascending, drawn
correctly on a grid that is also scrolled sideways with two frozen columns.

Which way it points is our own memory of the clicks, because ABC toggles on a second click of the same
heading and there is nothing to read that back from. Where ABC *does* say — `PROPLIST:SortColumn`,
which it keeps when the browse was given sort colours — that is believed instead, since a sort can also
be changed by a tab, a button or the browse's own code, none of which come through us.

## Grouped and multi-line formats

A grouped browse puts several fields on each record over more than one line, under headings that span
them — the shape the List Box Formatter shows as a tree. Read as a flat list of columns, that comes out
as one very long row with most of the headings missing.

The runtime describes the whole structure, which is what makes this tractable:

- `PROPLIST:GroupNo` — which group a column belongs to, 0 for none.
- `PROPLIST:LastOnLine` — where the format wraps onto the next line of the record. Counting these is
  how a multi-line format is recognised at all.
- **`PROPLIST:Group` (0040H) added to any other property** reads the *group's* version of it, so
  `PROPLIST:Header + PROPLIST:Group` is where "Last Name", "Address" and "Telephone" actually live —
  the fields underneath usually carry no heading of their own.

**Flattening** is what is built: every field becomes a column of its own on a single line, taking its
own heading if it has one and the group's if it has not (and both, `Address City`, when they differ).
Resizing, sorting and freezing then work per field, and the grid scrolls sideways rather than growing
taller — which is the thing it already does well.

**Faithful** is the other half, and it is now built. Untick *Flatten a grouped or multi-line format*
and the record is drawn the way the formatter lays it out: the group headings span their fields, each
record is as many lines tall as the format makes it, and the banding, the selection bar and the
gridlines cover the whole record rather than each line of it.

The engine needed a column that says **where it goes** rather than only how wide it is —
`d2g_ColumnAt(h, col, group, line, x, width, align)` — plus `d2g_Group` for the spanning headings and
`d2g_Lines` for the height of a record. An ordinary browse sets no groups at all, and every one of
those paths is skipped, so nothing about a flat browse changed.

Two things follow from grouping that are worth knowing:

- **Freezing counts groups, not fields.** Freezing one freezes the whole name block, which is the only
  thing that makes sense when a heading spans several fields.
- **The draggable edges are the groups', not the fields'.** One heading stands over several fields and
  there is nothing sensible to grab between two of them that sit on different lines. Dragging a group
  edge scales the fields inside it to keep their share, and shifts every group to its right along.
  `d2g_HitEdge` still answers nothing here, so a click that is not on a group edge falls through to
  sorting.

Clicking a group heading sorts by the **first field in that group** — `d2g_HitCol` answers with it, so
everything downstream is unchanged.

`docs/BrowseGrid-grouped.png` is `grptest.clw`: two-line records, three spanning headings, the name
group frozen, drawn straight from the same calls `BG:Groups` makes.

## Wrapping long text

**Wrap text that is too long for its column** on the extension, with a spin for how many lines a cell
may use, 2 to 4. Every row is that many lines tall whether its text needs them or not: rows of
differing heights would take the page size, the hit testing and the scrolling with them, and none of
those want to know that one particular address happened to be long.

The wrapping itself is DirectWrite's —  on the text format, set per cell alongside
the alignment that was already set there, so headings never wrap and cells do.

It appeared not to work for three builds, and the reason is worth writing down. Forcing wrapping on
unconditionally changed nothing, so the vtable index looked wrong. Reading the value back settled it:

    GRPTEST rows=6 setwrap0>got0

Set 0, got 0 — DirectWrite had wrapping on the whole time. The text was being **truncated to 63
characters when stored**, because  was 64, and 63 characters at 9 point happened to just fit
the column. There was nothing left to wrap. A cell that can wrap wants room to be worth wrapping, so
 is 128 now (and  96, which is still more rows than any screen holds at the minimum row
height).

 is the harness with a narrow Address column, wrapping onto a second line.

## A grouped browse that showed nothing at all

Two faults, and the first is why the grid came up empty.

**The row height was being squared.** `d2g_RowNeed` already counts the lines in a record and the lines
a wrapped cell may use; `BG:Rows` then multiplied by the line count *again*. On a four-line format that
makes one line taller than the whole browse, so ABC worked out that no records fitted, loaded none, and
the grid had nothing whatever to draw.

**And the headings were only the groups'.** In a real grouped format most of the words in the header
belong to the **columns** — "Last Name", "Major", "Grad Year" are the columns' own headings, and only
"Address" and "Telephone" are their groups'. Drawing group headings alone left the first group blank,
which is exactly what it did. `d2g_ColumnAt` now carries the column's own heading, the header is as
many lines tall as the record, and each column's heading is drawn on the line its field sits on — the
header mirrors the row.

## PROP:LineHeight is one LINE, not one record — in both places

Zooming a multi-line browse left **one** record on screen and nothing else. The title said it:
`rowh=108 lh=66 items=1`.

`PROP:LineHeight` is the height of a line, and on a multi-line format the LIST multiplies it by the
lines in a record. `BG:Rows` divides by the line count for exactly that reason — but the **font path had
its own copy of the calculation** and never got the fix, so after a zoom the LIST was told a whole
three-line record was one line, worked out that a record was three times taller again, and loaded a
single one.

Two copies of one rule, and only one of them corrected. The font path divides now, and asks `BG:Items`
to reload to the new page size while it is there.

## The original fault, for the record

A grouped browse drew exactly **one** record, and scrolled one record at a time — which is a much more
useful symptom than a blank grid, because it says the queue held one.

`PROP:LineHeight` is the height of a **line**, and on a multi-line format the LIST multiplies it by the
lines in the record itself. Handing it the whole record height therefore told the browse each record
was lines-times-taller than it really is: it worked out that one fitted, and loaded one.

The grid keeps the record height. The LIST is given one line of it. Reading the other way round needed
the same correction — the LIST's own line height has to be multiplied **up** by the lines in a record
before it means anything to the grid.

## Resizing a group has to be reversible

Dragging a group narrow and then wide again piled every field up on the left, overwriting each other.

Each drag scaled the **current** numbers, and integer arithmetic drives them to nothing: squeeze a
group far enough and the offsets round to zero, then growing it back multiplies zero by a ratio, which
is still zero. The layout was destroyed by the first drag and there was nothing left to restore.

Each field now keeps the offset and width it was **read** with, and the group keeps the width those
were measured against. Every resize recomputes from those, never from the last result. Storing the
original numbers rather than a proportion of them also avoids rounding twice — a proportion truncates
going in and again coming out, which left the fields a pixel short of where they started.

`proptest.clw` squeezes a 300-wide group down to 60 and back:

    PROP-PASS was 200,300,160,140 now 200,300,160,140 grp=300

## Excel's drop-down on every heading

**Excel-style drop-down button on every heading** puts a boxed arrow at the right of each heading, the
way Excel's autofilter does, with the sort mark moved just left of it. Clicking one opens a menu:

- Sort ascending, sort descending
- Filter on the value under the selection
- Clear this filter, clear all filters

Sorting goes through the browse exactly as a heading click does. **Filtering calls the browse object's
own `SetFilter`**, so range limits, locators and everything else the browse was given keep working —
which is why the object has to be named on the prompts. It defaults to `BRW1`.

The field name for the filter expression is read at run time with **`WHO()`**. An ABC browse queue
labels its fields with the file fields they came from, so `WHO(Queue:Browse:1, n)` answers
`STU:LastName` — exactly what a filter wants, and it means nothing has to be mapped by hand. That is
the trick that makes this possible from outside the browse template.

The button is drawn before the resize edge is tested, because they occupy the same few pixels and the
button is what is visibly there.

`docs/BrowseGrid-filter-button.png` shows the buttons with a sorted column beside one.

**Not built yet:** Excel's checklist of distinct values. That needs a pass over the VIEW to collect
them, and a small window to show them in. The value under the selection covers the common case in the
meantime.

## Every option has to be generated at least once

The filter button shipped with a `CODE` statement in a ROUTINE that had no `DATA` section. Clarion only
accepts `CODE` after a `DATA` block, so the moment anyone switched the button on their app would not
compile — `Expected: <statement> … DATA …`.

It got through because the test app had the option **off**, which is its default, so that ROUTINE never
generated. Registering a template only parses it; a generate is what proves the emitted Clarion is
Clarion, and a generate only covers the paths whose prompts are switched on.

The test app now has every optional path **on** — flattening off so the grouped one runs, wrapping on,
diagnostics on, filter button on — so a generate exercises the code that used to hide behind a default.
Turning them on is a TXA round trip:

    ClarionCL -win -au -ax app.app out.txa      # export
    ...edit the %prompt values in out.txa...
    ClarionCL -win -au -ai app.app out.txa      # import
    ClarionCL -win -au -ag app.app              # and generate

## The grid was throwing the browse's own filter away

`SetFilter` with no ID uses `'5 Standard'` — and that is the ID the **BrowseBox template itself** uses
for the filter the developer set on the browse (`ABBROWSE.TPW:1120`). Filtering from the grid was
therefore discarding it, and clearing a grid filter left the browse permanently unfiltered for the rest
of the run. On a browse with a designed filter that is not a cosmetic bug: it shows records the
procedure was written never to show.

Each column now has **an ID of its own**, `BrowseGrid:<n>`, and the developer's `'5 Standard'` is left
alone. ABC does the joining: `ApplyFilter` walks every ID it holds and ANDs them, each in its own
brackets, with the range limits in front (`ABFILE.CLW:2613`). An empty expression **deletes** that ID
rather than leaving an empty bracket, so setting every column on every apply is both safe and
idempotent, and there is nothing to concatenate here any more.

## Why it is an extension and not a child of the browse

It was briefly converted to a `#CONTROL` with `REQ(BrowseBox)`, which is what nests a template under the
browse in the Extensions tree the way "Update a Record from Browse Box" is nested. Being a child is
genuinely better on paper: the browse object, its queue and its LIST all come from the parent instead of
from prompts, and `#AT(%BrowserMethodCodeSection, parent, 'ResetQueue')` becomes available — an embed
*inside* the browse object, firing exactly when the queue has been rebuilt.

It was reverted, for a reason that is not negotiable: **a control template has to place a control.** One
with no `CONTROLS` block registers perfectly well and then never appears anywhere it can be added from,
because control templates are added from the window designer by placing something. Giving it a `REGION`
to place made it addable and turned "tick a box on the browse" into "open the designer and drop a
control on the window" — a worse workflow for a template whose whole job is to take over a browse that
is already there.

So it stays a `PROCEDURE` extension, added on the Extensions tab, and the LIST control it is pointed at
is what tells two browses apart. The description reads **`Grid on ?Browse:1`** so the tree says which.

Worth recording for anyone tempted by the same idea: `#PREPARE` runs when prompts are *loaded*, not when
code is generated, so a `#SET` there never reaches the emitted source; and unregistering a template makes
Clarion drop **every** addition belonging to it from the app, which is a way out of an orphaned instance
but takes the global extension with it.

## A grid you cannot get stuck in

The column chooser shipped able to hide **every** column, which leaves a grid drawing banded stripes
and nothing else — and, worse, nothing to click on to undo it. The diagnostics line said it in one
glance:

    BG q=4 fill=136 filt=0 cols=0 lines=1 rowh=38 ... draw=4 ... items=4

`q=4` and `draw=4` — the queue was fine and four rows were being drawn. `cols=0` — there was nothing to
draw *in* them. That is what the diagnostics prompt is for: an empty grid looks identical whether the
queue was empty, the rows were too tall, or the columns were all gone, and those want different fixes.

And then the rescue itself took the program down on startup — it finished with `DO BG:Columns` from
**inside** `BG:Columns`. That is not a recursive call in Clarion: a ROUTINE holds one return address, so
calling it from within itself loses the way back. The read is a two-pass `LOOP` now, and the rescue
`CYCLE`s rather than calling anything.

Three things came out of it. The chooser **refuses** to hide the last column. `BG:Columns`, if it ever
finds nothing to show, **puts the widths back** from what they were before they went and reads again,
so a grid can always be got back to whatever put it in that state. And **Reset layout** on the heading
menu throws away everything the grid remembers — widths, hidden columns, filters — and reads the browse
as it was designed. Anything that can be got into a state needs a way out of it, and hunting through an
INI file is not one.

The ticks are plain text now (`X` in a *Show* column) rather than a picture-token checkbox, because a
checkbox nobody can see is what makes hiding everything an easy mistake.

## A field equate belongs to whichever window is current

Unticking a column and pressing OK did nothing whatever — no error, no change. The generated code was
right, the write was right, and `widzero.clw` proves `PROPLIST:Width = 0` takes even on a LIST that has
had `WS_VISIBLE` stripped:

    WIDZERO visible 60>0 | concealed 60>0 TAKES

The fault is Clarion's oldest trap. **A field equate is resolved against whatever window is CURRENT**,
and while the Columns dialog was open that was the *dialog*. So every `?Browse:1{PROPLIST:Width} = 0`
written inside its ACCEPT loop went to a control of the Columns window instead of to the browse. It is
a legal write. It simply lands somewhere else, and nothing complains.

The dialog decides now, and the widths are applied after `CLOSE(ChW)`, when the browse window is
current again and the same lines mean what they read as.

## Dragging a column shut hides it

A column cannot be dragged narrower than its heading button, so Excel's "drag it to nothing and it is
gone" was unreachable. The **intent** is caught before the clamp — if the drag asked for less than eight
pixels, the column is hidden when the button comes up, keeping its width so **Columns…** can restore it
at the size it was. Never the last column.

## Which columns to show

The chooser shipped with two faults that made it useless rather than merely rough.

**The columns had no names.** It read `PROPLIST:Header`, and in a grouped format most columns carry no
heading of their own — the group's stands over the lot — so the list came out blank, and falling back to
"Column 7" is no better. `WHO()` answers with the field the column actually shows, `STU:LastName`,
because an ABC browse queue labels its fields with the file fields they came from. It is the same thing
that lets the grid build a filter expression, and it should have been the first answer here too.

**And every row read "1".** A LIST with `FROM(queue)` hands its format columns the queue's fields **in
the order they are declared** — there is no naming of one to the other. The queue was `Mark, On, Name`,
so the second column showed `On`, which is 1 for every visible column. The fields that are displayed
have to be declared first. The same mistake was sitting in the value checklist beside it.

**And nothing happened when you clicked.** A Clarion LIST only raises `ACCEPTED` on a double click or
Enter, so single clicks fell through and the dialog looked inert. Space toggles the highlighted row now,
and there are **Show**, **Hide**, **All** and **None** buttons — a list that appears to ignore you is
worse than no list at all.

**Columns…** on the heading menu. Hiding a column is not a grid idea at all — a LIST column of zero
width is already invisible to Clarion and `BG:Columns` already skips those — so the chooser only has to
set widths and read them back, and nothing in the grid needed teaching about hidden columns.

**A hidden column has to be stored as hidden.** `BG:Remember` wrote a width for every column the *grid*
was drawing — and a hidden column is not one of those, so its old width stayed in the file and
`BG:Recall` put it straight back on the next open. Hiding lasted exactly as long as the window did. It
now writes every LIST column, and `BG:Recall` honours a stored `0` instead of skipping it. Zero is a
width too.

The width a column had before it was hidden is kept separately, so unhiding puts it back where it was
rather than at some default. That falls out of the layout store keying on **LIST column number**: a column the
grid is not drawing still has somewhere to keep its width.

## Excel's checklist of values

**Filter by value…** lists every value in the column, ticked, with All and None. Untick what you do not
want. Everything ticked, or nothing, means no filter rather than an impossible one.

The field is known only by **name** — `WHO()` off the browse queue — so the values are read with
`EVALUATE()`, which resolves a name against whatever is bound. ABC binds the whole record buffer
(`FileManager.BindFields`), and the proof it is already bound is that the filter expressions built from
those same names work at all.

The chosen values become `(f = 'a' OR f = 'b')` in **that column's** filter ID, which is what the
per-column IDs bought: one column can hold several values without touching another column's filter, and
ABC ANDs the columns together itself.

Two things are deliberate. Reading the file moves its record buffer, **which the browse shares** — so
this always finishes by re-applying the filters, which makes the browse re-read and puts it back where
it belongs, whether values were chosen or cancelled. And the scan is capped (50,000 records, 500
distinct values), because a checklist is only useful while it is short. It needs the file named on the
prompts; without it the grid only ever sees a page of the queue, and it says so rather than offering an
empty list.

## The layout is remembered

Column widths and filters are kept between runs, through the application's **own `INIMgr`** — no new
storage, no new file, and it lands wherever that application already puts its settings. The section is
named for the procedure and the grid (`BrowseGrid:BrowseStudents:Grid1`), so two grids on one window do
not tread on each other.

Widths are put back **before** `BG:Columns` reads them, so one path decides a width and the grid is
never told twice. They are keyed by **LIST column number** rather than by grid column, because a hidden
column is not in the grid's list at all and its width would otherwise have nowhere to come back to —
which is what makes the column chooser possible without a second store.

**Filters are deliberately not kept.** Widths are safe to put back — the worst a bad one can do is look
wrong. A filter is not: it is handed to ABC as an *expression*, and an expression that will not parse is
a run-time error at window open, before there is anything on screen to explain it. A filter stored by an
earlier version of this template therefore killed the application every time the window opened, and went
on doing it through every rebuild, because it lived in the INI file rather than in the program. Any that
were stored are purged on the next open.

It was the wrong idea on its own merits, too. Someone opening a browse expects to see the records, not
yesterday's filter with no indication of why three quarters of the file is missing.

Saving happens at Kill, so it costs nothing until the window closes.

## A filter per column, added together

Filtering a second column made the first column's funnel disappear — and the glyph was telling the
truth: the filter had gone too. There was **one** filter and **one** marked column, so a second one
replaced the first, and the browse quietly stopped being filtered on a column the user still thought
was filtered. That is worse than the missing glyph.

Filters are per column now and add up the way Excel's do. Each column keeps its own expression; they
are joined with `AND` only on the way out to `SetFilter`, because ABC keeps a single expression per ID.
The marks are a set rather than one column index, so every filtered heading shows its funnel, and all
of them are re-applied on every refill. **Clear this filter** clears the column you opened the menu on;
**Clear all filters** clears the lot.

## POPUP counts its separators

Filtering did nothing, and *clearing* a filter applied one — on the value that had been selected
earlier. The menu was numbered wrong: `POPUP` counts a `-` as an item, so with two separators in the
string every choice after the first was one or two higher than it looked. "Filter on" was item **3**
and matched no case at all; "Clear this filter" was item **4**, which is where the filter code was. So
clearing filtered, filtering did nothing, and the mark never appeared because the branch that sets it
never ran.

The menu has no separators now and the cases are numbered as they read.

## A filter does not take hold until the browse has re-read

Filtering appeared to do nothing until something else was clicked, and clearing a filter appeared not
to clear it until the next action — always one step behind.

`BrowseClass.SetSort` does not finish applying a filter before it returns. It ends with
`SELF.PostNewSelection`, which is a **POST**, so the re-read lands on a later ACCEPT cycle. Filling the
grid straight after `SetFilter` therefore read the queue as it was *before* the filter. It also
restarts from the queue's own view position rather than the top (`RESET(SELF.View,
SELF.ListQueue.GetViewPosition())`), so a filter that matches nothing near the cursor can come back
empty even when it matches plenty elsewhere.

So the filter is applied, the browse is asked to go to the top of the new set through its own event
(`POST(EVENT:ScrollTop, list)`), **and a refill of the grid is posted behind it**. Relying on `Reset` or
`TakeNewSelection` to fire after a filter was not enough on its own — the posted refill is handled after
everything the browse posted for itself, so by the time it runs the queue is whatever the browse ended
up with, whichever path got it there.

## Ascending and descending have to mean it

Both menu items sorted ascending, whichever was chosen, and the arrow always pointed up.

`BG:Sort` sets ascending whenever it thinks the heading is a new one — and the menu cleared `SortOn`
first, precisely so the toggle would not fire, which sent both items down that branch. Asking twice for
descending did not help: two presses from an unknown starting point land back where they began.

Nothing reports ABC's sort direction back — `PROPLIST:SortColumn` is an `ABS()` — so the only way to
ask for a direction is to know where it currently is. `SortOn` and `SortDir` are that: a model of ABC's
state, kept by the same rule ABC keeps it (a new heading starts ascending, the same heading toggles).
The menu now presses only as often as getting to the asked-for direction takes — none, one or two.

## One button, saying everything

Two arrows in the same corner meaning different things is worse than one that means something, so the
separate sort mark is gone wherever the button is drawn. The button *is* the state:

| | |
|---|---|
| `˅` U+02C5 | not sorted — this opens a menu |
| `▲` U+25B2 | sorted ascending |
| `▼` U+25BC | sorted descending |
| a funnel, U+E71C, on a filled button | filtered |

The funnel is out of Windows' own icon font — Segoe MDL2 Assets on 10, Segoe Fluent Icons on 11, the
same code point in both. If neither resolves, DirectWrite falls back and the **filled button** still
says it is filtered, so nothing depends on that font being found.

They are **characters**, not icons and not shapes hand-built out of one-pixel rows, which is what they
were at first. Rows meant a fixed pixel size that ignored Ctrl-wheel and looked crude next to the text
beside it; a character scales with the type and reads as an icon because it *is* one — the font's.

They cannot go through `text()`, which converts from ANSI on the way in and would lose anything above
127, so `glyph()` takes a code point and hands DirectWrite the UTF-16 directly. DirectWrite falls back
to another font by itself when the chosen one has no glyph, so these draw whatever font the grid was
given.

A grouped heading reads the state of whichever of its fields carries it, since the button belongs to
the group. The filter mark is re-applied on every fill, because a refill would otherwise wipe it.

With the buttons switched **off**, the old sort mark beside the title comes back — there is nowhere
else for it to go.

## A record is as tall as its tallest group

A grouped browse came out with rows far too deep and the text floating in the middle of them. The
diagnostics said it in two numbers: `lines=5 rowh=114`.

`BG:Columns` counted a line for **every** `LastOnLine` in **every** group. A format with two breaks in
the name block and two in the address block therefore reported five lines, when a record is only as
tall as its *tallest* group — three. `BG:Groups` had always computed that correctly, so the template and
the engine were working from different numbers, and the LIST was handed a line height a third too small.

Then wrapping multiplied on top: three lines times two wrapped lines is a row six deep, with every
field centred in a box twice the height of its text. **Wrapping no longer stacks on a format's own
lines** — it is for a flat browse, where a cell has one line and needs more. A grouped record has
already been told exactly how many lines it wants.

## The first draw is in the wrong place

The grid came up covering the buttons and running off the window, and a manual resize put it right.

`BG:Place` measures the LIST and puts the region over it — and at `Init` the LIST is still where the
**designer** put it. The window resizer has not run yet, and on a window that opens maximised, or
restores to a remembered size, the LIST is about to move. Placing the region then and leaving it there
is the whole fault.

`EVENT:Sized` already deferred its work for exactly this reason. Now the first placement is deferred
too: `BG:Setup` ends by posting its own resize event, and `EVENT:OpenWindow` posts one as well — the
first moment everything has been given its real place. Resizing by hand worked because it was the only
thing that ever asked for a second placement.

## Empty grid under the rows

A browse would draw its records and then leave a blank banded row and a stretch of background beneath
them. Both are the same thing: **ABC had loaded fewer records than the grid had room to draw**, and what
is left over is drawn as empty grid.

The two sides count differently. ABC decides how many to load from the LIST's height and its line
height; the grid decides how many it can draw from the region's height and its row height. They are
close but not equal — the two headings are different sizes, for one — and the gap shows.

It is done through the **line height**, not the geometry. ABC divides the LIST's height by its line
height to decide how many records fit, so asking for `fit` of them is arithmetic on a number nobody can
see: `newLineHeight = items × lineHeight / fit`.

Stretching the LIST taller was the first attempt and it worked — until `BG:Place` started following the
LIST on every fill, at which point the grid inherited the stretch and ran off the bottom of the window
and over the buttons. Two mechanisms feeding each other, each correct alone. **The lesson is not "pick
the other one" but "do not make geometry the lever twice."**

## Still to come

Smooth scrolling end to end. The engine scrolls by pixels already; the Clarion side currently pushes
the browse's own queue, which is one page, so it moves a page at a time like any browse. Buffering a
few pages around the viewport and moving through the VIEW with NEXT/PREVIOUS is the next piece.
