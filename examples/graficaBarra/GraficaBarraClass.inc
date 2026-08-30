!ABCIncludeFile
! ============================================================================
!  GraficaBarraClass - charts for Clarion, drawn with native graphics
!  primitives (BOX / LINE / POLYGON / ELLIPSE / PIE / SHOW). Works on WINDOWs
!  (into an IMAGE control) and on REPORTs (drawn straight into the band as
!  vector primitives, so PDF export stays as small as possible - no bitmap
!  involved). Pure Clarion - no external dependencies.
!
!  THIRTEEN CHART TYPES, one property:  Obj.ChartType = Chart:Pie
!    Chart:Column       vertical bars (the default - v1 behaviour)
!    Chart:Bar          horizontal bars
!    Chart:StackedCol   stacked vertical bars
!    Chart:StackedBar   stacked horizontal bars
!    Chart:Stacked100   100% stacked vertical bars
!    Chart:Line         line, optional markers
!    Chart:Area         filled area under the line
!    Chart:StackedArea  areas stacked on top of each other
!    Chart:Scatter      markers only
!    Chart:Pie          pie
!    Chart:Pie3D        pie with a three-dimensional edge
!    Chart:Donut        pie with a hole (optional text in the middle)
!    Chart:Radar        spider / radar web
!
!  AND ANY COMBINATION OF BARS AND LINES. A series may be told how it is
!  drawn, whatever the chart type says:  Obj.SetSeriesPlot(2, Plot:Line)
!  draws series 2 as a line over the bars of the others - sales as columns
!  and the trend as a line, on the one value axis, which is the shape a
!  Clarion LIST has never been able to give you.
!
!  USAGE (handled by the graficaBarra template, or call it yourself):
!    INCLUDE('GraficaBarraClass.INC'),ONCE     then declare one per graph:
!      Ventas  GraficaBarraClass
!
!    ! --- one series (all types) -------------------------------------------
!    Ventas.Title = 'Ventas 2026'
!    Ventas.AddBar('Ene', 120)                 ! auto palette color
!    Ventas.AddBar('Feb', 95, 0B6752Eh)        ! explicit color (Clarion BGR)
!
!    ! --- several series (bars / lines / areas / stacks) -------------------
!    Ventas.ChartType = Chart:StackedCol
!    Ventas.AddSeries('Norte')                 ! series 1, auto color
!    Ventas.AddSeries('Sur')                   ! series 2
!    Ventas.AddCat('Ene', 120, 80)             ! one category, one value each
!    Ventas.AddCat('Feb',  95, 60)
!
!    ! --- a combo: bars for one series, a line for the other ---------------
!    Ventas.ChartType = Chart:Column           ! bars, for the series that
!    Ventas.AddSeries('Ventas')                !   say nothing
!    Ventas.AddSeries('Tendencia')
!    Ventas.SetSeriesPlot(2, Plot:Line)        ! ...but this one is a line
!    Ventas.AddCat('Ene', 120, 118)            ! both read the same axis
!
!    ! --- a bar with no line point on it -----------------------------------
!    Ventas.AddCat('Prm.', 93400000, 0)        ! the average: a bar, but the
!    Ventas.SetNoValue(2, Ventas.NBars)        !   trend has nothing to say
!                                              !   there, so the line stops
!
!    Ventas.Draw(MyWindow, ?Graph)             ! window: draw into the IMAGE
!    ! report (per band):
!    !   SETTARGET(MyReport, ?Band) ; Ventas.Paint(?Placeholder) ; SETTARGET()
!
!  REUSING ONE OBJECT: ClearAll() throws the DATA away, it cannot un-draw a
!  chart that is already on the page. Paint therefore clears the placeholder's
!  own rectangle before it draws (EraseFirst=1), so a second chart painted into
!  the same placeholder REPLACES the first instead of landing on top of it.
!  Set EraseFirst=0 only when you really do want to overlay.
!
!  Values may be negative (bars hang below the zero baseline). If AutoScale=1
!  (default) the value axis is computed from the data and rounded up to a
!  "nice" 1/2/5 x 10^k number; call SetRange(min,max) for a fixed scale.
!
!  This file MUST be stored in ANSI (not UTF-8), CRLF line ends.
! ============================================================================

