! ============================================================================
!  WordDocClass - implementation.
!
!  wdoc.c (compiled into the exe by the PRAGMA below) is the control itself:
!  the host window, its toolbar and the RichEdit editing surface. This file is
!  the Clarion side: placing the control over a placeholder REGION, moving
!  documents in and out of BLOBs, and turning pages into report IMAGEs.
!
!  Only scalars and raw buffers cross into C - no groups, no arrays.
!
!  This file MUST be stored in ANSI (not UTF-8), with CRLF line endings.
! ============================================================================
  MEMBER

  INCLUDE('WordDocClass.INC'),ONCE             ! must precede the PRAGMA / wdoc.c prototypes

  PRAGMA('compile(wdoc.c)')                    ! Clarion's own C compiler builds the control

  MAP
    MODULE('wdoc.c')
wd_init            PROCEDURE(),LONG,NAME('_wdoc_init')
wd_last_step       PROCEDURE(),LONG,NAME('_wdoc_last_step')
wd_struct_sizes    PROCEDURE(),LONG,NAME('_wdoc_struct_sizes')
wd_create          PROCEDURE(LONG,LONG,LONG,LONG,LONG,LONG),LONG,NAME('_wdoc_create')
wd_destroy         PROCEDURE(LONG),NAME('_wdoc_destroy')
wd_alive           PROCEDURE(LONG),LONG,NAME('_wdoc_alive')
wd_hwnd            PROCEDURE(LONG),LONG,NAME('_wdoc_hwnd')
wd_move            PROCEDURE(LONG,LONG,LONG,LONG,LONG),NAME('_wdoc_move')
wd_show            PROCEDURE(LONG,LONG),NAME('_wdoc_show')
wd_enable          PROCEDURE(LONG,LONG),NAME('_wdoc_enable')
wd_focus           PROCEDURE(LONG),NAME('_wdoc_focus')
wd_set_flags       PROCEDURE(LONG,LONG),NAME('_wdoc_set_flags')
wd_load            PROCEDURE(LONG,*STRING,LONG),LONG,RAW,PROC,NAME('_wdoc_load')
wd_save            PROCEDURE(LONG,LONG),LONG,NAME('_wdoc_save')
wd_copy            PROCEDURE(LONG,*STRING,LONG),LONG,RAW,PROC,NAME('_wdoc_copy')
wd_insert_rtf      PROCEDURE(LONG,*STRING,LONG),LONG,RAW,PROC,NAME('_wdoc_insert_rtf')
wd_insert_text     PROCEDURE(LONG,*CSTRING),RAW,NAME('_wdoc_insert_text')
wd_insert_image    PROCEDURE(LONG,*CSTRING,LONG),LONG,RAW,NAME('_wdoc_insert_image')
wd_insert_table    PROCEDURE(LONG,LONG,LONG,LONG),LONG,NAME('_wdoc_insert_table')
wd_length          PROCEDURE(LONG),LONG,NAME('_wdoc_length')
wd_get_modified    PROCEDURE(LONG),LONG,NAME('_wdoc_get_modified')
wd_set_modified    PROCEDURE(LONG,LONG),NAME('_wdoc_set_modified')
wd_seq             PROCEDURE(LONG),LONG,NAME('_wdoc_seq')
wd_effect          PROCEDURE(LONG,LONG,LONG),NAME('_wdoc_effect')
wd_set_face        PROCEDURE(LONG,*CSTRING),RAW,NAME('_wdoc_set_face')
wd_set_size        PROCEDURE(LONG,LONG),NAME('_wdoc_set_size')
wd_set_color       PROCEDURE(LONG,LONG),NAME('_wdoc_set_color')
wd_set_back        PROCEDURE(LONG,LONG),NAME('_wdoc_set_back')
wd_set_align       PROCEDURE(LONG,LONG),NAME('_wdoc_set_align')
wd_set_numbering   PROCEDURE(LONG,LONG),NAME('_wdoc_set_numbering')
wd_indent          PROCEDURE(LONG,LONG),NAME('_wdoc_indent')
wd_get_format      PROCEDURE(LONG,LONG),LONG,NAME('_wdoc_get_format')
wd_get_face        PROCEDURE(LONG,*CSTRING,LONG),LONG,RAW,PROC,NAME('_wdoc_get_face')
wd_command         PROCEDURE(LONG,LONG),NAME('_wdoc_command')
wd_can             PROCEDURE(LONG,LONG),LONG,NAME('_wdoc_can')
wd_undo_group      PROCEDURE(LONG,LONG),LONG,PROC,NAME('_wdoc_undo_group')
wd_undo_clear      PROCEDURE(LONG),NAME('_wdoc_undo_clear')
wd_undo_limit      PROCEDURE(LONG,LONG),NAME('_wdoc_undo_limit')
wd_set_readonly    PROCEDURE(LONG,LONG),NAME('_wdoc_set_readonly')
wd_set_zoom        PROCEDURE(LONG,LONG),NAME('_wdoc_set_zoom')
wd_set_paper       PROCEDURE(LONG,LONG),NAME('_wdoc_set_paper')
wd_set_page_width  PROCEDURE(LONG,LONG),NAME('_wdoc_set_page_width')
wd_select          PROCEDURE(LONG,LONG,LONG),NAME('_wdoc_select')
wd_find            PROCEDURE(LONG,*CSTRING,LONG,LONG),LONG,RAW,NAME('_wdoc_find')
wd_paginate        PROCEDURE(LONG,LONG,LONG),LONG,NAME('_wdoc_paginate')
wd_page_used       PROCEDURE(LONG,LONG),LONG,NAME('_wdoc_page_used')
wd_render_page     PROCEDURE(LONG,LONG,LONG,LONG,*CSTRING),LONG,RAW,NAME('_wdoc_render_page')
wd_temp_name       PROCEDURE(LONG,LONG,*CSTRING,LONG),LONG,RAW,PROC,NAME('_wdoc_temp_name')
wd_delete_file     PROCEDURE(*CSTRING),LONG,RAW,PROC,NAME('_wdoc_delete_file')
    END
  END


