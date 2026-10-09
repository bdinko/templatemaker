! ============================================================================
!  WordDocTools - implementation.
!
!  The work is done in wdoc.c (already compiled into the exe by WordDocClass):
!  it walks the RichEdit document itself, so every RTF Word or WordPad writes
!  is understood the same way the editor understands it. This file is the
!  Clarion face of it. Text results come back through the document's buffer,
!  the same way WordDocClass.GetRtf gets its RTF.
!
!  This file MUST be stored in ANSI (not UTF-8), with CRLF line endings.
! ============================================================================
  MEMBER

  INCLUDE('WordDocTools.INC'),ONCE

  MAP
    MODULE('wdoc.c')
wt_copy            PROCEDURE(LONG,*STRING,LONG),LONG,RAW,PROC,NAME('_wdoc_copy')
wt_length          PROCEDURE(LONG),LONG,NAME('_wdoc_length')
wt_find_at         PROCEDURE(LONG,*CSTRING,LONG,LONG,LONG),LONG,RAW,NAME('_wdoc_find_at')
wt_found_end       PROCEDURE(LONG),LONG,NAME('_wdoc_found_end')
wt_show_range      PROCEDURE(LONG,LONG,LONG),NAME('_wdoc_show_range')
wt_count           PROCEDURE(LONG,*CSTRING,LONG),LONG,RAW,NAME('_wdoc_count')
wt_replace_range   PROCEDURE(LONG,LONG,LONG,*CSTRING),LONG,RAW,PROC,NAME('_wdoc_replace_range')
wt_replace_all     PROCEDURE(LONG,*CSTRING,*CSTRING,LONG),LONG,RAW,NAME('_wdoc_replace_all')
wt_mark_all        PROCEDURE(LONG,*CSTRING,LONG,LONG),LONG,RAW,NAME('_wdoc_mark_all')
wt_text_range      PROCEDURE(LONG,LONG,LONG),LONG,NAME('_wdoc_text_range')
wt_runs            PROCEDURE(LONG),LONG,PROC,NAME('_wdoc_runs')
wt_face_count      PROCEDURE(LONG),LONG,NAME('_wdoc_face_count')
wt_face_name       PROCEDURE(LONG,LONG,*CSTRING,LONG),LONG,RAW,PROC,NAME('_wdoc_face_name')
wt_face_chars      PROCEDURE(LONG,LONG),LONG,NAME('_wdoc_face_chars')
wt_replace_face    PROCEDURE(LONG,*CSTRING,*CSTRING),LONG,RAW,NAME('_wdoc_replace_face')
wt_scale_sizes     PROCEDURE(LONG,LONG),LONG,NAME('_wdoc_scale_sizes')
wt_set_font_range  PROCEDURE(LONG,LONG,LONG,*CSTRING,LONG),RAW,NAME('_wdoc_set_font_range')
wt_look            PROCEDURE(LONG,LONG,LONG),LONG,NAME('_wdoc_look')
wt_face_at         PROCEDURE(LONG,LONG,*CSTRING,LONG),LONG,RAW,PROC,NAME('_wdoc_face_at')
wt_to_text         PROCEDURE(LONG,LONG,*CSTRING),LONG,RAW,NAME('_wdoc_to_text')
wt_stats           PROCEDURE(LONG,LONG),LONG,NAME('_wdoc_stats')
wt_export          PROCEDURE(LONG,LONG,LONG,*CSTRING,*CSTRING,*CSTRING),LONG,RAW,NAME('_wdoc_export')
    END
  END


!=== RtfToolBase: the document ================================================
RtfToolBase.Attach PROCEDURE(*WordDocClass pDoc)
  CODE
  SELF.Kill()
  SELF.Doc &= pDoc
  SELF.Own = FALSE

! our own invisible document, made the first time something is loaded
RtfToolBase.Hidden PROCEDURE()
  CODE
  IF NOT SELF.Doc &= NULL THEN RETURN TRUE.
  SELF.Doc &= NEW WordDocClass
  SELF.Own = TRUE
  IF NOT SELF.Doc.InitHidden()
    SELF.Kill()
    RETURN FALSE
  END
  RETURN TRUE

RtfToolBase.LoadString PROCEDURE(STRING pRtfOrText)
  CODE
  IF NOT SELF.Hidden() THEN RETURN FALSE.
  SELF.Doc.LoadString(pRtfOrText)
  RETURN TRUE

