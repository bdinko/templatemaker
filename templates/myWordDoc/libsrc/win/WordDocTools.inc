!ABCIncludeFile(MYWORDDOC)
! ============================================================================
!  WordDocTools - things to do with an RTF document, beside the editor.
!
!    RtfSearchClass    find, find next/previous, count, replace, replace all,
!                      highlight every hit, the text around a hit
!    RtfFontClass      what font/size/style a position or the selection has,
!                      the fonts a document uses, replace a font, resize all
!    RtfTextClass      RTF to plain text (lists and tables kept readable),
!                      word/character/paragraph counts, excerpts, text to RTF
!    RtfHtmlClass      RTF to HTML - a page or a fragment, pictures embedded
!                      or written as files
!    RtfMarkdownClass  RTF to Markdown - headings, lists, tables, pictures
!    RtfMergeClass     mail merge: [[Name]] placeholders filled from your
!                      values or straight from BIND()ed file fields
!
!  Every class works on a document in one of two ways:
!    Tool.Attach(Doc1)            ! an editor on a window, or a report's document:
!                                 ! the tool works on what the user sees
!    Tool.LoadBlob(DOC:Body)      ! or its own hidden document: LoadString,
!                                 ! LoadBlob or LoadFile, and SaveBlob/SaveFile
!                                 ! to keep the changes
!  Positions are 0-based character positions, the same ones
!  WordDocClass.SelectText uses (a paragraph break counts as one character).
!
!  On a live editor the tools keep the user's selection and scroll position
!  (Find and FindNext move the selection to the hit on purpose).
!
!  FILES: WordDocTools.inc and WordDocTools.clw beside WordDocClass.inc/.clw
!         and wdoc.c on the redirection path. ANSI, CRLF.
! ============================================================================

  OMIT('_EndOfInclude_',_WordDocToolsPresent_)
_WordDocToolsPresent_ EQUATE(1)

  INCLUDE('WordDocClass.INC'),ONCE

! one field for RtfMergeClass
RtfMergeFieldQ     QUEUE,TYPE
Name                 STRING(64)
Value                &STRING
                   END

! ----------------------------------------------------------------------------
!  RtfToolBase - the document every tool works on
! ----------------------------------------------------------------------------
RtfToolBase        CLASS,TYPE,MODULE('WordDocTools.CLW'),LINK('WordDocTools.CLW')
Doc                  &WordDocClass             ! the document worked on
Own                  BYTE,PROTECTED            ! we made Doc ourselves (hidden)
Buf                  &STRING,PROTECTED         ! holds the last text result

Attach               PROCEDURE(*WordDocClass pDoc)       ! work on an existing document
LoadString           PROCEDURE(STRING pRtfOrText),BYTE,PROC
LoadBlob             PROCEDURE(*BLOB pBlob),BYTE,PROC
LoadFile             PROCEDURE(STRING pFileName),BYTE,PROC
SaveBlob             PROCEDURE(*BLOB pBlob)
SaveFile             PROCEDURE(STRING pFileName),BYTE,PROC  ! the RTF
GetRtf               PROCEDURE(),STRING
Ready                PROCEDURE(),BYTE          ! a document is there to work on
Undo                 PROCEDURE()               ! takes back the last change - a whole ReplaceAll,
Redo                 PROCEDURE()               ! SetFontAll or Merge is one step
CanUndo              PROCEDURE(),BYTE
Kill                 PROCEDURE()
Destruct             PROCEDURE()

H                    PROCEDURE(),LONG,PROTECTED                  ! the document's slot in wdoc.c
Hidden               PROCEDURE(),BYTE,PROTECTED                  ! makes our own hidden document
Fetch                PROCEDURE(LONG pLen),STRING,PROC,PROTECTED       ! the C result -> SELF.Buf
SaveBuf              PROCEDURE(STRING pFileName),BYTE,PROTECTED  ! writes SELF.Buf to a file
                   END