!=== LIFE CYCLE ===============================================================
! pFeq is a REGION placed in the window formatter: the control takes its
! rectangle. pFlags = -1 builds the flags from ShowToolbar/ReadOnly/PageView.
WordDocClass.Init PROCEDURE(LONG pWinHandle,LONG pFeq,LONG pFlags=-1)
L:Flags  LONG
L:Face   CSTRING(32)
  CODE
  SELF.Kill()
  SELF.Err = 0
  SELF.WinHandle = pWinHandle
  SELF.Feq = pFeq
  IF wd_init() <> 0
    SELF.Err = wd_last_step()
    RETURN FALSE
  END
  IF pFlags = -1
    L:Flags = CHOOSE(SELF.ShowToolbar <> 0, WD:Toolbar, 0) + |
              CHOOSE(SELF.ReadOnly <> 0, WD:ReadOnly, 0) + |
              CHOOSE(SELF.PageView <> 0, WD:PageView, 0)
  ELSE
    L:Flags = pFlags
  END
  SELF.LastW = -1                                  ! force the first Reposition to place it
  SELF.H = wd_create(pWinHandle, 0, 0, 10, 10, L:Flags)
  IF SELF.H = 0
    SELF.Err = wd_last_step()
    RETURN FALSE
  END
  IF SELF.PageWidth THEN wd_set_page_width(SELF.H, SELF.PageWidth).
  IF SELF.DefaultFont OR SELF.DefaultSize
    wd_select(SELF.H, 0, -1)
    IF SELF.DefaultFont
      L:Face = SELF.DefaultFont
      wd_set_face(SELF.H, L:Face)
    END
    IF SELF.DefaultSize THEN wd_set_size(SELF.H, SELF.DefaultSize * 10).
    wd_select(SELF.H, 0, 0)
    wd_set_modified(SELF.H, 0)
  END
  SELF.Shown = 1
  SELF.Reposition()
  RETURN TRUE

! An invisible document with no window - a REPORT procedure loads the BLOB
! into it and prints its pages.
WordDocClass.InitHidden PROCEDURE()
  CODE
  SELF.Kill()
  SELF.Err = 0
  IF wd_init() <> 0
    SELF.Err = wd_last_step()
    RETURN FALSE
  END
  SELF.H = wd_create(0, 0, 0, 800, 600, 0)
  IF SELF.H = 0 THEN SELF.Err = wd_last_step(); RETURN FALSE.
  RETURN TRUE