RtfToolBase.LoadBlob PROCEDURE(*BLOB pBlob)
  CODE
  IF NOT SELF.Hidden() THEN RETURN FALSE.
  SELF.Doc.LoadBlob(pBlob)
  RETURN TRUE

RtfToolBase.LoadFile PROCEDURE(STRING pFileName)
  CODE
  IF NOT SELF.Hidden() THEN RETURN FALSE.
  RETURN SELF.Doc.LoadFile(pFileName)

RtfToolBase.SaveBlob PROCEDURE(*BLOB pBlob)
  CODE
  IF SELF.Ready() THEN SELF.Doc.SaveBlob(pBlob).

RtfToolBase.SaveFile PROCEDURE(STRING pFileName)
  CODE
  IF NOT SELF.Ready() THEN RETURN FALSE.
  RETURN SELF.Doc.SaveFile(pFileName)

RtfToolBase.GetRtf PROCEDURE()
  CODE
  IF NOT SELF.Ready() THEN RETURN ''.
  RETURN SELF.Doc.GetRtf()

RtfToolBase.Ready PROCEDURE()
  CODE
  IF SELF.Doc &= NULL THEN RETURN FALSE.
  RETURN CHOOSE(SELF.Doc.Slot() <> 0)

RtfToolBase.Undo PROCEDURE()
  CODE
  IF SELF.Ready() THEN SELF.Doc.Undo().

RtfToolBase.Redo PROCEDURE()
  CODE
  IF SELF.Ready() THEN SELF.Doc.Redo().

RtfToolBase.CanUndo PROCEDURE()
  CODE
  IF NOT SELF.Ready() THEN RETURN FALSE.
  RETURN SELF.Doc.CanUndo()

RtfToolBase.Kill PROCEDURE()
  CODE
  IF SELF.Own AND NOT SELF.Doc &= NULL
    SELF.Doc.Kill()
    DISPOSE(SELF.Doc)
  END
  SELF.Doc &= NULL
  SELF.Own = FALSE
  IF NOT SELF.Buf &= NULL THEN DISPOSE(SELF.Buf).

RtfToolBase.Destruct PROCEDURE()
  CODE
  SELF.Kill()

RtfToolBase.H PROCEDURE()
  CODE
  IF SELF.Doc &= NULL THEN RETURN 0.
  RETURN SELF.Doc.Slot()

! the C side left pLen bytes in the document's buffer
RtfToolBase.Fetch PROCEDURE(LONG pLen)
  CODE
  IF NOT SELF.Buf &= NULL THEN DISPOSE(SELF.Buf).
  IF pLen <= 0 THEN RETURN ''.
  SELF.Buf &= NEW STRING(pLen)
  wt_copy(SELF.H(), SELF.Buf, pLen)
  RETURN SELF.Buf

RtfToolBase.SaveBuf PROCEDURE(STRING pFileName)
OutName  CSTRING(261),STATIC,THREAD
OutFile  FILE,DRIVER('DOS'),NAME(OutName),PRE(OF),CREATE,THREAD
           RECORD
Chunk        STRING(32768)
           END
         END
L:Len    LONG
L:Pos    LONG
L:N      LONG
  CODE
  OutName = CLIP(pFileName)
  CREATE(OutFile)
  IF ERRORCODE() THEN RETURN FALSE.
  OPEN(OutFile, 22H)                               ! read/write, deny write
  IF ERRORCODE() THEN RETURN FALSE.
  L:Len = 0
  IF NOT SELF.Buf &= NULL THEN L:Len = LEN(SELF.Buf).
  L:Pos = 0
  LOOP WHILE L:Pos < L:Len
    L:N = L:Len - L:Pos
    IF L:N > SIZE(OF:Chunk) THEN L:N = SIZE(OF:Chunk).
    OF:Chunk[1 : L:N] = SELF.Buf[L:Pos + 1 : L:Pos + L:N]
    ADD(OutFile, L:N)
    L:Pos += L:N
  END
  CLOSE(OutFile)
  RETURN TRUE


!=== RtfSearchClass ===========================================================
RtfSearchClass.Flags PROCEDURE(BYTE pForward)
  CODE
  RETURN CHOOSE(pForward <> 0, 1, 0) + CHOOSE(SELF.WholeWord <> 0, 2, 0) + CHOOSE(SELF.MatchCase <> 0, 4, 0)

