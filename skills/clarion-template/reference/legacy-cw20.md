# The Legacy (CW20) Chain — Porting From and Writing For It

Everything here was verified against `<CLARION_ROOT>\template\win` (Legacy chain root `CW.TPL`; browse
control in `CtlBrow.TPW`; procedure template `Window.TPW`; program `Program.TPW`), against generated
Legacy source, and by shipping `BrowseGridLeg.tpl` — a full port of an ABC control template
(`templates/BrowseGridLeg/` in this repo) to the Legacy chain. Copy that template's shapes rather than
re-deriving them.

## Attaching to the chain

The Legacy chain's `#TEMPLATE(Clarion,'Clarion Release Templates')` header carries **no `FAMILY`
attribute** — `Clarion` is the chain's *name*. The family string an add-on template uses to attach to
Legacy apps is **`CW20`**:

```
#TEMPLATE(MyLegacyTool,'My tool for the Legacy chain'),FAMILY('CW20')
#TEMPLATE(MyDualTool,'Works on both chains'),FAMILY('ABC','CW20')     #! rtarpdf.tpl does this
```

`FAMILY('Clarion')` looks plausible and attaches to nothing.

## Embed-point mapping (ABC → Legacy)

**Identical in both chains — port with zero changes** (Legacy in `Program.TPW`/`Window.TPW`, ABC in
`ABPROGRM.TPW`/`ABWINDOW.TPW`): `%AfterGlobalIncludes`, `%GlobalData`, `%GlobalMap`,
`%ProgramProcedures`, `%DataSection`, `%ProcedureRoutines`.

**ABC's `%WindowManagerMethodCodeSection` has no Legacy equivalent** — remap each method:

| ABC method (`%WindowManagerMethodCodeSection,'X'`) | Legacy embed |
|---|---|
| `Init` | `%AfterWindowOpening` |
| `Reset` | `%RefreshWindowBeforeDisplay` |
| `TakeNewSelection` | `%ControlEventHandling` (the LIST, `EVENT:NewSelection`) |
| `TakeWindowEvent` | `%WindowEventHandling` |
| `TakeFieldEvent` | `%ControlEventHandling` |
| `Kill` | `%BeforeWindowClosing` |

**`%WindowEventHandling` is parameterised by event NAME, and the name list is closed.** It cannot carry
a custom event (`EVENT:User+n`) — there is no name to give it. For self-posted events, use
**`%EventCaseBeforeGenerated`**: it lands inside `CASE EVENT()` *ahead of* the generated `OF` clauses,
so an `OF MyCustomEvent` there is reached first and can `CYCLE` past the generated handling:

```
#AT(%EventCaseBeforeGenerated),WHERE(%MyDisable=0 AND %MyList)
    OF MyTool:Resized:%ActiveTemplateInstance
      ...handle it...
#ENDAT
```

Structural bonus found while porting: a Legacy browse's instance-scoped `%AfterControlRefresh` is
generated *inside* the procedure-level `%RefreshWindowAfterLookup`, so an extension can hook the
procedure-level embed and skip instance matching entirely.

## The porting gaps (things ABC has that Legacy simply lacks)

1. **No `INIMgr`.** ABC's `INIMgr.Fetch/Update` (layout memory etc.) has no Legacy counterpart — emit
   plain `GETINI`/`PUTINI` with a key you build from `%Procedure`/`%Control`.
2. **No browse object.** There is no `%bgBrowseObj`-style class instance to call methods on. Legacy
   browse machinery is ROUTINEs prefixed `BRW1::` (the prefix comes from the template instance number),
   so an ABC template's object-prompt can be reused but must emit routine calls (`DO BRW1::FillRecord`)
   per family.
3. **Header-click sorting: `SortOrder` is a dead end; use `PROP:Order` on the VIEW.** A Legacy browse
   recomputes `BRW1::SortOrder` from `CHOICE(?CurrentTab)` in `SelectSort` on every refresh, and only
   design-time orders exist. Verified working recipe:
   - Set `PROP:Order` on the view — it overrides `SET(key)` (tested set-while-closed and
     set-while-open-then-`SET(view)`).
   - Apply it **AFTER** `BRW1::Reset` — Reset does CLOSE/SET(key)/OPEN and `CLOSE(view)` discards
     `PROP:Order`.
   - Refill with `BRW1::FillRecord`, **not** `RefreshPage` — RefreshPage calls Reset again on an empty
     queue and undoes the order.
   - `Reset` only restores the default order when `UsingAdditionalSortOrder` is true; leave the flag
     alone and the custom order stands.
   - Get the field name from `WHO(queue,fld)` → `BRW1::CUS:NAME`, strip the prefix. Note the design-time
     order for a string key is `+UPPER(CUS:Name)` — a bare `+CUS:NAME` sorts case-SENSITIVELY and
     differs from the tab's own order.
   - Anything that drives the browse through `Reset` (a resize sets `ForceRefresh`) drops the order —
     re-assert by comparing live `PROP:Order` against the imposed string.
4. **Keyboard interception differs by mode.** In a Legacy browse the LIST keeps the focus; a template
   that owns its own paging must intercept the browse's scroll EVENTS (`EVENT:ScrollUp/Down`,
   `PageUp/Down`, `ScrollTop/Bottom`, `ScrollDrag`) in the ACCEPT loop and `CYCLE` them away, not alert
   keycodes (see the alerted-keys-carry-no-KEYCHAR gotcha in patterns.md P15).

## What transfers unchanged

Page size comes from `?List{PROP:Items}` in both chains (Legacy: `BRW1::ItemsToFill =
?Browse:1{PROP:Items}`), and `PROP:LineHeight` is settable — so line-height arithmetic that makes the
browse load more/fewer rows transfers directly (divide by lines-per-record everywhere, per P15). Queue
access is generic (`RECORDS`/`GET`/`WHAT`/`WHO`/`CHOICE`/`PROPLIST`), and the Legacy browse queue is
even named `Queue:Browse:1`.

## Reference implementation

`templates/BrowseGridLeg/` in this repo: a `#CONTROL`-free extension suite (grid takeover, search box,
filter bar) targeting `FAMILY('CW20')`, with file-loaded and page-loaded modes split by
`#IF(%bglLoad = 'File loaded')` throughout — a worked example of every remapping above, including
`%EventCaseBeforeGenerated` custom events, `PROP:Order` sorting, GETINI/PUTINI persistence, and
bounded mutual ROUTINE recursion (`BGL:Fill` ⇄ `BGL:Bottom`).