WordDocClass.Kill PROCEDURE()
L:Path  CSTRING(300)
L:I     LONG
  CODE
  IF SELF.H
    LOOP L:I = 1 TO SELF.Rendered                  ! the page metafiles we left in %TEMP%
      wd_temp_name(SELF.H, L:I, L:Path, SIZE(L:Path))
      wd_delete_file(L:Path)
    END
    wd_destroy(SELF.H)
  END
  SELF.H = 0
  SELF.Rendered = 0
  SELF.Pages = 0
  IF NOT SELF.Buf &= NULL THEN DISPOSE(SELF.Buf).

WordDocClass.Alive PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H <> 0 AND wd_alive(SELF.H) <> 0)

WordDocClass.Slot PROCEDURE()
  CODE
  RETURN SELF.H

WordDocClass.StructSizes PROCEDURE()
  CODE
  RETURN wd_struct_sizes()

WordDocClass.Hwnd PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H = 0, 0, wd_hwnd(SELF.H))

! Follows the placeholder: its rectangle (a window resizer may move or stretch
! it), whether it is visible (it may sit on a TAB that is not showing), and
! whether it is disabled.
WordDocClass.Reposition PROCEDURE()
L:Pix  LONG
L:X    LONG
L:Y    LONG
L:W    LONG
L:H    LONG
L:Vis  LONG
L:Dis  LONG
  CODE
  IF SELF.H = 0 OR SELF.Feq = 0 THEN RETURN.
  L:Pix = 0{PROP:Pixels}
  0{PROP:Pixels} = 1
  L:X = SELF.Feq{PROP:Xpos}
  L:Y = SELF.Feq{PROP:Ypos}
  L:W = SELF.Feq{PROP:Width}
  L:H = SELF.Feq{PROP:Height}
  0{PROP:Pixels} = L:Pix
  IF L:X <> SELF.LastX OR L:Y <> SELF.LastY OR L:W <> SELF.LastW OR L:H <> SELF.LastH
    SELF.LastX = L:X; SELF.LastY = L:Y; SELF.LastW = L:W; SELF.LastH = L:H
    wd_move(SELF.H, L:X, L:Y, L:W, L:H)
  END
  L:Vis = SELF.Feq{PROP:Visible}                   ! a PROP read is a string - '0' is TRUE
  IF L:Vis <> SELF.Shown
    SELF.Shown = L:Vis
    wd_show(SELF.H, L:Vis)
  END
  L:Dis = SELF.Feq{PROP:Disable}
  wd_enable(SELF.H, CHOOSE(L:Dis = 0))

WordDocClass.TakeEvent PROCEDURE()
  CODE
  IF SELF.H = 0 THEN RETURN FALSE.
  SELF.Reposition()
  RETURN wd_get_modified(SELF.H)


!=== CONTENT ==================================================================
WordDocClass.LoadBlob PROCEDURE(*BLOB pBlob)
L:Size  LONG
L:Buf   &STRING
  CODE
  IF SELF.H = 0 THEN RETURN.
  L:Size = pBlob{PROP:Size}
  IF L:Size <= 0
    SELF.ClearAll()
    RETURN
  END
  L:Buf &= NEW STRING(L:Size)
  L:Buf = pBlob[0 : L:Size - 1]
  wd_load(SELF.H, L:Buf, L:Size)
  DISPOSE(L:Buf)

WordDocClass.SaveBlob PROCEDURE(*BLOB pBlob)
L:Len  LONG
L:Buf  &STRING
  CODE
  IF SELF.H = 0 THEN RETURN.
  L:Len = wd_save(SELF.H, 0)
  IF L:Len <= 0
    pBlob{PROP:Size} = 0
  ELSE
    L:Buf &= NEW STRING(L:Len)
    wd_copy(SELF.H, L:Buf, L:Len)
    pBlob{PROP:Size} = L:Len
    pBlob[0 : L:Len - 1] = L:Buf
    DISPOSE(L:Buf)
  END
  wd_set_modified(SELF.H, 0)