! ----------------------------------------------------------------------------
!  RtfSearchClass - find, count, replace
! ----------------------------------------------------------------------------
RtfSearchClass     CLASS(RtfToolBase),TYPE,MODULE('WordDocTools.CLW'),LINK('WordDocTools.CLW')
MatchCase            BYTE                      ! "Smith" does not find "smith"
WholeWord            BYTE                      ! "art" does not find "party"
Wrap                 BYTE(1)                   ! FindNext/FindPrevious go round the end
SelectHits           BYTE(1)                   ! select (and scroll to) each hit

FoundAt              LONG(-1)                  ! the last hit: start (-1 = none) ...
FoundEnd             LONG(-1)                  ! ... and end
What                 CSTRING(1024)             ! what the last Find looked for

Find                 PROCEDURE(STRING pText),LONG,PROC      ! first hit from the top; -1 none
FindNext             PROCEDURE(),LONG,PROC                  ! the next hit after the last one
FindPrevious         PROCEDURE(),LONG,PROC
Count                PROCEDURE(STRING pText),LONG
Replace              PROCEDURE(STRING pFind,STRING pWith),BYTE,PROC  ! the current hit, then finds the next
ReplaceAll           PROCEDURE(STRING pFind,STRING pWith),LONG,PROC  ! returns how many
HighlightAll         PROCEDURE(STRING pText,LONG pColor=COLOR:Yellow),LONG,PROC  ! COLOR:None takes it off
Context              PROCEDURE(LONG pChars=40),STRING       ! "...text around the last hit..."
TextAt               PROCEDURE(LONG pFrom,LONG pTo),STRING  ! plain text of a range

Flags                PROCEDURE(BYTE pForward),LONG,PROTECTED
Hit                  PROCEDURE(LONG pAt),LONG,PROTECTED
                   END

! ----------------------------------------------------------------------------
!  RtfFontClass - which font am I on, and the fonts in a document
! ----------------------------------------------------------------------------
RtfFontClass       CLASS(RtfToolBase),TYPE,MODULE('WordDocTools.CLW'),LINK('WordDocTools.CLW')
! ---- filled by Read() -------------------------------------------------------
Face                 CSTRING(32)               ! '' = the selection mixes fonts
Size                 REAL                      ! points; 0 = mixed sizes
Bold                 LONG                      ! 1 / 0, -1 = mixed
Italic               LONG
Underline            LONG
Strike               LONG
Script               LONG                      ! 0 normal, 1 superscript, 2 subscript, -1 mixed
Color                LONG                      ! COLOR:None = automatic, -2 = mixed
Highlight            LONG                      ! COLOR:None = none, -2 = mixed
Align                LONG                      ! WD:Left/Right/Center/Justify, -1 mixed
List                 LONG                      ! WD:NoList/Bullets/Numbers..., -1 mixed

Read                 PROCEDURE(LONG pPos=-1),BYTE,PROC     ! -1 = the selection; else the character at pPos
Describe             PROCEDURE(),STRING        ! "Georgia 12pt, bold, italic" from the last Read

FontCount            PROCEDURE(),LONG          ! scans the document: how many fonts it uses
FontName             PROCEDURE(LONG pN),STRING ! 1..FontCount
FontChars            PROCEDURE(LONG pN),LONG   ! characters set in font N
FontList             PROCEDURE(<STRING pSep>),STRING  ! every font, separated by pSep (default ", ")
MainFont             PROCEDURE(),STRING        ! the font most of the text uses

ReplaceFont          PROCEDURE(STRING pOld,STRING pNew),LONG,PROC  ! stretches changed
SetFontAll           PROCEDURE(STRING pFace,REAL pPoints=0)       ! '' / 0 leave that part
SetFontRange         PROCEDURE(LONG pFrom,LONG pTo,STRING pFace,REAL pPoints=0)
ScaleSizes           PROCEDURE(LONG pPercent),LONG,PROC            ! 120 = every size 20% bigger
                   END

! ----------------------------------------------------------------------------
!  RtfTextClass - RTF to plain text, counts, excerpts
! ----------------------------------------------------------------------------
RtfTextClass       CLASS(RtfToolBase),TYPE,MODULE('WordDocTools.CLW'),LINK('WordDocTools.CLW')
ListPrefixes         BYTE(1)                   ! "- " / "1." in front of list items
Bullet               CSTRING(16)               ! what a bullet becomes; '' = '- '
TabCells             BYTE(1)                   ! table cells separated by TAB (else ' | ')
PictureMarks         BYTE                      ! write [picture] where a picture was
Utf8                 BYTE                      ! UTF-8 instead of the ANSI code page

