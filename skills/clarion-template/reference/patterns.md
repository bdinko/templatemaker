# Clarion Template — Authoring Patterns (the real-world playbook)

Patterns distilled from shipped ABC templates and third-party sets (AJE*, CapeSoft AnyFont/AnyText,
ChromeExplorer, HotDates, KeepingTabs, Cryptonite). Each is something you will reach for repeatedly.

---

## P1 — The disable switch (put it on every template)

Give the developer one checkbox that turns the whole template off, and guard **every** `#AT` with it.

```
#PROMPT('&Disable this template',CHECK),%MyToolDisable,DEFAULT(0),AT(10)
...
#AT(%AfterGlobalIncludes),WHERE(%MyToolDisable=0)
INCLUDE('MyTool.INC'),ONCE
#ENDAT
```

---

## P2 — Multi-DLL aware global declarations (the *instance* / global data)

A class instance or global variable must be declared `EXTERNAL,DLL(dll_mode)` in every DLL except the
one that actually owns it (the root). This is mandatory for any template used in multi-DLL apps.
(For where the class's **methods** live — one shared copy vs a copy per DLL — see **P2b**.)

```
#AT(%GlobalData),WHERE(%MyToolDisable=0)
  #IF(%MultiDLL=0 OR %RootDLL=1)
MyGlo:Caption        CSTRING(40)
%MyToolObject        MyToolClass
  #ELSE
MyGlo:Caption        CSTRING(40),EXTERNAL,DLL(dll_mode)
%MyToolObject        MyToolClass,EXTERNAL,DLL(dll_mode)
  #ENDIF
#ENDAT
```

> **`%MultiDLL` and `%RootDLL` are NOT built-in symbols** — verified: they appear nowhere in
> `template\win\*.tp?`. They are prompts *your template declares*, the CapeSoft convention
> (`accessory\template\cape01.tpw:36`):
> ```
> #PROMPT('This is part of a Multi-DLL program',CHECK),%MultiDLL,DEFAULT(%ProgramExtension='DLL'),AT(10)
> #ENABLE(%MultiDLL=1)
>   #PROMPT('This is the root/data DLL',CHECK),%RootDLL,AT(10)
> #ENDENABLE
> ```
> Use them and you are asking the developer to answer a question the app already knows. **The ABC-native
> alternative needs no prompt**: `%DefaultExternal = 'None External'` is true in the owning app and false in
> the children (corpus: `cleansdw.tpw:25`), with `%ProgramExtension` and `%DefaultExport` alongside. Prefer it.

And export the owned symbols from the root DLL:
```
#AT(%DllExportList),WHERE(%ProgramExtension='DLL' AND %RootDLL=1 AND %MultiDLL=1)
 #INSERT(%ExportClassesPR,'MyTool.Inc')
 #INSERT(%AddExpItem,'$MyGlo:Caption')
 $%MyToolObject     @?
#ENDAT
```
`$Label` is the export spelling for a data item. **`%ExportClassesPR` is CapeSoft's**, defined in
`accessory\template\cape02.tpw:394` — it only exists if that chain is registered. `%AddExpItem` is ABC's
(`ABBLDEXP.TPW`). Don't mix the two families' helpers by accident.

---

## P2b — Where a CLASS's *code* lives in a multi-DLL suite

P2 places the *instance*. This places the *methods*: in a suite you normally want **one** app to compile the
class and the rest to import it, not every DLL carrying a private copy. Two project defines decide it, exactly
as every ABC class does it:

```
MyClass  CLASS,TYPE,MODULE('MyClass.CLW'),LINK('MyClass.CLW',_myThingLinkMode_),DLL(_myThingDllMode_)
```
| define | 1 means |
|---|---|
| `_myThingLinkMode_` | compile `MyClass.clw` into **this** app (and, if it is a DLL, export the class) |
| `_myThingDllMode_`  | **import** the class from another DLL; compile no copy |

**Undefined is safe and is the single-EXE behaviour** — with neither define set (a hand-coded project, a demo)
`LINK` behaves as 1 and `DLL` as 0, so the class is simply linked in. Do **not** add `EQUATE` defaults for
them: they would collide with the pragma defines the templates generate.

### Best route — register an ABC *category*: nothing to maintain, no mangled names

1. `.inc` line 1 → `!ABCIncludeFile(MYTHING)`. The **argument is the category** that files this class in the
   IDE's class registry. Bare `!ABCIncludeFile` = category `ABC`; `svgraph.inc` uses `(GRAPH)`; CapeSoft's
   `MessageBox.inc` uses `(ABC)` to deliberately piggyback on the ABC chain's own location.
   **Tag EVERY class you ship, even one with no multi-DLL ambitions** — see the box below.
2. Prompts — the shipped Override box (`Override defaults` + LINK / DLL / LIB / None + library name):
   `#INSERT(%AbcLibraryPrompts(ABC))`  (defined `ABOOP.tpw:131`).
3. In the **`APPLICATION`-scope** extension:
```
#AT(%BeforeGenerateApplication),WHERE(%MyThingDisable=0)
  #CALL(%AddCategory(ABC),'MYTHING')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'MYTHING','myThing','')
#ENDAT
```
Args are *(category, DllMode-prefix, library base name)*. The prefix builds the define names, so `'myThing'`
→ `_myThingLinkMode_` / `_myThingDllMode_`. Corpus: `svgraph.tpl:38`, `qcenter.tpw:98`, `abmail.tpl:310`.

That is all. The shipped chain then does **both** halves:
- `ABPROGRM.TPW:88` — `#CALL(%DefineCategoryPragmas)` at `%CustomGlobalDeclarations` emits
  `#pragma define(_myThingLinkMode_=>n)` / `_myThingDllMode_` into the project (and `#PROJECT`s the `.LIB`
  if the developer chose LIB/DLL and named one).
- `ABBLDEXP.TPW` — the ABC `.EXP` builder walks the class registry and writes `VMT$`, `TYPE$` and every
  non-private, non-inherited method of every **link-mode** category class, name-mangled by the built-in
  `LINKNAME()`. **You never write a mangled symbol down**, and adding a method to the class later needs no
  template change. `%DLLExportList` is a real embed, but you do not need it for a class.

**The default needs no prompt and is already right.** `%SetCategoryLocation`'s `'?'` defaults are
LinkMode = `~%GlobalExternal`, DllMode = `%GlobalExternal AND %ExternalSource='Dynamic Link Library (DLL)'`:

| App's Global Properties → External | Link | Dll | Effect |
|---|---|---|---|
| *None external* — the data DLL, or a single EXE | 1 | 0 | compiles the class in; if a DLL, exports it |
| *All external → Dynamic Link Library* — the children | 0 | 1 | imports the class; none of its code |

Traps, all three hit for real:
- **Placing a class is a per-APPLICATION decision**, so only an `APPLICATION`-scope extension can make it — a
  `#CONTROL` or `#CODE` template cannot (it has no `%BeforeGenerateApplication`). So the global extension must
  be added to *every* app in the suite; miss one and it silently compiles a private copy again. Say so in the
  prompts, because "the control template is self-contained" stops being true in a suite.
- **The class registry reads the `.inc` that is on the redirection path**, not the one in your repo or project
  folder. A stale copy there carrying the old tag files the class under a *different* category, so the export
  list follows that category's location instead of yours — and it stays invisible while the two agree, which
  they do until someone uses the Override box.
- A DLL can only export symbols it **defines**, so only a link-mode app may export the class. That is exactly
  what `ABBLDEXP`'s `#IF (%Category AND %CategoryLinkMode)` guard is for — don't try to force exports on.

> ### Never ship a class with a bare `!ABCIncludeFile` — it breaks other people's data DLLs
> This is the one to remember even if you never do multi-DLL. `ABBLDEXP` exports every registered class whose
> category is link-mode and **never checks whether the application uses the class**. A bare tag means category
> `ABC`, which *is* link-mode in a data DLL — so **every** bare-tagged `.inc` on the redirection path gets
> exported from that DLL, whether the app touches it or not. Any whose `.clw` was never compiled in (nothing
> included its `.inc`, so its `LINK` never fired) fails the build with a wall of:
> ```
> ADDMONTHS@F13CALENDARCLASSll is unresolved for export - data.exp:396,3
> ```
> Measured: re-tagging one class took it from 35 lines in a data DLL's `.EXP` to **0**. So give every shipped
> class its own category — one per template, classes shipped together sharing it. A category nobody registers
> is simply never auto-exported, and the class still links per-app exactly as before; there is no downside and
> nothing else to change. Only add the registration (step 3) when you actually want the class shared.
>
> Three corollaries, each of which cost real debugging time:
> - **The registry reads the `.inc` on the redirection path**, not your project's copy. Tell developers to
>   replace *that* one on upgrade, or the old tag keeps the old behaviour.
> - **A renamed or superseded class left on the redirection path still breaks a data DLL**, because the
>   registry finds it even though no template references it any more. `CalendarClass.inc`, superseded by
>   `MyCalendarClass`, sat there for three days and produced exactly the error above.
> - **There is more than one libsrc folder, and the registry reads them ALL while the compiler obeys
>   precedence.** `CLARION120.RED` searches `.` (the app folder), then `%ROOT%\libsrc\win`, and only then
>   `%ROOT%\Accessory\libsrc\win` — so a stale duplicate in an earlier folder *wins*, and updating the
>   right one fixes nothing. Worse, because the registry registers every copy it finds, a method whose
>   signature changed between the two copies ends up registered **twice**: the `.EXP` gets both spellings
>   (`BUILD@F10AZTECCLASSRsc` from the old `*CSTRING` prototype and `BUILD@F10AZTECCLASSsb` from the new
>   `STRING` one) while the compiler builds only the copy that won redirection — so roughly half the
>   methods of each affected class come out unresolved. If a class fails on *some* of its methods rather
>   than all of them, stop looking at the template and go hunting for a duplicate `.inc`. `installer\`
>   `Check-InstalledClasses.ps1` in this repo audits all of it in one command.

### CapeSoft route — only if the `cape0*.tpw` chain is registered
```
#AT(%DllExportList),WHERE(%ProgramExtension='DLL' AND %RootDLL=1 AND %MultiDLL=1 AND %MyThingDisable=0)
  #INSERT(%ExportClassesPR,'MyClass.Inc')
#ENDAT
#AT(%CustomGlobalDeclarations),WHERE(%MyThingDisable=0)
  #INSERT(%Defines,1,'LinkMode','DllMode',%MultiDLL,%RootDll)
#ENDAT
```
Same idea, its own registry: `%ExportClassesPR` (`cape02.tpw:394`) loops CapeSoft's parsed class list
(`%dClasses8Bx`/`%dMethods8Cx`) and emits `VMT$`/`TYPE$`/`LINKNAME(...)` just like ABC's does.

### Last resort — a hand-written export list
Only when nothing generates an `.EXP` (a hand-coded, non-AppGen multi-DLL build). Precedent for shipping one:
`accessory\libsrc\win\MO.EXP`. Format is `  SYMBOL<spaces>@?` under an `EXPORTS` line, `;` comments allowed.
To read the true names: **Clarion `.obj` files are OMF, not COFF** — walk records `type(1) len(2,LE) payload`
and pull `PUBDEF` (0x90/0x91). Names look like `ADDROW@F11EXPORTCLASS` and `CRC32@F11EXPORTCLASSRsbl` — method
name, `@F`, the length-prefixed class name, then param type codes — plus `VMT$`, `VMTP$`, `TYPE$`. Export the
methods + `VMT$` + `TYPE$`; **do not** export `TYPE$<someQueue>` for a `QUEUE,TYPE` in the same `.inc`, because
every module that includes the header defines those itself. A hand-written list goes stale the moment a
prototype changes, which is the whole reason to prefer the category route.

### Verifying any of this without the IDE
- **Template side, headlessly:** graft `[ADDITION] NAME <set> <template>` (+ `[INSTANCE] INSTANCE 1` +
  `[PROMPTS]`) into the **`[PROGRAM]`** section of a TXA, then `ClarionCL -win -au -ai app.app app.txa` and
  `-ag app.app`. The generated pragmas show up in the app's `[PROJECT]` section when you `-ax` it back out,
  and the `.EXP` is written to disk — read both. Flip `%GlobalExternal LONG (0/1)` and the `#link "x.DLL"`
  line to switch the app between owner and child.
- **Compile side:** a `.cwproj` pair — DLL = `<OutputType>Library</OutputType>` + `<Model>Dll</Model>` +
  `<DefineConstants>_myThingDllMode_=&gt;0%3b_myThingLinkMode_=&gt;1</DefineConstants>` + an `.EXP`; EXE = the
  reverse defines + `<ProjectReference>`. Model: `C:\clarion12\examples\IMDD\Multi_DLL\data.cwproj`.
  Prove the split really happened by checking the EXE does **not** contain the class's code.

**Working reference implementation:** `templates/myExport/` in this repo — `ExportClass.inc` (the tag, the two
mode arguments, the `_ExportClassPresent_` include guard) and `myExport.tpl` (the Multi-DLL tab and the
category registration), with the developer-facing explanation in `docs/myExport-template.html`. Everything in
this pattern was verified there: a generated ABC DLL app emitted the 73 export lines, the same app set to
*External → DLL* emitted none, and an EXE built with `DllMode=>1` imported the class from a DLL and ran.
Copy that shape rather than re-deriving it.

---

## P3 — Include the class header once

```
#AT(%AfterGlobalIncludes),WHERE(%MyToolDisable=0)
INCLUDE('MyTool.INC'),ONCE
INCLUDE('MyToolEx.INC'),ONCE
#ENDAT
```
`ONCE` is what makes it safe to drop the extension on many procedures without duplicate-symbol errors.

---

## P4 — Init / Kill lifecycle

```
#AT(%ProgramSetup),PRIORITY(5000),WHERE(%MyToolDisable=0)
%MyToolObject.Init()
  #IF(%MyConnString)
%MyToolObject.SetConnection(%MyConnString)
  #ENDIF
#ENDAT
#!
#AT(%ProgramEnd),WHERE(%MyToolDisable=0)
%MyToolObject.Kill()
#ENDAT
```
For a per-procedure extension use `%ProcedureInitialize` / `%ProcedureSetup` and the procedure's
WindowManager method embeds (`%WindowManagerMethodCodeSection,'Init','(),BYTE'`).

---

## P5 — Multi-instance controls/extensions

When `#CONTROL`/`#EXTENSION` is `MULTI`, every instance must produce uniquely named symbols. Append
`%ActiveTemplateInstance` (and the procedure/control) to generated labels:

```
ktSelectedTab%ActiveTemplateInstance_%Procedure_%ControlNameToUse   LONG
```
Manage the list of instances with a `#BUTTON('...'),MULTI(%list,%descExpr),INLINE` whose contained
prompts repeat per row. `%list` holds rows; iterate with `#FOR(%list)`.

---

## P6 — Reusable logic with `#GROUP` + `#INSERT`/`#CALL`/`#RETURN`

```
#GROUP(%StripQFromControl)
  #IF(SLICE(%Control,1,1)='?')
    #RETURN(SUB(%Control,2,LEN(CLIP(%Control))))
  #ELSE
    #RETURN(%Control)
  #ENDIF
...
#SET(%CtrlName,%StripQFromControl())          #! value-returning group used as a function
```
Groups can take parameters with defaults: `#GROUP(%ReadGlobal,%pa,%force)`. Use `#INSERT(%g,a,b)` to
emit its output at a point, `#CALL(%g,a,b)` for side-effects only.

---

## P7 — Conditional & looping generation

```
#IF(%MyLanguage='SPA')
Glo:InsertText = GETINI('BUTTONS','INSERT','Agregar','.\GLOBAL.INI')
#ELSIF(%MyLanguage='ENG')
Glo:InsertText = GETINI('BUTTONS','INSERT','Insert','.\GLOBAL.INI')
#ENDIF

#FOR(%Control),WHERE(%ControlType='LIST' OR %ControlType='DROP' OR %ControlType='COMBO')
%Control{PROP:LineHeight} = %GlobalInterLine
#ENDFOR
```
Detect whether a sibling template is present in the app:
```
#FOR(%ApplicationTemplate),WHERE(%ApplicationTemplate='AJE_StimulSoft(AJEStimulSoft)')
  #SET(%StimulSoftPresent,%True)
  #BREAK
#ENDFOR
```

---

## P8 — Add project files & libraries

```
#AT(%CustomGlobalDeclarations),WHERE(%MyToolDisable=0)
 #PROJECT('None(MyHelper.exe), CopyToOutputDirectory=Always')
 #PROJECT('None(icudtl.dat), CopyToOutputDirectory=Always')
  #IF(%SomeIcon)
 #PROJECT(%SomeIcon)
  #ENDIF
#ENDAT
```

---

## P9 — Expose custom embed points to the developer

Let users inject their own code inside your generated procedures/methods:
```
#EMBED(%MyToolBeforeSend,'Before Send'),TREE('MyTool|SendRequest|1-Before')
#EMBED(%MyToolAfterSend,'After Send'),TREE('MyTool|SendRequest|2-After')
```
Place these between your generated statements so developers can extend without editing the template.

---

## P10 — Safe (re)declaration

A group that may run for many instances should not re-`#DECLARE` the same symbol:
```
#IF(VAREXISTS(%MyState)=0)
  #DECLARE(%MyState)
#ENDIF
```
Use `#PREPARE` … `#ENDPREPARE` to do one-time setup when the procedure template loads, and
`#ATSTART`/`#ATEND` for parse-time init/cleanup that must bracket the whole generation.

---

## P11 — Reading classes / registering objects (ABC convention)

ABC templates call helper groups to read `.INC` class definitions and register instances in the embed
tree under a category:
```
#ATSTART
  #IF(%MyToolDisable=0)
    #INSERT(%ReadGlobal,2,0)
    #IF(%MultiDLL=0 OR %RootDLL=1)
      #INSERT(%AddObjectPR,%MyToolClass,%MyToolObject,'Global Objects')
    #ENDIF
  #ENDIF
#ENDAT
```
`#CONTEXT(%Application,%applicationTemplateInstance)` switches into the instance's scope before reading
its per-instance settings.

---

## Drawing graphics into a control, and redrawing on resize

Clarion has graphics primitives — `PIE`, `ELLIPSE`, `BOX`, `ROUNDBOX`, `ARC`, `CHORD`, `POLYGON`, `LINE`
(see `builtins.clw`) — plus `SETPENCOLOR`/`SETPENWIDTH`. `PIE(x,y,w,h, *SIGNED[] slices, *LONG[] colors,
depth=0, wholeValue=0, startAngle=0)` draws a whole pie from arrays of relative sizes + colors.

- **Target a control as the canvas — and you MUST pass the window.** The **two-argument** form
  `SETTARGET(<window>, ?imageControl)` aims primitives at an IMAGE control, with coordinates **relative to
  the control** (its top-left is `0,0`, so `PIE(0,0,w,h,…)` fills the image). The **one-argument** form
  **`SETTARGET(,?imageControl)` (window omitted) does NOT do this** — primitives then draw on the *window*
  at absolute coordinates, so `BOX(0,0,…)`/`PIE(0,0,…)` land at the **window's** top-left, not on the image.
  (Real bug — myPie GitHub issue #5: "MyPieDraw wrong to position Pie at (0,0), it needs to be at the Image
  X,Y".) Always supply the window:
    - In window/procedure-embed code the window is in scope — pass it: `SETTARGET(MyWindow, ?Image)`.
    - In a **standalone helper PROCEDURE** there is no implicit window. Give it a `WINDOW` parameter and pass
      it through: `MyPieDraw(WINDOW pWnd, SIGNED pImageFeq, …)` → `SETTARGET(pWnd, pImageFeq)`. You *can* use
      `System{PROP:Target}` for "the current window", but passing it is cleaner (and lets the same helper
      target a `REPORT, ?Band`).
    - **Fallback when you can't pass the window:** read the control's window position with
      `GETPOSITION(pImageFeq, ImgX, ImgY)` and draw window-relative at `BOX(ImgX,ImgY,…)` / `PIE(ImgX,ImgY,…)`.
  `SETTARGET()` with no args restores the previous target. (`svgraph.clw` draws into an image via the
  two-arg form.)
- **Image graphics PERSIST and accumulate** — they are NOT auto-cleared. Before redrawing, clear with
  **`BLANK`** (no args = wipe the whole current target's graphics; `svgraph.clw` calls `blank` at the top
  of every redraw). A filled `BOX` is NOT a real clear — it only paints over, so when the control shrinks
  the older/larger drawing survives underneath/around it and you get resize artifacts. Use `BLANK` first,
  then (optionally) a `BOX` to set a specific background color, then draw.
- **Register a self-contained `CASE EVENT()` at `TakeWindowEvent` with `PRIORITY(2000)`, NEVER 2500.**
  ABC's framework registers its OWN `LOOP`/`CASE EVENT()` scaffolding for `TakeWindowEvent` at
  **`PRIORITY(2500)`** (`ABWINDOW.TPW:563` — same embed, same `'(),BYTE'` signature). A template block that
  also sits at 2500 interleaves *inside* the framework's `CASE EVENT()` and the generated method comes out
  with a **duplicate `CASE EVENT() / CASE EVENT()`** (and a doubled `END`) — a hard compile error. Use 2000,
  which lands your self-contained handler **above** the framework's loop — the proven spot myQRDraw, myPixel
  and showLine use:
  ```
  #AT(%WindowManagerMethodCodeSection,'TakeWindowEvent','(),BYTE'),PRIORITY(2000),WHERE(%MyDisable=0)
    CASE EVENT()
    OF EVENT:OpenWindow
      …first draw…
    OF EVENT:Sized
      …redraw…
    END
  #ENDAT
  ```
  (The idiomatic per-event alternative is `#AT(%WindowEventHandling,'OpenWindow')`, but it only emits if that
  event is already in `%WindowEvent`, so the self-contained-CASE-at-2000 form is more reliable for
  "always draw on open/resize".)
- **Redraw after a resize via a POSTED event, not directly in `EVENT:Sized`.** At the top of
  `TakeWindowEvent` (PRIORITY 2000) the ABC resizer has NOT yet repositioned/resized the child controls,
  so the control's `PROP:Width/Height` is still the old size. Instead `POST` a private event
  (`EQUATE(EVENT:User+nnn)`) on `EVENT:Sized` (and on `EVENT:OpenWindow` for the first draw), and do the
  actual draw when that posted event is handled — by then the window has finished opening / resizing and
  the control reports its new size. Re-read `PROP:Width/Height` inside the draw so it fits the new size.
- **Background + inset niceties (from the myPie fix):** let `COLOR:None` mean "no background box" so the
  caller can keep the image's own backdrop — `IF pBackColor <> COLOR:None THEN SETPENCOLOR(pBackColor);
  BOX(x,y,w,h,pBackColor) END`. And inset the drawing a little so it isn't flush on the box edge:
  `Indt = pPieW * .02; x += Indt; y += Indt; w -= Indt*2; h -= Indt*2` before `PIE(x,y,w,h,…)`.

## Drawing on a REPORT (not a window) — needs a SEPARATE extension

The same draw helper does NOT just work when an extension is dropped on a report. A report procedure has
**two** structures — the print **progress WINDOW** and the **REPORT** — and the window-oriented wiring grabs
the wrong one. Build a dedicated report extension (corpus: `myQRDraw` ships `myQRDraw` for windows +
`myQRDrawReport` for reports; `blobsrv.tpw` for blob-in-report-control). Two gotchas, both of which make it
silently target the window or draw nothing:

- **A `#PROMPT(...,CONTROL)` lists WINDOW controls only.** On a report it offers the progress window's
  controls (and their USE variables), never the report's — the developer picks a control that isn't on the
  report. List the **report's** controls instead with a `FROM()` over `%ReportControl`, filtered by type:
  ```
  #PROMPT('&Image control:',FROM(%ReportControl,%ReportControlType = 'IMAGE')),%MyRptImage,REQ,DEFAULT('')
  ```
  `%ReportControl` yields the same `?`-prefixed field equate a window `CONTROL` prompt gives, so it drops
  straight into `GETPOSITION(%MyRptImage,…)`. Corpus: `blobsrv.tpw:20`
  (`FROM(%ReportControl, %ReportControlType = 'IMAGE' OR …)`).

- **Reports render bands through the print engine, not a window event loop** — there is no
  `EVENT:OpenWindow`/`Sized`/`TakeWindowEvent` for the printed content. Draw in the **print-loop** embed
  **`%BeforePrint`** ('Before Printing Detail Section') — it fires before each DETAIL band prints, so a
  graphic is produced **per record**. Make the **report** the graphics target with **`SETTARGET(%Report)`**
  (`%Report` is the report-label symbol; `SETTARGET` accepts a `REPORT` target + band feq —
  `builtins.clw:1791`), NOT `SETTARGET(,?image)`:
  ```
  #AT(%BeforePrint),WHERE(%MyDisable=0 AND %MyRptImage)
    IF QRBuildMatrix(loc:Value, %MyEcc)        #! encode this row's value
      SETTARGET(%Report)                       #! the report/band is the target
      QRPaint(%MyRptImage, …)                  #! GETPOSITION the band image + draw
      SETTARGET()
    END
  #ENDAT
  ```
  An extension may legitimately fill `%BeforePrint` (corpus: accessory `mytable.tpl:665`, "Blobs on Report -
  Before Print Detail"). No repaint ROUTINE — there is no event loop; the code re-encodes from the live
  field value every time the band prints. Band-draw **placement** is timing-sensitive and not statically
  verifiable — give the report extension a fixed self-test value and confirm by scanning a printout. If a
  single graphic per *page* (not per record) is wanted, target a page-header band / a different embed.

## Shipping a self-contained CLASS (.inc/.clw) from a template

When a template needs real logic (an encoder, a parser), put it in a **CLASS** in an external `.inc`
(declaration) + `.clw` (methods) rather than emitting dozens of free procedures into `%ProgramProcedures` —
the methods then compile in their own module and the program's global procedure area stays lean. Wiring that
actually compiles (corpus: CapeSoft `StringTheory`/`Reflection`, ABC `ABFILE`):

- **The `.clw` MUST have a module-level `MAP`/`END` — this is the non-obvious one.** The compiler folds the
  `BUILTINS.CLW` prototypes into the module's `MAP`; with **no `MAP`, there is nowhere for them to resolve**,
  so every prototyped runtime function (`LEN`, `BOX`, `SETTARGET`, `GETPOSITION`, `SETPENCOLOR`, `BLANK`,
  `CLIP`, …) fails with **"Unknown function/procedure label"** — while intrinsic keywords (`INT`, `ABS`,
  `BSHIFT`, `BAND`, `CHOOSE`) still compile, which makes the cause look mysterious. An **empty** `MAP`/`END`
  is enough (the builtins are added implicitly). Every shipped class `.clw` (StringTheory, ABFILE, ABERROR,
  ABWINDOW) carries one. Header:
  ```
    MEMBER
    MAP
    END
    INCLUDE('MyClass.INC'),ONCE
  ```
  Use bare `MEMBER` (no parens — the standard form for a class module added via LINK).
- **Give the class `Construct`/`Destruct` if it owns reference members** (`&Queue`, `&Class`, …) to
  `NEW`/`DISPOSE` them. A class of only simple/array members doesn't need them; `Construct` is still a handy
  place to do one-time setup (e.g. build lookup tables at instance startup).
- **Self-contained link:** declare the class `MyClass CLASS,TYPE,MODULE('MyClass.CLW'),LINK('MyClass.CLW')`.
  The `LINK` adds the `.clw` to the project automatically — no manual project edit. This is the simplest thing
  that works and is *correct* when the class holds no shared state: every target just links its own copy.
  Its cost is real though — in a multi-DLL suite **every DLL and the EXE carry a full copy of the code**, and
  there is no way for the developer to opt out. Add the two mode arguments
  (`LINK('MyClass.CLW',_myThingLinkMode_),DLL(_myThingDllMode_)`) and register a category as in **P2b** and
  one copy serves the suite, at no cost to single-EXE apps (undefined defines = linked in, as before).
  VIRTUAL methods are **fine** across a DLL boundary — verified — as long as `VMT$`/`TYPE$` are exported,
  which the category route does for you. (Keeping methods non-VIRTUAL only matters if you are hand-maintaining
  an export list and want to keep it short.)
- **The instance is GLOBAL DATA → make it multi-DLL aware** (else a multi-DLL build fails: procedures in other
  DLLs reference an instance that was never declared `EXTERNAL` there). Use ABC's built-in symbols, no extra
  prompts (corpus: `cleansdw.tpw`):
  ```
  #AT(%GlobalData),WHERE(%Disable=0)
    #IF(%DefaultExternal = 'None External')
  MyObj  MyClass                              #! single-EXE or root DLL: defined here
    #ELSE
  MyObj  MyClass,EXTERNAL,DLL(dll_mode)       #! other DLL/EXE: imported
    #ENDIF
  #ENDAT
  #AT(%DLLExportList),WHERE(%Disable=0)
    #IF(%DefaultExternal = 'None External' AND %ProgramExtension='DLL' AND %DefaultExport)
  $MyObj  @?                                  #! export the shared instance from the root DLL
    #ENDIF
  #ENDAT
  ```
  Include the header with `#AT(%AfterGlobalIncludes)` → `INCLUDE('MyClass.INC'),ONCE`.
- **Ship the `.inc`/`.clw` and tell the developer to copy them to a redirection-path folder** (app dir or
  `\clarion12\libsrc\win`). For Clarion 12 store them in **ANSI** (not UTF-8 — a BOM or multibyte char breaks
  the compiler; pure-ASCII content is safe either way).
- Reference: the `myQRDraw` set (`QRCodeClass.inc`/`.clw`).

## Gotchas checklist

- [ ] Every `#AT` honors the disable prompt via `WHERE()`.
- [ ] Globals are `EXTERNAL,DLL(dll_mode)` in the non-owning apps, and exported from the owner (P2). Prefer
      ABC's `%DefaultExternal = 'None External'` to author-declared `%MultiDLL`/`%RootDLL` prompts.
- [ ] Every shipped class `.inc` has its **own** `!ABCIncludeFile(CATEGORY)` — a bare tag makes any data DLL
      export the class whether it uses it or not, and unresolved-for-export errors follow (P2b).
- [ ] To *share* a class across a suite it also needs `LINK(...,_xLinkMode_),DLL(_xDllMode_)` and the category
      registered, which is `APPLICATION`-scope only (P2b).
- [ ] `INCLUDE(...),ONCE` on every class header.
- [ ] Output-line indentation matches required Clarion columns (labels col 1).
- [ ] Multi-instance symbols carry `%ActiveTemplateInstance`.
- [ ] `PRIORITY()` set where multiple `#AT`s share an embed point.
- [ ] `<39>` (not a bare `'`) for quotes inside string attributes/defaults.
- [ ] `#GROUP` definitions placed AFTER all `#AT`/`#EMBED` blocks (a `#GROUP` has no end-marker and
      swallows following lines until the next section directive — an `#AT` after a `#GROUP` errors
      "#AT not valid in a #GROUP"). Put groups at the end; calls resolve by forward reference.
- [ ] Per-iteration values in per-procedure `#AT` output (e.g. an INI key from `%Procedure`+`%Control`)
      built by **direct symbol substitution** in the output line: `'%Procedure' & '_' & '%Control'`
      (each `%Sym` substitutes inside the quotes at gen time; `&` concatenates the literals at runtime).
      Two traps that both yield a BLANK/wrong value here:
        • an extension-level `#DECLARE`'d symbol + `#SET` → "GEN: Unknown Variable '%sym'" (the symbol is
          not in scope during per-procedure generation);
        • a `#GROUP` that reads *ambient* `%Control`/`%Procedure` called inline as `%(%MakeKey())` →
          returns EMPTY, because an inline group call does NOT inherit the caller's `#FOR` context.
      If you must use a group, PASS the values as parameters (corpus idiom: `%(%StripPling(%BrowseFile))`),
      don't rely on ambient context.
- [ ] Literal `%` in emitted lines (modulus `x % 7`, etc.) escaped as `%%` — otherwise the template
      won't register (`Expected an identifier`). Avoid `%` in comments (write "MOD"). Watch for bare `%`
      in trailing parentheticals. Corpus: `ABUPDATE.TPW:866` (`SELF.RecordsProcessed %% %RecordsToCheckpoint`).
- [ ] On a **REPORT**, use a SEPARATE extension: pick controls with `FROM(%ReportControl,…)` (a `,CONTROL`
      prompt lists WINDOW controls only), and draw in the `%BeforePrint` embed via `SETTARGET(%Report)` —
      reports have no window event loop. See "Drawing on a REPORT".
- [ ] Block terminators balanced (`#ENDAT`, `#ENDIF`/`#END`, `#ENDFOR`, `#ENDTAB`, `#ENDSHEET`, …).
- [ ] `.tpl` `#INCLUDE`s all its `.tpw` parts; `#TEMPLATE` header present and at column 1.
- [ ] Legacy-chain targets declare `FAMILY('CW20')` — never `FAMILY('Clarion')`, which attaches to
      nothing (`Clarion` is the chain's NAME; `CW.TPL` declares no family). See `legacy-cw20.md`.
- [ ] Generated code referencing a `CONTROLS`-block control is `#IF(%symbol)`-guarded — the block is a
      placement-time stamp, and instances placed before the block changed keep their old controls (P15).
- [ ] Default parameter values (`=0`, `=1`) appear ONLY in the **prototype** (the MAP / `.inc`),
      never in a free-standing procedure's **implementation** header. Write the body as
      `weekNumber PROCEDURE(LONG pDate)` even though the prototype is `weekNumber PROCEDURE(LONG pDate=0),LONG`.
      (CLASS *methods* are the exception — their impl mirrors the CLASS prototype and keeps the default.)
      Getting this wrong yields "No matching prototype available", "Unknown identifier: <param>", and
      "Cannot RETURN value from procedure" all at once.
- [ ] Property writes aimed at another window are wrapped in `SETTARGET()` or deferred until that window
      is current again — a field equate resolves against the CURRENT window and writes to the wrong one
      silently (P15).
- [ ] ROUTINE recursion is BOUNDED by a strict pass marker AND the inner `DO` is the routine's last
      statement (P15) — unbounded recursion is a stack-overflow death; bounded mutual recursion is
      shipped and fine (BGL:Fill ⇄ BGL:Bottom).
- [ ] `PROP:LineHeight` divided by the lines per record, in EVERY copy of the calculation (P15).
- [ ] Queue fields that a `FROM(queue)` LIST displays are declared FIRST, in display order (P15).
- [ ] `POPUP()` item numbers account for separators (P15).
- [ ] Verified by a GENERATE with every optional prompt switched on, and by RUNNING the result — not by
      registering, and not by compiling (P15).


## P15 — Code that compiles cleanly and does the wrong thing

Every fault below produced Clarion that **registered, generated and built without a single error**, and
then misbehaved at run time or could not be used at all. A clean compile proves nothing about any of
them, which is the point of collecting them: these are the ones a build will never catch.

### Run time

**A field equate belongs to whichever window is CURRENT.** `?Ctl{PROP:Whatever} = x` is applied to the
window that is current *at that moment*, not to the window `?Ctl` was declared on. Open a second window
(a dialog, a lookup) and every property write aimed at the first one silently lands on the second. It is
a legal write; nothing complains and nothing changes.
*Symptom:* a dialog's OK button appears to do nothing at all.
*Fix:* decide inside the dialog, apply after `CLOSE(dialog)` — or wrap the writes in
`SETTARGET(theOtherWindow)` … `SETTARGET()`.

**UNBOUNDED ROUTINE recursion kills the process — but BOUNDED mutual recursion works.** The old rule
here ("a ROUTINE holds a single return address, so a `DO` of itself dies") is disproven by shipped
code: `BrowseGridLeg` (the Legacy BrowseGrid port in the ClarionLive fork) has `BGL:Fill` ending with
`DO BGL:Bottom`, which may `DO BGL:Fill` again — mutual
ROUTINE recursion, depth 3 — and it runs correctly (Clarion 6 Legacy chain, user-tested repeatedly,
plus an adversarial review pass specifically on the recursion). Return addresses evidently stack.
What actually dies is recursion with **no terminating guard** — a stack overflow, and the app
"opens and closes again immediately".
*The two safety rules that make bounded recursion sound:* (1) a **strict pass marker** that can only
step forward (BGL uses `BtmFix` stepping 0→1→2→0, so no measurement outcome can loop it); (2) the
inner `DO` is the routine's **last statement**, so it does not matter whether routine-local DATA is
per-entry or static — the locals the inner call may clobber are already dead.
*Simpler alternative when it fits:* a `LOOP pass = 1 TO 2` with `CYCLE` avoids the question entirely.

**`PROP:LineHeight` is the height of one LINE, not one record.** On a multi-line list format the runtime
multiplies it by the lines in a record. Hand it a whole record height and the list concludes each record
is *lines²* tall.
*Symptom:* a browse loads one record, or a handful, and the rest "disappear".
*Fix:* divide by the lines per record — **everywhere**, including any second copy of the calculation.
(This one shipped twice: `BG:Rows` was corrected and the font-resize path had its own copy that was not.)

**A `FROM(queue)` LIST maps format columns to queue fields in DECLARATION order.** There is no naming of
one to the other. Declare a queue as `Mark, On, Name` and the second display column shows `On`.
*Symptom:* a column shows `1` (or a stray number) where a name was expected.
*Fix:* declare the displayed fields first, in display order.

**A LIST raises `ACCEPTED` only on a double click or Enter.** A single click raises
`EVENT:NewSelection`, which is not the same thing.
*Symptom:* a tick-list dialog looks completely inert.
*Fix:* `ALRT(SpaceKey)` on the list plus an `EVENT:AlertKey` handler, and buttons for the same actions.

**`POPUP()` counts its separators as items.** A `'-'` occupies an ordinal.
*Symptom:* every choice after the first separator runs the wrong branch — and the branches that fall off
the end do nothing, so half the menu is silently dead.
*Fix:* no separators, or count them.

**Reading a field you only know by name.** `WHO(queue, n)` returns an ABC browse queue's field *label*,
which is the file field it came from (`STU:LastName`) — enough to build a filter expression from outside
the browse template. `EVALUATE('STU:LastName')` then reads its current value, because ABC binds the whole
record buffer (`FileManager.BindFields`). Between them you can filter and collect distinct values without
the developer mapping anything by hand.

**A ROUTINE's `CODE` needs a `DATA` section before it.** A bare `CODE` with no `DATA` inside a ROUTINE
is a compile error — either declare locals under `DATA` or omit both keywords entirely.
*Symptom:* an error on the `CODE` line of a routine that looks structurally fine.

**An ALERTED key carries no character — `KEYCHAR()` returns 0 for it.** On an `IMM` LIST, printable
keystrokes already arrive as `EVENT:AlertKey` natively, no `PROP:Alrt` needed; alerting more keys gets
you events without characters. That is why ABC's IncrementalLocator alerts only `BSKey` and `SpaceKey`
(the two the LIST would otherwise consume) and special-cases space with
`CHOOSE(KEYCODE()=SpaceKey,' ',CHR(KEYCHAR()))`. Copy that recipe for type-to-search.
*Symptom:* typed letters reach the handler but every one reads back as nothing.

**A REGION cannot take the focus.** `SELECT()` on it is a no-op and `PROP:Alrt` on it never fires,
because alerts need the focus. Keep the focus on a real control (the LIST) and intercept *its* events;
the region still gets mouse events through `PROP:IMM`.
*Symptom:* a region-based control with no keyboard at all.

**Runtime `{PROP:Use} = var` rebinding is unreliable.** It can fix focus-time redisplay while
`DISPLAY(control)` through it does nothing. Write `{PROP:ScreenText}` directly for anything that must
actually appear on screen now.

**Queue `SORT` — the help is wrong two ways** (verified by test program). The string form
`SORT(q,'+Field1,-Field2')` accepts queue field **labels** and matches them **case-blind**, contrary to
the documentation; and the comparison-function form `SORT(q, MyCompareFunc)` is a **silent no-op** — it
returns without sorting and without error. For a case-insensitive sort, decorate–sort–undecorate: copy
an UPPER'd key into a spare field, string-SORT on it, restore.
*Symptom:* a "custom" sort that leaves the queue untouched, or mixed-case rows ordered ASCII-ly.

**Overlapping sibling controls fight.** A button placed "inside" an ENTRY loses clicks to it and is
repainted over on every keystroke. Fix: `WS_CLIPSIBLINGS` on the entry plus
`SetWindowPos(button, HWND_TOP, ...)` — the standard pair for any control drawn over another.

**Clarion COLOR longs are `00BBGGRR`.** Anything expecting RGB (Direct2D, HTML, most APIs) needs the
ends swapped — and negative values are system-colour *indices* (`COLOR:BTNFACE`), which cannot be
byte-swapped; resolve them first.

### Generate time and AppGen

**`#PREPARE` runs when the prompts are LOADED, not when code is generated.** A `#SET` there never reaches
the emitted source.
*Symptom:* an emitted line comes out with a blank where a derived symbol should be —
`Grid1:Lst = .ILC.GetControl()`.
*Fix:* substitute the expression directly into the emitted line, or `#SET` inside the `#AT`.

**A `#CONTROL` with no `CONTROLS` block registers perfectly and can never be added.** Control templates
are added by *placing* something from the window designer; with nothing to place there is nothing to
pick up.
*Corollary:* if a template must not put a control on the window, it has to be an `#EXTENSION`. An
extension cannot nest under a control template in the Extensions tree, so "add it on top of the browse"
and "place nothing" are mutually exclusive. Pick which one matters.

**A blank line inside a prompt sheet is a syntax error.** `#SHEET`/`#TAB`/`#BOXED` accept directives
only; an empty line is an output line. The same goes for a bare `!` comment — `!` is only legal inside
`#AT` generated-code blocks; everywhere else in a template use `#!`. One stray `!` in a prompt sheet
cascades into a screenful of "Expected ENDSHEET/ENDTAB/ENDBOXED" errors pointing at the wrong lines.
*Symptom:* `Expected ENDSHEET` pointing at a line that looks fine.

**A `CONTROLS` block is a STAMP applied at placement time.** Re-registering the template updates the
stamp, not the instances already sitting on windows — they keep the controls they were born with. So
any generated code that references a control added to the block later must be wrapped in
`#IF(%symbol)`, or a stale placement generates `IF FIELD() =  AND ...` (the symbol substitutes empty).
*Symptom:* apps that placed the template before the change won't generate; fresh placements are fine.

**Prompt `AT(x,y)` is absolute within the enclosing TAB** (not the BOXED/OPTION it sits in), and
positioning is all-or-nothing — one positioned prompt means everything after it needs positioning too.
Omit `y` to keep the flow; `AT(,,,h)` sets height only; `AT(10)` (x-indent only) is always safe —
which is why the corpus sprinkles exactly that form on CHECK prompts.

**Control-template embeds are not `#AT`-able from other templates.** An embed declared inside a
`#CONTROL` is reachable only by that template; another template's `#AT(%ThatEmbed)` gets
"Unknown Variable" at generation. Only the procedure/program-level embeds (Window.TPW / STANDARD.TPW /
Program.TPW, or their ABC equivalents) are public targets.

**A control template finds its own placed controls with
`#FOR(%Control),WHERE(%ControlInstance = %ActiveTemplateInstance)`** — and distinguishes several of its
own by `%ControlType`. Without the WHERE it iterates every control on the window.

**Unregistering a template makes Clarion drop EVERY addition belonging to it** from any app that is
opened afterwards. That is the way out of an orphaned instance the IDE will not delete — but it takes the
global extension with it, so re-add that first.
```
ClarionCL -tl                       # list registered chains
ClarionCL -tu <ChainName>           # unregister BY CHAIN NAME, not by path
ClarionCL -tr <full path to .tpl>   # register
```
Deleting a registered `.tpl` without unregistering it breaks **all** registration afterwards with
`Could not open include file <name>.tpl`.

### Verifying, so these get caught

Registering only parses. **A generate is what proves the emitted Clarion is Clarion — and a generate only
covers the paths whose prompts are switched ON.** A template with six optional features verified at their
defaults has five paths nobody has ever generated. Switch them all on with a TXA round trip:

```
ClarionCL -win -au -ax app.app out.txa      # export
   ...edit the %prompt values in out.txa...
ClarionCL -win -au -ai app.app out.txa      # import
ClarionCL -win -au -ag app.app              # generate
```

And **run the executable**. Building is not running: a ROUTINE that calls itself, a write to the wrong
window and a list that ignores clicks all compile perfectly. Starting the program takes four seconds.

For anything with no visible output, make the program report into its own **window title** and read it
back from PowerShell — the pattern used throughout `examples/BrowseGrid`. A one-line title
(`q=4 cols=0 draw=4 items=4`) distinguishes "the queue was empty" from "the columns were never read"
from "the rows were too tall", which look identical on screen and want completely different fixes.

## Adding a global, callable utility function via template

The make-or-break rule: a module that **defines** a free procedure must see a **BARE** prototype for it
(no `MODULE()` wrapper) — that's what marks it "defined in THIS module" so the body matches. Other
modules (and the global map) must see it **wrapped** in `MODULE('thatfile.clw')` so the linker knows
where it lives. Proof: `wbstd.CLW`/`ICSTD.CLW` prototype their own procedures bare in their own MAP;
`MODULE('Windows')`/`MODULE('SCHOOLnnn.CLW')` wrappers are used only for *external* procedures. Putting a
`MODULE('self.clw')` wrapper in the defining module's own MAP yields "No matching prototype available",
"Unknown identifier: <param>", and "Cannot RETURN value" all at once.

**Best approach (self-contained, no external files, EXE targets):** define the function IN the program
module and prototype it BARE in the global map — same module, so the bare prototype matches the body.
This is the structure of the simplest single-file Clarion program and avoids all multi-module traps.
```
#AT(%GlobalMap),WHERE(...)                       #! prototype, bare = "in the program module"
Func                 PROCEDURE(LONG p=0),LONG
#ENDAT
#AT(%ProgramProcedures),WHERE(...)               #! body, in the program module (EXE targets)
Func  PROCEDURE(LONG p=0)
loc:x  LONG
  CODE
  RETURN loc:x
#ENDAT
```
The default in the prototype makes the parameter omittable at the call site (`Func()`). Note: the only
corpus examples of a procedure with a default param (ABC class methods, e.g. ABBROWSE.CLW:2265) keep the
`=0` in BOTH the prototype and the body header — mirror that (`=0` in both) for an exact match.
`%ProgramProcedures` is EXE-only; for multi-DLL, emit the body into the shared/root target and export it.

**Critical MAP-indentation gotcha:** `%GlobalMap` (and any embed inside a structure) auto-indents your
emitted lines. A **long-form** prototype `Func PROCEDURE(...)` needs its label in **column 1**, so the
auto-indent breaks it with bogus errors ("Redefining system intrinsic: LONG", "Illegal return type",
"Indistinguishable new prototype"). Use the **short prototype form** in a MAP embed — `Func(params),return`
(no `PROCEDURE` keyword, no label) — which has no column-1 requirement and survives indentation. This is
exactly what `ICSTD.CLW`'s MAP (`GetHexValue(BYTE),BYTE`, indented) and `anytext.tpl`'s `%GlobalMap`
(`AnyTextFreeCache()`) do. The body in `%ProgramProcedures` is a DATA region and is NOT auto-indented, so
write it long-form at column 1 as normal. Short-form proto and long-form body match fine.

**Alternative (separate shipped module):** if you must keep bodies in a hand-maintained `.clw`, the
defining module must see a BARE prototype (its own `MAP` `INCLUDE`s a bare `.inc`), and the global map
must reference it WRAPPED in `MODULE('myFuncs.clw')`, plus `#PROJECT('myFuncs.clw')` to compile it. This
works but is fiddly (MEMBER()/MODULE() matching) — prefer the program-module approach above unless you
have a reason not to.

## P12 — Calling a Windows / external DLL API (e.g. shelling a command hidden)

To call a DLL export (kernel32, urlmon, user32, …) the prototype goes in a `MODULE('dll')` block. Three rules,
each learned from a compile failure:

1. **The `MODULE('dll')` block MUST be in the GLOBAL map.** A local (procedure) `MAP` — e.g. one you emit
   inside a helper body in `%ProgramProcedures` — does NOT accept a `MODULE()` external declaration; the
   compiler reads the prototype's parameter types as attributes (`Unknown attribute: LONG`, `Unknown
   attribute: CSTRING`, `Expected: <ID> … END INCLUDE OMIT …`). Emit it via `#AT(%GlobalMap)`.
2. **Type-only parameters, one line each.** Names break it (`Unknown attribute: <name>`); so do over-long
   lines. The most portable mapping is **all `LONG`**, passing pointers as `ADDRESS(x)` at the call (no
   `*type`, no `RAW`).
3. **Unique label + `NAME()` to dodge runtime clashes.** The ABC runtime already prototypes common APIs
   (`CloseHandle`, `WaitForSingleObject`, …). Prefix yours and bind via `NAME()`.

```
#AT(%GlobalMap),WHERE(%MyDisable=0)
  MODULE('kernel32')
my_CreateProcess(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
my_WaitObject(LONG,ULONG),LONG,PASCAL,NAME('WaitForSingleObject')
my_CloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
  END
#ENDAT
```
Call site (string + GROUPs passed by `ADDRESS()`): `my_CreateProcess(0, ADDRESS(loc:Cmd), 0,0,0, CREATE_NO_WINDOW, 0,0, ADDRESS(si), ADDRESS(pi))`.
**Simplest of all if a console flash is acceptable:** skip the API entirely and use built-in `RUN('cmd …', 1)`
(`1` = wait) — no prototypes, no structs, always compiles. Good fallback to offer in a comment.
Reference: this is the `myQR` template (curl download, hidden+synchronous via `CreateProcessA`).

## P13 — Emitting a developer-entered value (literal vs variable/expression)

When a prompt value is dropped straight into generated code (`x = %MyValue`), a plain literal is a trap: the
user types `https://a.com/b` and you emit `x = https://a.com/b`, where Clarion parses the `.`/`/` as
field-access/operators → `Unknown identifier: …`, `Field not found: …`. Don't rely on the user adding quotes.

Give an explicit mode with a `CHECK`, default to literal so the obvious case just works:
```
#PROMPT('&Value:',@s255),%MyValue,DEFAULT('https://example.com')
#PROMPT('Value is a varia&ble / expression (untick = literal text)',CHECK),%MyValueIsVar,DEFAULT(0)
…
#IF(%MyValueIsVar)
  loc:V = %MyValue                #! a variable/expression — emitted verbatim, read live
#ELSE
  loc:V = '%MyValue'              #! a literal — auto-quoted
#ENDIF
```
Caveat to document: a literal containing a `'` needs it doubled (`''`) or use variable mode — the template
can't safely escape arbitrary embedded quotes at generate time.

## P14 — Porting a numeric algorithm to runtime Clarion (the integer-math traps)

When you emit a non-trivial computation in Clarion (a hash, a CRC, an encoder — e.g. the `myQRDraw`
template's QR encoder ported from a C# reference), four language differences bite. Get them wrong and the
output is silently wrong, not a compile error.

1. **Clarion ROUNDS on assignment to an integer; it does not truncate.** `n = 7/2` gives **4**, not 3.
   Every place the source language did integer/floor division, wrap it: `n = INT(7/2)`. This includes
   right-shift-by-division, `bit/8`, `r/2`, percentage math — anywhere a fractional result is assigned to a
   LONG/BYTE.

2. **Modulus: avoid the literal `%`.** Clarion *has* a `%` modulus operator, but in a template every emitted
   `%` must be escaped `%%` (the parser reads `%` as a symbol start — unescaped, the template won't even
   register). Sidestep the whole trap with a one-line helper and call it everywhere:
   ```
   QRMod  PROCEDURE(LONG a,LONG b)        #! a MOD b, no '%' in the emitted source
     CODE
     RETURN a - INT(a/b)*b
   ```
   Now no emitted line contains `%`, so there is nothing to escape and nothing to forget.

3. **Bit operations are functions, not operators.** There is no `<<`, `>>`, `&`, `|`, `^`. Use
   `BSHIFT(v,n)` (n **positive = left**, **negative = right**), `BAND`, `BOR`, `BXOR`. They nest:
   `(x>>9)&1` → `BAND(BSHIFT(x,-9),1)`. Hex literals must start with a digit and end in `h`: `0x11D` →
   `011Dh`, `0xEC` → `0ECh`.

4. **0-based algorithm vs 1-based Clarion arrays.** Clarion `DIM(n)` is indexed `1..n`. Keep the
   algorithm's coordinates 0-based (so every modulus/shift formula is copied verbatim from the source) and
   isolate the offset in tiny accessors — `QRGetM(r,c) → RETURN QR:Mod[r+1,c+1]` / `QRSet(r,c,v)`. Mixing
   the two conventions inline is the #1 source of off-by-one corruption.

Verifying a port you **cannot run** (you can't drive AppGen): anchor it to a runnable oracle.
- Keep the reference implementation in a tested project (here, `designer/QrCodeCore` validated by ZXing).
- **Pin a golden vector** — the exact expected output for one fixed input — as an automated test.
- Build a **self-test option** into the template that produces that same fixed output, so the developer can
  *observe* correctness end-to-end (for myQRDraw: a "draw HELLO WORLD" toggle whose 21×21 symbol equals the
  golden matrix — scanning it confirms the whole pipeline on the target machine).

Also: a short-form `%GlobalMap` prototype carries the return type (`QRGfMul(LONG,LONG),LONG`); the matching
body **omits** it (`QRGfMul PROCEDURE(LONG a,LONG b)`) — confirmed against `libsrc\win\SystemString.clw`.

Reference: the `myQRDraw` template (offline QR encoder + `BOX` drawing; companion to the online `myQR`).