WordDocClass.LoadString PROCEDURE(STRING pRtfOrText)
L:Len  LONG
L:Buf  &STRING
  CODE
  IF SELF.H = 0 THEN RETURN.
  L:Len = LEN(CLIP(pRtfOrText))
  IF L:Len = 0 THEN SELF.ClearAll(); RETURN.
  L:Buf &= NEW STRING(L:Len)
  L:Buf = pRtfOrText
  wd_load(SELF.H, L:Buf, L:Len)
  DISPOSE(L:Buf)

WordDocClass.GetRtf PROCEDURE()
L:Len  LONG
  CODE
  IF NOT SELF.Buf &= NULL THEN DISPOSE(SELF.Buf).
  IF SELF.H = 0 THEN RETURN ''.
  L:Len = wd_save(SELF.H, 0)
  IF L:Len <= 0 THEN RETURN ''.
  SELF.Buf &= NEW STRING(L:Len)
  wd_copy(SELF.H, SELF.Buf, L:Len)
  RETURN SELF.Buf

WordDocClass.GetText PROCEDURE()
L:Len  LONG
  CODE
  IF NOT SELF.Buf &= NULL THEN DISPOSE(SELF.Buf).
  IF SELF.H = 0 THEN RETURN ''.
  L:Len = wd_save(SELF.H, 1)
  IF L:Len <= 0 THEN RETURN ''.
  SELF.Buf &= NEW STRING(L:Len)
  wd_copy(SELF.H, SELF.Buf, L:Len)
  RETURN SELF.Buf

WordDocClass.LoadFile PROCEDURE(STRING pFileName)
DocName  CSTRING(261),STATIC,THREAD
DocFile  FILE,DRIVER('DOS'),NAME(DocName),PRE(DF),THREAD
           RECORD
Chunk        STRING(32768)
           END
         END
L:Size   LONG
L:Pos    LONG
L:Got    LONG
L:Buf    &STRING
  CODE
  IF SELF.H = 0 THEN RETURN FALSE.
  DocName = CLIP(pFileName)
  OPEN(DocFile, 40H)                               ! read-only, deny none
  IF ERRORCODE() THEN RETURN FALSE.
  L:Size = BYTES(DocFile)
  IF L:Size <= 0 THEN CLOSE(DocFile); SELF.ClearAll(); RETURN TRUE.
  L:Buf &= NEW STRING(L:Size)
  L:Pos = 0
  LOOP WHILE L:Pos < L:Size
    GET(DocFile, L:Pos + 1, SIZE(DF:Chunk))
    IF ERRORCODE() THEN BREAK.
    L:Got = BYTES(DocFile)
    IF L:Got <= 0 THEN BREAK.
    IF L:Pos + L:Got > L:Size THEN L:Got = L:Size - L:Pos.
    L:Buf[L:Pos + 1 : L:Pos + L:Got] = DF:Chunk[1 : L:Got]
    L:Pos += L:Got
  END
  CLOSE(DocFile)
  wd_load(SELF.H, L:Buf, L:Pos)
  DISPOSE(L:Buf)
  RETURN TRUE

WordDocClass.SaveFile PROCEDURE(STRING pFileName)
DocName  CSTRING(261),STATIC,THREAD
DocFile  FILE,DRIVER('DOS'),NAME(DocName),PRE(DF),CREATE,THREAD
           RECORD
Chunk        STRING(32768)
           END
         END
L:Len    LONG
L:Pos    LONG
L:N      LONG
L:Buf    &STRING
  CODE
  IF SELF.H = 0 THEN RETURN FALSE.
  L:Len = wd_save(SELF.H, 0)
  DocName = CLIP(pFileName)
  CREATE(DocFile)
  IF ERRORCODE() THEN RETURN FALSE.
  OPEN(DocFile, 22H)                               ! read/write, deny write
  IF ERRORCODE() THEN RETURN FALSE.
  IF L:Len > 0
    L:Buf &= NEW STRING(L:Len)
    wd_copy(SELF.H, L:Buf, L:Len)
    L:Pos = 0
    LOOP WHILE L:Pos < L:Len
      L:N = L:Len - L:Pos
      IF L:N > SIZE(DF:Chunk) THEN L:N = SIZE(DF:Chunk).
      DF:Chunk[1 : L:N] = L:Buf[L:Pos + 1 : L:Pos + L:N]
      ADD(DocFile, L:N)
      L:Pos += L:N
    END
    DISPOSE(L:Buf)
  END
  CLOSE(DocFile)
  RETURN TRUE