ToText               PROCEDURE(),STRING,PROC
SaveText             PROCEDURE(STRING pFileName),BYTE,PROC
WordCount            PROCEDURE(),LONG
CharCount            PROCEDURE(BYTE pWithSpaces=1),LONG
ParagraphCount       PROCEDURE(),LONG          ! paragraphs that have text
PictureCount         PROCEDURE(),LONG
TableCount           PROCEDURE(),LONG
Excerpt              PROCEDURE(LONG pMaxChars=200),STRING  ! one line, cut at a word, with '...'
IsRtf                PROCEDURE(STRING pText),BYTE
TextToRtf            PROCEDURE(STRING pText,<STRING pFace>,REAL pPoints=0),STRING  ! plain text -> an RTF document
                   END

! ----------------------------------------------------------------------------
!  RtfHtmlClass - RTF to HTML
! ----------------------------------------------------------------------------
RtfHtmlClass       CLASS(RtfToolBase),TYPE,MODULE('WordDocTools.CLW'),LINK('WordDocTools.CLW')
FullPage             BYTE(1)                   ! 0 = a <div> fragment for an e-mail or a page you build
Title                CSTRING(256)              ! the page's <title>
SkipPictures         BYTE
ImageFolder          CSTRING(261)              ! '' = pictures embedded as data: URIs;
ImageUrl             CSTRING(261)              ! else written there as image1.png... and
                                               ! linked as ImageUrl & 'image1.png'
ToHtml               PROCEDURE(),STRING,PROC   ! UTF-8
SaveHtml             PROCEDURE(STRING pFileName),BYTE,PROC
                   END

! ----------------------------------------------------------------------------
!  RtfMarkdownClass - RTF to Markdown
! ----------------------------------------------------------------------------
RtfMarkdownClass   CLASS(RtfToolBase),TYPE,MODULE('WordDocTools.CLW'),LINK('WordDocTools.CLW')
SkipPictures         BYTE
ImageFolder          CSTRING(261)              ! as RtfHtmlClass
ImageUrl             CSTRING(261)
ToMarkdown           PROCEDURE(),STRING,PROC   ! UTF-8
SaveMarkdown         PROCEDURE(STRING pFileName),BYTE,PROC
                   END

! ----------------------------------------------------------------------------
!  RtfMergeClass - fill [[Name]] placeholders
! ----------------------------------------------------------------------------
RtfMergeClass      CLASS(RtfToolBase),TYPE,MODULE('WordDocTools.CLW'),LINK('WordDocTools.CLW')
FieldOpen            CSTRING(9)                ! '' = '[['
FieldClose           CSTRING(9)                ! '' = ']]'
UseBound             BYTE(1)                   ! a field you did not Set is looked up with
                                               ! EVALUATE - so BIND(Customers) fills [[CUS:Name]]
BlankUnknown         BYTE                      ! a placeholder nobody filled becomes ''
Fields               &RtfMergeFieldQ,PRIVATE
Found                &RtfMergeFieldQ,PRIVATE

SetField             PROCEDURE(STRING pName,STRING pValue)
ClearFields          PROCEDURE()
Merge                PROCEDURE(),LONG,PROC     ! placeholders replaced
FieldCount           PROCEDURE(),LONG          ! distinct placeholders in the document
FieldName            PROCEDURE(LONG pN),STRING
Missing              PROCEDURE(),STRING        ! placeholders with no value, comma-separated
Destruct             PROCEDURE()               ! RtfToolBase.Destruct runs as well

Opener               PROCEDURE(),STRING,PRIVATE
Closer               PROCEDURE(),STRING,PRIVATE
Scan                 PROCEDURE(),PRIVATE
ValueOf              PROCEDURE(STRING pName,*BYTE pKnown),STRING,PROC,PRIVATE
                   END

  _EndOfInclude_