GraficaBarra:MaxBars    EQUATE(48)                             ! categories / slices / points
GraficaBarra:MaxSeries  EQUATE(8)                              ! series (1 = the simple case)
GraficaBarra:MaxSeries2 EQUATE(7)                              ! MaxSeries - 1 (series 2..8 storage)
GraficaBarra:MaxPoly    EQUATE(200)                            ! POLYGON scratch: 100 corners
GraficaBarra:Pi         EQUATE(3.14159265358979)

! ---- chart types -----------------------------------------------------------
Chart:Column       EQUATE(0)                                   ! vertical bars (default)
Chart:Bar          EQUATE(1)                                   ! horizontal bars
Chart:StackedCol   EQUATE(2)
Chart:StackedBar   EQUATE(3)
Chart:Stacked100   EQUATE(4)                                   ! 100% stacked columns
Chart:Line         EQUATE(5)
Chart:Area         EQUATE(6)
Chart:StackedArea  EQUATE(7)
Chart:Scatter      EQUATE(8)
Chart:Pie          EQUATE(9)
Chart:Pie3D        EQUATE(10)
Chart:Donut        EQUATE(11)
Chart:Radar        EQUATE(12)

! ---- how one series is drawn (combos) --------------------------------------
Plot:Default       EQUATE(0)                                   ! whatever ChartType says
Plot:Bar           EQUATE(1)                                   ! this series is a bar
Plot:Line          EQUATE(2)                                   ! this series is a line

! ---- legend placement ------------------------------------------------------
Legend:Bottom      EQUATE(0)
Legend:Right       EQUATE(1)
Legend:Top         EQUATE(2)

! ---- marker shapes ---------------------------------------------------------
Marker:Circle      EQUATE(0)
Marker:Square      EQUATE(1)
Marker:Diamond     EQUATE(2)