WordDocClass.ClearAll PROCEDURE()
L:Empty  STRING(1)
  CODE
  IF SELF.H THEN wd_load(SELF.H, L:Empty, 0).

WordDocClass.Length PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H = 0, 0, wd_length(SELF.H))

WordDocClass.Modified PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H <> 0 AND wd_get_modified(SELF.H) <> 0)

WordDocClass.SetModified PROCEDURE(BYTE pOn)
  CODE
  IF SELF.H THEN wd_set_modified(SELF.H, pOn).


!=== INSERTING ================================================================
WordDocClass.InsertText PROCEDURE(STRING pText)
L:Txt  &CSTRING
  CODE
  IF SELF.H = 0 THEN RETURN.
  L:Txt &= NEW CSTRING(LEN(pText) + 1)
  L:Txt = pText
  wd_insert_text(SELF.H, L:Txt)
  DISPOSE(L:Txt)

WordDocClass.InsertRtf PROCEDURE(STRING pRtf)
L:Len  LONG
L:Buf  &STRING
  CODE
  IF SELF.H = 0 THEN RETURN.
  L:Len = LEN(CLIP(pRtf))
  IF L:Len = 0 THEN RETURN.
  L:Buf &= NEW STRING(L:Len)
  L:Buf = pRtf
  wd_insert_rtf(SELF.H, L:Buf, L:Len)
  DISPOSE(L:Buf)

! 1 = inserted; -1 cannot read the file, -2 not PNG/JPG/BMP/EMF/WMF, -3 no memory
WordDocClass.InsertImage PROCEDURE(STRING pFileName,LONG pMaxWidthTw=0)
L:Path  CSTRING(261)
  CODE
  IF SELF.H = 0 THEN RETURN 0.
  L:Path = CLIP(pFileName)
  RETURN wd_insert_image(SELF.H, L:Path, pMaxWidthTw)

WordDocClass.InsertTable PROCEDURE(LONG pRows,LONG pCols,LONG pWidthTw=0)
  CODE
  IF SELF.H = 0 THEN RETURN FALSE.
  RETURN wd_insert_table(SELF.H, pRows, pCols, pWidthTw)


!=== FORMATTING ===============================================================
WordDocClass.Bold      PROCEDURE(BYTE pHow=WD:Toggle)
  CODE
  IF SELF.H THEN wd_effect(SELF.H, 1, pHow).
WordDocClass.Italic    PROCEDURE(BYTE pHow=WD:Toggle)
  CODE
  IF SELF.H THEN wd_effect(SELF.H, 2, pHow).
WordDocClass.Underline PROCEDURE(BYTE pHow=WD:Toggle)
  CODE
  IF SELF.H THEN wd_effect(SELF.H, 3, pHow).
WordDocClass.Strike    PROCEDURE(BYTE pHow=WD:Toggle)
  CODE
  IF SELF.H THEN wd_effect(SELF.H, 4, pHow).

WordDocClass.SetFont PROCEDURE(STRING pFace)
L:Face  CSTRING(32)
  CODE
  IF SELF.H = 0 THEN RETURN.
  L:Face = CLIP(pFace)
  wd_set_face(SELF.H, L:Face)

WordDocClass.SetFontSize PROCEDURE(REAL pPoints)
  CODE
  IF SELF.H THEN wd_set_size(SELF.H, pPoints * 10).

! Clarion colours are already 0BBGGRRh like Win32; system colours (negative)
! and COLOR:None mean "automatic"
WordDocClass.SetColor PROCEDURE(LONG pColor)
  CODE
  IF SELF.H THEN wd_set_color(SELF.H, CHOOSE(pColor < 0, -1, pColor)).

WordDocClass.SetHighlight PROCEDURE(LONG pColor)
  CODE
  IF SELF.H THEN wd_set_back(SELF.H, CHOOSE(pColor < 0, -1, pColor)).

WordDocClass.SetAlign PROCEDURE(BYTE pAlign)
  CODE
  IF SELF.H THEN wd_set_align(SELF.H, pAlign).

