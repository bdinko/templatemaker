!ABCIncludeFile(MYWORDDOC)
! ============================================================================
!  WordDocClass - a word processor on a Clarion window, stored in a BLOB.
!
!  The control is our own: wdoc.c (compiled into your exe by Clarion's own C
!  compiler - no DLL, no OCX, no COM registration) registers a host window
!  that paints its own toolbar and holds the Windows text engine (RichEdit,
!  msftedit.dll) as its editing surface. Text, fonts, colours, alignment,
!  bullets, numbering, indents, pictures and tables are all supported, and
!  the whole document is plain RTF, so it fits a BLOB and Word can open it.
!
!  ON A WINDOW (the myWordDoc control template writes this for you)
!    INCLUDE('WordDocClass.INC'),ONCE
!    Doc1   WordDocClass
!
!    ! after OPEN(window):
!      Doc1.Init(0{PROP:Handle}, ?DocRegion)       ! a REGION marks where it goes
!      Doc1.LoadBlob(DOC:Body)
!    ! in the ACCEPT loop, for every event:
!      Doc1.TakeEvent()                            ! follows resizes / tabs
!    ! when the record is saved:
!      Doc1.SaveBlob(DOC:Body)
!    ! before CLOSE(window):
!      Doc1.Kill()
!
!  ON A REPORT (the myWordDocReport extension writes this for you)
!    Doc1.InitHidden()
!    Doc1.LoadBlob(DOC:Body)
!    LOOP Page# = 1 TO Doc1.PaginateForReport(Report, ?DocImage, WD:Flow)
!      Doc1.PreparePage(Report, ?DocImage, Page#)  ! points the IMAGE at piece N
!      PRINT(RPT:DocBand)
!    END
!  WD:Flow prints the document one line per band, so it starts in whatever
!  room is left on the page and carries on over the next pages. WD:Pages
!  prints it in pieces the size of the IMAGE (a new page when one won't fit).
!    Doc1.Kill()
!
!  The pages are vector metafiles, so the text stays sharp and PDFs stay small.
!
!  FILES: WordDocClass.inc, WordDocClass.clw and wdoc.c on the redirection
!         path. Save as ANSI, CRLF.
! ============================================================================

  OMIT('_EndOfInclude_',_WordDocClassPresent_)
_WordDocClassPresent_ EQUATE(1)

! ---- Init flags (match WDF_* in wdoc.c) -----------------------------------
WD:Toolbar         EQUATE(1)                   ! our own formatting toolbar on top
WD:ReadOnly        EQUATE(2)                   ! view only
WD:PageView        EQUATE(4)                   ! show the printed width on a grey desk
WD:NoBorder        EQUATE(8)

! ---- alignment -------------------------------------------------------------
WD:Left            EQUATE(1)
WD:Right           EQUATE(2)
WD:Center          EQUATE(3)
WD:Justify         EQUATE(4)

! ---- lists -----------------------------------------------------------------
WD:NoList          EQUATE(0)
WD:Bullets         EQUATE(1)
WD:Numbers         EQUATE(2)                   ! 1. 2. 3.
WD:LowerLetters    EQUATE(3)                   ! a. b. c.
WD:UpperLetters    EQUATE(4)                   ! A. B. C.
WD:LowerRoman      EQUATE(5)                   ! i. ii. iii.
WD:UpperRoman      EQUATE(6)                   ! I. II. III.

! ---- Bold()/Italic()/... argument -------------------------------------------
WD:Off             EQUATE(0)
WD:On              EQUATE(1)
WD:Toggle          EQUATE(2)

! ---- what a page of A4 / Letter holds, in twips (1/1440 inch) --------------
WD:LetterWidth     EQUATE(12240 - 2880)        ! 8.5in less 1in margins
WD:A4Width         EQUATE(11906 - 2880)

! PaginateForReport modes
WD:Pages           EQUATE(0)                   ! pieces the size of the IMAGE
WD:Flow            EQUATE(1)                   ! line by line: fills the room left on a page

WordDocClass CLASS,TYPE,MODULE('WordDocClass.CLW'),LINK('WordDocClass.CLW')

! ---- set these BEFORE Init (or pass pFlags) --------------------------------
ShowToolbar          BYTE(1)
ReadOnly             BYTE
PageView             BYTE                      ! needs PageWidth
PageWidth            LONG                      ! printed line width, twips; 0 = wrap at the window
DefaultFont          CSTRING(32)               ! blank = Segoe UI
DefaultSize          REAL                      ! points; 0 = 11

! ---- read-only state --------------------------------------------------------
Err                  LONG                      ! non-zero when Init could not create the control
Pages                LONG                      ! from the last Paginate

! ---- internals ---------------------------------------------------------------
H                    LONG,PRIVATE              ! our slot inside wdoc.c
Feq                  LONG,PRIVATE              ! the placeholder REGION
WinHandle            LONG,PRIVATE
Shown                BYTE,PRIVATE
LastX                LONG,PRIVATE
LastY                LONG,PRIVATE
LastW                LONG,PRIVATE
LastH                LONG,PRIVATE
PageW                LONG,PRIVATE              ! twips, from the last Paginate
PageH                LONG,PRIVATE
Rendered             LONG,PRIVATE              ! highest page written to %TEMP%
Buf                  &STRING,PRIVATE           ! holds GetRtf/GetText results
FullH                LONG,PRIVATE              ! report IMAGE height before shrinking (thous)
BandH                LONG,PRIVATE              ! its band's height before shrinking (thous)
ShrunkFeq            LONG,PRIVATE              ! the IMAGE a last page left shrunk (0 = none)
FullY                LONG,PRIVATE              ! report IMAGE top before flowing (thous)
Flow                 BYTE,PRIVATE              ! last PaginateForReport cut it line by line

! ---- life cycle ---------------------------------------------------------------
Init                 PROCEDURE(LONG pWinHandle,LONG pFeq,LONG pFlags=-1),BYTE,PROC
InitHidden           PROCEDURE(),BYTE,PROC     ! an invisible document, for reports
Kill                 PROCEDURE()
TakeEvent            PROCEDURE(),BYTE,PROC     ! call for EVERY event; true when edited since last call
Reposition           PROCEDURE()               ! follow the placeholder (done by TakeEvent)
Alive                PROCEDURE(),BYTE
Hwnd                 PROCEDURE(),LONG
Slot                 PROCEDURE(),LONG          ! the document's number inside wdoc.c (WordDocTools uses it)
StructSizes          PROCEDURE(),LONG          ! diagnostic: 84188 when the C structs match Win32

! ---- content ---------------------------------------------------------------------
LoadBlob             PROCEDURE(*BLOB pBlob)
SaveBlob             PROCEDURE(*BLOB pBlob)
LoadString           PROCEDURE(STRING pRtfOrText)
GetRtf               PROCEDURE(),STRING
GetText              PROCEDURE(),STRING        ! plain text, for searching/indexing
LoadFile             PROCEDURE(STRING pFileName),BYTE,PROC
SaveFile             PROCEDURE(STRING pFileName),BYTE,PROC
ClearAll             PROCEDURE()
Length               PROCEDURE(),LONG          ! characters
Modified             PROCEDURE(),BYTE
SetModified          PROCEDURE(BYTE pOn)

! ---- inserting ---------------------------------------------------------------------
InsertText           PROCEDURE(STRING pText)
InsertRtf            PROCEDURE(STRING pRtf)
InsertImage          PROCEDURE(STRING pFileName,LONG pMaxWidthTw=0),LONG,PROC  ! PNG JPG BMP EMF WMF
InsertTable          PROCEDURE(LONG pRows,LONG pCols,LONG pWidthTw=0),BYTE,PROC

! ---- formatting the selection -------------------------------------------------------
Bold                 PROCEDURE(BYTE pHow=WD:Toggle)
Italic               PROCEDURE(BYTE pHow=WD:Toggle)
Underline            PROCEDURE(BYTE pHow=WD:Toggle)
Strike               PROCEDURE(BYTE pHow=WD:Toggle)
SetFont              PROCEDURE(STRING pFace)
SetFontSize          PROCEDURE(REAL pPoints)
SetColor             PROCEDURE(LONG pColor)    ! COLOR:None = automatic
SetHighlight         PROCEDURE(LONG pColor)    ! COLOR:None = no highlight
SetAlign             PROCEDURE(BYTE pAlign)
SetList              PROCEDURE(BYTE pStyle)
Indent               PROCEDURE(LONG pTwips=360)
Outdent              PROCEDURE(LONG pTwips=360)
GetFont              PROCEDURE(),STRING        ! blank when the selection mixes fonts
GetFormat            PROCEDURE(LONG pWhich),LONG ! 1 bold..4 strike, 5 size*10, 6 colour, 7 highlight, 8 align, 9 list; -1 mixed

! ---- editing ---------------------------------------------------------------------------
Undo                 PROCEDURE()               ! Ctrl+Z; a tool operation (Replace All, a merge...) is one step
Redo                 PROCEDURE()
CanUndo              PROCEDURE(),BYTE
CanRedo              PROCEDURE(),BYTE
ClearUndo            PROCEDURE()               ! forget the history (LoadBlob/LoadString/LoadFile do it)
SetUndoLimit         PROCEDURE(LONG pSteps)    ! how many steps are kept (RichEdit's default is 100)
BeginUndoGroup       PROCEDURE()               ! everything until EndUndoGroup undoes as ONE step;
EndUndoGroup         PROCEDURE()               ! pairs nest
CutText              PROCEDURE()
CopyText             PROCEDURE()
PasteText            PROCEDURE()
SelectAll            PROCEDURE()
SelectText           PROCEDURE(LONG pFrom,LONG pTo)
Find                 PROCEDURE(STRING pText,BYTE pMatchCase=0,BYTE pWholeWord=0),LONG,PROC
Focus                PROCEDURE()
SetReadOnly          PROCEDURE(BYTE pOn)
SetToolbar           PROCEDURE(BYTE pOn)
SetZoom              PROCEDURE(LONG pPercent)  ! 0 = 100%
SetPaperColor        PROCEDURE(LONG pColor)    ! COLOR:None = window colour
SetPageWidth         PROCEDURE(LONG pTwips)

! ---- printing ------------------------------------------------------------------------------
Paginate             PROCEDURE(LONG pWidthTw,LONG pHeightTw),LONG,PROC
RenderPage           PROCEDURE(LONG pPage),STRING  ! writes page N to %TEMP% as a .wmf; returns its path
RenderPageTo         PROCEDURE(LONG pPage,STRING pFileName),BYTE,PROC  ! .emf or .wmf, by extension
PageUsedHeight       PROCEDURE(LONG pPage),LONG    ! twips actually filled on page N
PaginateForReport    PROCEDURE(*REPORT pReport,LONG pImageFeq,BYTE pMode=0),LONG  ! WD:Pages / WD:Flow
PreparePage          PROCEDURE(*REPORT pReport,LONG pImageFeq,LONG pPage,BYTE pShrinkLast=1)
                   END

  _EndOfInclude_
