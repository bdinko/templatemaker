!ABCIncludeFile(MYEXPORT)
! ============================================================================
!  ExportClass - export ANY Clarion LIST / browse to a file, or to paper.
!
!  Formats:  CSV | CSV (UTF-8) | TSV | XML | JSON | HTML | Excel .xlsx | PDF
!  Plus:     Print - straight to a Windows printer, no file at all
!
!  Pure Clarion + the Win32 API that ships with Windows. No DLL, no OCX, no
!  Excel installation, no external helper program. The .xlsx it writes is a
!  real OOXML workbook (a ZIP of XML parts, built here) - Excel, LibreOffice,
!  Google Sheets and every xlsx reader open it directly.
!
!  HOW IT KNOWS WHAT TO EXPORT
!  ---------------------------
!  It reads the LIST control's own FORMAT at run time:
!      ?List{PROPLIST:Exists,c}   - is there a column c
!      ?List{PROPLIST:FieldNo,c}  - which QUEUE field that column shows
!      ?List{PROPLIST:Header,c}   - the column heading (becomes the file's)
!      ?List{PROPLIST:Picture,c}  - the column picture (formats the value)
!  and pulls each value out of the queue with WHAT(Queue, FieldNo). So the
!  export always matches what the user sees: same columns, same order, same
!  headings, same pictures - including columns the user re-ordered or resized
!  at run time. (This is the same recipe the shipped brwext.clw uses.)
!
!  USAGE (the myExport template does all of this for you)
!  ------------------------------------------------------
!    INCLUDE('ExportClass.INC'),ONCE
!    Exporter1  ExportClass
!
!      Exporter1.Init(?Browse:1, Queue:Browse:1)   ! list feq + its queue
!      Exporter1.Title = 'Customers'
!      IF Exporter1.Ask()                          ! modal format+filename dialog
!         Exporter1.StartFile()
!         BRW1.Reset()                             ! walk the WHOLE view...
!         LOOP
!           IF BRW1.Next() THEN BREAK .
!           BRW1.SetQueueRecord()                  ! ...fill the queue buffer
!           Exporter1.AddRow()
!         END
!         Exporter1.EndFile()
!      END
!
!    For a plain hand-coded LIST + QUEUE the whole job is one call:
!      IF Exporter1.Ask() THEN Exporter1.ExportQueue() .
!    or simply
!      Exporter1.Run()
!
!  PRINT AND PDF
!  -------------
!  Print and PDF sit in the SAME format list as CSV/XML/etc (Exp:Print and
!  Exp:PDF) - Ask() offers them like any other format. Picking Print hides the
!  "Save to" file box (there is no file) and relabels the button "Print"; it
!  prints straight to SELF.PrinterName, or Windows' configured default printer
!  when that is blank - there is no interactive OS Print dialog, so nothing
!  here depends on that dialog's binary struct. PDF just writes a file, same
!  as HTML or XLSX.
!
!  They also work stand-alone, without ever opening Ask():
!      Exporter1.Fmt = Exp:PDF
!      Exporter1.FileName = 'Customers.pdf'
!      Exporter1.ExportQueue()
!
!      Exporter1.Fmt = Exp:Print
!      IF Exporter1.PrintOut() THEN ... .      ! prints to SELF.PrinterName or the default printer
!
!  Print is pure GDI (CreateDC on SELF.PrinterName or the default printer, then
!  StartDoc/StartPage/EndPage/EndDoc) - no REPORT structure and, deliberately,
!  no Win32 struct of any kind, so nothing here depends on a binary layout that
!  can't be verified without a compiler. PDF is a hand-built file (objects +
!  xref table, the same technique as the .xlsx ZIP above), using the standard
!  PDF fonts Helvetica/Helvetica-Bold so nothing is embedded. Both lay the
!  LIST's columns out proportionally to their on-screen widths and paginate
!  automatically, repeating the heading row on every page.
!
!  SELF.PageSetup() opens a small Clarion dialog (Orientation / Paper / Margins).
!  PDF honours all of it exactly. Print honours the margins and font size, but
!  NOT orientation/paper - a printed page follows the target printer's own
!  configured default (its Properties in Windows' Devices and Printers), since
!  there is no interactive Print dialog here to change that per job.
!
!  FILES
!  -----
!    ExportClass.inc / ExportClass.clw   - put both on the redirection path
!                                          (the app folder, or \clarion12\libsrc\win)
!    Both files must be stored ANSI with CRLF line endings.
!
!  OPTIONAL: COMPRESSED .xlsx
!  --------------------------
!  By default the .xlsx parts are STORED (a valid, uncompressed ZIP) so the
!  class has zero dependencies. If you also own the myExport sibling template
!  myCompress, set _ExportDeflate_ to 1 below and put CompressClass.inc /
!  CompressClass.clw on the redirection path - the parts are then DEFLATEd and
!  a big workbook shrinks by roughly 8-10x. Nothing else changes.
!
!  MULTI-DLL
!  ---------
!  The class is registered with the ABC class chain as category MYEXPORT (the
!  !ABCIncludeFile(MYEXPORT) tag on line 1), so where its code lives is decided
!  by two project defines, exactly like every ABC class:
!
!    _myExportLinkMode_   1 = compile ExportClass.clw into THIS app
!    _myExportDllMode_    1 = import the class from another DLL instead
!
!  The myExportGlobal template sets both for you from the application's own
!  "External" setting, and - in the app that owns the class - adds the whole
!  class to that DLL's generated .EXP. Add myExportGlobal to every app in the
!  suite and nothing else is needed.
!
!  Neither symbol has to exist: undefined means "link it in", which is what a
!  single EXE and a hand-coded project want. For a hand-coded multi-DLL build,
!  set the two defines in each project's Defines list and paste the shipped
!  ExportClass.exp into the exporting DLL's .EXP.
! ============================================================================

!  This runs every time the file is processed (deliberately NOT nested inside
!  the OMIT('_EndOfInclude_',...) guard below - Clarion 11/12 reports a
!  "nested omit" error if a COMPILE sits inside an OMIT block). Harmless to
!  repeat: INCLUDE('CompressClass.INC'),ONCE is already self-guarding.
_ExportDeflate_    EQUATE(0)                    ! 1 = deflate .xlsx parts with CompressClass (myCompress)

  COMPILE('_EndDeflateInc_',_ExportDeflate_)
INCLUDE('CompressClass.INC'),ONCE
  _EndDeflateInc_

  OMIT('_EndOfInclude_',_ExportClassPresent_)
_ExportClassPresent_ EQUATE(1)

! ---- the formats ----------------------------------------------------------
Exp:CSV            EQUATE(1)                    ! comma separated, system code page
Exp:CSVUTF8        EQUATE(2)                    ! comma separated, UTF-8 + BOM (Excel-safe accents)
Exp:TSV            EQUATE(3)                    ! tab separated
Exp:XML            EQUATE(4)                    ! UTF-8 XML, one element per column
Exp:JSON           EQUATE(5)                    ! UTF-8 array of objects
Exp:XLSX           EQUATE(6)                    ! real Excel workbook (OOXML)
Exp:HTML           EQUATE(7)                    ! styled HTML table
Exp:Print          EQUATE(8)                    ! straight to a Windows printer - no file
Exp:PDF            EQUATE(9)                    ! hand-built PDF, Helvetica, paginated
Exp:Formats        EQUATE(9)                    ! how many of the above there are

! ---- Allow bit mask (Allow = BOR of these; default = all) ------------------
Exp:AllowCSV       EQUATE(1)
Exp:AllowCSVUTF8   EQUATE(2)
Exp:AllowTSV       EQUATE(4)
Exp:AllowXML       EQUATE(8)
Exp:AllowJSON      EQUATE(16)
Exp:AllowXLSX      EQUATE(32)
Exp:AllowHTML      EQUATE(64)
Exp:AllowPrint     EQUATE(128)
Exp:AllowPDF       EQUATE(256)
Exp:AllowAll       EQUATE(511)

! ---- page setup: SELF.PageOrient -------------------------------------------
Exp:Portrait       EQUATE(1)
Exp:Landscape      EQUATE(2)
! ---- page setup: SELF.PagePaper --------------------------------------------
Exp:Letter         EQUATE(1)
Exp:A4             EQUATE(2)

! ---- languages ------------------------------------------------------------
!  Every word the dialog, the Save-As box and the messages show comes out of
!  the Txt() method, so adding a language means overriding one method - see the
!  note above ExportClass.Txt in the .clw.
Exp:English        EQUATE(1)
Exp:Spanish        EQUATE(2)

! ---- every string the user can see ----------------------------------------
!  The export dialog
Txt:WinTitle       EQUATE(1)                    ! window caption and banner
Txt:Subtitle       EQUATE(2)
Txt:SubtitleNoCol  EQUATE(3)                    ! ...when the column picker is off
Txt:FormatLbl      EQUATE(4)
Txt:SaveToLbl      EQUATE(5)
Txt:FileTip        EQUATE(6)
Txt:PickTip        EQUATE(7)
Txt:ColumnsLbl     EQUATE(8)
Txt:ColHint        EQUATE(9)
Txt:ColUse         EQUATE(10)                   ! the four column-list headings
Txt:ColNum         EQUATE(11)
Txt:ColHeadFile    EQUATE(12)
Txt:ColPicture     EQUATE(13)
Txt:ColOnList      EQUATE(14)
Txt:ToggleBtn      EQUATE(15)
Txt:EditBtn        EQUATE(16)
Txt:AllBtn         EQUATE(17)
Txt:NoneBtn        EQUATE(18)
Txt:DefBtn         EQUATE(19)
Txt:DefTip         EQUATE(20)
Txt:IncHeadings    EQUATE(21)
Txt:ApplyPics      EQUATE(22)
Txt:ApplyPicsTip   EQUATE(23)
Txt:OpenAfter      EQUATE(24)
Txt:ExportBtn      EQUATE(25)
Txt:Cancel         EQUATE(26)
Txt:OfWord         EQUATE(27)                   ! "(3 of 8 selected)"
Txt:SelectedWord   EQUATE(28)
!  The one-column popup
Txt:EdTitle        EQUATE(29)
Txt:EdHeading      EQUATE(30)
Txt:OnTheList      EQUATE(31)
Txt:HeadingLbl     EQUATE(32)
Txt:HeadTip        EQUATE(33)
Txt:PictureLbl     EQUATE(34)
Txt:PicTip         EQUATE(35)
Txt:EdDefBtn       EQUATE(36)
Txt:EdFoot         EQUATE(37)
Txt:OK             EQUATE(38)
!  Format names, as the drop list and the Save-As title show them
Txt:FmtCSV         EQUATE(39)
Txt:FmtCSVU        EQUATE(40)
Txt:FmtTSV         EQUATE(41)
Txt:FmtXML         EQUATE(42)
Txt:FmtJSON        EQUATE(43)
Txt:FmtXLSX        EQUATE(44)
Txt:FmtHTML        EQUATE(45)
Txt:FmtPrint       EQUATE(82)
Txt:FmtPDF         EQUATE(83)
!  The Save-As file-type descriptions
Txt:MaskCSV        EQUATE(46)
Txt:MaskTSV        EQUATE(47)
Txt:MaskXML        EQUATE(48)
Txt:MaskJSON       EQUATE(49)
Txt:MaskXLSX       EQUATE(50)
Txt:MaskHTML       EQUATE(51)
Txt:MaskText       EQUATE(52)
Txt:MaskAll        EQUATE(53)
Txt:MaskPDF        EQUATE(84)
!  The one-liner under the dialog, per format
Txt:HintCSV        EQUATE(54)
Txt:HintCSVU       EQUATE(55)
Txt:HintTSV        EQUATE(56)
Txt:HintXML        EQUATE(57)
Txt:HintJSON       EQUATE(58)
Txt:HintXLSX       EQUATE(59)
Txt:HintHTML       EQUATE(60)
Txt:HintPrint      EQUATE(85)
Txt:HintPDF        EQUATE(86)
!  Messages
Txt:MsgTitle       EQUATE(61)
Txt:NoColumns      EQUATE(62)
Txt:NoFormats      EQUATE(63)
Txt:NeedFile       EQUATE(64)
Txt:NeedColumn     EQUATE(65)
Txt:BadPicture     EQUATE(66)
Txt:BadPicture2    EQUATE(67)
Txt:PicTitle       EQUATE(68)
Txt:FailTitle      EQUATE(69)
Txt:NoneSelected   EQUATE(70)
Txt:NoFileName     EQUATE(71)
Txt:CantCreate     EQUATE(72)
Txt:CantCreate2    EQUATE(73)
Txt:CantWrite      EQUATE(74)
Txt:CantWrite2     EQUATE(75)
Txt:RowsExported   EQUATE(76)
Txt:DoneTitle      EQUATE(77)
Txt:ExportToTitle  EQUATE(78)
Txt:RowsHtml       EQUATE(79)                   ! the count under the HTML table
Txt:ColumnWord     EQUATE(80)                   ! heading for a column the list does not name
Txt:ExportWord     EQUATE(81)                   ! the suggested file name when nothing better
!  Print - the dialog just relabels the OK button and hides "Save to"; it
!  prints straight to SELF.PrinterName or the Windows default printer.
Txt:PrintBtn       EQUATE(87)                   ! the Export button caption when Fmt=Exp:Print
Txt:NoPrinter      EQUATE(88)                   ! no default printer, or SELF.PrinterName not found
Txt:RowsPrinted    EQUATE(89)                   ! " row(s) printed on "
Txt:PageWord       EQUATE(90)                   ! " page(s)"
Txt:PreviewChk     EQUATE(91)                   ! "Preview before printing" - shown only for Fmt=Exp:Print
Txt:PageSetupBtn   EQUATE(92)                   ! "Page Setup..." - shown for Fmt=Exp:Print or Exp:PDF
!  Totals row (Excel .xlsx only)
Txt:ColTotal       EQUATE(93)                   ! the picker's "Tot" (sum) column heading
Txt:TotalBtn       EQUATE(94)                   ! "Toggle t&otal" button caption
Txt:TotalsChk      EQUATE(95)                   ! "Add a &totals row" checkbox caption
Txt:TotalsTip      EQUATE(96)                   ! tooltip under the totals checkbox
Txt:NotNumeric     EQUATE(97)                   ! shown if Tot is toggled on a non-numeric column
!  Average / Minimum / Maximum summary rows (Excel .xlsx only)
Txt:SummaryLbl     EQUATE(98)                   ! "Summary rows:" prompt
Txt:SumChk         EQUATE(99)                   ! "&Sum" checkbox caption
Txt:AvgChk         EQUATE(100)                  ! "&Avg" checkbox caption
Txt:MinChk         EQUATE(101)                  ! "M&in" checkbox caption
Txt:MaxChk         EQUATE(102)                  ! "Ma&x" checkbox caption
!  Email when done (Simple MAPI)
Txt:EmailChk       EQUATE(103)                  ! "&Email the file when it is done" checkbox caption
Txt:CantEmail      EQUATE(104)                  ! shown if Simple MAPI could not open a compose window
Txt:EmailFailTitle EQUATE(105)                  ! that popup's title
!  Subtotal / group rows (Excel .xlsx only)
Txt:ColGroup       EQUATE(106)                  ! the picker's "Grp" column heading
Txt:GroupBtn       EQUATE(107)                  ! "Toggle &group" button caption
!  Multiple sheets in one workbook (code-driven only)
Txt:XlsxOnly       EQUATE(108)                  ! shown if StartWorkbook()/StartSheet() is called for a non-xlsx format
Txt:NotInWorkbook  EQUATE(109)                  ! shown if StartSheet() is called without StartWorkbook() first
Txt:TooManySheets  EQUATE(110)                  ! shown past the 100-sheet cap
Txt:NoSheets       EQUATE(111)                  ! shown if EndWorkbook() is called with no sheets ever stashed
Txt:SplitChk       EQUATE(112)                  ! "Split sheets" checkbox caption
Txt:CntChk         EQUATE(113)                  ! "Cnt" checkbox caption
Txt:PdfTruncTitle  EQUATE(114)                  ! title of the "PDF is incomplete" warning popup
Txt:PdfTruncMsg    EQUATE(115)                  ! its message
Txt:EmailFrontChk  EQUATE(116)                  ! "Bring it to the front" checkbox caption
Txt:Strings        EQUATE(116)                  ! how many of the above there are

! ---- one row per data column found on the LIST ----------------------------
!  Head / Pic are what the FILE gets and the user may edit them in the dialog;
!  HeadDef / PicDef are what the LIST itself says, so "Defaults" can undo.
ExportColumnQueue  QUEUE,TYPE
ColNo                LONG                       ! the LIST column number
FldNo                LONG                       ! the QUEUE field it displays
Use                  BYTE                       ! 1 = include this column in the file
Head                 CSTRING(129)               ! the heading to write (renameable)
Pic                  CSTRING(33)                ! the picture to apply (overridable)
HeadDef              CSTRING(129)               ! the heading the LIST shows
PicDef               CSTRING(33)                ! the picture the LIST shows
Tag                  CSTRING(65)                ! Head made safe for an XML/JSON name
IsNum                BYTE                       ! 1 = write unquoted in JSON / as a number in xlsx
Width                LONG                       ! the column width, in dialog units
Total                BYTE                       ! 1 = sum this (numeric) column in the xlsx Totals row
GroupBy              BYTE                       ! 1 = this is THE column to break/subtotal on (single-select)
                   END

! ---- one row per part written into the .xlsx archive ----------------------
ExportZipQueue     QUEUE,TYPE
EName                CSTRING(65)
ECrc                 ULONG
ECSize               ULONG
EUSize               ULONG
EOfs                 ULONG
EMeth                USHORT
                   END

! ---- one PDF object, so the xref table can be written after the fact ------
!  PdfWrite appends every object to SELF.Arc as it goes (same growable buffer
!  the .xlsx ZIP uses) and remembers where each one started.
ExportPdfQueue     QUEUE,TYPE
PNum                 LONG                       ! object number (1-based, in order)
POfs                 ULONG                      ! byte offset of "N 0 obj" in SELF.Arc
                   END

! ---- one finished sheet, waiting for EndWorkbook() to zip it in -----------
!  StartSheet()/EndSheet() build each sheet exactly the way a single-sheet
!  export always has (SELF.Buf, via XlsxSheetBegin/XlsxSheetEnd), then
!  EndSheet() moves the finished, already-UTF8 XML here and frees SELF.Buf so
!  the next sheet starts clean. A single-sheet export ends up with exactly
!  one entry here too - XlsxWrite() has one job either way: zip whatever is
!  waiting in SELF.Sheets.
ExportSheetQueue   QUEUE,TYPE
SName                CSTRING(65)                ! the tab name, already run through SheetName()
SData                &STRING                    ! that sheet's finished <worksheet>...</worksheet>, UTF-8
SLen                 LONG                       ! how many bytes of SData are valid
                   END

! ---- one distinct decimal-preserving number format actually used ----------
!  Shared across every sheet in the workbook (styles.xml is one part for the
!  whole file), built up as columns are scanned - a plain integer column
!  never needs one of these at all, so most exports register none.
ExportNumFmtQueue  QUEUE,TYPE
Decimals             LONG                       ! decimal places this format shows
Parens               BYTE                       ! 1 = negatives in parentheses, matching SELF.NegativeParens
NumFmtId             LONG                       ! the xlsx numFmtId assigned (164, 165, ... - custom range)
StyleN               LONG                       ! cellXfs index for an ordinary data cell using this format
StyleT               LONG                       ! cellXfs index for a bold, top-bordered total/subtotal cell
                   END

ExportClass        CLASS,TYPE,MODULE('ExportClass.CLW'),LINK('ExportClass.CLW',_myExportLinkMode_),DLL(_myExportDllMode_)
! ---- what to export -------------------------------------------------------
ListControl          SIGNED                     ! the LIST field equate
Q                    &QUEUE                     ! the queue that LIST displays
! ---- what the user chose (Ask fills these; set them yourself to skip Ask) --
Fmt                  LONG(1)                    ! Exp:CSV .. Exp:HTML
FileName             CSTRING(261)               ! full path of the file to write
! ---- options --------------------------------------------------------------
Allow                LONG(Exp:AllowAll)         ! Exp:AllowAll, or a BOR of the Exp:Allow* bits
Title                CSTRING(65)                ! sheet name / XML root / HTML heading
RowTag               CSTRING(33)                ! XML element for one row (default 'Row')
Headers              BYTE(1)                    ! write a heading row
Pictures             BYTE(1)                    ! run each value through its column picture
VisibleOnly          BYTE(1)                    ! start with hidden and icon columns un-ticked
HideZeroWidth        BYTE(0)                    ! don't even offer a zero-width column - not just untick it, leave it out of the picker entirely
OpenWhenDone         BYTE(1)                    ! open the file in its default program
EmailWhenDone        BYTE(0)                    ! open a new message (Simple MAPI) with the file attached
EmailSubject         CSTRING(129)               ! blank = Title
EmailBody            CSTRING(1025)              ! blank = no note text
EmailToFront         BYTE(1)                    ! 1 = try to bring the mail client's own window to the front, not just flash its taskbar icon
Confirm              BYTE(1)                    ! show the "N rows exported" popup
AllowColumns         BYTE(1)                    ! let the user pick/rename columns in the dialog
Language             BYTE(1)                    ! Exp:English / Exp:Spanish
Delim                STRING(1)                  ! CSV separator; blank = comma
! ---- Totals row (Excel .xlsx only) -----------------------------------------
Totals               BYTE(0)                    ! 1 = write a bold Sum row under the data
TotalsLabel          CSTRING(41)                ! label for the Sum row; Construct defaults it to 'Total'
TotalsAvg            BYTE(0)                    ! 1 = write a bold Average row under the data
AvgLabel             CSTRING(41)                ! label for the Average row; Construct defaults it to 'Average'
TotalsMin            BYTE(0)                    ! 1 = write a bold Minimum row under the data
MinLabel             CSTRING(41)                ! label for the Minimum row; Construct defaults it to 'Minimum'
TotalsMax            BYTE(0)                    ! 1 = write a bold Maximum row under the data
MaxLabel             CSTRING(41)                ! label for the Maximum row; Construct defaults it to 'Maximum'
TotalsCnt            BYTE(0)                    ! 1 = write a bold Count row under the data
CntLabel             CSTRING(41)                ! label for the Count row; Construct defaults it to 'Count'
SplitByGroup         BYTE(0)                    ! 1 = ALSO write one extra sheet per distinct group value (needs a Grp column)
NegativeParens       BYTE(0)                    ! 1 = negative numbers show as (123.45) instead of -123.45, in every numeric column's own xlsx format
! ---- Print / PDF page setup ------------------------------------------------
PageOrient           BYTE(Exp:Landscape)        ! Exp:Portrait / Exp:Landscape
PagePaper            BYTE(Exp:Letter)           ! Exp:Letter / Exp:A4 (PDF only - Print uses the printer's own)
MarginLeft           LONG(720)                  ! twips (1440/inch); default 0.5"
MarginTop            LONG(720)
MarginRight          LONG(720)
MarginBottom         LONG(720)
FontFace             CSTRING(33)                ! blank = Arial (Print) / Helvetica (PDF)
FontSize             LONG(9)                    ! points, body text
TitleSize            LONG(14)                   ! points, the printed/PDF title
PrinterName          CSTRING(65)                ! blank = the Windows default printer
Copies               LONG(1)
PagesOut             LONG                       ! pages produced by the last Print/PDF
PdfTruncated         BYTE                       ! 1 = the last PDF ran out of pages (Exp:PdfPageCap) before every row fit - some rows were left out. Check this even with Confirm off, since the completion popup respects Confirm and won't tell you otherwise.
! ---- remembering the last export ------------------------------------------
Persist              BYTE(0)                    ! 1 = save/restore the choices between runs
Profile              CSTRING(65)                ! which saved profile; blank = derived from Title
IniFile              CSTRING(261)               ! where to save; blank = the app's own .INI
! ---- results --------------------------------------------------------------
RowsOut              LONG                       ! rows written by the last export
ErrCode              LONG                       ! 0 = ok
ErrText              CSTRING(161)
! ---- internals ------------------------------------------------------------
Cols                 &ExportColumnQueue,PROTECTED
Parts                &ExportZipQueue,PROTECTED
PdfObjs              &ExportPdfQueue,PROTECTED
! ---- multiple sheets in one workbook (code-driven only, no dialog) --------
Sheets               &ExportSheetQueue,PROTECTED       ! finished sheets, waiting for EndWorkbook()
InWorkbook           BYTE,PROTECTED                    ! 1 = between StartWorkbook() and EndWorkbook()
CurSheetName         CSTRING(65),PROTECTED             ! the sheet StartSheet() is currently building
WorkbookRowsOut      LONG,PROTECTED                    ! running total across every sheet, for the completion popup
Buf                  &STRING,PROTECTED          ! the file text (or the xlsx sheet) being built
BufLen               LONG,PROTECTED
BufCap               LONG,PROTECTED
Arc                  &STRING,PROTECTED          ! the .xlsx ZIP / the PDF body, being assembled
ArcLen               LONG,PROTECTED
ArcCap               LONG,PROTECTED
U8                   &STRING,PROTECTED          ! UTF-8 scratch
U8Len                LONG,PROTECTED
U8Cap                LONG,PROTECTED
CrcTab               ULONG,DIM(256),PROTECTED
CrcReady             BYTE,PROTECTED
Started              BYTE,PROTECTED
Sig                  CSTRING(1025),PROTECTED    ! the LIST layout the column list was built from
Loaded               BYTE,PROTECTED             ! the saved settings have been read back once
ColSum               DECIMAL(20,6),DIM(64),PROTECTED   ! running per-USED-column sum
ColMin               DECIMAL(20,6),DIM(64),PROTECTED   ! running per-USED-column minimum
ColMax               DECIMAL(20,6),DIM(64),PROTECTED   ! running per-USED-column maximum
ColCount             LONG,DIM(64),PROTECTED            ! how many numeric values were accumulated per USED column
! ---- Subtotal / group rows (Excel .xlsx only) ------------------------------
GroupCol             LONG,PROTECTED                    ! which USED column (1..64) is the group-by column, 0 = none
GroupPrev            CSTRING(261),PROTECTED            ! previous row's group-by value, for detecting a break
GroupFirstRow        LONG,PROTECTED                    ! xlsx row number where the CURRENT group started
GroupHasRow          BYTE,PROTECTED                    ! at least one row written yet (suppresses a break on row 1)
XlsxRow              LONG,PROTECTED                    ! next physical xlsx row to write - data, subtotal, or total
GrpSum               DECIMAL(20,6),DIM(64),PROTECTED   ! per-group running sum, reset at each break
GrpMin               DECIMAL(20,6),DIM(64),PROTECTED   ! per-group running minimum
GrpMax               DECIMAL(20,6),DIM(64),PROTECTED   ! per-group running maximum
GrpCount             LONG,DIM(64),PROTECTED            ! how many numeric values went into the CURRENT group
! ---- SplitByGroup: the SAME grouping, but each group also gets its own ----
! ---- sheet (in addition to, not instead of, the single main sheet above) --
GrpBuf               &STRING,PROTECTED                 ! the CURRENT group's own worksheet XML, being built up
GrpBufLen            LONG,PROTECTED
GrpBufCap            LONG,PROTECTED
GrpXlsxRow           LONG,PROTECTED                    ! next row to write in the CURRENT group's OWN sheet - separate from the main sheet's XlsxRow
GrpFirstRow          LONG,PROTECTED                    ! that sheet's OWN first data row (always where GrpXlsxRow started) - NOT SELF.GroupFirstRow, which is the MAIN sheet's coordinate for the same group
! ---- decimal-preserving / parenthesised-negative number formats -----------
NumFmts              &ExportNumFmtQueue,PROTECTED      ! every distinct format actually used, shared across all sheets
ColStyleN            LONG,DIM(64),PROTECTED            ! per-USED-column cellXfs index for an ordinary numeric cell (0 = today's default style)
ColStyleT            LONG,DIM(64),PROTECTED            ! per-USED-column cellXfs index for a bold/bordered total cell (2 = today's default style)
! ---- Print (GDI) working state --------------------------------------------
PrnDC                LONG,PROTECTED             ! the printer HDC while a job is open
PrnFont              LONG,PROTECTED             ! current HFONT (body)
PrnFontB             LONG,PROTECTED             ! bold HFONT (heading)
PrnPageW             LONG,PROTECTED             ! printable width,  device pixels
PrnPageH             LONG,PROTECTED             ! printable height, device pixels
PrnMarginL           LONG,PROTECTED
PrnMarginT           LONG,PROTECTED
PrnDpiX              LONG,PROTECTED
PrnDpiY              LONG,PROTECTED
PrnY                 LONG,PROTECTED             ! current pen position, device pixels from the top margin
PrnRowH              LONG,PROTECTED             ! one row's height, device pixels
PrnPage              LONG,PROTECTED             ! current page number
PrnColX              LONG,DIM(64),PROTECTED     ! left edge of each USED column, device pixels
PrnColW              LONG,DIM(64),PROTECTED     ! width          of each USED column, device pixels
PrnColN              LONG,PROTECTED             ! how many USED columns PrnColX/W hold
! ---- PDF working state ------------------------------------------------------
PdfPageW             LONG,PROTECTED             ! page size, points (1/72")
PdfPageH             LONG,PROTECTED
PdfY                 LONG,PROTECTED             ! current pen position, points from the TOP of the page
PdfRowH              LONG,PROTECTED             ! one row's height, points
PdfPage              LONG,PROTECTED             ! current page number - kept UNCAPPED so PdfFinish can tell truncation happened
PdfNextObj           LONG,PROTECTED             ! next free PDF object number
PdfPagesObj          LONG,PROTECTED             ! object number of the /Pages tree
PdfCatalogObj        LONG,PROTECTED             ! object number of the /Catalog
PdfFontObj           LONG,PROTECTED             ! object number of /Helvetica
PdfFontBObj          LONG,PROTECTED             ! object number of /Helvetica-Bold
PdfKids              CSTRING(32769),PROTECTED   ! "N 0 R N 0 R ..." - one per REAL page (up to Exp:PdfPageCap), built as we go
PdfPageObjs          LONG,DIM(2000),PROTECTED   ! object number of each page (page count capped at Exp:PdfPageCap - see PdfNewPage)
PdfContObj           LONG,PROTECTED             ! object number of the CURRENT page's content stream
PdfDictOpen          CSTRING(3),PROTECTED       ! '<<' - built at runtime with CHR(60)&CHR(60) in PdfBegin().
                                                 ! A literal '<<' typed into a .clw string constant gets
                                                 ! silently collapsed to a single '<' by Clarion's own
                                                 ! <NNN> character-escape scanner (the same mechanism behind
                                                 ! Exp:CRLF's '<13,10>'), which corrupts every PDF dictionary
                                                 ! opener - so this one is never written as a literal.
PdfContent           &STRING,PROTECTED          ! the current page's content stream text, growing
PdfContLen           LONG,PROTECTED
PdfContCap           LONG,PROTECTED
PdfColX              LONG,DIM(64),PROTECTED     ! left edge of each USED column, points
PdfColW              LONG,DIM(64),PROTECTED     ! width          of each USED column, points
PdfColN              LONG,PROTECTED

! ---- setup ----------------------------------------------------------------
Construct            PROCEDURE
Destruct             PROCEDURE
Init                 PROCEDURE(SIGNED pList,*QUEUE pQ)
Kill                 PROCEDURE
ScanColumns          PROCEDURE(),LONG,PROC      ! read the LIST format if it changed -> column count
Rescan               PROCEDURE(),LONG,PROC      ! force a re-read, discarding any column edits
Columns              PROCEDURE(),LONG           ! how many data columns the LIST has
Selected             PROCEDURE(),LONG           ! how many of them are ticked for export

! ---- the column list (what the dialog edits; usable from your code too) ---
ResetColumns         PROCEDURE()                ! back to the LIST's own headings/pictures
SelectAll            PROCEDURE(BYTE pOn)        ! tick or untick every column
ColumnUse            PROCEDURE(LONG pCol,BYTE pOn)         ! include/exclude one column
ColumnRename         PROCEDURE(LONG pCol,STRING pHead)     ! blank = back to the list's heading
ColumnPicture        PROCEDURE(LONG pCol,STRING pPic)      ! blank = raw value, no picture
ColumnHeading        PROCEDURE(LONG pCol),STRING           ! what this column is called in the file
ColumnDefault        PROCEDURE(LONG pCol),STRING           ! what the LIST calls it
ColumnPic            PROCEDURE(LONG pCol),STRING
ColumnDefaultPic     PROCEDURE(LONG pCol),STRING           ! the picture the LIST uses

! ---- remembering the last export -----------------------------------------
LoadSettings         PROCEDURE()                ! restore format, folder, flags and columns
SaveSettings         PROCEDURE()                ! done for you after a successful export
ForgetSettings       PROCEDURE()                ! wipe this profile's saved settings
ColumnOn             PROCEDURE(LONG pCol),BYTE
ColumnIsNum          PROCEDURE(LONG pCol),BYTE              ! is this column classified as numeric
ColumnTotal          PROCEDURE(LONG pCol,BYTE pOn)          ! include/exclude one numeric column from the Totals row
ColumnTotalOn        PROCEDURE(LONG pCol),BYTE              ! is this column ticked for the Totals row
TotalsCount          PROCEDURE(),LONG                       ! how many columns are ticked for the Totals row
ColumnGroupBy        PROCEDURE(LONG pCol,BYTE pOn)          ! marks pCol as THE group-by/subtotal column (single-select: turning one on turns any other off); pOn=0 clears it
ColumnGroupOn        PROCEDURE(LONG pCol),BYTE               ! is pCol the group-by column?

! ---- the run-time dialog --------------------------------------------------
Ask                  PROCEDURE(),BYTE,VIRTUAL   ! modal format + file name dialog. 1 = go
AskFileName          PROCEDURE(),BYTE,VIRTUAL   ! just the Save-As dialog, for SELF.Fmt
FormatName           PROCEDURE(LONG pFmt),STRING
FormatExt            PROCEDURE(LONG pFmt),STRING
FormatMask           PROCEDURE(LONG pFmt),STRING
FormatHint           PROCEDURE(LONG pFmt),STRING           ! the one-liner shown under the dialog
Allowed              PROCEDURE(LONG pFmt),BYTE
SuggestName          PROCEDURE(),STRING         ! Title (or the window title) + today's date
ForceExt             PROCEDURE(LONG pFmt)       ! swap SELF.FileName's extension to match pFmt
Note                 PROCEDURE(STRING pText,STRING pTitle,LONG pIcon),VIRTUAL   ! modal popup
Txt                  PROCEDURE(LONG pId),STRING,VIRTUAL   ! one string, in SELF.Language

! ---- writing --------------------------------------------------------------
StartFile            PROCEDURE(),BYTE           ! begin; writes the preamble + heading row
AddRow               PROCEDURE()                ! append the row now in the QUEUE BUFFER
EndFile              PROCEDURE(),BYTE,PROC      ! finish, write to disk, optionally open it
! ---- multiple sheets in one .xlsx (code-driven only - see the docs) -------
StartWorkbook        PROCEDURE(),BYTE           ! once, before the first sheet - Exp:XLSX only
StartSheet           PROCEDURE(STRING pName),BYTE   ! like StartFile(), but for one sheet in the shared workbook
EndSheet             PROCEDURE(),BYTE           ! like EndFile()'s worksheet half, but stashes instead of writing
EndWorkbook          PROCEDURE(),BYTE,PROC      ! assembles every stashed sheet and writes the .xlsx to disk
ExportQueue          PROCEDURE(),BYTE,PROC      ! StartFile + every record in SELF.Q + EndFile
Run                  PROCEDURE(),BYTE,PROC      ! Ask + ExportQueue

! ---- printing (SELF.Fmt = Exp:Print; also callable stand-alone) -----------
!  Same StartFile/AddRow/EndFile engine drives Print too - when Fmt=Exp:Print,
!  StartFile() opens the printer (SELF.PrinterName, or the Windows default)
!  and starts the print job instead of a file, AddRow() draws a row with GDI,
!  and EndFile() ends the job. PrintOut() is the one-call version for
!  hand-coded use, independent of Ask()/ExportQueue. (Named PrintOut, not
!  Print - PRINT is a reserved Clarion intrinsic statement, so a class cannot
!  have a method called Print.)
PrintOut             PROCEDURE(),BYTE,PROC,VIRTUAL   ! opens the printer + StartFile+rows+EndFile
                                                      ! (named PrintOut, not Print - PRINT is a
                                                      ! Clarion intrinsic statement, reserved)
PageSetup            PROCEDURE(),BYTE,PROC,VIRTUAL   ! Windows Page Setup dialog -> Orient/Margins/Paper

! ---- preview (no REPORT structure, so no built-in Clarion PrintPreviewClass)
!  Builds the SAME PDF Exp:PDF would, into a temp file, then opens it in
!  whatever the user's default PDF viewer is - that viewer's own zoom/page
!  controls become the preview UI, at zero extra Win32 risk. Not a pixel-exact
!  match for Print() (different font metrics), but the layout and pagination
!  are the same, since both share PdfColumnWidths' proportional column logic.
PreviewOut           PROCEDURE(),BYTE,PROC,VIRTUAL   ! temp PDF + ShellOpen it

! ---- one cell (VIRTUAL - override to reshape a value) ---------------------
HeaderText           PROCEDURE(LONG pCol),STRING,VIRTUAL
CellText             PROCEDURE(LONG pCol),STRING,VIRTUAL   ! display text (picture applied)
CellNumber           PROCEDURE(LONG pCol),STRING,VIRTUAL   ! raw numeric literal

! ---- helpers (protected) --------------------------------------------------
Need                 PROCEDURE(LONG pAdd),PROTECTED         ! grow Buf to hold pAdd more bytes
Cat                  PROCEDURE(STRING pText),PROTECTED      ! append to Buf
ArcNeed              PROCEDURE(LONG pAdd),PROTECTED
ArcCat               PROCEDURE(STRING pText),PROTECTED      ! append to Arc
U8Need               PROCEDURE(LONG pSize),PROTECTED
FreeBuffers          PROCEDURE,PROTECTED
Sep                  PROCEDURE(),STRING,PROTECTED           ! the delimited-format separator
! ...the Cat*Field/Text helpers escape straight into Buf: a value with nothing
! to escape costs one Cat, so a big export never pays per-character overhead.
CatCsvField          PROCEDURE(STRING pText,STRING pDelim),PROTECTED
CatFlatField         PROCEDURE(STRING pText),PROTECTED      ! TSV: no tabs/newlines survive
CatXmlText           PROCEDURE(STRING pText),PROTECTED
CatJsonText          PROCEDURE(STRING pText),PROTECTED
CatHtmlText          PROCEDURE(STRING pText),PROTECTED
Classify             PROCEDURE(LONG pCol),PROTECTED        ! re-derive Tag + IsNum from Head/Pic
LayoutSig            PROCEDURE(),STRING,PROTECTED          ! a fingerprint of the LIST's format
SigKey               PROCEDURE(),STRING,PROTECTED          ! that fingerprint, short enough for an INI
IniPath              PROCEDURE(),STRING,PROTECTED          ! IniFile, or <the exe>.INI
IniSection           PROCEDURE(),STRING,PROTECTED          ! [myExport_<profile>]
FolderOf             PROCEDURE(STRING pPath),STRING,PROTECTED
SafeTag              PROCEDURE(STRING pText,LONG pCol),STRING,PROTECTED
SheetName            PROCEDURE(STRING pText),STRING,PROTECTED
ColRef               PROCEDURE(LONG pCol),STRING,PROTECTED  ! 1 -> A, 27 -> AA
IsAscii              PROCEDURE(*STRING pData,LONG pLen),BYTE,PROTECTED
ToUTF8               PROCEDURE(*STRING pData,LONG pLen),PROTECTED   ! -> SELF.U8 / SELF.U8Len
WriteDisk            PROCEDURE(STRING pFile,*STRING pData,LONG pLen),BYTE,PROTECTED
ShellOpen            PROCEDURE(STRING pFile),PROTECTED
EmailFile            PROCEDURE(STRING pFile),PROTECTED,VIRTUAL  ! Simple MAPI by default - override this in a derived class to use something else (e.g. CapeSoft Office Inside's oiOutlook.SendEmail) instead
CrcInit              PROCEDURE,PROTECTED
CRC32                PROCEDURE(*STRING pData,LONG pLen),ULONG,PROTECTED
Le16                 PROCEDURE(ULONG pVal),STRING,PROTECTED
Le32                 PROCEDURE(ULONG pVal),STRING,PROTECTED
ZipAdd               PROCEDURE(STRING pName,*STRING pData,LONG pLen),PROTECTED
ZipFinish            PROCEDURE,PROTECTED
XlsxSubtotalRow      PROCEDURE(STRING pGroupLabel,LONG pFrow,LONG pLrow),PROTECTED  ! one subtotal row for the group just finished
XlsxTotalsRow        PROCEDURE(),PROTECTED                  ! bold =SUM() row (StartFile resets ColSum, AddRow accumulates it)
XlsxSheetBegin       PROCEDURE(),PROTECTED                  ! the worksheet-XML preamble - shared by StartFile() and StartSheet()
XlsxSheetEnd         PROCEDURE(),PROTECTED                  ! the worksheet-XML close - shared by EndFile() and EndSheet()
XlsxStashSheet       PROCEDURE(STRING pName),PROTECTED      ! moves the finished sheet in SELF.Buf into SELF.Sheets, UTF-8 already applied
XmlAttr              PROCEDURE(STRING pText),STRING,PROTECTED  ! XML-escapes a short value for use INSIDE an attribute (e.g. a sheet name)
! ---- SplitByGroup's own, separate worksheet-XML buffer --------------------
GrpNeed              PROCEDURE(LONG pAdd),PROTECTED         ! grows GrpBuf - GrpBuf's own Need()
GrpCat               PROCEDURE(STRING pText),PROTECTED      ! appends to GrpBuf - GrpBuf's own Cat()
GrpCatXmlText        PROCEDURE(STRING pText),PROTECTED      ! GrpBuf's own CatXmlText() - no length cap, unlike XmlAttr
GrpSheetBegin        PROCEDURE(),PROTECTED                  ! the worksheet preamble for the CURRENT group's own sheet
GrpSheetEnd          PROCEDURE(LONG pFrow,LONG pLrow),PROTECTED  ! this group's own Sum/Avg/Min/Max row(s) + close tags
GrpStashSheet        PROCEDURE(STRING pGroupValue),PROTECTED  ! moves GrpBuf into SELF.Sheets, named after the group value
XlsxMoveLastToFirst  PROCEDURE(),PROTECTED                  ! SplitByGroup: the just-stashed main sheet ends up last - move it back to position 1
PicDecimals          PROCEDURE(STRING pPic),LONG,PROTECTED  ! how many decimal places a Clarion @N picture shows (0 = none/unparseable)
XlsxNumFmtCode       PROCEDURE(LONG pDecimals),STRING,PROTECTED  ! the Excel format code for that many decimals, e.g. '0.00'
XlsxRegisterNumFmt   PROCEDURE(LONG pDecimals),LONG,PROTECTED    ! finds or creates SELF.NumFmts' entry for pDecimals + SELF.NegativeParens, returns its row position
XlsxWrite            PROCEDURE(),BYTE,PROTECTED             ! zip the parts and write the .xlsx

! ---- Print internals (GDI) -------------------------------------------------
PrnBegin             PROCEDURE(),BYTE,PROTECTED             ! opens the printer DC, StartDoc, fonts, column widths
PrnNewPage           PROCEDURE(),PROTECTED                  ! StartPage + repeat the heading row
PrnHeader            PROCEDURE(),PROTECTED                  ! draw the heading row at SELF.PrnY
PrnRow               PROCEDURE(),PROTECTED                  ! draw the QUEUE BUFFER's row at SELF.PrnY
PrnCell              PROCEDURE(LONG pCol,STRING pText,BYTE pBold),PROTECTED
PrnEnd               PROCEDURE(),BYTE,PROTECTED             ! EndPage/EndDoc, release the DC + fonts
PrnColumnWidths      PROCEDURE(),PROTECTED                  ! Cols.Width -> PrnColX/PrnColW (device px)

! ---- PDF internals ----------------------------------------------------------
PdfBegin             PROCEDURE(),BYTE,PROTECTED             ! page size/margins, catalog+font objects
PdfNewPage           PROCEDURE(),PROTECTED                  ! open a new page's content stream
PdfClosePage         PROCEDURE(),PROTECTED                  ! flush the content stream to an object
PdfHeader            PROCEDURE(),PROTECTED
PdfRow               PROCEDURE(),PROTECTED
PdfCell              PROCEDURE(LONG pCol,STRING pText,BYTE pBold),PROTECTED
PdfFinish            PROCEDURE(),BYTE,PROTECTED             ! Pages tree + xref + trailer, WriteDisk
PdfColumnWidths      PROCEDURE(),PROTECTED                  ! Cols.Width -> PdfColX/PdfColW (points)
PdfBeginObj          PROCEDURE(LONG pNum),PROTECTED          ! "N 0 obj" - records the offset for xref, into SELF.Arc
PdfNum               PROCEDURE(LONG pVal),STRING,PROTECTED  ! a plain, unpadded decimal string - every number in the PDF goes through this, not a raw '&'
PdfPad10             PROCEDURE(ULONG pVal),STRING,PROTECTED  ! a byte offset, zero-padded to 10 digits (xref format)
PdfContNeed          PROCEDURE(LONG pAdd),PROTECTED
PdfContCat           PROCEDURE(STRING pText),PROTECTED       ! append to the current page's content stream
PdfEscape            PROCEDURE(STRING pText),STRING,PROTECTED
PdfStrWidth          PROCEDURE(STRING pText,LONG pSize,BYTE pBold),LONG,PROTECTED  ! Helvetica AFM, 1/1000 em
PdfClip              PROCEDURE(STRING pText,LONG pSize,BYTE pBold,LONG pMaxWidth),STRING,PROTECTED
                   END

  _EndOfInclude_