WordDocClass.SetList PROCEDURE(BYTE pStyle)
  CODE
  IF SELF.H THEN wd_set_numbering(SELF.H, pStyle).

WordDocClass.Indent PROCEDURE(LONG pTwips=360)
  CODE
  IF SELF.H THEN wd_indent(SELF.H, pTwips).

WordDocClass.Outdent PROCEDURE(LONG pTwips=360)
  CODE
  IF SELF.H THEN wd_indent(SELF.H, -pTwips).

WordDocClass.GetFont PROCEDURE()
L:Face  CSTRING(32)
  CODE
  IF SELF.H = 0 THEN RETURN ''.
  wd_get_face(SELF.H, L:Face, SIZE(L:Face))
  RETURN L:Face

WordDocClass.GetFormat PROCEDURE(LONG pWhich)
  CODE
  RETURN CHOOSE(SELF.H = 0, 0, wd_get_format(SELF.H, pWhich))


!=== EDITING ==================================================================
WordDocClass.Undo      PROCEDURE()
  CODE
  IF SELF.H THEN wd_command(SELF.H, 1).
WordDocClass.Redo      PROCEDURE()
  CODE
  IF SELF.H THEN wd_command(SELF.H, 2).
WordDocClass.CanUndo PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H <> 0 AND wd_can(SELF.H, 1) <> 0)
WordDocClass.CanRedo PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.H <> 0 AND wd_can(SELF.H, 2) <> 0)
WordDocClass.ClearUndo PROCEDURE()
  CODE
  IF SELF.H THEN wd_undo_clear(SELF.H).
WordDocClass.SetUndoLimit PROCEDURE(LONG pSteps)
  CODE
  IF SELF.H THEN wd_undo_limit(SELF.H, pSteps).
! Several edits from code (inserts, formatting, tool calls) as one Ctrl+Z.
WordDocClass.BeginUndoGroup PROCEDURE()
  CODE
  IF SELF.H THEN wd_undo_group(SELF.H, 1).
WordDocClass.EndUndoGroup PROCEDURE()
  CODE
  IF SELF.H THEN wd_undo_group(SELF.H, 0).
WordDocClass.CutText   PROCEDURE()
  CODE
  IF SELF.H THEN wd_command(SELF.H, 3).
WordDocClass.CopyText  PROCEDURE()
  CODE
  IF SELF.H THEN wd_command(SELF.H, 4).
WordDocClass.PasteText PROCEDURE()
  CODE
  IF SELF.H THEN wd_command(SELF.H, 5).
WordDocClass.SelectAll PROCEDURE()
  CODE
  IF SELF.H THEN wd_command(SELF.H, 6).

WordDocClass.SelectText PROCEDURE(LONG pFrom,LONG pTo)
  CODE
  IF SELF.H THEN wd_select(SELF.H, pFrom, pTo).

! selects the next match (wrapping to the top); returns its position or -1
WordDocClass.Find PROCEDURE(STRING pText,BYTE pMatchCase=0,BYTE pWholeWord=0)
L:Txt  &CSTRING
L:R    LONG
  CODE
  IF SELF.H = 0 OR NOT CLIP(pText) THEN RETURN -1.
  L:Txt &= NEW CSTRING(LEN(CLIP(pText)) + 1)
  L:Txt = CLIP(pText)
  L:R = wd_find(SELF.H, L:Txt, pMatchCase, pWholeWord)
  DISPOSE(L:Txt)
  RETURN L:R

WordDocClass.Focus PROCEDURE()
  CODE
  IF SELF.H THEN wd_focus(SELF.H).

WordDocClass.SetReadOnly PROCEDURE(BYTE pOn)
  CODE
  SELF.ReadOnly = pOn
  IF SELF.H THEN wd_set_readonly(SELF.H, pOn).

WordDocClass.SetToolbar PROCEDURE(BYTE pOn)
  CODE
  SELF.ShowToolbar = pOn
  IF SELF.H
    wd_set_flags(SELF.H, CHOOSE(pOn <> 0, WD:Toolbar, 0) + CHOOSE(SELF.ReadOnly <> 0, WD:ReadOnly, 0) + |
                         CHOOSE(SELF.PageView <> 0, WD:PageView, 0))
  END