! records a hit (or a miss) and shows it
RtfSearchClass.Hit PROCEDURE(LONG pAt)
  CODE
  SELF.FoundAt = pAt
  IF pAt < 0
    SELF.FoundEnd = -1
  ELSE
    SELF.FoundEnd = wt_found_end(SELF.H())
    IF SELF.SelectHits THEN wt_show_range(SELF.H(), SELF.FoundAt, SELF.FoundEnd).
  END
  RETURN pAt

RtfSearchClass.Find PROCEDURE(STRING pText)
  CODE
  SELF.What = CLIP(pText)
  IF NOT SELF.Ready() OR SELF.What = '' THEN RETURN SELF.Hit(-1).
  RETURN SELF.Hit(wt_find_at(SELF.H(), SELF.What, 0, -1, SELF.Flags(1)))

RtfSearchClass.FindNext PROCEDURE()
L:From  LONG
L:R     LONG
  CODE
  IF NOT SELF.Ready() OR SELF.What = '' THEN RETURN -1.
  L:From = CHOOSE(SELF.FoundEnd < 0, 0, SELF.FoundEnd)
  L:R = wt_find_at(SELF.H(), SELF.What, L:From, -1, SELF.Flags(1))
  IF L:R < 0 AND SELF.Wrap AND L:From > 0
    L:R = wt_find_at(SELF.H(), SELF.What, 0, -1, SELF.Flags(1))
  END
  RETURN SELF.Hit(L:R)

RtfSearchClass.FindPrevious PROCEDURE()
L:From  LONG
L:End   LONG
L:R     LONG
  CODE
  IF NOT SELF.Ready() OR SELF.What = '' THEN RETURN -1.
  L:End = wt_length(SELF.H())
  L:From = CHOOSE(SELF.FoundAt < 0, L:End, SELF.FoundAt)
  L:R = wt_find_at(SELF.H(), SELF.What, L:From, 0, SELF.Flags(0))
  IF L:R < 0 AND SELF.Wrap AND L:From < L:End
    L:R = wt_find_at(SELF.H(), SELF.What, L:End, 0, SELF.Flags(0))
  END
  RETURN SELF.Hit(L:R)

RtfSearchClass.Count PROCEDURE(STRING pText)
L:T  &CSTRING
L:N  LONG
  CODE
  IF NOT SELF.Ready() OR NOT CLIP(pText) THEN RETURN 0.
  L:T &= NEW CSTRING(LEN(CLIP(pText)) + 1)
  L:T = CLIP(pText)
  L:N = wt_count(SELF.H(), L:T, SELF.Flags(1))
  DISPOSE(L:T)
  RETURN L:N

! Like Word's Replace button: replaces the hit that is showing (when it still
! reads pFind) and moves on to the next one. The first call only finds.
RtfSearchClass.Replace PROCEDURE(STRING pFind,STRING pWith)
L:W     &CSTRING
L:Done  BYTE
  CODE
  IF NOT SELF.Ready() OR NOT CLIP(pFind) THEN RETURN FALSE.
  IF SELF.What <> CLIP(pFind)
    SELF.What = CLIP(pFind)
    SELF.FoundAt = -1
    SELF.FoundEnd = -1
  END
  IF SELF.FoundAt >= 0
    IF wt_find_at(SELF.H(), SELF.What, SELF.FoundAt, SELF.FoundEnd, SELF.Flags(1)) = SELF.FoundAt
      L:W &= NEW CSTRING(LEN(CLIP(pWith)) + 1)
      L:W = CLIP(pWith)
      SELF.FoundEnd = wt_replace_range(SELF.H(), SELF.FoundAt, SELF.FoundEnd, L:W)
      DISPOSE(L:W)
      L:Done = TRUE
    END
  END
  SELF.FindNext()
  RETURN L:Done

RtfSearchClass.ReplaceAll PROCEDURE(STRING pFind,STRING pWith)
L:F  &CSTRING
L:W  &CSTRING
L:N  LONG
  CODE
  IF NOT SELF.Ready() OR NOT CLIP(pFind) THEN RETURN 0.
  L:F &= NEW CSTRING(LEN(CLIP(pFind)) + 1)
  L:W &= NEW CSTRING(LEN(CLIP(pWith)) + 1)
  L:F = CLIP(pFind)
  L:W = CLIP(pWith)
  L:N = wt_replace_all(SELF.H(), L:F, L:W, SELF.Flags(1))
  DISPOSE(L:F)
  DISPOSE(L:W)
  SELF.FoundAt = -1
  SELF.FoundEnd = -1
  RETURN L:N

