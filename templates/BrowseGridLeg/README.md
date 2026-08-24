# BrowseGridLeg — BrowseGrid for the Legacy (CW20) template chain

A port of [BrowseGrid](../BrowseGrid) to the Clarion **Legacy** template family.
The browse engine underneath is untouched — file access, sort orders, range
limits, locators and the update round-trip all remain the generated Legacy
browse's own — while the LIST is concealed and a Direct2D grid draws in its
place.

Beyond the port, this version adds features the ABC original does not have:

- **File-loaded mode** — the whole view read into the queue once (5,000 SQLite
  records in ~10ms), giving an exact scrollbar thumb, instant in-memory sorts,
  and live thumb-drag scrolling
- **Live search box** (`BrowseGridLegSearch`) — browser-style narrowing with
  type-to-search from the list, case-blind, with a clear button and a placed
  "Locate" prompt
- **Criteria filter bar** (`BrowseGridLegFilter`) — a full-width, self-describing
  filter button driven by [myFilter](../myFilter)'s `MyFilterClass` (used
  unchanged — it is pure Clarion): build conditions per field, save filters by
  name, apply them from the button's menu. The filter is applied through
  `PROP:Filter` on the view, so it can filter on joined files' fields
- **Excel-style value menus** on the headings (funnel button) for
  low-cardinality columns
- **Case-blind header-click sorting** (decorate–sort–undecorate; the queue
  `SORT` string form is case-sensitive and the comparison-function form is a
  silent no-op — see the comments in `BGL:SortQ`)
- **Column management** — drag-resize with splitter cursor, right-click column
  chooser, and drag-to-reorder with a ghost heading chip and an insertion
  marker; widths, visibility and order all remembered per user in an INI
- **Double-click opens the Change form**, routed through the browse's own
  `AlertKey` machinery
- **Word wrap with variable-height rows** — long cells wrap onto extra lines
  (DirectWrite's own wrapping, up to a per-cell line allowance), and with
  "grow rows only as needed" each row is measured (`CreateTextLayout` +
  `GetMetrics`) and takes only the lines its own text needs; paging works from
  a conservative page size while fills push the measured optimum, and the last
  screen bottom-anchors at the final record the way a stock browse does
  (file-loaded only)

## Files

| File | What it is |
|---|---|
| `BrowseGridLeg.tpl` | The template set: global extension, procedure extension, search box and filter bar control templates |
| `d2grid.c` | The Direct2D grid, extended from the original with `d2g_FilterBtns` / `d2g_FilterOn` / `d2g_HitBtn` wiring and a `d2g_Carry` drag-reorder overlay (ghost chip + insertion line) |

The filter bar also needs `MyFilterClass.inc` / `MyFilterClass.clw` from
[templates/myFilter](../myFilter) on the redirection path (with the INI-key fix
— filter names containing `=` broke saved-filter round-trips through the
profile API).

Tested against Clarion 12, TopSpeed and SQLite drivers, browses of 5,000 and
10,000 records. The SQLite conversion notes (padded CHAR storage and the
optimistic-concurrency WHERE clause, POSITION drift after a Change, error 37
from CLOSE on a never-opened view) live as comments at the relevant spots in
the template.