WordDocClass.SetZoom PROCEDURE(LONG pPercent)
  CODE
  IF SELF.H THEN wd_set_zoom(SELF.H, pPercent).

WordDocClass.SetPaperColor PROCEDURE(LONG pColor)
  CODE
  IF SELF.H THEN wd_set_paper(SELF.H, CHOOSE(pColor < 0, -1, pColor)).

WordDocClass.SetPageWidth PROCEDURE(LONG pTwips)
  CODE
  SELF.PageWidth = pTwips
  IF SELF.H THEN wd_set_page_width(SELF.H, pTwips).


!=== PRINTING =================================================================
! Splits the document into pages of pWidthTw x pHeightTw twips (1/1440 inch).
WordDocClass.Paginate PROCEDURE(LONG pWidthTw,LONG pHeightTw)
  CODE
  SELF.Pages = 0
  IF SELF.H = 0 THEN RETURN 0.
  SELF.PageW = pWidthTw
  SELF.PageH = pHeightTw
  SELF.Pages = wd_paginate(SELF.H, pWidthTw, pHeightTw)
  RETURN SELF.Pages

WordDocClass.PageUsedHeight PROCEDURE(LONG pPage)
  CODE
  RETURN CHOOSE(SELF.H = 0, 0, wd_page_used(SELF.H, pPage))

! Draws page N into %TEMP% as an enhanced metafile and returns the path. The
! files are removed by Kill.
WordDocClass.RenderPage PROCEDURE(LONG pPage)
L:Path  CSTRING(300)
L:H     LONG
  CODE
  IF SELF.H = 0 OR pPage < 1 OR pPage > SELF.Pages THEN RETURN ''.
  wd_temp_name(SELF.H, pPage, L:Path, SIZE(L:Path))
  L:H = SELF.PageH
  IF wd_render_page(SELF.H, pPage, SELF.PageW, L:H, L:Path) = 0 THEN RETURN ''.
  IF pPage > SELF.Rendered THEN SELF.Rendered = pPage.
  RETURN L:Path

! Writes page N to a file of your choosing: an enhanced metafile for .emf, a
! placeable Windows metafile for .wmf.
WordDocClass.RenderPageTo PROCEDURE(LONG pPage,STRING pFileName)
L:Path  CSTRING(261)
  CODE
  IF SELF.H = 0 OR pPage < 1 OR pPage > SELF.Pages THEN RETURN FALSE.
  L:Path = CLIP(pFileName)
  RETURN CHOOSE(wd_render_page(SELF.H, pPage, SELF.PageW, SELF.PageH, L:Path) <> 0)

! Measures the report IMAGE that will carry the document and paginates to its
! size. The report's own units do not matter: like ABC's ReportAttributeManager
! we switch it to THOUS for the read and put it back.
! WD:Flow cuts it one line per piece instead (RichEdit always lays out at least
! one line, so a 1-twip page is one line). Each line is then its own band, and
! the report engine itself puts it on this page if it fits or the next if not:
! the document starts in whatever room is left and fills every page.
WordDocClass.PaginateForReport PROCEDURE(*REPORT pReport,LONG pImageFeq,BYTE pMode=0)
L:WasThous  LONG
L:WasMM     LONG
L:WasPts    LONG
L:W         LONG
L:H         LONG
L:Band      LONG
  CODE
  IF SELF.H = 0 THEN RETURN 0.
  L:WasThous = pReport{PROP:Thous}
  L:WasMM    = pReport{PROP:MM}
  L:WasPts   = pReport{PROP:Points}
  pReport{PROP:Thous} = TRUE
  L:Band = pReport $ pImageFeq{PROP:Parent}
  IF SELF.ShrunkFeq = pImageFeq                    ! the previous document's last page shrank it:
    pReport $ pImageFeq{PROP:Height} = SELF.FullH  ! put the designed size back before measuring
    pReport $ pImageFeq{PROP:Ypos} = SELF.FullY
    IF L:Band AND SELF.BandH THEN pReport $ L:Band{PROP:Height} = SELF.BandH.
  END
  SELF.ShrunkFeq = 0
  SELF.Flow = CHOOSE(pMode = WD:Flow)
  SELF.FullY = pReport $ pImageFeq{PROP:Ypos}
  L:W = pReport $ pImageFeq{PROP:Width}
  L:H = pReport $ pImageFeq{PROP:Height}
  SELF.FullH = L:H
  SELF.BandH = CHOOSE(L:Band = 0, 0, pReport $ L:Band{PROP:Height})
  IF L:WasMM
    pReport{PROP:MM} = TRUE
  ELSIF L:WasPts
    pReport{PROP:Points} = TRUE
  ELSIF NOT L:WasThous
    pReport{PROP:Thous} = FALSE
  END
  IF SELF.Flow
    SELF.Paginate(L:W * 1.44, 1)                   ! one line per piece
    SELF.PageH = L:H * 1.44                        ! the tallest a piece may print
    RETURN SELF.Pages
  END
  RETURN SELF.Paginate(L:W * 1.44, L:H * 1.44)     ! thousandths of an inch -> twips