RtfSearchClass.HighlightAll PROCEDURE(STRING pText,LONG pColor=COLOR:Yellow)
L:T  &CSTRING
L:N  LONG
  CODE
  IF NOT SELF.Ready() OR NOT CLIP(pText) THEN RETURN 0.
  L:T &= NEW CSTRING(LEN(CLIP(pText)) + 1)
  L:T = CLIP(pText)
  L:N = wt_mark_all(SELF.H(), L:T, SELF.Flags(1), CHOOSE(pColor < 0, -1, pColor))
  DISPOSE(L:T)
  RETURN L:N

RtfSearchClass.Context PROCEDURE(LONG pChars=40)
L:A  LONG
L:B  LONG
L:N  LONG
  CODE
  IF NOT SELF.Ready() OR SELF.FoundAt < 0 THEN RETURN ''.
  L:N = wt_length(SELF.H())
  L:A = SELF.FoundAt - pChars
  IF L:A < 0 THEN L:A = 0.
  L:B = SELF.FoundEnd + pChars
  IF L:B > L:N THEN L:B = L:N.
  RETURN CHOOSE(L:A > 0, '...', '') & SELF.TextAt(L:A, L:B) & CHOOSE(L:B < L:N, '...', '')

RtfSearchClass.TextAt PROCEDURE(LONG pFrom,LONG pTo)
  CODE
  IF NOT SELF.Ready() THEN RETURN ''.
  RETURN SELF.Fetch(wt_text_range(SELF.H(), pFrom, pTo))


!=== RtfFontClass =============================================================
RtfFontClass.Read PROCEDURE(LONG pPos=-1)
L:Face  CSTRING(32)
  CODE
  IF NOT SELF.Ready() THEN RETURN FALSE.
  wt_face_at(SELF.H(), pPos, L:Face, SIZE(L:Face))
  SELF.Face      = L:Face
  SELF.Size      = wt_look(SELF.H(), pPos, 5) / 10
  SELF.Bold      = wt_look(SELF.H(), pPos, 1)
  SELF.Italic    = wt_look(SELF.H(), pPos, 2)
  SELF.Underline = wt_look(SELF.H(), pPos, 3)
  SELF.Strike    = wt_look(SELF.H(), pPos, 4)
  SELF.Color     = wt_look(SELF.H(), pPos, 6)          ! -1 = COLOR:None (automatic)
  SELF.Highlight = wt_look(SELF.H(), pPos, 7)
  SELF.Align     = wt_look(SELF.H(), pPos, 8)
  SELF.List      = wt_look(SELF.H(), pPos, 9)
  SELF.Script    = wt_look(SELF.H(), pPos, 10)
  RETURN TRUE

RtfFontClass.Describe PROCEDURE()
L:S  CSTRING(200)
  CODE
  L:S = CHOOSE(SELF.Face = '', 'mixed fonts', SELF.Face)
  IF SELF.Size = 0
    L:S = L:S & ', mixed sizes'
  ELSIF SELF.Size = INT(SELF.Size)
    L:S = L:S & ' ' & INT(SELF.Size) & 'pt'
  ELSE
    L:S = L:S & ' ' & SELF.Size & 'pt'
  END
  IF SELF.Bold = 1 THEN L:S = L:S & ', bold'.
  IF SELF.Italic = 1 THEN L:S = L:S & ', italic'.
  IF SELF.Underline = 1 THEN L:S = L:S & ', underlined'.
  IF SELF.Strike = 1 THEN L:S = L:S & ', struck through'.
  IF SELF.Script = 1 THEN L:S = L:S & ', superscript'.
  IF SELF.Script = 2 THEN L:S = L:S & ', subscript'.
  RETURN L:S

RtfFontClass.FontCount PROCEDURE()
  CODE
  IF NOT SELF.Ready() THEN RETURN 0.
  wt_runs(SELF.H())
  RETURN wt_face_count(SELF.H())