GraficaBarraClass CLASS,TYPE,MODULE('GraficaBarraClass.CLW'),LINK('GraficaBarraClass.CLW')
! ---- what to draw ----
ChartType          LONG                                        ! Chart:Column ... Chart:Radar
Title              CSTRING(64)                                 ! centered above the plot
! ---- features on/off ----
ShowValues         BYTE                                        ! numeric value on each bar / point / slice
ValueDP            LONG                                        ! decimals on values
ShowLabels         BYTE                                        ! category label (under the axis, or beside a slice)
ShowScale          BYTE                                        ! numeric scale down the left (or along the bottom)
ScaleDP            LONG                                        ! decimals on scale labels
ShowGrid           BYTE                                        ! gridlines (rings on a radar)
GridDivs           LONG                                        ! scale/grid divisions (default 5)
ShowAxis           BYTE                                        ! value axis + zero baseline
ShowLegend         BYTE                                        ! key of series (or of slices on a pie)
LegendPos          LONG                                        ! Legend:Bottom / Legend:Right / Legend:Top
ShowMarkers        BYTE                                        ! dots on Line / Area (always on for Scatter)
MarkerShape        LONG                                        ! Marker:Circle / Square / Diamond
MarkerSize         LONG                                        ! 0 = auto from the text height
LineWidth          LONG                                        ! pen width for Line / Area / Radar (default 2)
Smooth             BYTE                                        ! Line / Area: round the corners off
Percent            BYTE                                        ! show values as a % of the total (pie / stacks)
ColorText          BYTE                                        ! 1 = re-color text with SETFONT (0 = target's font)
! ---- the chart's own type (blank / 0 = whatever the target is using) ----
FontName           CSTRING(32)                                 ! typeface for every label on this chart
FontSize           LONG                                        ! points. ALSO scales TextW/TextH when they
                                                               ! are 0, so the layout follows the type
FontStyle          LONG                                        ! FONT:regular / FONT:bold / ...
! ---- pie / donut / radar ----
Depth3D            LONG                                        ! Chart:Pie3D edge depth (0 = auto)
DonutPct           LONG                                        ! Chart:Donut hole, % of the diameter (default 55)
DonutText          CSTRING(32)                                 ! optional text in the middle of a donut
HoleColor          LONG                                        ! donut hole fill (COLOR:None = follow the background)
StartAngle         LONG                                        ! pie: first slice, degrees clockwise from 12 o'clock
! ---- scale ----
AutoScale          BYTE                                        ! 1 = derive the scale from the data
MinVal             REAL                                        ! used when AutoScale = 0
MaxVal             REAL
! ---- layout ----
BarGapPct          LONG                                        ! gap between bars, percent of one slot
TextW              LONG                                        ! char cell override. 0 = work it out: 4 x 9
TextH              LONG                                        ! dialog units on a window, 62 x 130 thousandths
                                                               ! on a report, both scaled by FontSize / 9 when
                                                               ! a FontSize was asked for
EraseFirst         BYTE                                        ! 1 (default) = Paint clears its own rectangle
                                                               ! before drawing. 0 = draw ON TOP of whatever is
                                                               ! already there (deliberate overlays).
! ---- colors (Clarion BGR longs) ----
BackColor          LONG                                        ! whole-control background (COLOR:None = leave)
PlotColor          LONG                                        ! plot-area fill (COLOR:None = leave)
AxisColor          LONG
GridColor          LONG
TextColor          LONG
BarBorderColor     LONG                                        ! COLOR:None = border same as the fill
! ---- data: categories (series 1 lives here, so v1 code keeps working) ----
NBars              LONG
BarLabel           STRING(32),DIM(GraficaBarra:MaxBars)
BarValue           REAL,DIM(GraficaBarra:MaxBars)              ! series 1
BarColor           LONG,DIM(GraficaBarra:MaxBars)              ! -1 (COLOR:None) = auto palette
! ---- data: extra series (2..GraficaBarra:MaxSeries) ----
NSeries            LONG                                        ! 0/1 = one series, up to MaxSeries
SeriesName         STRING(32),DIM(GraficaBarra:MaxSeries)
SeriesColor        LONG,DIM(GraficaBarra:MaxSeries)            ! -1 (COLOR:None) = auto palette
SeriesPlot         LONG,DIM(GraficaBarra:MaxSeries)            ! Plot:Default / Plot:Bar / Plot:Line
SeriesValue        REAL,DIM(GraficaBarra:MaxSeries2,GraficaBarra:MaxBars) ! series 2..8
NoVal              BYTE,DIM(GraficaBarra:MaxSeries,GraficaBarra:MaxBars)  ! 1 = this cell has NO value:
                                                               ! the category is there, this series has
                                                               ! nothing to say about it. See SetNoValue

! ---- methods: data --------------------------------------------------------
Construct          PROCEDURE
ClearBars          PROCEDURE                                   ! drop the categories (keeps the series names)
ClearAll           PROCEDURE                                   ! drop the categories AND the series. DATA only -
                                                               ! it does not un-draw a chart already on the page;
                                                               ! EraseFirst (default 1) does that at Paint time.
AddBar             PROCEDURE(STRING pLabel,REAL pValue,LONG pColor=-1)
AddSeries          PROCEDURE(STRING pName,LONG pColor=-1,LONG pPlot=0),LONG,PROC ! returns the series number
SetSeriesPlot      PROCEDURE(LONG pSeries,LONG pPlot)          ! Plot:Bar / Plot:Line for one series;
                                                               ! Plot:Default hands it back to ChartType
AddCat             PROCEDURE(STRING pLabel,REAL v1,REAL v2=0,REAL v3=0,REAL v4=0,REAL v5=0,REAL v6=0,REAL v7=0,REAL v8=0)
SetValue           PROCEDURE(LONG pSeries,LONG pCat,REAL pValue)  ! also clears NoVal for that cell
SetNoValue         PROCEDURE(LONG pSeries,LONG pCat)           ! that cell has nothing to draw: the bar
                                                               ! is skipped and the LINE BREAKS rather
                                                               ! than diving to zero. A trend that stops
                                                               ! short of an average bar is the case.
GetValue           PROCEDURE(LONG pSeries,LONG pCat),REAL      ! 0 for a cell with no value
HasValue           PROCEDURE(LONG pSeries,LONG pCat),BYTE      ! 0 = skip this point
SetRange           PROCEDURE(REAL pMin,REAL pMax)              ! fixed scale (sets AutoScale=0)
Demo               PROCEDURE                                   ! sample data suited to ChartType (self-test)
! ---- methods: drawing -----------------------------------------------------
Draw               PROCEDURE(WINDOW pWin,SIGNED pImageFeq)     ! window: target the IMAGE, clear, paint
Paint              PROCEDURE(SIGNED pFeq,BYTE pWindowMode=0)   ! paint into the CURRENT target at pFeq's rect;
                                                               ! pWindowMode=1 = image-relative (windows),
                                                               ! 0 = band offset kept (reports). Either way
                                                               ! EraseFirst=1 clears pFeq's rect beforehand.
! ---- internal: helpers ----------------------------------------------------
NiceMax            PROCEDURE(REAL v),REAL                      ! round up to 1/2/5 x 10^k
NiceStep           PROCEDURE(REAL v),REAL                     ! round up to 1/2/2.5/5/10 x 10^k:
                                                               ! the gap BETWEEN two gridlines
Palette            PROCEDURE(LONG i),LONG                      ! professional auto colors (cycles)
FmtNum             PROCEDURE(REAL v,LONG dp),STRING
SeriesCount        PROCEDURE(),LONG                            ! effective series count (never 0)
PlotOf             PROCEDURE(LONG pSeries),LONG                ! Plot:Bar or Plot:Line, resolved
IsCombo            PROCEDURE(),BYTE                            ! 1 = the series are not all one shape
BarSeriesCount     PROCEDURE(),LONG                            ! how many series are drawn as bars
BarSeriesIndex     PROCEDURE(LONG pSeries),LONG                ! its place among them (0 = not a bar)
ColorOf            PROCEDURE(LONG pSeries,LONG pCat),LONG      ! resolved fill color
IsStacked          PROCEDURE(),BYTE
IsHorizontal       PROCEDURE(),BYTE
IsPie              PROCEDURE(),BYTE
StackSum           PROCEDURE(LONG pCat,BYTE pPositive),REAL    ! sum of the +ve (or -ve) values of one category
CatTotal           PROCEDURE(LONG pCat),REAL                   ! ABS sum over the series of one category
! ---- internal: painters ---------------------------------------------------
PaintCartesian     PROCEDURE
PaintBars          PROCEDURE
PaintStack         PROCEDURE
PaintLine          PROCEDURE(LONG pSeries)
PaintArea          PROCEDURE
PaintPie           PROCEDURE
PaintRadar         PROCEDURE
PaintGrid          PROCEDURE
PaintLegend        PROCEDURE
! ---- internal: primitives -------------------------------------------------
TextAt             PROCEDURE(LONG px,LONG py,STRING pTxt,LONG pColor)
TextMid            PROCEDURE(LONG px,LONG py,STRING pTxt,LONG pColor)  ! px = the CENTER of the text
FillBox            PROCEDURE(LONG px,LONG py,LONG pw,LONG ph,LONG pColor)
Marker             PROCEDURE(LONG px,LONG py,LONG pColor)
LegendKey          PROCEDURE(LONG px,LONG py,LONG pw,LONG pSeries,LONG pColor) ! the legend's swatch:
                                                               ! a block, or a line for a line series
PolyStart          PROCEDURE
PolyAdd            PROCEDURE(LONG px,LONG py)
PolyDraw           PROCEDURE(LONG pFill)
VY                 PROCEDURE(REAL v),LONG                      ! value -> y (vertical charts)
VX                 PROCEDURE(REAL v),LONG                      ! value -> x (horizontal charts)
! ---- internal: draw state (set by Paint - do not assign) ------------------
zFeq               SIGNED                                      ! control being drawn into
zWin               BYTE                                        ! 1 = window mode
zCW                LONG                                        ! text cell, target units
zCH                LONG
zPad               LONG
zSc                LONG                                        ! pen scale (1 on a window, ~14 on a THOUS report)
zX                 LONG                                        ! whole rectangle
zY                 LONG
zW                 LONG
zH                 LONG
zPX                LONG                                        ! plot rectangle
zPY                LONG
zPW                LONG
zPH                LONG
zLo                REAL                                        ! value axis
zHi                REAL
zDivs              LONG                                        ! gridlines actually used (zero lands on one)
zZY                LONG                                        ! zero baseline (vertical)
zZX                LONG                                        ! zero baseline (horizontal)
zNS                LONG                                        ! series being drawn
zLegW              LONG                                        ! space the legend needs
zLegH              LONG
zFont              CSTRING(64)                                 ! the target's own font, for re-coloring text
zFSize             LONG
zFStyle            LONG
zFChar             LONG
zLastColor         LONG
zNPoly             LONG                                        ! POLYGON scratch
zPoly              SIGNED,DIM(GraficaBarra:MaxPoly)
zSlice             SIGNED,DIM(GraficaBarra:MaxBars)            ! PIE scratch
zSliceColor        LONG,DIM(GraficaBarra:MaxBars)
                   END