! Points the report IMAGE at page N. With pShrinkLast the last page's IMAGE and
! band are cut down to what the text really fills, so whatever prints after the
! document follows straight on instead of after a blank page-sized gap.
WordDocClass.PreparePage PROCEDURE(*REPORT pReport,LONG pImageFeq,LONG pPage,BYTE pShrinkLast=1)
L:WasThous  LONG
L:WasMM     LONG
L:WasPts    LONG
L:Used      LONG
L:UsedTh    LONG
L:Band      LONG
L:Path      CSTRING(300)
L:Shrink    BYTE
  CODE
  IF SELF.H = 0 OR pPage < 1 OR pPage > SELF.Pages THEN RETURN.
  L:Shrink = CHOOSE(pShrinkLast <> 0 AND pPage = SELF.Pages)
  IF SELF.Flow                                     ! one line: exactly its height, in whole thous
    L:Shrink = TRUE
    L:Used = wd_page_used(SELF.H, pPage)
    IF L:Used > SELF.PageH THEN L:Used = SELF.PageH.
    IF L:Used < 15 THEN L:Used = 15.
    L:Used = INT((L:Used + 1.43) / 1.44) * 1.44    ! round up to a whole thou, so the lines stack exactly
  ELSIF L:Shrink
    L:Used = wd_page_used(SELF.H, pPage) + 60      ! a little slack under the last line
    IF L:Used > SELF.PageH OR L:Used <= 60 THEN L:Used = SELF.PageH.
  ELSE
    L:Used = SELF.PageH
  END
  wd_temp_name(SELF.H, pPage, L:Path, SIZE(L:Path))
  IF wd_render_page(SELF.H, pPage, SELF.PageW, L:Used, L:Path) = 0 THEN RETURN.
  IF pPage > SELF.Rendered THEN SELF.Rendered = pPage.

  L:WasThous = pReport{PROP:Thous}
  L:WasMM    = pReport{PROP:MM}
  L:WasPts   = pReport{PROP:Points}
  pReport{PROP:Thous} = TRUE
  L:UsedTh = ROUND(L:Used / 1.44, 1)
  L:Band = pReport $ pImageFeq{PROP:Parent}
  pReport $ pImageFeq{PROP:Height} = L:UsedTh
  IF SELF.Flow                                     ! the band is just the line: no gap between lines
    pReport $ pImageFeq{PROP:Ypos} = 0
    IF L:Band THEN pReport $ L:Band{PROP:Height} = L:UsedTh.
  ELSIF L:Band AND SELF.BandH
    pReport $ L:Band{PROP:Height} = SELF.BandH - SELF.FullH + L:UsedTh
  END
  IF L:Shrink THEN SELF.ShrunkFeq = pImageFeq.      ! PaginateForReport undoes it for the next document
  IF L:WasMM
    pReport{PROP:MM} = TRUE
  ELSIF L:WasPts
    pReport{PROP:Points} = TRUE
  ELSIF NOT L:WasThous
    pReport{PROP:Thous} = FALSE
  END
  pReport $ pImageFeq{PROP:Text} = ''               ! an IMAGE only re-reads its file when the name
  pReport $ pImageFeq{PROP:Text} = L:Path          ! changes, and page N of every document has the same one