RtfFontClass.FontName PROCEDURE(LONG pN)
L:Face  CSTRING(32)
  CODE
  IF NOT SELF.Ready() THEN RETURN ''.
  wt_face_name(SELF.H(), pN, L:Face, SIZE(L:Face))
  RETURN L:Face

RtfFontClass.FontChars PROCEDURE(LONG pN)
  CODE
  IF NOT SELF.Ready() THEN RETURN 0.
  RETURN wt_face_chars(SELF.H(), pN)

RtfFontClass.FontList PROCEDURE(<STRING pSep>)
L:S    CSTRING(4096)
L:Sep  CSTRING(32)
L:I    LONG
  CODE
  L:Sep = ', '
  IF NOT OMITTED(pSep) THEN L:Sep = pSep.
  LOOP L:I = 1 TO SELF.FontCount()
    IF L:I > 1 THEN L:S = L:S & L:Sep.
    L:S = L:S & SELF.FontName(L:I)
  END
  RETURN L:S

RtfFontClass.MainFont PROCEDURE()
L:I     LONG
L:Best  LONG
L:Most  LONG(-1)
  CODE
  LOOP L:I = 1 TO SELF.FontCount()
    IF SELF.FontChars(L:I) > L:Most
      L:Most = SELF.FontChars(L:I)
      L:Best = L:I
    END
  END
  RETURN CHOOSE(L:Best = 0, '', SELF.FontName(L:Best))

RtfFontClass.ReplaceFont PROCEDURE(STRING pOld,STRING pNew)
L:Old  CSTRING(32)
L:New  CSTRING(32)
  CODE
  IF NOT SELF.Ready() THEN RETURN 0.
  L:Old = CLIP(pOld)
  L:New = CLIP(pNew)
  RETURN wt_replace_face(SELF.H(), L:Old, L:New)

RtfFontClass.SetFontAll PROCEDURE(STRING pFace,REAL pPoints=0)
  CODE
  SELF.SetFontRange(0, -1, pFace, pPoints)

RtfFontClass.SetFontRange PROCEDURE(LONG pFrom,LONG pTo,STRING pFace,REAL pPoints=0)
L:Face  CSTRING(32)
  CODE
  IF NOT SELF.Ready() THEN RETURN.
  L:Face = CLIP(pFace)
  wt_set_font_range(SELF.H(), pFrom, pTo, L:Face, pPoints * 10)

RtfFontClass.ScaleSizes PROCEDURE(LONG pPercent)
  CODE
  IF NOT SELF.Ready() THEN RETURN 0.
  RETURN wt_scale_sizes(SELF.H(), pPercent)


!=== RtfTextClass =============================================================
RtfTextClass.ToText PROCEDURE()
L:Bullet  CSTRING(16)
  CODE
  IF NOT SELF.Ready() THEN RETURN ''.
  L:Bullet = SELF.Bullet
  RETURN SELF.Fetch(wt_to_text(SELF.H(), CHOOSE(SELF.Utf8 <> 0, 1, 0) + CHOOSE(SELF.ListPrefixes <> 0, 2, 0) + |
                                         CHOOSE(SELF.TabCells <> 0, 4, 0) + CHOOSE(SELF.PictureMarks <> 0, 8, 0), L:Bullet))

RtfTextClass.SaveText PROCEDURE(STRING pFileName)
  CODE
  IF NOT SELF.Ready() THEN RETURN FALSE.
  SELF.ToText()
  RETURN SELF.SaveBuf(pFileName)

RtfTextClass.WordCount PROCEDURE()
  CODE
  RETURN CHOOSE(NOT SELF.Ready(), 0, wt_stats(SELF.H(), 1))

RtfTextClass.CharCount PROCEDURE(BYTE pWithSpaces=1)
  CODE
  RETURN CHOOSE(NOT SELF.Ready(), 0, wt_stats(SELF.H(), CHOOSE(pWithSpaces <> 0, 2, 3)))

RtfTextClass.ParagraphCount PROCEDURE()
  CODE
  RETURN CHOOSE(NOT SELF.Ready(), 0, wt_stats(SELF.H(), 4))

RtfTextClass.PictureCount PROCEDURE()
  CODE
  RETURN CHOOSE(NOT SELF.Ready(), 0, wt_stats(SELF.H(), 5))

RtfTextClass.TableCount PROCEDURE()
  CODE
  RETURN CHOOSE(NOT SELF.Ready(), 0, wt_stats(SELF.H(), 6))

! the start of the text on one line: whitespace folded, cut at a word
RtfTextClass.Excerpt PROCEDURE(LONG pMaxChars=200)
L:None  CSTRING(2)
L:Len   LONG
L:Out   &STRING
L:N     LONG
L:I     LONG
L:C     STRING(1)
L:Cut   BYTE
  CODE
  IF NOT SELF.Ready() OR pMaxChars < 1 THEN RETURN ''.
  L:Len = wt_to_text(SELF.H(), 0, L:None)
  SELF.Fetch(L:Len)
  IF L:Len <= 0 THEN RETURN ''.
  L:Out &= NEW STRING(pMaxChars + 3)
  LOOP L:I = 1 TO L:Len
    L:C = SELF.Buf[L:I]
    IF VAL(L:C) < 32 OR L:C = '|' THEN L:C = ' '.
    IF L:C = ' ' AND (L:N = 0 OR L:Out[L:N] = ' ') THEN CYCLE.
    IF L:N >= pMaxChars
      L:Cut = TRUE
      BREAK
    END
    L:N += 1
    L:Out[L:N] = L:C
  END
  IF L:Cut
    L:I = L:N
    LOOP WHILE L:I > pMaxChars / 2 AND L:Out[L:I] <> ' '
      L:I -= 1
    END
    IF L:Out[L:I] = ' ' THEN L:N = L:I - 1.
    L:Out[L:N + 1 : L:N + 3] = '...'
    L:N += 3
  END
  DISPOSE(SELF.Buf)
  SELF.Buf &= NEW STRING(L:N)
  SELF.Buf = L:Out[1 : L:N]
  DISPOSE(L:Out)
  RETURN SELF.Buf

RtfTextClass.IsRtf PROCEDURE(STRING pText)
  CODE
  RETURN CHOOSE(SUB(LEFT(pText), 1, 5) = '{{\rtf')

! Plain text as a small RTF document - for LoadString, InsertRtf or a BLOB.
! Characters above 127 are written as \'hh in the ANSI code page.
RtfTextClass.TextToRtf PROCEDURE(STRING pText,<STRING pFace>,REAL pPoints=0)
Hex     STRING('0123456789abcdef')
L:Face  CSTRING(32)
L:Len   LONG
L:I     LONG
L:N     LONG
L:V     LONG
L:C     STRING(1)
L:Head  CSTRING(200)
  CODE
  IF NOT OMITTED(pFace) THEN L:Face = CLIP(pFace).
  IF L:Face = '' THEN L:Face = 'Segoe UI'.
  L:Head = '{{\rtf1\ansi\ansicpg1252\deff0{{\fonttbl{{\f0\fswiss ' & L:Face & ';}}\pard\f0\fs' & |
           CHOOSE(pPoints > 0, INT(pPoints * 2), 22) & ' '
  L:Len = LEN(CLIP(pText))
  IF NOT SELF.Buf &= NULL THEN DISPOSE(SELF.Buf).
  SELF.Buf &= NEW STRING(LEN(L:Head) + L:Len * 5 + 8)
  L:N = LEN(L:Head)
  SELF.Buf[1 : L:N] = L:Head
  L:I = 1
  LOOP WHILE L:I <= L:Len
    L:C = pText[L:I]
    L:V = VAL(L:C)
    CASE L:V
    OF 13
      IF L:I < L:Len AND VAL(pText[L:I + 1]) = 10 THEN L:I += 1.
      SELF.Buf[L:N + 1 : L:N + 5] = '\par '
      L:N += 5
    OF 10
      SELF.Buf[L:N + 1 : L:N + 5] = '\par '
      L:N += 5
    OF 9
      SELF.Buf[L:N + 1 : L:N + 5] = '\tab '
      L:N += 5
    OF 92 OROF 123 OROF 125                       ! \ { }
      SELF.Buf[L:N + 1] = '\'
      SELF.Buf[L:N + 2] = L:C
      L:N += 2
    ELSE
      IF L:V > 127
        SELF.Buf[L:N + 1 : L:N + 2] = '\'''
        SELF.Buf[L:N + 3] = Hex[BSHIFT(L:V, -4) + 1]
        SELF.Buf[L:N + 4] = Hex[BAND(L:V, 15) + 1]
        L:N += 4
      ELSIF L:V >= 32
        SELF.Buf[L:N + 1] = L:C
        L:N += 1
      END
    END
    L:I += 1
  END
  SELF.Buf[L:N + 1 : L:N + 5] = '\par}'
  L:N += 5
  RETURN SELF.Buf[1 : L:N]


!=== RtfHtmlClass / RtfMarkdownClass ==========================================
RtfHtmlClass.ToHtml PROCEDURE()
  CODE
  IF NOT SELF.Ready() THEN RETURN ''.
  RETURN SELF.Fetch(wt_export(SELF.H(), CHOOSE(SELF.FullPage <> 0, 0, 1), CHOOSE(SELF.SkipPictures <> 0, 1, 0), |
                              SELF.Title, SELF.ImageFolder, SELF.ImageUrl))

RtfHtmlClass.SaveHtml PROCEDURE(STRING pFileName)
  CODE
  IF NOT SELF.Ready() THEN RETURN FALSE.
  SELF.ToHtml()
  RETURN SELF.SaveBuf(pFileName)

RtfMarkdownClass.ToMarkdown PROCEDURE()
L:None  CSTRING(2)
  CODE
  IF NOT SELF.Ready() THEN RETURN ''.
  RETURN SELF.Fetch(wt_export(SELF.H(), 2, CHOOSE(SELF.SkipPictures <> 0, 1, 0), L:None, SELF.ImageFolder, SELF.ImageUrl))

RtfMarkdownClass.SaveMarkdown PROCEDURE(STRING pFileName)
  CODE
  IF NOT SELF.Ready() THEN RETURN FALSE.
  SELF.ToMarkdown()
  RETURN SELF.SaveBuf(pFileName)


!=== RtfMergeClass ============================================================
RtfMergeClass.Opener PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.FieldOpen = '', '[[', SELF.FieldOpen)

RtfMergeClass.Closer PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.FieldClose = '', ']]', SELF.FieldClose)

RtfMergeClass.SetField PROCEDURE(STRING pName,STRING pValue)
L:Len  LONG
  CODE
  IF SELF.Fields &= NULL THEN SELF.Fields &= NEW RtfMergeFieldQ.
  SELF.Fields.Name = UPPER(LEFT(pName))
  GET(SELF.Fields, SELF.Fields.Name)
  IF NOT ERRORCODE()
    DISPOSE(SELF.Fields.Value)
    DELETE(SELF.Fields)
  END
  L:Len = LEN(CLIP(pValue))
  SELF.Fields.Name = UPPER(LEFT(pName))
  SELF.Fields.Value &= NEW STRING(CHOOSE(L:Len = 0, 1, L:Len))
  SELF.Fields.Value = pValue
  ADD(SELF.Fields, SELF.Fields.Name)

RtfMergeClass.ClearFields PROCEDURE()
  CODE
  IF SELF.Fields &= NULL THEN RETURN.
  LOOP WHILE RECORDS(SELF.Fields)
    GET(SELF.Fields, 1)
    DISPOSE(SELF.Fields.Value)
    DELETE(SELF.Fields)
  END

! finds every placeholder: Found.Name is the name, Found.Value the text to replace
RtfMergeClass.Scan PROCEDURE()
L:None   CSTRING(2)
L:Len    LONG
L:Open   CSTRING(9)
L:Close  CSTRING(9)
L:P      LONG
L:A      LONG
L:B      LONG
L:Name   STRING(64)
  CODE
  IF SELF.Found &= NULL THEN SELF.Found &= NEW RtfMergeFieldQ.
  LOOP WHILE RECORDS(SELF.Found)
    GET(SELF.Found, 1)
    DISPOSE(SELF.Found.Value)
    DELETE(SELF.Found)
  END
  IF NOT SELF.Ready() THEN RETURN.
  L:Open = SELF.Opener()
  L:Close = SELF.Closer()
  L:Len = wt_to_text(SELF.H(), 0, L:None)
  SELF.Fetch(L:Len)
  L:P = 1
  LOOP WHILE L:P <= L:Len
    L:A = INSTRING(L:Open, SELF.Buf[1 : L:Len], 1, L:P)
    IF L:A = 0 THEN BREAK.
    L:B = INSTRING(L:Close, SELF.Buf[1 : L:Len], 1, L:A + LEN(L:Open))
    IF L:B = 0 THEN BREAK.
    L:P = L:B + LEN(L:Close)
    IF L:B - L:A - LEN(L:Open) < 1 OR L:B - L:A - LEN(L:Open) > 64 THEN CYCLE.
    L:Name = LEFT(SELF.Buf[L:A + LEN(L:Open) : L:B - 1])
    IF INSTRING('<13>', L:Name, 1, 1) OR INSTRING(L:Open, L:Name, 1, 1)
      L:P = L:A + LEN(L:Open)                      ! not a placeholder: look again after the opener
      CYCLE
    END
    SELF.Found.Name = L:Name
    GET(SELF.Found, SELF.Found.Name)
    IF ERRORCODE()
      SELF.Found.Name = L:Name
      SELF.Found.Value &= NEW STRING(L:B + LEN(L:Close) - L:A)
      SELF.Found.Value = SELF.Buf[L:A : L:B + LEN(L:Close) - 1]
      ADD(SELF.Found, SELF.Found.Name)
    END
  END

RtfMergeClass.ValueOf PROCEDURE(STRING pName,*BYTE pKnown)
L:V  ANY
  CODE
  pKnown = FALSE
  IF NOT SELF.Fields &= NULL
    SELF.Fields.Name = UPPER(LEFT(pName))
    GET(SELF.Fields, SELF.Fields.Name)
    IF NOT ERRORCODE()
      pKnown = TRUE
      RETURN CLIP(SELF.Fields.Value)
    END
  END
  IF SELF.UseBound
    L:V = EVALUATE(CLIP(LEFT(pName)))
    IF NOT ERRORCODE()
      pKnown = TRUE
      RETURN CLIP(L:V)
    END
  END
  RETURN ''

RtfMergeClass.Merge PROCEDURE()
L:I      LONG
L:Known  BYTE
L:Count  LONG
L:F      &CSTRING
L:W      &CSTRING
L:V      ANY
  CODE
  SELF.Scan()
  IF NOT SELF.Ready() THEN RETURN 0.
  SELF.Doc.BeginUndoGroup()                       ! the whole merge is one Undo
  LOOP L:I = 1 TO RECORDS(SELF.Found)
    GET(SELF.Found, L:I)
    L:V = SELF.ValueOf(SELF.Found.Name, L:Known)
    IF NOT L:Known AND NOT SELF.BlankUnknown THEN CYCLE.
    L:F &= NEW CSTRING(LEN(SELF.Found.Value) + 1)
    L:F = SELF.Found.Value
    L:W &= NEW CSTRING(LEN(CLIP(L:V)) + 1)
    L:W = CLIP(L:V)
    L:Count += wt_replace_all(SELF.H(), L:F, L:W, 4)    ! match case: [[Name]] exactly
    DISPOSE(L:F)
    DISPOSE(L:W)
  END
  SELF.Doc.EndUndoGroup()
  RETURN L:Count

RtfMergeClass.FieldCount PROCEDURE()
  CODE
  SELF.Scan()
  RETURN RECORDS(SELF.Found)

RtfMergeClass.FieldName PROCEDURE(LONG pN)
  CODE
  IF SELF.Found &= NULL THEN SELF.Scan().
  GET(SELF.Found, pN)
  IF ERRORCODE() THEN RETURN ''.
  RETURN CLIP(SELF.Found.Name)

RtfMergeClass.Missing PROCEDURE()
L:S      CSTRING(4096)
L:I      LONG
L:Known  BYTE
  CODE
  SELF.Scan()
  LOOP L:I = 1 TO RECORDS(SELF.Found)
    GET(SELF.Found, L:I)
    SELF.ValueOf(SELF.Found.Name, L:Known)
    IF L:Known THEN CYCLE.
    IF L:S <> '' THEN L:S = L:S & ', '.
    L:S = L:S & CLIP(SELF.Found.Name)
  END
  RETURN L:S

RtfMergeClass.Destruct PROCEDURE()
  CODE
  SELF.ClearFields()
  IF NOT SELF.Fields &= NULL THEN DISPOSE(SELF.Fields).
  IF NOT SELF.Found &= NULL
    LOOP WHILE RECORDS(SELF.Found)
      GET(SELF.Found, 1)
      DISPOSE(SELF.Found.Value)
      DELETE(SELF.Found)
    END
    DISPOSE(SELF.Found)
  END
