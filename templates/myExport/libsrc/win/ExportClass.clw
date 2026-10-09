! ============================================================================
!  ExportClass - implementation.   See ExportClass.inc for the overview.
!
!  This file must be stored ANSI, with CRLF line endings.
! ============================================================================
  MEMBER()

  MAP
    MODULE('win32')
      exCreateFile(*CSTRING lpFileName, ULONG dwDesiredAccess, ULONG dwShareMode, LONG lpSecurityAttributes, ULONG dwCreationDisposition, ULONG dwFlagsAndAttributes, LONG hTemplateFile),LONG,RAW,PASCAL,NAME('CreateFileA')
      exWriteFile( LONG hFile, *STRING lpBuffer, ULONG nBytes, *ULONG lpWritten, LONG lpOverlapped ),LONG,RAW,PASCAL,NAME('WriteFile')
      exCloseHandle( LONG hObject ),LONG,RAW,PASCAL,PROC,NAME('CloseHandle')
      exMB2WC( UNSIGNED CodePage, ULONG dwFlags, *STRING lpMultiByteStr, SIGNED cbMultiByte, *STRING lpWideCharStr, SIGNED cchWideChar ),SIGNED,RAW,PASCAL,NAME('MultiByteToWideChar')
      exWC2MB( UNSIGNED CodePage, ULONG dwFlags, *STRING lpWideCharStr, SIGNED cchWideChar, *STRING lpMultiByteStr, SIGNED cbMultiByte, LONG lpDefaultChar, LONG lpUsedDefault ),SIGNED,RAW,PASCAL,NAME('WideCharToMultiByte')
      exShellExec( LONG hwnd, *CSTRING lpOperation, *CSTRING lpFile, *CSTRING lpParameters, *CSTRING lpDirectory, SIGNED nShowCmd ),ULONG,PASCAL,RAW,PROC,NAME('ShellExecuteA')
      exModuleFile( LONG hModule, *CSTRING lpFilename, ULONG nSize ),ULONG,RAW,PASCAL,NAME('GetModuleFileNameA')
      exGetTempPath( ULONG nSize,*CSTRING pBuf ),ULONG,RAW,PASCAL,NAME('GetTempPathA')
      exMoveFileEx( *CSTRING lpExistingFileName, *CSTRING lpNewFileName, ULONG dwFlags ),LONG,RAW,PASCAL,NAME('MoveFileExA')
      exDeleteFile( *CSTRING lpFileName ),LONG,RAW,PASCAL,PROC,NAME('DeleteFileA')
!     ---- printing: plain GDI, no complex Win32 structs -----------------
      exGetDefaultPrinter( *CSTRING pBuf,*LONG pSize ),LONG,RAW,PASCAL,NAME('GetDefaultPrinterA')
      exCreateDC( *CSTRING pDriver,*CSTRING pDevice,LONG pOutput,LONG pInitData ),LONG,RAW,PASCAL,NAME('CreateDCA')
      exStartDoc( LONG hDC,*GROUP pDI ),SIGNED,RAW,PASCAL,NAME('StartDocA')
      exEndDoc( LONG hDC ),SIGNED,RAW,PASCAL,PROC,NAME('EndDoc')
      exStartPage( LONG hDC ),SIGNED,RAW,PASCAL,PROC,NAME('StartPage')
      exEndPage( LONG hDC ),SIGNED,RAW,PASCAL,PROC,NAME('EndPage')
      exDeleteDC( LONG hDC ),SIGNED,RAW,PASCAL,PROC,NAME('DeleteDC')
      exCreateFont( SIGNED nHeight,SIGNED nWidth,SIGNED nEsc,SIGNED nOrient,SIGNED nWeight, |
                    ULONG bItalic,ULONG bUnder,ULONG bStrike,ULONG nCharSet,ULONG nOutPrec, |
                    ULONG nClipPrec,ULONG nQuality,ULONG nPitch,*CSTRING pFace ),LONG,RAW,PASCAL,NAME('CreateFontA')
      exSelectObject( LONG hDC,LONG hObj ),LONG,RAW,PASCAL,PROC,NAME('SelectObject')
      exDeleteObject( LONG hObj ),SIGNED,RAW,PASCAL,PROC,NAME('DeleteObject')
      exGetDeviceCaps( LONG hDC,SIGNED nIndex ),SIGNED,RAW,PASCAL,NAME('GetDeviceCaps')
      exTextOut( LONG hDC,SIGNED x,SIGNED y,*CSTRING pStr,SIGNED nCount ),SIGNED,RAW,PASCAL,PROC,NAME('TextOutA')
      exGetTextExtent( LONG hDC,*CSTRING pStr,SIGNED nCount,*GROUP pSize ),SIGNED,RAW,PASCAL,PROC,NAME('GetTextExtentPoint32A')
      exSetBkMode( LONG hDC,SIGNED nMode ),SIGNED,RAW,PASCAL,PROC,NAME('SetBkMode')
!     ---- "Email it when it is done": Outlook (or whatever mail client) would
!     ---- otherwise only flash on the taskbar rather than actually coming to
!     ---- the front - Windows' foreground-lock, by design, stops a background
!     ---- process from stealing focus outright. This tells Windows "let
!     ---- whichever process asks next have it" - called right before
!     ---- MAPISendMail, in EmailFile().
      exAllowSetForegroundWindow( LONG dwProcessId ),SIGNED,RAW,PASCAL,PROC,NAME('AllowSetForegroundWindow')
      exLoadLibrary( *CSTRING lpLibFileName ),LONG,RAW,PASCAL,NAME('LoadLibraryA')
      exGetProcAddress( LONG hModule,*CSTRING lpProcName ),LONG,RAW,PASCAL,NAME('GetProcAddress')
    END
    MODULE('MAPI32.DLL')
!     ---- "Email it when it is done": Simple MAPI, whatever mail client is
!     ---- registered as the default (Outlook, Windows Mail, etc.). Loaded at
!     ---- RUN time, not linked: Clarion ships no MAPI32.LIB, so a link-time
!     ---- import broke the build of every app that uses ExportClass on a
!     ---- machine without one. DLL(1) + a NAME shared with exMAPISendMailFp
!     ---- below makes this a call through that pointer - the StringTheory
!     ---- recipe for zlib. EmailFile() fills it with GetProcAddress.
      exMAPISendMail( LONG lhSession, LONG ulUIParam, *GROUP lpMessage, ULONG flFlags, ULONG ulReserved ), |
                      ULONG,RAW,PASCAL,DLL(1),NAME('exMAPISendMailFp')
    END
  END

!  MAPISendMail, found at run time the first time an export is e-mailed.
!  0 until then; still 0 if the machine has no Simple MAPI at all.
exMAPISendMailFp   LONG,NAME('exMAPISendMailFp')

  INCLUDE('ExportClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

Exp:CP_ACP         EQUATE(0)                    ! the machine's ANSI code page
Exp:CP_UTF8        EQUATE(65001)
Exp:MinChunk       EQUATE(65536)                ! the buffers never start smaller than this
Exp:PdfPageCap     EQUATE(2000)                 ! PdfPageObjs' DIM size - see PdfNewPage for what happens past this
Exp:BOM            EQUATE('<239,187,191>')      ! UTF-8 byte order mark
Exp:CRLF           EQUATE('<13,10>')
Exp:TAB            EQUATE('<9>')

! ---- GDI constants used only by Print ---------------------------------
Prn:LOGPIXELSX          EQUATE(88)
Prn:LOGPIXELSY          EQUATE(90)
Prn:HORZRES             EQUATE(8)
Prn:VERTRES             EQUATE(10)
Prn:TRANSPARENT         EQUATE(1)

! ############################################################################
!  Lifetime
! ############################################################################
ExportClass.Construct PROCEDURE
  CODE
  SELF.Cols    &= NEW ExportColumnQueue
  SELF.Parts   &= NEW ExportZipQueue
  SELF.PdfObjs &= NEW ExportPdfQueue
  SELF.Delim  = ','
  SELF.RowTag = 'Row'
  SELF.Title  = 'Data'
  SELF.TotalsLabel = 'Total'
  SELF.AvgLabel    = 'Average'
  SELF.MinLabel    = 'Minimum'
  SELF.MaxLabel    = 'Maximum'
  SELF.CntLabel    = 'Count'


ExportClass.Destruct PROCEDURE
  CODE
  SELF.Kill()


ExportClass.Init PROCEDURE(SIGNED pList,*QUEUE pQ)
  CODE
  SELF.ListControl = pList
  SELF.Q          &= pQ
  SELF.ScanColumns()


ExportClass.Kill PROCEDURE
  CODE
  SELF.FreeBuffers()
  IF ~SELF.Cols &= NULL
    FREE(SELF.Cols)
    DISPOSE(SELF.Cols)
  END
  IF ~SELF.Parts &= NULL
    FREE(SELF.Parts)
    DISPOSE(SELF.Parts)
  END
  IF ~SELF.PdfObjs &= NULL
    FREE(SELF.PdfObjs)
    DISPOSE(SELF.PdfObjs)
  END


! ############################################################################
!  Reading the LIST's own layout
! ############################################################################
!  Everything the export knows about its columns comes from the live control,
!  so a column the user hid, widened or dragged somewhere else is honoured.
!
!  Init calls this before every export, but the user may have renamed columns
!  or un-ticked some in the dialog - and those edits must survive to the next
!  export. So it fingerprints the LIST's layout first and only rebuilds when
!  the layout has actually changed. Rescan() forces it.
ExportClass.ScanColumns PROCEDURE()
c    LONG,AUTO
f    LONG,AUTO
n    LONG,AUTO
p    LONG,AUTO
w    LONG,AUTO
ex   LONG,AUTO
ic   LONG,AUTO
it   LONG,AUTO
sg   CSTRING(1025)
h    CSTRING(129)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  IF ~SELF.ListControl
    FREE(SELF.Cols)
    SELF.Sig = ''
    RETURN 0
  END
  sg = SELF.LayoutSig()
  IF sg = SELF.Sig AND RECORDS(SELF.Cols)
    RETURN RECORDS(SELF.Cols)                             ! same layout - keep the user's choices
  END
  FREE(SELF.Cols)
  n = 0
!  Every PROPLIST read goes through a LONG first: a property returns a STRING,
!  and the STRING '0' is logically TRUE - so ~?List{PROPLIST:Width,c} never
!  fires on a hidden column, and a plain ?List{PROPLIST:Icon,c} is always true.
  LOOP c = 1 TO 512
    ex = SELF.ListControl{PROPLIST:Exists,c}
    IF ~ex THEN BREAK .
    f = SELF.ListControl{PROPLIST:FieldNo,c}
    IF ~f THEN CYCLE .                                    ! a decoration, not a data column
    w  = SELF.ListControl{PROPLIST:Width,c}
    IF SELF.HideZeroWidth AND ~w THEN CYCLE .             ! leave it out of the picker entirely, not just unticked
    ic = SELF.ListControl{PROPLIST:Icon,c}
    it = SELF.ListControl{PROPLIST:IconTrn,c}
    n += 1
    h = CLIP(SELF.ListControl{PROPLIST:Header,c})
    LOOP p = 1 TO LEN(h)                                  ! '|' wraps a heading on screen
      IF h[p] = '|' THEN h[p] = ' ' .
    END
    h = CLIP(LEFT(h))
    IF ~h THEN h = SELF.Txt(Txt:ColumnWord) & n .
    SELF.Cols.ColNo   = c
    SELF.Cols.FldNo   = f
    SELF.Cols.Width   = w
    SELF.Cols.HeadDef = h
    SELF.Cols.PicDef  = CLIP(SELF.ListControl{PROPLIST:Picture,c})
    SELF.Cols.Head    = SELF.Cols.HeadDef
    SELF.Cols.Pic     = SELF.Cols.PicDef
!   Hidden and icon columns are listed but start un-ticked, so the dialog can
!   still offer them - VisibleOnly picks the starting state, not the contents.
    SELF.Cols.Use = 1
    IF SELF.VisibleOnly
      IF ic OR it OR ~w THEN SELF.Cols.Use = 0 .
    END
    ADD(SELF.Cols)
    SELF.Classify(n)
  END
  SELF.Sig = sg
  RETURN n


ExportClass.Rescan PROCEDURE()
  CODE
  SELF.Sig = ''                                           ! forget the layout we matched against
  RETURN SELF.ScanColumns()


!  A fingerprint of the LIST's format. Column count, field numbers and widths
!  are enough: if those match, it is the same layout and the user's renames,
!  picture overrides and tick marks still apply.
ExportClass.LayoutSig PROCEDURE()
c    LONG,AUTO
ex   LONG,AUTO
sg   CSTRING(1025)
one  CSTRING(41)
  CODE
  sg = ''
  IF ~SELF.ListControl THEN RETURN sg .
  LOOP c = 1 TO 512
    ex = SELF.ListControl{PROPLIST:Exists,c}
    IF ~ex THEN BREAK .
    one = c & ':' & SELF.ListControl{PROPLIST:FieldNo,c} & ':' & SELF.ListControl{PROPLIST:Width,c} & ';'
    IF LEN(sg) + LEN(one) > 1024 THEN BREAK .
    sg = sg & one
  END
  RETURN sg


!  Tag (the XML/JSON name) and IsNum both follow the CURRENT heading and
!  picture, so they are re-derived whenever either is edited.
ExportClass.Classify PROCEDURE(LONG pCol)
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  SELF.Cols.Tag   = SELF.SafeTag(SELF.Cols.Head,pCol)
  SELF.Cols.IsNum = 0
  IF ~SELF.Q &= NULL                                      ! a real number, shown as a number?
    IF ~ISSTRING(WHAT(SELF.Q,SELF.Cols.FldNo))
      IF ~SELF.Cols.Pic
        SELF.Cols.IsNum = 1
      ELSIF UPPER(SUB(SELF.Cols.Pic,1,2)) = '@N'          ! @D / @T / @P / @S / @E stay text
        SELF.Cols.IsNum = 1
      END
    END
  END
  PUT(SELF.Cols)


ExportClass.Columns PROCEDURE()
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  RETURN RECORDS(SELF.Cols)


ExportClass.Selected PROCEDURE()
i  LONG,AUTO
n  LONG(0)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  LOOP i = 1 TO RECORDS(SELF.Cols)
    GET(SELF.Cols,i)
    IF ~ERRORCODE() AND SELF.Cols.Use THEN n += 1 .
  END
  RETURN n


! ############################################################################
!  Remembering the last export
! ############################################################################
!  Everything the user chose in the dialog - the format, the folder, the three
!  option ticks and the whole column list - is written to an INI section when
!  an export succeeds, and read back the next time the dialog opens.
!
!  The saved columns are keyed by position and guarded by SigKey(), a short
!  fingerprint of the LIST's layout. If the browse gains, loses or re-sizes a
!  column the fingerprint no longer matches and the stale column settings are
!  ignored - the format, folder and flags still come back.

!  IniFile if you set one, otherwise <the running exe>.INI beside the program.
ExportClass.IniPath PROCEDURE()
nm  CSTRING(261)
n   ULONG,AUTO
i   LONG,AUTO
cut LONG(0)
  CODE
  IF CLIP(LEFT(SELF.IniFile)) THEN RETURN CLIP(LEFT(SELF.IniFile)) .
  nm = ''
  n  = exModuleFile(0,nm,260)
  IF ~n THEN RETURN '' .                                  ! no path: GETINI falls back to WIN.INI
  LOOP i = LEN(nm) TO 1 BY -1
    IF nm[i] = '\' OR nm[i] = '/' THEN BREAK .
    IF nm[i] = '.' THEN cut = i; BREAK .
  END
  IF cut THEN nm = SUB(nm,1,cut-1) .
  RETURN CLIP(nm) & '.INI'


ExportClass.IniSection PROCEDURE()
p  CSTRING(65)
  CODE
  p = CLIP(LEFT(SELF.Profile))
  IF ~p THEN p = SELF.SafeTag(SELF.Title,0) .
  RETURN 'myExport_' & p


!  A short, INI-safe stand-in for the layout fingerprint: the column count plus
!  a rolling checksum kept small enough that a LONG never overflows.
ExportClass.SigKey PROCEDURE()
sg   CSTRING(1025)
i    LONG,AUTO
sum  LONG(0)
  CODE
  sg = SELF.LayoutSig()
  LOOP i = 1 TO LEN(sg)
    sum = (sum * 31 + VAL(sg[i])) % 99991
  END
  RETURN SELF.Columns() & 'x' & sum


ExportClass.FolderOf PROCEDURE(STRING pPath)
n  CSTRING(261)
i  LONG,AUTO
  CODE
  n = CLIP(LEFT(pPath))
  LOOP i = LEN(n) TO 1 BY -1
    IF n[i] = '\' OR n[i] = '/' THEN RETURN SUB(n,1,i-1) .
  END
  RETURN ''


ExportClass.LoadSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
fold  CSTRING(261)
v     CSTRING(161)
i     LONG,AUTO
gotGroup BYTE,AUTO
  CODE
  SELF.Loaded = 1
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  SELF.Fmt          = GETINI(sect,'Fmt',SELF.Fmt,f)
  SELF.Headers      = GETINI(sect,'Headers',SELF.Headers,f)
  SELF.PageOrient   = GETINI(sect,'PageOrient',SELF.PageOrient,f)
  SELF.EmailToFront = GETINI(sect,'EmailToFront',SELF.EmailToFront,f)
  SELF.Pictures     = GETINI(sect,'Pictures',SELF.Pictures,f)
  SELF.OpenWhenDone = GETINI(sect,'OpenWhenDone',SELF.OpenWhenDone,f)
  SELF.EmailWhenDone = GETINI(sect,'EmailWhenDone',SELF.EmailWhenDone,f)
  SELF.Totals       = GETINI(sect,'Totals',SELF.Totals,f)
  SELF.TotalsAvg    = GETINI(sect,'TotalsAvg',SELF.TotalsAvg,f)
  SELF.TotalsMin    = GETINI(sect,'TotalsMin',SELF.TotalsMin,f)
  SELF.TotalsMax    = GETINI(sect,'TotalsMax',SELF.TotalsMax,f)
  SELF.TotalsCnt    = GETINI(sect,'TotalsCnt',SELF.TotalsCnt,f)
  fold = GETINI(sect,'Folder','',f)
  IF CLIP(fold)                                           ! same folder, a freshly-dated name
    SELF.FileName = CLIP(fold) & '\' & SELF.SuggestName()
    SELF.ForceExt(SELF.Fmt)
  END
  IF GETINI(sect,'Sig','',f) <> SELF.SigKey() THEN RETURN .  ! layout changed - keep the live columns
  LOOP i = 1 TO SELF.Columns()
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    SELF.Cols.Use = GETINI(sect,'C' & i & '.Use',SELF.Cols.Use,f)
    v = GETINI(sect,'C' & i & '.Head','',f)
    IF CLIP(v) THEN SELF.Cols.Head = CLIP(v) .
    v = GETINI(sect,'C' & i & '.Pic','',f)                 ! stored with a leading '=' so that a
    IF SUB(v,1,1) = '='                                    ! deliberately BLANK picture survives
      SELF.Cols.Pic = CLIP(SUB(v,2,32))
    END
    PUT(SELF.Cols)
    SELF.Classify(i)
    GET(SELF.Cols,i)                                        ! Classify() re-derives IsNum - read it back
    IF ~ERRORCODE()
      SELF.Cols.Total = GETINI(sect,'C' & i & '.Total',SELF.Cols.Total,f)
      IF ~SELF.Cols.IsNum THEN SELF.Cols.Total = 0 .          ! a saved layout may have changed since
      SELF.Cols.GroupBy = GETINI(sect,'C' & i & '.GroupBy',SELF.Cols.GroupBy,f)
      PUT(SELF.Cols)
    END
  END
  gotGroup = 0                                                ! in case the INI somehow had more than one
  LOOP i = 1 TO SELF.Columns()
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    IF SELF.Cols.GroupBy
      IF gotGroup
        SELF.Cols.GroupBy = 0
        PUT(SELF.Cols)
      ELSE
        gotGroup = 1
      END
    END
  END


ExportClass.SaveSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
i     LONG,AUTO
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Fmt',SELF.Fmt,f)
  PUTINI(sect,'Headers',SELF.Headers,f)
  PUTINI(sect,'PageOrient',SELF.PageOrient,f)
  PUTINI(sect,'EmailToFront',SELF.EmailToFront,f)
  PUTINI(sect,'Pictures',SELF.Pictures,f)
  PUTINI(sect,'OpenWhenDone',SELF.OpenWhenDone,f)
  PUTINI(sect,'EmailWhenDone',SELF.EmailWhenDone,f)
  PUTINI(sect,'Totals',SELF.Totals,f)
  PUTINI(sect,'TotalsAvg',SELF.TotalsAvg,f)
  PUTINI(sect,'TotalsMin',SELF.TotalsMin,f)
  PUTINI(sect,'TotalsMax',SELF.TotalsMax,f)
  PUTINI(sect,'TotalsCnt',SELF.TotalsCnt,f)
  PUTINI(sect,'Folder',SELF.FolderOf(SELF.FileName),f)
  PUTINI(sect,'Sig',SELF.SigKey(),f)
  LOOP i = 1 TO SELF.Columns()
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    PUTINI(sect,'C' & i & '.Use',SELF.Cols.Use,f)
    IF SELF.Cols.Head <> SELF.Cols.HeadDef                 ! only store what the user changed
      PUTINI(sect,'C' & i & '.Head',CLIP(SELF.Cols.Head),f)
    ELSE
      PUTINI(sect,'C' & i & '.Head','',f)
    END
    IF SELF.Cols.Pic <> SELF.Cols.PicDef
      PUTINI(sect,'C' & i & '.Pic','=' & CLIP(SELF.Cols.Pic),f)
    ELSE
      PUTINI(sect,'C' & i & '.Pic','',f)
    END
    PUTINI(sect,'C' & i & '.Total',SELF.Cols.Total,f)
    PUTINI(sect,'C' & i & '.GroupBy',SELF.Cols.GroupBy,f)
  END


ExportClass.ForgetSettings PROCEDURE
f     CSTRING(261)
sect  CSTRING(80)
i     LONG,AUTO
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  PUTINI(sect,'Sig','',f)                                 ! kills the column half on the next load
  PUTINI(sect,'Folder','',f)
  PUTINI(sect,'Totals','',f)
  PUTINI(sect,'TotalsAvg','',f)
  PUTINI(sect,'TotalsMin','',f)
  PUTINI(sect,'TotalsMax','',f)
  PUTINI(sect,'TotalsCnt','',f)
  LOOP i = 1 TO SELF.Columns()
    PUTINI(sect,'C' & i & '.Use','',f)
    PUTINI(sect,'C' & i & '.Head','',f)
    PUTINI(sect,'C' & i & '.Pic','',f)
    PUTINI(sect,'C' & i & '.Total','',f)
    PUTINI(sect,'C' & i & '.GroupBy','',f)
  END
  SELF.Loaded = 0


! ############################################################################
!  The column list - what the dialog edits, and what your code can drive
! ############################################################################
ExportClass.ResetColumns PROCEDURE
i  LONG,AUTO
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  LOOP i = 1 TO RECORDS(SELF.Cols)
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    SELF.Cols.Head = SELF.Cols.HeadDef
    SELF.Cols.Pic  = SELF.Cols.PicDef
    SELF.Cols.Use  = 1
    IF SELF.VisibleOnly AND ~SELF.Cols.Width THEN SELF.Cols.Use = 0 .
    PUT(SELF.Cols)
    SELF.Classify(i)
  END


ExportClass.SelectAll PROCEDURE(BYTE pOn)
i  LONG,AUTO
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  LOOP i = 1 TO RECORDS(SELF.Cols)
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    SELF.Cols.Use = pOn
    PUT(SELF.Cols)
  END


ExportClass.ColumnUse PROCEDURE(LONG pCol,BYTE pOn)
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  SELF.Cols.Use = pOn
  PUT(SELF.Cols)


ExportClass.ColumnRename PROCEDURE(LONG pCol,STRING pHead)
h  CSTRING(129)
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  h = CLIP(LEFT(pHead))
  IF ~h THEN h = SELF.Cols.HeadDef .                      ! blank means "put it back"
  SELF.Cols.Head = h
  PUT(SELF.Cols)
  SELF.Classify(pCol)


ExportClass.ColumnPicture PROCEDURE(LONG pCol,STRING pPic)
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  SELF.Cols.Pic = CLIP(LEFT(pPic))                        ! blank = write the raw value
  PUT(SELF.Cols)
  SELF.Classify(pCol)


ExportClass.ColumnHeading PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.Head)


ExportClass.ColumnDefault PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.HeadDef)


ExportClass.ColumnPic PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.Pic)


ExportClass.ColumnDefaultPic PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN '' .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.PicDef)


ExportClass.ColumnOn PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN 0 .
  RETURN SELF.Cols.Use


ExportClass.ColumnIsNum PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN 0 .
  RETURN SELF.Cols.IsNum


!  Only a numeric column can go in the Totals row - a text column has nothing
!  to sum, so pOn=1 is silently ignored (and the flag cleared) when IsNum=0.
ExportClass.ColumnTotal PROCEDURE(LONG pCol,BYTE pOn)
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  IF pOn AND ~SELF.Cols.IsNum THEN RETURN .
  SELF.Cols.Total = CHOOSE(pOn <> 0,1,0)
  PUT(SELF.Cols)


ExportClass.ColumnTotalOn PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN 0 .
  RETURN SELF.Cols.Total


ExportClass.TotalsCount PROCEDURE()
i  LONG,AUTO
n  LONG(0)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  LOOP i = 1 TO RECORDS(SELF.Cols)
    GET(SELF.Cols,i)
    IF ~ERRORCODE() AND SELF.Cols.Use AND SELF.Cols.IsNum AND SELF.Cols.Total THEN n += 1 .
  END
  RETURN n


!  Only one column can be the group-by column at a time - ticking a new one
!  clears whichever was ticked before, the same way a radio button would.
ExportClass.ColumnGroupBy PROCEDURE(LONG pCol,BYTE pOn)
i  LONG,AUTO
  CODE
  IF SELF.Cols &= NULL THEN RETURN .
  IF pOn
    LOOP i = 1 TO RECORDS(SELF.Cols)
      GET(SELF.Cols,i)
      IF ERRORCODE() THEN CYCLE .
      IF SELF.Cols.GroupBy AND i <> pCol
        SELF.Cols.GroupBy = 0
        PUT(SELF.Cols)
      END
    END
  END
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN .
  SELF.Cols.GroupBy = CHOOSE(pOn <> 0,1,0)
  PUT(SELF.Cols)


ExportClass.ColumnGroupOn PROCEDURE(LONG pCol)
  CODE
  IF SELF.Cols &= NULL THEN RETURN 0 .
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN 0 .
  RETURN SELF.Cols.GroupBy


! ############################################################################
!  Format descriptions
! ############################################################################
ExportClass.FormatName PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV     ; RETURN SELF.Txt(Txt:FmtCSV)
  OF Exp:CSVUTF8 ; RETURN SELF.Txt(Txt:FmtCSVU)
  OF Exp:TSV     ; RETURN SELF.Txt(Txt:FmtTSV)
  OF Exp:XML     ; RETURN SELF.Txt(Txt:FmtXML)
  OF Exp:JSON    ; RETURN SELF.Txt(Txt:FmtJSON)
  OF Exp:XLSX    ; RETURN SELF.Txt(Txt:FmtXLSX)
  OF Exp:HTML    ; RETURN SELF.Txt(Txt:FmtHTML)
  OF Exp:Print   ; RETURN SELF.Txt(Txt:FmtPrint)
  OF Exp:PDF     ; RETURN SELF.Txt(Txt:FmtPDF)
  END
  RETURN ''


ExportClass.FormatExt PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV     ; RETURN '.csv'
  OF Exp:CSVUTF8 ; RETURN '.csv'
  OF Exp:TSV     ; RETURN '.tsv'
  OF Exp:XML     ; RETURN '.xml'
  OF Exp:JSON    ; RETURN '.json'
  OF Exp:XLSX    ; RETURN '.xlsx'
  OF Exp:HTML    ; RETURN '.html'
  OF Exp:Print   ; RETURN ''                     ! no file
  OF Exp:PDF     ; RETURN '.pdf'
  END
  RETURN '.txt'


ExportClass.FormatMask PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV OROF Exp:CSVUTF8
    RETURN SELF.Txt(Txt:MaskCSV) & '|*.csv|' & SELF.Txt(Txt:MaskText) & '|*.txt|' & |
           SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:TSV
    RETURN SELF.Txt(Txt:MaskTSV) & '|*.tsv|' & SELF.Txt(Txt:MaskText) & '|*.txt|' & |
           SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:XML
    RETURN SELF.Txt(Txt:MaskXML) & '|*.xml|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:JSON
    RETURN SELF.Txt(Txt:MaskJSON) & '|*.json|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:XLSX
    RETURN SELF.Txt(Txt:MaskXLSX) & '|*.xlsx|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:HTML
    RETURN SELF.Txt(Txt:MaskHTML) & '|*.html;*.htm|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  OF Exp:PDF
    RETURN SELF.Txt(Txt:MaskPDF) & '|*.pdf|' & SELF.Txt(Txt:MaskAll) & '|*.*'
  END
  RETURN SELF.Txt(Txt:MaskAll) & '|*.*'


ExportClass.FormatHint PROCEDURE(LONG pFmt)
  CODE
  CASE pFmt
  OF Exp:CSV     ; RETURN SELF.Txt(Txt:HintCSV)
  OF Exp:CSVUTF8 ; RETURN SELF.Txt(Txt:HintCSVU)
  OF Exp:TSV     ; RETURN SELF.Txt(Txt:HintTSV)
  OF Exp:XML     ; RETURN SELF.Txt(Txt:HintXML)
  OF Exp:JSON    ; RETURN SELF.Txt(Txt:HintJSON)
  OF Exp:XLSX    ; RETURN SELF.Txt(Txt:HintXLSX)
  OF Exp:HTML    ; RETURN SELF.Txt(Txt:HintHTML)
  OF Exp:Print   ; RETURN SELF.Txt(Txt:HintPrint)
  OF Exp:PDF     ; RETURN SELF.Txt(Txt:HintPDF)
  END
  RETURN ''


ExportClass.Allowed PROCEDURE(LONG pFmt)
  CODE
  IF pFmt < 1 OR pFmt > Exp:Formats THEN RETURN 0 .
  IF ~SELF.Allow THEN RETURN 1 .                          ! nothing configured = everything
  RETURN CHOOSE(BAND(SELF.Allow,BSHIFT(1,pFmt-1)) <> 0,1,0)


ExportClass.SuggestName PROCEDURE()
s   CSTRING(129)
i   LONG,AUTO
  CODE
  s = CLIP(LEFT(SELF.Title))
  IF ~s THEN s = SELF.Txt(Txt:ExportWord) .
  LOOP i = 1 TO LEN(s)
    IF INSTRING(s[i],'\/:*?"<>|. ',1,1) THEN s[i] = '_' .
  END
  RETURN CLIP(s) & '_' & FORMAT(YEAR(TODAY()),@n04) & FORMAT(MONTH(TODAY()),@n02) & FORMAT(DAY(TODAY()),@n02)


!  Make the extension agree with the chosen format - so switching format in the
!  dialog silently retargets 'Customers.csv' to 'Customers.xlsx'.
ExportClass.ForceExt PROCEDURE(LONG pFmt)
n    CSTRING(261)
i    LONG,AUTO
cut  LONG(0)
  CODE
  IF pFmt = Exp:Print THEN RETURN .             ! Print writes no file - nothing to retarget
  n = CLIP(LEFT(SELF.FileName))
  IF ~n THEN RETURN .
  LOOP i = LEN(n) TO 1 BY -1
    IF n[i] = '\' OR n[i] = '/' THEN BREAK .
    IF n[i] = '.' THEN cut = i; BREAK .
  END
  IF cut THEN n = SUB(n,1,cut-1) .
  SELF.FileName = CLIP(n) & SELF.FormatExt(pFmt)


ExportClass.Note PROCEDURE(STRING pText,STRING pTitle,LONG pIcon)
  CODE
  MESSAGE(pText,pTitle,pIcon,BUTTON:OK,BUTTON:OK,0)


! ############################################################################
!  Every word the user can see, in SELF.Language
! ############################################################################
!  The window structures below are declared with the English text - that is
!  only the design-time placeholder. At run time the dialog assigns every
!  caption from here, so this method is the single source of truth and the
!  English and Spanish wording can never drift apart.
!
!  TO ADD A LANGUAGE: derive the class and override this one method -
!
!      MyExporter  CLASS(ExportClass)
!      Txt           PROCEDURE(LONG pId),STRING,DERIVED
!                  END
!
!      MyExporter.Txt PROCEDURE(LONG pId)
!        CODE
!        IF SELF.Language = 3                             ! your own equate
!          CASE pId
!          OF Txt:ExportBtn ; RETURN '&Exporter'
!          ...
!          END
!        END
!        RETURN PARENT.Txt(pId)                           ! anything you skip
!
!  Accented letters are written as Clarion <nnn> escapes (CP1252) so this file
!  stays plain ASCII and survives any editor - see the note at the top.
ExportClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = Exp:Spanish
    CASE pId
!    the export dialog
    OF Txt:WinTitle      ; RETURN 'Exportar datos'
    OF Txt:Subtitle      ; RETURN 'Elige un formato y un destino, y luego las columnas.'
    OF Txt:SubtitleNoCol ; RETURN 'Elige un formato y luego la carpeta y el nombre del archivo.'
    OF Txt:FormatLbl     ; RETURN '&Formato:'
    OF Txt:SaveToLbl     ; RETURN 'Guardar &en:'
    OF Txt:FileTip       ; RETURN 'D<243>nde se escribir<225> el archivo exportado'
    OF Txt:PickTip       ; RETURN 'Elegir la carpeta y el nombre del archivo'
    OF Txt:ColumnsLbl    ; RETURN 'Columnas'
    OF Txt:ColHint       ; RETURN 'Doble clic o Espacio para incluir o excluir.'
    OF Txt:ColUse        ; RETURN 'Usar'
    OF Txt:ColNum        ; RETURN '#'
    OF Txt:ColHeadFile   ; RETURN 'Encabezado en el archivo'
    OF Txt:ColPicture    ; RETURN 'Picture'
    OF Txt:ColOnList     ; RETURN 'Columna en la lista'
    OF Txt:ToggleBtn     ; RETURN '&Incluir / excluir'
    OF Txt:EditBtn       ; RETURN '&Renombrar / picture...'
    OF Txt:AllBtn        ; RETURN '&Todas'
    OF Txt:NoneBtn       ; RETURN '&Ninguna'
    OF Txt:DefBtn        ; RETURN '&Predeterminados'
    OF Txt:DefTip        ; RETURN 'Devolver cada encabezado y picture a como los tiene la lista'
    OF Txt:IncHeadings   ; RETURN 'Incluir los &encabezados de columna'
    OF Txt:ApplyPics     ; RETURN 'Aplicar el &picture de cada columna'
    OF Txt:ApplyPicsTip  ; RETURN 'Sin marcar = valores crudos; marcado = lo que muestra la lista'
    OF Txt:OpenAfter     ; RETURN '&Abrir el archivo al terminar'
    OF Txt:ExportBtn     ; RETURN 'E&xportar'
    OF Txt:Cancel        ; RETURN 'Cancelar'
    OF Txt:OfWord        ; RETURN ' de '
    OF Txt:SelectedWord  ; RETURN ' seleccionadas)'
!    the one-column popup
    OF Txt:EdTitle       ; RETURN 'Columna'
    OF Txt:EdHeading     ; RETURN 'Ajustes de la columna'
    OF Txt:OnTheList     ; RETURN 'En la lista:'
    OF Txt:HeadingLbl    ; RETURN '&Encabezado:'
    OF Txt:HeadTip       ; RETURN 'C<243>mo se llama esta columna en el archivo exportado'
    OF Txt:PictureLbl    ; RETURN '&Picture:'
    OF Txt:PicTip        ; RETURN 'En blanco = escribir el valor crudo'
    OF Txt:EdDefBtn      ; RETURN 'Pre&determinado'
    OF Txt:EdFoot        ; RETURN 'Encabezado en blanco = el de la lista.  Picture en blanco = el valor crudo.'
    OF Txt:OK            ; RETURN 'Aceptar'
!    the formats
    OF Txt:FmtCSV        ; RETURN 'CSV - separado por comas (*.csv)'
    OF Txt:FmtCSVU       ; RETURN 'CSV - separado por comas, UTF-8 (*.csv)'
    OF Txt:FmtTSV        ; RETURN 'TSV - separado por tabuladores (*.tsv)'
    OF Txt:FmtXML        ; RETURN 'Documento XML (*.xml)'
    OF Txt:FmtJSON       ; RETURN 'Documento JSON (*.json)'
    OF Txt:FmtXLSX       ; RETURN 'Libro de Excel (*.xlsx)'
    OF Txt:FmtHTML       ; RETURN 'Tabla HTML (*.html)'
    OF Txt:FmtPrint      ; RETURN 'Imprimir'
    OF Txt:FmtPDF        ; RETURN 'Documento PDF (*.pdf)'
!    the Save-As file types
    OF Txt:MaskCSV       ; RETURN 'Separado por comas'
    OF Txt:MaskTSV       ; RETURN 'Separado por tabuladores'
    OF Txt:MaskXML       ; RETURN 'Documentos XML'
    OF Txt:MaskJSON      ; RETURN 'Documentos JSON'
    OF Txt:MaskXLSX      ; RETURN 'Libros de Excel'
    OF Txt:MaskHTML      ; RETURN 'P<225>ginas web'
    OF Txt:MaskText      ; RETURN 'Archivos de texto'
    OF Txt:MaskAll       ; RETURN 'Todos los archivos'
    OF Txt:MaskPDF       ; RETURN 'Documentos PDF'
!    the one-liner under the dialog
    OF Txt:HintCSV       ; RETURN 'S<243>lo se entrecomillan los valores que lo necesitan (RFC 4180).'
    OF Txt:HintCSVU      ; RETURN 'Lleva marca UTF-8 (BOM), as<237> Excel lee bien los acentos.'
    OF Txt:HintTSV       ; RETURN 'Los tabuladores y saltos de l<237>nea dentro de un valor pasan a espacios.'
    OF Txt:HintXML       ; RETURN 'UTF-8. Los encabezados se vuelven nombres de elemento: mantenlos simples.'
    OF Txt:HintJSON      ; RETURN 'UTF-8. Las columnas num<233>ricas se escriben como n<250>meros, no como texto.'
    OF Txt:HintXLSX      ; RETURN 'Un libro de verdad: n<250>meros como n<250>meros, encabezados fijos y autofiltro.'
    OF Txt:HintHTML      ; RETURN 'Una tabla con estilo: impr<237>mela o p<233>gala en Word o Excel.'
    OF Txt:HintPrint     ; RETURN 'Imprime directamente - la impresora predeterminada si no defines PrinterName.'
    OF Txt:HintPDF       ; RETURN 'Un PDF de verdad, paginado, sin depender de nada m<225>s.'
!    Print
    OF Txt:PrintBtn      ; RETURN '&Imprimir'
    OF Txt:NoPrinter     ; RETURN 'No se eligi<243> ninguna impresora.'
    OF Txt:RowsPrinted   ; RETURN ' fila(s) impresas en '
    OF Txt:PageWord      ; RETURN ' p<225>gina(s)'
    OF Txt:PreviewChk    ; RETURN '&Vista previa antes de imprimir'
    OF Txt:PageSetupBtn  ; RETURN 'Config&urar p<225>gina...'
!    Totals row (Excel .xlsx only)
    OF Txt:ColTotal      ; RETURN 'Tot'
    OF Txt:TotalBtn      ; RETURN 'Act&ivar total'
    OF Txt:TotalsChk     ; RETURN 'A<241>adir una fila de &totales (suma las columnas marcadas)'
    OF Txt:TotalsTip     ; RETURN 'A<241>ade una fila en negrita con f<243>rmulas SUMA() bajo los datos - solo Excel .xlsx'
    OF Txt:NotNumeric    ; RETURN 'Solo se puede sumar una columna num<233>rica.'
!    Average / Minimum / Maximum summary rows
    OF Txt:SummaryLbl    ; RETURN 'Filas de resumen:'
    OF Txt:SumChk        ; RETURN '&Suma'
    OF Txt:AvgChk        ; RETURN 'Pro&medio'
    OF Txt:MinChk        ; RETURN 'M<237>&n'
    OF Txt:MaxChk        ; RETURN 'M<225>&x'
!    Email when done (Simple MAPI)
    OF Txt:EmailChk      ; RETURN '&Enviar el archivo por correo al terminar'
    OF Txt:CantEmail     ; RETURN 'No se pudo abrir un mensaje de correo para el archivo.'
    OF Txt:EmailFailTitle ; RETURN 'No se pudo enviar el correo'
!    Subtotal / group rows
    OF Txt:ColGroup      ; RETURN 'Grp'
    OF Txt:GroupBtn      ; RETURN 'Activar &grupo'
!    Multiple sheets in one workbook
    OF Txt:XlsxOnly      ; RETURN 'Las hojas m<250>ltiples solo existen en Excel .xlsx.'
    OF Txt:NotInWorkbook ; RETURN 'StartSheet() se llam<243> sin StartWorkbook() antes.'
    OF Txt:TooManySheets ; RETURN 'Este libro no admite m<225>s de 100 hojas.'
    OF Txt:NoSheets      ; RETURN 'No se gener<243> ninguna hoja antes de EndWorkbook().'
    OF Txt:SplitChk      ; RETURN 'Dividir en &hojas'
    OF Txt:CntChk        ; RETURN 'C&ant'
    OF Txt:PdfTruncTitle ; RETURN 'PDF incompleto'
    OF Txt:PdfTruncMsg   ; RETURN 'A este PDF se le acabaron las p<225>ginas antes de que cupieran todas las ' & |
                                   'filas, y las restantes se omitieron. Probar con Excel o CSV en su lugar ' & |
                                   'para un conjunto de datos tan grande.'
    OF Txt:EmailFrontChk ; RETURN 'Traer correo al &frente'
!    messages
    OF Txt:MsgTitle      ; RETURN 'Exportar'
    OF Txt:NoColumns     ; RETURN 'No hay nada que exportar: esta lista no tiene columnas de datos.'
    OF Txt:NoFormats     ; RETURN 'No se ha habilitado ning<250>n formato de exportaci<243>n.'
    OF Txt:NeedFile      ; RETURN 'Elige primero un nombre de archivo.'
    OF Txt:NeedColumn    ; RETURN 'Marca al menos una columna para exportar.'
    OF Txt:BadPicture    ; RETURN 'Un picture de Clarion empieza por @ - por ejemplo @n-11.2 o @d17.'
    OF Txt:BadPicture2   ; RETURN 'D<233>jalo en blanco para escribir el valor crudo.'
    OF Txt:PicTitle      ; RETURN 'Picture'
    OF Txt:FailTitle     ; RETURN 'La exportaci<243>n fall<243>'
    OF Txt:NoneSelected  ; RETURN 'No hay columnas seleccionadas para exportar.'
    OF Txt:NoFileName    ; RETURN 'No se indic<243> ning<250>n nombre de archivo.'
    OF Txt:CantCreate    ; RETURN 'No se pudo crear'
    OF Txt:CantCreate2   ; RETURN 'Comprueba que la carpeta existe y que el archivo no est<233> abierto.'
    OF Txt:CantWrite     ; RETURN 'No se pudo escribir en'
    OF Txt:CantWrite2    ; RETURN 'El disco puede estar lleno o protegido contra escritura.'
    OF Txt:RowsExported  ; RETURN ' fila(s) exportadas a'
    OF Txt:DoneTitle     ; RETURN 'Exportaci<243>n terminada'
    OF Txt:ExportToTitle ; RETURN 'Exportar a '
    OF Txt:RowsHtml      ; RETURN ' fila(s)'
    OF Txt:ColumnWord    ; RETURN 'Columna'
    OF Txt:ExportWord    ; RETURN 'Exportar'
    END
    RETURN ''
  END
  CASE pId
!  the export dialog
  OF Txt:WinTitle      ; RETURN 'Export data'
  OF Txt:Subtitle      ; RETURN 'Choose a format and a destination, then pick the columns.'
  OF Txt:SubtitleNoCol ; RETURN 'Choose a format, then the folder and file name.'
  OF Txt:FormatLbl     ; RETURN '&Format:'
  OF Txt:SaveToLbl     ; RETURN 'Save &to:'
  OF Txt:FileTip       ; RETURN 'Where the exported file will be written'
  OF Txt:PickTip       ; RETURN 'Choose the folder and the file name'
  OF Txt:ColumnsLbl    ; RETURN 'Columns'
  OF Txt:ColHint       ; RETURN 'Double-click or press Space to include or exclude.'
  OF Txt:ColUse        ; RETURN 'Use'
  OF Txt:ColNum        ; RETURN '#'
  OF Txt:ColHeadFile   ; RETURN 'Heading in the file'
  OF Txt:ColPicture    ; RETURN 'Picture'
  OF Txt:ColOnList     ; RETURN 'Column on the list'
  OF Txt:ToggleBtn     ; RETURN '&Include / exclude'
  OF Txt:EditBtn       ; RETURN '&Rename / picture...'
  OF Txt:AllBtn        ; RETURN '&All'
  OF Txt:NoneBtn       ; RETURN '&None'
  OF Txt:DefBtn        ; RETURN '&Defaults'
  OF Txt:DefTip        ; RETURN 'Put every heading and picture back the way the list has it'
  OF Txt:IncHeadings   ; RETURN 'Include the column &headings'
  OF Txt:ApplyPics     ; RETURN 'Apply each column''s &picture'
  OF Txt:ApplyPicsTip  ; RETURN 'Off = raw values, on = exactly what the list shows'
  OF Txt:OpenAfter     ; RETURN '&Open the file when it is done'
  OF Txt:ExportBtn     ; RETURN '&Export'
  OF Txt:Cancel        ; RETURN 'Cancel'
  OF Txt:OfWord        ; RETURN ' of '
  OF Txt:SelectedWord  ; RETURN ' selected)'
!  the one-column popup
  OF Txt:EdTitle       ; RETURN 'Column'
  OF Txt:EdHeading     ; RETURN 'Column settings'
  OF Txt:OnTheList     ; RETURN 'On the list:'
  OF Txt:HeadingLbl    ; RETURN '&Heading:'
  OF Txt:HeadTip       ; RETURN 'What this column is called in the exported file'
  OF Txt:PictureLbl    ; RETURN '&Picture:'
  OF Txt:PicTip        ; RETURN 'Blank = write the raw value'
  OF Txt:EdDefBtn      ; RETURN 'De&fault'
  OF Txt:EdFoot        ; RETURN 'Blank heading = the list''s own.  Blank picture = the raw value.'
  OF Txt:OK            ; RETURN 'OK'
!  the formats
  OF Txt:FmtCSV        ; RETURN 'CSV - comma separated (*.csv)'
  OF Txt:FmtCSVU       ; RETURN 'CSV - comma separated, UTF-8 (*.csv)'
  OF Txt:FmtTSV        ; RETURN 'TSV - tab separated (*.tsv)'
  OF Txt:FmtXML        ; RETURN 'XML document (*.xml)'
  OF Txt:FmtJSON       ; RETURN 'JSON document (*.json)'
  OF Txt:FmtXLSX       ; RETURN 'Excel workbook (*.xlsx)'
  OF Txt:FmtHTML       ; RETURN 'HTML table (*.html)'
  OF Txt:FmtPrint      ; RETURN 'Print'
  OF Txt:FmtPDF        ; RETURN 'PDF document (*.pdf)'
!  the Save-As file types
  OF Txt:MaskCSV       ; RETURN 'Comma separated'
  OF Txt:MaskTSV       ; RETURN 'Tab separated'
  OF Txt:MaskXML       ; RETURN 'XML documents'
  OF Txt:MaskJSON      ; RETURN 'JSON documents'
  OF Txt:MaskXLSX      ; RETURN 'Excel workbooks'
  OF Txt:MaskHTML      ; RETURN 'Web pages'
  OF Txt:MaskText      ; RETURN 'Text files'
  OF Txt:MaskAll       ; RETURN 'All files'
  OF Txt:MaskPDF       ; RETURN 'PDF documents'
!  the one-liner under the dialog
  OF Txt:HintCSV       ; RETURN 'Values are quoted only where they have to be (RFC 4180).'
  OF Txt:HintCSVU      ; RETURN 'Carries a UTF-8 byte-order mark, so Excel reads accented text correctly.'
  OF Txt:HintTSV       ; RETURN 'Tabs and line breaks inside a value become single spaces.'
  OF Txt:HintXML       ; RETURN 'UTF-8. Headings become element names, so keep them simple.'
  OF Txt:HintJSON      ; RETURN 'UTF-8. Numeric columns are written as numbers, not strings.'
  OF Txt:HintXLSX      ; RETURN 'A real workbook: numbers as numbers, frozen headings and an auto-filter.'
  OF Txt:HintHTML      ; RETURN 'A styled table - print it, or paste it into Word or Excel.'
  OF Txt:HintPrint     ; RETURN 'Prints straight to paper - the default printer unless you set PrinterName.'
  OF Txt:HintPDF       ; RETURN 'A real, paginated PDF - nothing else needed to read it.'
!  Print
  OF Txt:PrintBtn      ; RETURN '&Print'
  OF Txt:NoPrinter     ; RETURN 'No printer was chosen.'
  OF Txt:RowsPrinted   ; RETURN ' row(s) printed on '
  OF Txt:PageWord      ; RETURN ' page(s)'
  OF Txt:PreviewChk    ; RETURN 'Pre&view before printing'
  OF Txt:PageSetupBtn  ; RETURN 'Page &Setup...'
!  Totals row (Excel .xlsx only)
  OF Txt:ColTotal      ; RETURN 'Tot'
  OF Txt:TotalBtn      ; RETURN 'Toggle t&otal'
  OF Txt:TotalsChk     ; RETURN 'Add a &totals row (sums the ticked columns)'
  OF Txt:TotalsTip     ; RETURN 'Adds a bold row with SUM() formulas under the data - Excel .xlsx only'
  OF Txt:NotNumeric    ; RETURN 'Only a numeric column can be summed.'
!  Average / Minimum / Maximum summary rows
  OF Txt:SummaryLbl    ; RETURN 'Summary rows:'
  OF Txt:SumChk        ; RETURN '&Sum'
  OF Txt:AvgChk        ; RETURN '&Avg'
  OF Txt:MinChk        ; RETURN 'M&in'
  OF Txt:MaxChk        ; RETURN 'Ma&x'
!  Email when done (Simple MAPI)
  OF Txt:EmailChk      ; RETURN '&Email the file when it is done'
  OF Txt:CantEmail     ; RETURN 'Could not open a mail message for the file.'
  OF Txt:EmailFailTitle ; RETURN 'Could not send email'
!  Subtotal / group rows
  OF Txt:ColGroup      ; RETURN 'Grp'
  OF Txt:GroupBtn      ; RETURN 'Toggle &group'
!  Multiple sheets in one workbook
  OF Txt:XlsxOnly      ; RETURN 'Multiple sheets only exist in Excel .xlsx.'
  OF Txt:NotInWorkbook ; RETURN 'StartSheet() was called without StartWorkbook() first.'
  OF Txt:TooManySheets ; RETURN 'This workbook cannot hold more than 100 sheets.'
  OF Txt:NoSheets      ; RETURN 'No sheet was ever built before EndWorkbook().'
  OF Txt:SplitChk      ; RETURN 'Split &sheets'
  OF Txt:CntChk        ; RETURN 'C&nt'
  OF Txt:PdfTruncTitle ; RETURN 'PDF incomplete'
  OF Txt:PdfTruncMsg   ; RETURN 'This PDF ran out of pages before all the rows fit, and the remaining rows ' & |
                                 'were left out. Try Excel or CSV instead for a data set this large.'
  OF Txt:EmailFrontChk ; RETURN 'Bring email to &front'
!  messages
  OF Txt:MsgTitle      ; RETURN 'Export'
  OF Txt:NoColumns     ; RETURN 'There is nothing to export - this list has no data columns.'
  OF Txt:NoFormats     ; RETURN 'No export formats have been enabled.'
  OF Txt:NeedFile      ; RETURN 'Please choose a file name first.'
  OF Txt:NeedColumn    ; RETURN 'Please tick at least one column to export.'
  OF Txt:BadPicture    ; RETURN 'A Clarion picture starts with @ - for example @n-11.2 or @d17.'
  OF Txt:BadPicture2   ; RETURN 'Leave it blank to write the raw value.'
  OF Txt:PicTitle      ; RETURN 'Picture'
  OF Txt:FailTitle     ; RETURN 'Export failed'
  OF Txt:NoneSelected  ; RETURN 'No columns are selected for export.'
  OF Txt:NoFileName    ; RETURN 'No file name was given.'
  OF Txt:CantCreate    ; RETURN 'Could not create'
  OF Txt:CantCreate2   ; RETURN 'Check the folder exists and that the file is not already open.'
  OF Txt:CantWrite     ; RETURN 'Could not write to'
  OF Txt:CantWrite2    ; RETURN 'The disk may be full or write protected.'
  OF Txt:RowsExported  ; RETURN ' row(s) exported to'
  OF Txt:DoneTitle     ; RETURN 'Export complete'
  OF Txt:ExportToTitle ; RETURN 'Export to '
  OF Txt:RowsHtml      ; RETURN ' row(s)'
  OF Txt:ColumnWord    ; RETURN 'Column'
  OF Txt:ExportWord    ; RETURN 'Export'
  END
  RETURN ''


! ############################################################################
!  The run-time dialog:  which format, and where does it go
! ############################################################################
!  The columns LIST mirrors SELF.Cols one-for-one, so a row number in the
!  dialog IS the column's queue position - nothing to map.
!
!  Editing is a LIST plus buttons plus a small modal window, deliberately: an
!  edit-in-place manager driven outside a BrowseBox is unstable, and this is
!  both sturdier and easier to use with the keyboard.
ExportClass.Ask PROCEDURE()
FmtQ           QUEUE,PRE(FQ)
FName            STRING(40)
FId              LONG
               END
ColQ           QUEUE,PRE(CQ)
Mark             STRING(3)                            ! 'X' when the column is included
Num              LONG
Head             STRING(64)                           ! what the file will call it
Pic              STRING(32)
Tot              STRING(3)                            ! 'X' when ticked for the xlsx Totals row
Grp              STRING(3)                            ! 'X' when this is THE group-by/subtotal column
Src              STRING(64)                           ! what the LIST calls it
               END
i              LONG,AUTO
row            LONG,AUTO
Sel            LONG(1)
Ok             BYTE(0)
Shrink         LONG(0)
ExpFile        CSTRING(261)
ExpHdrs        BYTE
ExpPics        BYTE
ExpOpen        BYTE
ExpEmail       BYTE
ExpEmailFront  BYTE
ExpTotals      BYTE
ExpAvg         BYTE
ExpMin         BYTE
ExpMax         BYTE
ExpCnt         BYTE
ExpSplit       BYTE
EdHead         CSTRING(129)
EdPic          CSTRING(33)
EdOk           BYTE
BtnFeq         LONG,DIM(7)                          ! the column-picker button row
BtnCap         CSTRING(65)
BtnX           LONG
BtnW           LONG
ExpWnd WINDOW('Export data'),AT(,,436,370),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,GRAY,SYSTEM,MODAL
         PANEL,AT(0,0,436,36),USE(?ExpBand),FILL(0603A1FH)
         STRING('Export data'),AT(14,7),USE(?ExpT1),FONT('Segoe UI',12,COLOR:White,FONT:bold),TRN
         STRING('Choose a format and a destination, then pick the columns.'),AT(14,23),USE(?ExpT2), |
           FONT('Segoe UI',8,0D8C8B4H),TRN
         PROMPT('&Format:'),AT(14,52),USE(?ExpP1)
         LIST,AT(76,50,346,10),USE(?ExpFmt),VSCROLL,DROP(8),FROM(FmtQ),FORMAT('190L(2)@s40@')
         PROMPT('Save &to:'),AT(14,72),USE(?ExpP2)
         ENTRY(@s255),AT(76,70,328,10),USE(ExpFile),TIP('Where the exported file will be written')
         BUTTON('...'),AT(406,70,16,10),USE(?ExpPick),TIP('Choose the folder and the file name')
         STRING('Columns'),AT(14,92),USE(?ExpP3),FONT('Segoe UI',9,,FONT:bold),TRN
         STRING(''),AT(62,92,180,10),USE(?ExpCount),FONT('Segoe UI',8,0757575H),TRN
         STRING('Double-click or press Space to include or exclude.'),AT(242,92,180,10),USE(?ExpHint), |
           FONT('Segoe UI',8,0757575H),TRN
         LIST,AT(14,104,408,118),USE(?ExpCols),FROM(ColQ),VSCROLL,ALRT(MouseLeft2),ALRT(SpaceKey), |
           FORMAT('20C|M~Use~@s3@24R(2)|M~#~@n3@112L(2)|M~Heading in the file~@s64@' & |
                  '62L(2)|M~Picture~@s32@20C|M~Tot~@s3@20C|M~Grp~@s3@112L(2)|M~Column on the list~@s64@')
         BUTTON('&Include / exclude'),AT(14,226,68,13),USE(?ExpToggle)
         BUTTON('&Rename / picture...'),AT(86,226,74,13),USE(?ExpEdit)
         BUTTON('&All'),AT(164,226,30,13),USE(?ExpAll)
         BUTTON('&None'),AT(198,226,30,13),USE(?ExpNone)
         BUTTON('&Defaults'),AT(232,226,40,13),USE(?ExpDef),TIP('Put every heading and picture back the way the list has it')
         BUTTON('Toggle t&otal'),AT(276,226,70,13),USE(?ExpTotal),TIP('Sum or unsum the highlighted numeric column in the Totals row')
         BUTTON('Toggle &group'),AT(350,226,70,13),USE(?ExpGroup),TIP('Set (or clear) the highlighted column as the one to subtotal/group by')
         CHECK('Include the column &headings'),AT(14,250),USE(ExpHdrs)
         CHECK('Apply each column''s &picture'),AT(14,262),USE(ExpPics),TIP('Off = raw values, on = exactly what the list shows')
         CHECK('&Open the file when it is done'),AT(14,274),USE(ExpOpen)
         BUTTON('Page &Setup...'),AT(280,274,142,13),USE(?ExpPageSetup),TIP('Orientation, paper size and margins')
         CHECK('&Email the file when it is done'),AT(14,286),USE(ExpEmail),TIP('Opens a new message with the file attached, in your default mail program - you still press Send')
         CHECK('Bring email to &front'),AT(230,286,150,10),USE(ExpEmailFront),TIP('Try to bring the mail program''s own window forward, instead of it just flashing on the taskbar')
         PROMPT('Summary rows:'),AT(14,300),USE(?ExpSumP)
         CHECK('&Sum'),AT(100,298,45,10),USE(ExpTotals),TIP('Adds a bold Sum row under the data - Excel .xlsx only')
         CHECK('&Avg'),AT(148,298,45,10),USE(ExpAvg),TIP('Adds a bold Average row under the data - Excel .xlsx only')
         CHECK('M&in'),AT(196,298,45,10),USE(ExpMin),TIP('Adds a bold Minimum row under the data - Excel .xlsx only')
         CHECK('Ma&x'),AT(244,298,45,10),USE(ExpMax),TIP('Adds a bold Maximum row under the data - Excel .xlsx only')
         CHECK('C&nt'),AT(292,298,45,10),USE(ExpCnt),TIP('Adds a bold Count row under the data - Excel .xlsx only')
         CHECK('Split &sheets'),AT(340,298,82,10),USE(ExpSplit),TIP('Also write one extra sheet per distinct group value, alongside the main sheet - needs a Grp column')
         PANEL,AT(14,320,408,1),USE(?ExpRule),FILL(0D4D0CCH)
         STRING(''),AT(14,328,408,10),USE(?ExpInfo),FONT('Segoe UI',8,0757575H),TRN
         BUTTON('&Export'),AT(308,346,54,14),USE(?ExpOk),DEFAULT
         BUTTON('Cancel'),AT(366,346,54,14),USE(?ExpCancel)
       END
EdWnd  WINDOW('Column'),AT(,,258,124),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,GRAY,SYSTEM,MODAL
         PANEL,AT(0,0,258,28),USE(?EdBand),FILL(0603A1FH)
         STRING('Column settings'),AT(12,8),USE(?EdT1),FONT('Segoe UI',10,COLOR:White,FONT:bold),TRN
         PROMPT('On the list:'),AT(12,40),USE(?EdP0)
         STRING(''),AT(76,40,170,10),USE(?EdSrc),FONT('Segoe UI',9,,FONT:bold),TRN
         PROMPT('&Heading:'),AT(12,58),USE(?EdP1)
         ENTRY(@s128),AT(76,56,170,10),USE(EdHead),TIP('What this column is called in the exported file')
         PROMPT('&Picture:'),AT(12,76),USE(?EdP2)
         ENTRY(@s32),AT(76,74,104,10),USE(EdPic),TIP('Blank = write the raw value')
         BUTTON('De&fault'),AT(186,74,60,10),USE(?EdDef)
         STRING('Blank heading = the list''s own.  Blank picture = the raw value.'), |
           AT(12,92,234,10),USE(?EdHint),FONT('Segoe UI',8,0757575H),TRN
         BUTTON('OK'),AT(144,106,50,13),USE(?EdOk),DEFAULT
         BUTTON('Cancel'),AT(198,106,50,13),USE(?EdCancel)
       END
  CODE
  IF ~SELF.Columns() THEN SELF.ScanColumns() .
  IF ~SELF.Columns()
    SELF.Note(SELF.Txt(Txt:NoColumns),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
    RETURN 0
  END
!  Pick up where the user left off last time. This runs after the generated
!  code has applied the template's defaults, so the saved choices win - which
!  is the point.
  IF SELF.Persist AND ~SELF.Loaded THEN SELF.LoadSettings() .
  LOOP i = 1 TO Exp:Formats
    IF ~SELF.Allowed(i) THEN CYCLE .
    FQ:FName = SELF.FormatName(i)
    FQ:FId   = i
    ADD(FmtQ)
  END
  IF ~RECORDS(FmtQ)
    SELF.Note(SELF.Txt(Txt:NoFormats),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
    RETURN 0
  END
  LOOP i = 1 TO RECORDS(FmtQ)                             ! preselect the last format used
    GET(FmtQ,i)
    IF FQ:FId = SELF.Fmt
      Sel = i
      BREAK
    END
  END
  GET(FmtQ,Sel)
  SELF.Fmt = FQ:FId
  IF ~CLIP(SELF.FileName)
    SELF.FileName = CLIP(LONGPATH()) & '\' & SELF.SuggestName()
  END
  SELF.ForceExt(SELF.Fmt)
  ExpFile = SELF.FileName
  ExpHdrs = SELF.Headers
  ExpPics = SELF.Pictures
  ExpOpen = SELF.OpenWhenDone
  ExpEmail = SELF.EmailWhenDone
  ExpEmailFront = SELF.EmailToFront
  ExpTotals = SELF.Totals
  ExpAvg    = SELF.TotalsAvg
  ExpMin    = SELF.TotalsMin
  ExpMax    = SELF.TotalsMax
  ExpCnt    = SELF.TotalsCnt
  ExpSplit  = SELF.SplitByGroup
  OPEN(ExpWnd)
  DO SpeakDialog                                          ! every caption, in SELF.Language
  ?ExpFmt{PROP:Selected} = Sel
  DO FillCols
  DO SyncFmtMode                                          ! Print has no file - hide "Save to"
  DO SyncEmailFront                                        ! "Bring email to front" only makes sense once Email is on
  IF ~SELF.AllowColumns THEN DO HideCols .
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      SELECT(?ExpFmt)
    END
    CASE FIELD()
    OF ?ExpFmt
      CASE EVENT()
      OF EVENT:Accepted OROF EVENT:NewSelection
        i = CHOICE(?ExpFmt)
        IF i
          GET(FmtQ,i)
          IF ~ERRORCODE() AND FQ:FId <> SELF.Fmt
            SELF.Fmt      = FQ:FId
            SELF.FileName = ExpFile
            SELF.ForceExt(SELF.Fmt)                       ! retarget the extension for them
            ExpFile       = SELF.FileName
            DISPLAY(?ExpFile)
            DO ShowInfo
            DO SyncFmtMode
          END
        END
      END
    OF ?ExpPick
      CASE EVENT()
      OF EVENT:Accepted
        SELF.FileName = ExpFile
        IF SELF.AskFileName()
          ExpFile = SELF.FileName
          DISPLAY(?ExpFile)
        END
      END
    OF ?ExpPageSetup
      IF EVENT() = EVENT:Accepted THEN SELF.PageSetup() .
    OF ?ExpCols
      CASE EVENT()
      OF EVENT:AlertKey
        CASE KEYCODE()
        OF MouseLeft2 ; DO ToggleRow
        OF SpaceKey   ; DO ToggleRow
        END
      END
    OF ?ExpToggle
      IF EVENT() = EVENT:Accepted THEN DO ToggleRow .
    OF ?ExpEdit
      IF EVENT() = EVENT:Accepted THEN DO EditRow .
    OF ?ExpAll
      IF EVENT() = EVENT:Accepted
        SELF.SelectAll(1)
        DO FillCols
      END
    OF ?ExpNone
      IF EVENT() = EVENT:Accepted
        SELF.SelectAll(0)
        DO FillCols
      END
    OF ?ExpDef
      IF EVENT() = EVENT:Accepted
        SELF.ResetColumns()
        DO FillCols
      END
    OF ?ExpTotal
      IF EVENT() = EVENT:Accepted THEN DO ToggleTotal .
    OF ?ExpGroup
      IF EVENT() = EVENT:Accepted THEN DO ToggleGroup .
    OF ?ExpEmail
      IF EVENT() = EVENT:Accepted THEN DO SyncEmailFront .
    OF ?ExpOk
      CASE EVENT()
      OF EVENT:Accepted
        IF SELF.Fmt <> Exp:Print AND ~CLIP(LEFT(ExpFile))
          SELF.Note(SELF.Txt(Txt:NeedFile),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
          SELECT(?ExpFile)
          CYCLE
        END
        IF ~SELF.Selected()
          SELF.Note(SELF.Txt(Txt:NeedColumn),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
          SELECT(?ExpCols)
          CYCLE
        END
        Ok = 1
        POST(EVENT:CloseWindow)
      END
    OF ?ExpCancel
      CASE EVENT()
      OF EVENT:Accepted
        POST(EVENT:CloseWindow)
      END
    END
  END
  CLOSE(ExpWnd)
  IF Ok
    SELF.FileName     = CLIP(LEFT(ExpFile))
    SELF.Headers      = ExpHdrs
    SELF.Pictures     = ExpPics
    SELF.OpenWhenDone = ExpOpen
    SELF.EmailWhenDone = ExpEmail
    SELF.EmailToFront = ExpEmailFront
    SELF.Totals       = ExpTotals
    SELF.TotalsAvg    = ExpAvg
    SELF.TotalsMin    = ExpMin
    SELF.TotalsMax    = ExpMax
    SELF.TotalsCnt    = ExpCnt
    SELF.SplitByGroup = ExpSplit
    SELF.ForceExt(SELF.Fmt)
  END
  RETURN Ok

!  ---- rebuild the columns list from SELF.Cols, keeping the highlight -------
!  ---- the whole dialog speaks SELF.Language ---------------------------------
!  Run once, straight after OPEN. The English in the WINDOW structure above is
!  only what the designer sees; these assignments are what the user reads, so
!  there is exactly one place to change a word or add a language.
SpeakDialog ROUTINE
  ExpWnd{PROP:Text}     = SELF.Txt(Txt:WinTitle)
  ?ExpT1{PROP:Text}     = SELF.Txt(Txt:WinTitle)
  ?ExpT2{PROP:Text}     = SELF.Txt(Txt:Subtitle)
  ?ExpP1{PROP:Text}     = SELF.Txt(Txt:FormatLbl)
  ?ExpP2{PROP:Text}     = SELF.Txt(Txt:SaveToLbl)
  ?ExpFile{PROP:Tip}    = SELF.Txt(Txt:FileTip)
  ?ExpPick{PROP:Tip}    = SELF.Txt(Txt:PickTip)
  ?ExpP3{PROP:Text}     = SELF.Txt(Txt:ColumnsLbl)
  ?ExpHint{PROP:Text}   = SELF.Txt(Txt:ColHint)
  ?ExpCols{PROPLIST:Header,1} = SELF.Txt(Txt:ColUse)      ! the picker's own headings
  ?ExpCols{PROPLIST:Header,2} = SELF.Txt(Txt:ColNum)
  ?ExpCols{PROPLIST:Header,3} = SELF.Txt(Txt:ColHeadFile)
  ?ExpCols{PROPLIST:Header,4} = SELF.Txt(Txt:ColPicture)
  ?ExpCols{PROPLIST:Header,5} = SELF.Txt(Txt:ColTotal)
  ?ExpCols{PROPLIST:Header,6} = SELF.Txt(Txt:ColGroup)
  ?ExpCols{PROPLIST:Header,7} = SELF.Txt(Txt:ColOnList)
  ?ExpToggle{PROP:Text} = SELF.Txt(Txt:ToggleBtn)
  ?ExpEdit{PROP:Text}   = SELF.Txt(Txt:EditBtn)
  ?ExpAll{PROP:Text}    = SELF.Txt(Txt:AllBtn)
  ?ExpNone{PROP:Text}   = SELF.Txt(Txt:NoneBtn)
  ?ExpDef{PROP:Text}    = SELF.Txt(Txt:DefBtn)
  ?ExpDef{PROP:Tip}     = SELF.Txt(Txt:DefTip)
  ?ExpTotal{PROP:Text}  = SELF.Txt(Txt:TotalBtn)
  ?ExpGroup{PROP:Text}  = SELF.Txt(Txt:GroupBtn)
  ?ExpHdrs{PROP:Text}   = SELF.Txt(Txt:IncHeadings)
  ?ExpPics{PROP:Text}   = SELF.Txt(Txt:ApplyPics)
  ?ExpPics{PROP:Tip}    = SELF.Txt(Txt:ApplyPicsTip)
  ?ExpOpen{PROP:Text}   = SELF.Txt(Txt:OpenAfter)
  ?ExpEmail{PROP:Text}  = SELF.Txt(Txt:EmailChk)
  ?ExpEmailFront{PROP:Text}  = SELF.Txt(Txt:EmailFrontChk)
  ?ExpPageSetup{PROP:Text} = SELF.Txt(Txt:PageSetupBtn)
  ?ExpTotals{PROP:Text} = SELF.Txt(Txt:SumChk)
  ?ExpSumP{PROP:Text}   = SELF.Txt(Txt:SummaryLbl)
  ?ExpAvg{PROP:Text}    = SELF.Txt(Txt:AvgChk)
  ?ExpMin{PROP:Text}    = SELF.Txt(Txt:MinChk)
  ?ExpMax{PROP:Text}    = SELF.Txt(Txt:MaxChk)
  ?ExpCnt{PROP:Text}    = SELF.Txt(Txt:CntChk)
  ?ExpSplit{PROP:Text}  = SELF.Txt(Txt:SplitChk)
  ?ExpOk{PROP:Text}     = SELF.Txt(Txt:ExportBtn)
  ?ExpCancel{PROP:Text} = SELF.Txt(Txt:Cancel)
  DO SizeButtons


!  ---- the button row fits its own words -------------------------------------
!  'Defaults' is 8 characters; 'Predeterminados' is 15, and a button sized for
!  the English would cut it in half. So the five picker buttons are laid out
!  here instead of trusting the widths in the WINDOW structure: each one gets a
!  width from its own caption and the row is packed left to right. There are
!  ~150 spare dialog units to the right of the row, so a longer language grows
!  into empty space rather than off the edge.
!
!  The 3 units per character (plus padding) is for the dialog's Segoe UI 9 and
!  reproduces the hand-picked English widths to within a unit or two. '&' is
!  the accelerator marker and takes no space, so it is not counted.
SizeButtons ROUTINE
  BtnFeq[1] = ?ExpToggle
  BtnFeq[2] = ?ExpEdit
  BtnFeq[3] = ?ExpAll
  BtnFeq[4] = ?ExpNone
  BtnFeq[5] = ?ExpDef
  BtnFeq[6] = ?ExpTotal
  BtnFeq[7] = ?ExpGroup
  BtnX = 14
  LOOP i = 1 TO 7
    BtnCap = BtnFeq[i]{PROP:Text}
    BtnW   = LEN(CLIP(BtnCap))
    IF INSTRING('&',BtnCap,1,1) THEN BtnW -= 1 .          ! the accelerator marker
    BtnW = BtnW * 3 + 16
    IF BtnW < 30 THEN BtnW = 30 .                         ! keep All/None clickable
    BtnFeq[i]{PROP:Xpos}  = BtnX
    BtnFeq[i]{PROP:Width} = BtnW
    BtnX += BtnW + 4
  END


SpeakColumn ROUTINE
  EdWnd{PROP:Text}      = SELF.Txt(Txt:EdTitle)
  ?EdT1{PROP:Text}      = SELF.Txt(Txt:EdHeading)
  ?EdP0{PROP:Text}      = SELF.Txt(Txt:OnTheList)
  ?EdP1{PROP:Text}      = SELF.Txt(Txt:HeadingLbl)
  ?EdHead{PROP:Tip}     = SELF.Txt(Txt:HeadTip)
  ?EdP2{PROP:Text}      = SELF.Txt(Txt:PictureLbl)
  ?EdPic{PROP:Tip}      = SELF.Txt(Txt:PicTip)
  ?EdDef{PROP:Text}     = SELF.Txt(Txt:EdDefBtn)
  ?EdHint{PROP:Text}    = SELF.Txt(Txt:EdFoot)
  ?EdOk{PROP:Text}      = SELF.Txt(Txt:OK)
  ?EdCancel{PROP:Text}  = SELF.Txt(Txt:Cancel)


FillCols ROUTINE
  DATA
keep  LONG,AUTO
c     LONG,AUTO
  CODE
  keep = CHOICE(?ExpCols)
  FREE(ColQ)
  LOOP c = 1 TO SELF.Columns()
    GET(SELF.Cols,c)
    IF ERRORCODE() THEN CYCLE .
    CQ:Mark = CHOOSE(SELF.Cols.Use = 1,'X','')
    CQ:Num  = c
    CQ:Head = SELF.Cols.Head
    CQ:Pic  = SELF.Cols.Pic
    CQ:Tot  = CHOOSE(SELF.Cols.IsNum = 1 AND SELF.Cols.Total = 1,'X','')
    CQ:Grp  = CHOOSE(SELF.Cols.GroupBy = 1,'X','')
    CQ:Src  = SELF.Cols.HeadDef
    ADD(ColQ)
  END
  DISPLAY(?ExpCols)
  IF keep > 0 AND keep <= RECORDS(ColQ) THEN SELECT(?ExpCols,keep) .
  DO ShowInfo

ShowInfo ROUTINE
  ?ExpCount{PROP:Text} = '(' & SELF.Selected() & SELF.Txt(Txt:OfWord) & |
                         SELF.Columns() & SELF.Txt(Txt:SelectedWord)
  ?ExpInfo{PROP:Text}  = SELF.FormatHint(SELF.Fmt)

!  ---- Print writes no file - hide "Save to" and relabel the OK button. It
!  ---- prints straight to SELF.PrinterName or the Windows default printer
!  ---- when the export runs (StartFile -> PrnBegin) - no dialog appears.
!  ---- "Page Setup..." matters for Print and PDF alike (margins for both,
!  ---- orientation/paper for PDF).
SyncFmtMode ROUTINE
  IF SELF.Fmt = Exp:Print
    ?ExpP2{PROP:Hide}      = 1
    ?ExpFile{PROP:Hide}    = 1
    ?ExpPick{PROP:Hide}    = 1
    ?ExpOk{PROP:Text}      = SELF.Txt(Txt:PrintBtn)
  ELSE
    ?ExpP2{PROP:Hide}      = 0
    ?ExpFile{PROP:Hide}    = 0
    ?ExpPick{PROP:Hide}    = 0
    ?ExpOk{PROP:Text}      = SELF.Txt(Txt:ExportBtn)
  END
  IF SELF.Fmt = Exp:Print OR SELF.Fmt = Exp:PDF
    ?ExpPageSetup{PROP:Hide} = 0
  ELSE
    ?ExpPageSetup{PROP:Hide} = 1
  END
!  The summary rows only exist in the .xlsx writer - grey the picker button
!  and the four checkboxes out for every other format, rather than hide them,
!  so the dialog doesn't jump around as the user tries formats.
  IF SELF.Fmt = Exp:XLSX
    ?ExpTotal{PROP:Disable}  = 0
    ?ExpGroup{PROP:Disable}  = 0
    ?ExpSumP{PROP:Disable}   = 0
    ?ExpTotals{PROP:Disable} = 0
    ?ExpAvg{PROP:Disable}    = 0
    ?ExpMin{PROP:Disable}    = 0
    ?ExpMax{PROP:Disable}    = 0
    ?ExpCnt{PROP:Disable}    = 0
    ?ExpSplit{PROP:Disable}  = 0
  ELSE
    ?ExpTotal{PROP:Disable}  = 1
    ?ExpGroup{PROP:Disable}  = 1
    ?ExpSumP{PROP:Disable}   = 1
    ?ExpTotals{PROP:Disable} = 1
    ?ExpAvg{PROP:Disable}    = 1
    ?ExpMin{PROP:Disable}    = 1
    ?ExpMax{PROP:Disable}    = 1
    ?ExpCnt{PROP:Disable}    = 1
    ?ExpSplit{PROP:Disable}  = 1
  END

!  ---- include / exclude the highlighted column -----------------------------
ToggleRow ROUTINE
  row = CHOICE(?ExpCols)
  IF ~row THEN EXIT .
  SELF.ColumnUse(row,1 - SELF.ColumnOn(row))
  DO FillCols

!  ---- tick / untick it for the xlsx Totals row (numeric columns only) ------
ToggleTotal ROUTINE
  row = CHOICE(?ExpCols)
  IF ~row THEN EXIT .
  IF ~SELF.ColumnIsNum(row)
    SELF.Note(SELF.Txt(Txt:NotNumeric),SELF.Txt(Txt:MsgTitle),ICON:Exclamation)
    EXIT
  END
  SELF.ColumnTotal(row,1 - SELF.ColumnTotalOn(row))
  DO FillCols

!  ---- set (or clear) it as THE column to subtotal/group by - any column, --
!  ---- numeric or not, and only one at a time (ticking a new one clears the
!  ---- old one, same as FillCols already shows via ColumnGroupBy itself) ----
ToggleGroup ROUTINE
  row = CHOICE(?ExpCols)
  IF ~row THEN EXIT .
  SELF.ColumnGroupBy(row,1 - SELF.ColumnGroupOn(row))
  DO FillCols

!  ---- "Bring email to front" only means anything once Email is ticked ------
!  ---- hidden (not disabled) when Email is off, so it doesn't sit there
!  ---- greyed out taking up space for something that isn't relevant yet -----
SyncEmailFront ROUTINE
  ?ExpEmailFront{PROP:Hide} = CHOOSE(ExpEmail <> 0,0,1)

!  ---- rename it, or give it a different picture ----------------------------
EditRow ROUTINE
  row = CHOICE(?ExpCols)
  IF ~row THEN EXIT .
  EdHead = SELF.ColumnHeading(row)
  EdPic  = SELF.ColumnPic(row)
  EdOk   = 0
  OPEN(EdWnd)
  DO SpeakColumn                                          ! every caption, in SELF.Language
  ?EdSrc{PROP:Text} = SELF.ColumnDefault(row)
  ACCEPT
    CASE EVENT()
    OF EVENT:OpenWindow
      SELECT(?EdHead)
    END
    CASE FIELD()
    OF ?EdDef
      IF EVENT() = EVENT:Accepted
        EdHead = SELF.ColumnDefault(row)                  ! back to what the LIST itself says
        EdPic  = SELF.ColumnDefaultPic(row)
        DISPLAY(?EdHead)
        DISPLAY(?EdPic)
      END
    OF ?EdOk
      IF EVENT() = EVENT:Accepted
        IF CLIP(LEFT(EdPic)) AND SUB(CLIP(LEFT(EdPic)),1,1) <> '@'
          SELF.Note(SELF.Txt(Txt:BadPicture) & |
                    Exp:CRLF & Exp:CRLF & SELF.Txt(Txt:BadPicture2), |
                    SELF.Txt(Txt:PicTitle),ICON:Exclamation)
          SELECT(?EdPic)
          CYCLE
        END
        EdOk = 1
        POST(EVENT:CloseWindow)
      END
    OF ?EdCancel
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow) .
    END
  END
  CLOSE(EdWnd)
  IF EdOk
    SELF.ColumnRename(row,EdHead)
    SELF.ColumnPicture(row,EdPic)
    DO FillCols
  END

!  ---- no column picking: hide that block and close the gap -----------------
HideCols ROUTINE
  Shrink = 158                                            ! 92..250, the whole columns block
  ?ExpT2{PROP:Text}    = SELF.Txt(Txt:SubtitleNoCol)
  ?ExpP3{PROP:Hide}    = 1
  ?ExpCount{PROP:Hide} = 1
  ?ExpHint{PROP:Hide}  = 1
  ?ExpCols{PROP:Hide}  = 1
  ?ExpToggle{PROP:Hide}= 1
  ?ExpEdit{PROP:Hide}  = 1
  ?ExpAll{PROP:Hide}   = 1
  ?ExpNone{PROP:Hide}  = 1
  ?ExpDef{PROP:Hide}   = 1
  ?ExpTotal{PROP:Hide} = 1
  ?ExpGroup{PROP:Hide} = 1
  ?ExpHdrs{PROP:Ypos}    = 250 - Shrink
  ?ExpPics{PROP:Ypos}    = 262 - Shrink
  ?ExpOpen{PROP:Ypos}    = 274 - Shrink
  ?ExpPageSetup{PROP:Ypos} = 274 - Shrink
  ?ExpEmail{PROP:Ypos}   = 286 - Shrink
  ?ExpEmailFront{PROP:Ypos}   = 286 - Shrink
  ?ExpSumP{PROP:Ypos}    = 300 - Shrink
  ?ExpTotals{PROP:Ypos}  = 298 - Shrink
  ?ExpAvg{PROP:Ypos}     = 298 - Shrink
  ?ExpMin{PROP:Ypos}     = 298 - Shrink
  ?ExpMax{PROP:Ypos}     = 298 - Shrink
  ?ExpCnt{PROP:Ypos}     = 298 - Shrink
  ?ExpSplit{PROP:Ypos}   = 298 - Shrink
  ?ExpRule{PROP:Ypos}    = 320 - Shrink
  ?ExpInfo{PROP:Ypos}    = 328 - Shrink
  ?ExpOk{PROP:Ypos}      = 346 - Shrink
  ?ExpCancel{PROP:Ypos}  = 346 - Shrink
  0{PROP:Height}       = 0{PROP:Height} - Shrink
  0{PROP:Ypos}         = 0{PROP:Ypos} + Shrink / 2        ! stay centred


ExportClass.AskFileName PROCEDURE()
Name  CSTRING(261)
  CODE
  Name = CLIP(LEFT(SELF.FileName))
  IF ~Name THEN Name = SELF.SuggestName() & SELF.FormatExt(SELF.Fmt) .
  IF FILEDIALOG(SELF.Txt(Txt:ExportToTitle) & SELF.FormatName(SELF.Fmt),Name,SELF.FormatMask(SELF.Fmt), |
                FILE:Save + FILE:KeepDir + FILE:LongName + FILE:AddExtension)
    SELF.FileName = Name
    SELF.ForceExt(SELF.Fmt)
    RETURN 1
  END
  RETURN 0


! ############################################################################
!  One cell
! ############################################################################
ExportClass.HeaderText PROCEDURE(LONG pCol)
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  RETURN CLIP(SELF.Cols.Head)


ExportClass.CellText PROCEDURE(LONG pCol)
Fld  ANY
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '' .
  Fld &= WHAT(SELF.Q,SELF.Cols.FldNo)
  IF SELF.Pictures AND SELF.Cols.Pic
    RETURN CLIP(LEFT(FORMAT(Fld,SELF.Cols.Pic)))
  END
  RETURN CLIP(LEFT(Fld))


!  The unformatted value, for JSON numbers and real Excel numeric cells.
ExportClass.CellNumber PROCEDURE(LONG pCol)
Fld  ANY
s    CSTRING(65)
  CODE
  GET(SELF.Cols,pCol)
  IF ERRORCODE() THEN RETURN '0' .
  Fld &= WHAT(SELF.Q,SELF.Cols.FldNo)
  s = CLIP(LEFT(Fld))
  IF ~s THEN RETURN '0' .
  RETURN s


! ############################################################################
!  Writing:  StartFile -> AddRow (many) -> EndFile
! ############################################################################
ExportClass.StartFile PROCEDURE()
i     LONG,AUTO
n     LONG,AUTO
out   LONG,AUTO
w     LONG,AUTO
dlm   STRING(1)
  CODE
  SELF.ErrCode = 0
  SELF.ErrText = ''
  SELF.RowsOut = 0
  SELF.Started = 0
  IF ~SELF.Columns() THEN SELF.ScanColumns() .
  n = SELF.Columns()
  IF ~n
    SELF.ErrCode = 1
    SELF.ErrText = SELF.Txt(Txt:NoColumns)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF ~SELF.Selected()
    SELF.ErrCode = 3
    SELF.ErrText = SELF.Txt(Txt:NoneSelected)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF SELF.Fmt <> Exp:Print AND ~SELF.InWorkbook AND ~CLIP(LEFT(SELF.FileName))  ! Print writes no file; a workbook's
    SELF.ErrCode = 2                                                            ! FileName is only needed by EndWorkbook()
    SELF.ErrText = SELF.Txt(Txt:NoFileName)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF ~SELF.InWorkbook THEN SELF.FreeBuffers() .              ! mid-workbook, FreeBuffers() would wipe the sheets already stashed
  IF SELF.Fmt <> Exp:Print THEN SELF.Need(Exp:MinChunk) .    ! Print never touches SELF.Buf
  SELF.Started = 1
  dlm = SELF.Sep()

  CASE SELF.Fmt
!  ---- the delimited family ------------------------------------------------
  OF Exp:CSV OROF Exp:CSVUTF8 OROF Exp:TSV
    IF SELF.Headers
      out = 0
      LOOP i = 1 TO n
        GET(SELF.Cols,i)
        IF ~SELF.Cols.Use THEN CYCLE .
        out += 1
        IF out > 1 THEN SELF.Cat(dlm) .
        IF SELF.Fmt = Exp:TSV
          SELF.CatFlatField(SELF.HeaderText(i))
        ELSE
          SELF.CatCsvField(SELF.HeaderText(i),dlm)
        END
      END
      SELF.Cat(Exp:CRLF)
    END

!  ---- XML -----------------------------------------------------------------
  OF Exp:XML
    SELF.Cat('<?xml version="1.0" encoding="UTF-8"?>' & Exp:CRLF)
    SELF.Cat('<' & SELF.SafeTag(SELF.Title,0) & '>' & Exp:CRLF)

!  ---- JSON ----------------------------------------------------------------
  OF Exp:JSON
    SELF.Cat('[')

!  ---- HTML ----------------------------------------------------------------
  OF Exp:HTML
    SELF.Cat('<!DOCTYPE html>' & Exp:CRLF & '<html><head><meta charset="utf-8">' & Exp:CRLF)
    SELF.Cat('<title>')
    SELF.CatHtmlText(CLIP(SELF.Title))
    SELF.Cat('</title>' & Exp:CRLF)
    SELF.Cat('<style>' & |
             'body{{font:14px "Segoe UI",Arial,sans-serif;color:#23303b;background:#f5f7fa;margin:24px}' & |
             'h1{{font-size:19px;font-weight:600;color:#1f3a60;margin:0 0 4px}' & |
             'p.meta{{margin:0 0 18px;color:#6b7a88;font-size:12px}' & |
             'table{{border-collapse:collapse;background:#fff;box-shadow:0 1px 3px rgba(31,58,96,.12);font-size:13px}' & |
             'th{{background:#1f3a60;color:#fff;text-align:left;font-weight:600;padding:8px 12px;white-space:nowrap}' & |
             'td{{padding:6px 12px;border-bottom:1px solid #e3e9ef}' & |
             'tr:nth-child(even) td{{background:#f7f9fc}' & |
             'td.n{{text-align:right;font-variant-numeric:tabular-nums}' & |
             '</style></head><body>' & Exp:CRLF)
    SELF.Cat('<h1>')
    SELF.CatHtmlText(CLIP(SELF.Title))
    SELF.Cat('</h1>' & Exp:CRLF)
    SELF.Cat('<p class="meta">Exported ' & FORMAT(TODAY(),@d17) & ' ' & FORMAT(CLOCK(),@t4) & '</p>' & Exp:CRLF)
    SELF.Cat('<table>' & Exp:CRLF)
    IF SELF.Headers
      SELF.Cat('<thead><tr>')
      LOOP i = 1 TO n
        GET(SELF.Cols,i)
        IF ~SELF.Cols.Use THEN CYCLE .
        SELF.Cat('<th>')
        SELF.CatHtmlText(SELF.HeaderText(i))
        SELF.Cat('</th>')
      END
      SELF.Cat('</tr></thead>' & Exp:CRLF)
    END
    SELF.Cat('<tbody>' & Exp:CRLF)

!  ---- Excel .xlsx : the worksheet part -----------------------------------
  OF Exp:XLSX
    SELF.XlsxSheetBegin()

!  ---- Print: no buffer at all - StartDoc + StartPage + the heading row -----
  OF Exp:Print
    IF ~SELF.PrnBegin()
      SELF.Started = 0
      IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
      RETURN 0
    END

!  ---- PDF: catalog/font objects, page 1, and the heading row ---------------
  OF Exp:PDF
    IF ~SELF.PdfBegin()
      SELF.Started = 0
      IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
      RETURN 0
    END
  END
  RETURN 1


!  Append whatever is in the QUEUE BUFFER right now.
!  `i` walks every column the LIST has; `out` counts only the ticked ones, so
!  the file's field order and its A/B/C spreadsheet letters stay contiguous no
!  matter which columns the user left out.
ExportClass.AddRow PROCEDURE
i     LONG,AUTO
n     LONG,AUTO
out   LONG,AUTO
num   BYTE,AUTO
rw    LONG,AUTO
grw   LONG,AUTO                                            ! the CURRENT group's own row number, for SplitByGroup
dlm   STRING(1)
d     DECIMAL(20,6),AUTO                                   ! CellNumber() -> DECIMAL, for the Totals row
curGroupVal CSTRING(261)                                    ! this row's group-by value, if grouping is on
  CODE
  IF ~SELF.Started THEN RETURN .
  n = SELF.Columns()
  IF ~n THEN RETURN .
  dlm = SELF.Sep()
  out = 0

  CASE SELF.Fmt
  OF Exp:CSV OROF Exp:CSVUTF8 OROF Exp:TSV
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      out += 1
      IF out > 1 THEN SELF.Cat(dlm) .
      IF SELF.Fmt = Exp:TSV
        SELF.CatFlatField(SELF.CellText(i))
      ELSE
        SELF.CatCsvField(SELF.CellText(i),dlm)
      END
    END
    SELF.Cat(Exp:CRLF)

  OF Exp:XML
    SELF.Cat(' <' & CLIP(SELF.RowTag) & '>' & Exp:CRLF)
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      SELF.Cat('  <' & CLIP(SELF.Cols.Tag) & '>')
      SELF.CatXmlText(SELF.CellText(i))
      GET(SELF.Cols,i)
      SELF.Cat('</' & CLIP(SELF.Cols.Tag) & '>' & Exp:CRLF)
    END
    SELF.Cat(' </' & CLIP(SELF.RowTag) & '>' & Exp:CRLF)

  OF Exp:JSON
    IF SELF.RowsOut THEN SELF.Cat(',') .
    SELF.Cat(Exp:CRLF & '  {{')
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      num = SELF.Cols.IsNum
      out += 1
      IF out > 1 THEN SELF.Cat(',') .
      SELF.Cat('"')
      SELF.CatJsonText(SELF.HeaderText(i))
      SELF.Cat('":')
      IF num                                              ! a number stays a JSON number
        SELF.Cat(SELF.CellNumber(i))
      ELSE
        SELF.Cat('"')
        SELF.CatJsonText(SELF.CellText(i))
        SELF.Cat('"')
      END
    END
    SELF.Cat('}')

  OF Exp:HTML
    SELF.Cat('<tr>')
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      IF SELF.Cols.IsNum
        SELF.Cat('<td class="n">')
      ELSE
        SELF.Cat('<td>')
      END
      SELF.CatHtmlText(SELF.CellText(i))
      SELF.Cat('</td>')
    END
    SELF.Cat('</tr>' & Exp:CRLF)

  OF Exp:XLSX
!   ---- subtotal / group rows: peek this row's group value, handle a break --
    IF SELF.GroupCol
      curGroupVal = ''
      out = 0
      LOOP i = 1 TO n
        GET(SELF.Cols,i)
        IF ~SELF.Cols.Use THEN CYCLE .
        out += 1
        IF out = SELF.GroupCol
          curGroupVal = SELF.CellText(i)
          BREAK
        END
      END
      IF SELF.GroupHasRow AND curGroupVal <> SELF.GroupPrev
        SELF.XlsxSubtotalRow(SELF.GroupPrev,SELF.GroupFirstRow,SELF.XlsxRow - 1)
        IF SELF.SplitByGroup                                ! close the FINISHED group's own separate sheet too
          SELF.GrpSheetEnd(SELF.GrpFirstRow,SELF.GrpXlsxRow - 1)
          SELF.GrpStashSheet(SELF.GroupPrev)
        END
        LOOP i = 1 TO 64
          SELF.GrpSum[i] = 0 ; SELF.GrpMin[i] = 0 ; SELF.GrpMax[i] = 0 ; SELF.GrpCount[i] = 0
        END
        SELF.GroupFirstRow = SELF.XlsxRow
        IF SELF.SplitByGroup THEN SELF.GrpSheetBegin() .    ! ... and start the NEW group's
      ELSIF ~SELF.GroupHasRow
        SELF.GroupFirstRow = SELF.XlsxRow
        IF SELF.SplitByGroup THEN SELF.GrpSheetBegin() .    ! the very first group's sheet
      END
      SELF.GroupPrev   = curGroupVal
      SELF.GroupHasRow = 1
    END

    rw = SELF.XlsxRow
    out = 0
    SELF.Cat('<row r="' & rw & '">')
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      num = SELF.Cols.IsNum
      out += 1
      IF num                                              ! a true numeric cell: sums, sorts, charts
        IF out <= 64 AND SELF.ColStyleN[out]
          SELF.Cat('<c r="' & SELF.ColRef(out) & rw & '" s="' & SELF.ColStyleN[out] & '"><v>' & SELF.CellNumber(i) & '</v></c>')
        ELSE
          SELF.Cat('<c r="' & SELF.ColRef(out) & rw & '"><v>' & SELF.CellNumber(i) & '</v></c>')
        END
        IF (SELF.Totals OR SELF.TotalsAvg OR SELF.TotalsMin OR SELF.TotalsMax OR SELF.TotalsCnt) AND SELF.Cols.Total AND out <= 64
          d = SELF.CellNumber(i)                          ! STRING -> DECIMAL
          IF SELF.ColCount[out] = 0                       ! first value seen for this column
            SELF.ColMin[out] = d
            SELF.ColMax[out] = d
          ELSE
            IF d < SELF.ColMin[out] THEN SELF.ColMin[out] = d .
            IF d > SELF.ColMax[out] THEN SELF.ColMax[out] = d .
          END
          SELF.ColSum[out]   += d                          ! running sum for this column
          SELF.ColCount[out] += 1                          ! how many values went into it (for the average)
          IF SELF.GroupCol                                 ! the same, but reset at every group break
            IF SELF.GrpCount[out] = 0
              SELF.GrpMin[out] = d
              SELF.GrpMax[out] = d
            ELSE
              IF d < SELF.GrpMin[out] THEN SELF.GrpMin[out] = d .
              IF d > SELF.GrpMax[out] THEN SELF.GrpMax[out] = d .
            END
            SELF.GrpSum[out]   += d
            SELF.GrpCount[out] += 1
          END
        END
      ELSE
        SELF.Cat('<c r="' & SELF.ColRef(out) & rw & '" t="inlineStr"><is><t>')
        SELF.CatXmlText(SELF.CellText(i))
        SELF.Cat('</t></is></c>')
      END
    END
    SELF.Cat('</row>')
    SELF.XlsxRow += 1

!   ---- SplitByGroup: this SAME row, again, into the CURRENT group's own ----
!   ---- sheet - a second, independent copy, not a reference to the above ----
    IF SELF.SplitByGroup AND SELF.GroupCol
      grw = SELF.GrpXlsxRow
      out = 0
      SELF.GrpCat('<row r="' & grw & '">')
      LOOP i = 1 TO n
        GET(SELF.Cols,i)
        IF ~SELF.Cols.Use THEN CYCLE .
        num = SELF.Cols.IsNum
        out += 1
        IF num
          IF out <= 64 AND SELF.ColStyleN[out]
            SELF.GrpCat('<c r="' & SELF.ColRef(out) & grw & '" s="' & SELF.ColStyleN[out] & '"><v>' & SELF.CellNumber(i) & '</v></c>')
          ELSE
            SELF.GrpCat('<c r="' & SELF.ColRef(out) & grw & '"><v>' & SELF.CellNumber(i) & '</v></c>')
          END
        ELSE
          SELF.GrpCat('<c r="' & SELF.ColRef(out) & grw & '" t="inlineStr"><is><t>')
          SELF.GrpCatXmlText(SELF.CellText(i))
          SELF.GrpCat('</t></is></c>')
        END
      END
      SELF.GrpCat('</row>')
      SELF.GrpXlsxRow += 1
    END

  OF Exp:Print
    SELF.PrnRow()

  OF Exp:PDF
    SELF.PdfRow()
  END
  SELF.RowsOut += 1


ExportClass.EndFile PROCEDURE()
n     LONG,AUTO
ok    BYTE(0)
  CODE
  IF ~SELF.Started
    IF SELF.ErrCode AND SELF.Confirm
      SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand)
    END
    RETURN 0
  END
  SELF.Started = 0
  n = SELF.Columns()

  CASE SELF.Fmt
  OF Exp:XML
    SELF.Cat('</' & SELF.SafeTag(SELF.Title,0) & '>' & Exp:CRLF)
  OF Exp:JSON
    SELF.Cat(Exp:CRLF & ']' & Exp:CRLF)
  OF Exp:HTML
    SELF.Cat('</tbody></table>' & Exp:CRLF)
    SELF.Cat('<p class="meta">' & CLIP(LEFT(FORMAT(SELF.RowsOut,@n_11))) & SELF.Txt(Txt:RowsHtml) & '</p>' & Exp:CRLF)
    SELF.Cat('</body></html>' & Exp:CRLF)
  OF Exp:XLSX
    SELF.XlsxSheetEnd()
    SELF.XlsxStashSheet(SELF.Title)                         ! single-sheet export: exactly one entry for XlsxWrite() to zip
    IF SELF.SplitByGroup AND SELF.GroupCol THEN SELF.XlsxMoveLastToFirst() .  ! the main sheet stays the FIRST tab
  END

  CASE SELF.Fmt
  OF Exp:XLSX
    ok = SELF.XlsxWrite()
  OF Exp:Print
    ok = SELF.PrnEnd()                                    ! EndPage/EndDoc - no file at all
  OF Exp:PDF
    ok = SELF.PdfFinish()                                 ! Pages tree + xref + trailer -> disk
  OF Exp:CSVUTF8 OROF Exp:XML OROF Exp:JSON OROF Exp:HTML
    SELF.ToUTF8(SELF.Buf,SELF.BufLen)                     ! these formats declare UTF-8
    IF SELF.Fmt = Exp:CSVUTF8                             ! Excel needs the BOM to trust it
      SELF.BufLen = 0
      SELF.Cat(Exp:BOM)
      SELF.Need(SELF.U8Len)
      SELF.Buf[SELF.BufLen+1 : SELF.BufLen+SELF.U8Len] = SELF.U8[1 : SELF.U8Len]
      SELF.BufLen += SELF.U8Len
      ok = SELF.WriteDisk(SELF.FileName,SELF.Buf,SELF.BufLen)
    ELSE
      ok = SELF.WriteDisk(SELF.FileName,SELF.U8,SELF.U8Len)
    END
  ELSE
    ok = SELF.WriteDisk(SELF.FileName,SELF.Buf,SELF.BufLen)
  END

  SELF.FreeBuffers()
  IF ~ok
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF SELF.Persist THEN SELF.SaveSettings() .              ! remember how they left it
  IF SELF.Confirm
    IF SELF.Fmt = Exp:Print                                ! no file - report pages instead
      SELF.Note(CLIP(LEFT(FORMAT(SELF.RowsOut,@n_11))) & SELF.Txt(Txt:RowsPrinted) & |
                CLIP(LEFT(FORMAT(SELF.PagesOut,@n_11))) & SELF.Txt(Txt:PageWord), |
                SELF.Txt(Txt:DoneTitle),ICON:Asterisk)
    ELSE
      SELF.Note(CLIP(LEFT(FORMAT(SELF.RowsOut,@n_11))) & SELF.Txt(Txt:RowsExported) & Exp:CRLF & Exp:CRLF & |
                CLIP(SELF.FileName),SELF.Txt(Txt:DoneTitle),ICON:Asterisk)
    END
    IF SELF.PdfTruncated                                  ! shown AFTER the normal completion popup, not instead of it
      SELF.Note(SELF.Txt(Txt:PdfTruncMsg),SELF.Txt(Txt:PdfTruncTitle),ICON:Exclamation)
    END
  END
  IF SELF.Fmt <> Exp:Print AND SELF.OpenWhenDone THEN SELF.ShellOpen(SELF.FileName) .
  IF SELF.Fmt <> Exp:Print AND SELF.EmailWhenDone THEN SELF.EmailFile(SELF.FileName) .
  RETURN 1


! ############################################################################
!  Multiple sheets in one workbook - code-driven only, no Ask() dialog for it
! ############################################################################
!  Once, before the first sheet. Resets everything (including any sheets left
!  over from an earlier, abandoned attempt) and switches StartFile() into
!  "leave the buffers and the sheet stash alone between sheets" mode.
ExportClass.StartWorkbook PROCEDURE()
  CODE
  SELF.ErrCode = 0
  SELF.ErrText = ''
  IF SELF.Fmt <> Exp:XLSX
    SELF.ErrCode = 20
    SELF.ErrText = SELF.Txt(Txt:XlsxOnly)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF ~CLIP(LEFT(SELF.FileName))
    SELF.ErrCode = 2
    SELF.ErrText = SELF.Txt(Txt:NoFileName)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  SELF.FreeBuffers()
  SELF.InWorkbook      = 1
  SELF.WorkbookRowsOut = 0
  RETURN 1


!  Like StartFile(), scoped to one sheet: call Init() first if this sheet's
!  columns/list are different from the last one, then this, then the usual
!  AddRow() loop, then EndSheet(). Up to 100 sheets - comfortably more than
!  any real workbook needs, and keeps the fixed-size parts XlsxWrite() builds
!  safely within their buffers regardless.
ExportClass.StartSheet PROCEDURE(STRING pName)
  CODE
  SELF.ErrCode = 0
  SELF.ErrText = ''
  IF SELF.Fmt <> Exp:XLSX
    SELF.ErrCode = 20
    SELF.ErrText = SELF.Txt(Txt:XlsxOnly)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF ~SELF.InWorkbook
    SELF.ErrCode = 21
    SELF.ErrText = SELF.Txt(Txt:NotInWorkbook)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF ~SELF.Sheets &= NULL AND RECORDS(SELF.Sheets) >= 100
    SELF.ErrCode = 22
    SELF.ErrText = SELF.Txt(Txt:TooManySheets)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  SELF.CurSheetName = pName
  RETURN SELF.StartFile()


!  Closes this sheet's worksheet XML and stashes it - the workbook itself
!  isn't written until EndWorkbook(). SELF.RowsOut folds into
!  SELF.WorkbookRowsOut first, for one true row count across every sheet in
!  EndWorkbook()'s completion popup.
ExportClass.EndSheet PROCEDURE()
  CODE
  IF SELF.Fmt <> Exp:XLSX OR ~SELF.InWorkbook OR ~SELF.Started THEN RETURN 0 .
  SELF.XlsxSheetEnd()
  SELF.WorkbookRowsOut += SELF.RowsOut
  SELF.XlsxStashSheet(SELF.CurSheetName)
  SELF.Started = 0
  RETURN 1


!  Assembles every sheet EndSheet() stashed into one real .xlsx and writes it
!  to disk - the workbook-level equivalent of EndFile(). Ends "in workbook
!  mode" either way, so a failed attempt doesn't wedge the next StartWorkbook().
ExportClass.EndWorkbook PROCEDURE()
ok  BYTE(0)
  CODE
  IF SELF.Fmt <> Exp:XLSX OR ~SELF.InWorkbook THEN RETURN 0 .
  IF SELF.Sheets &= NULL OR RECORDS(SELF.Sheets) = 0
    SELF.ErrCode = 23
    SELF.ErrText = SELF.Txt(Txt:NoSheets)
    SELF.InWorkbook = 0
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  ok = SELF.XlsxWrite()
  SELF.FreeBuffers()
  SELF.InWorkbook = 0
  IF ~ok
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:FailTitle),ICON:Hand) .
    RETURN 0
  END
  IF SELF.Confirm
    SELF.Note(CLIP(LEFT(FORMAT(SELF.WorkbookRowsOut,@n_11))) & SELF.Txt(Txt:RowsExported) & Exp:CRLF & Exp:CRLF & |
              CLIP(SELF.FileName),SELF.Txt(Txt:DoneTitle),ICON:Asterisk)
  END
  IF SELF.OpenWhenDone  THEN SELF.ShellOpen(SELF.FileName) .
  IF SELF.EmailWhenDone THEN SELF.EmailFile(SELF.FileName) .
  RETURN 1


!  The whole queue, start to finish - right for a hand-coded LIST, and for a
!  browse whose records are all loaded.
ExportClass.ExportQueue PROCEDURE()
i  LONG,AUTO
  CODE
  IF ~SELF.StartFile() THEN RETURN 0 .
  IF ~SELF.Q &= NULL
    LOOP i = 1 TO RECORDS(SELF.Q)
      GET(SELF.Q,i)
      IF ERRORCODE() THEN BREAK .
      SELF.AddRow()
    END
  END
  RETURN SELF.EndFile()


ExportClass.Run PROCEDURE()
  CODE
  IF ~SELF.Ask() THEN RETURN 0 .
  RETURN SELF.ExportQueue()


! ############################################################################
!  Printing - the one-call version for hand-coded use. Sets Fmt to Exp:Print
!  and drives the same StartFile/AddRow/EndFile engine everything else uses,
!  so a browse walked through StartFile()/AddRow()/EndFile() by hand (see the
!  header comment) prints exactly as easily as it exports.
!  Named PrintOut, not Print - PRINT is a reserved Clarion intrinsic statement.
! ############################################################################
ExportClass.PrintOut PROCEDURE()
i  LONG,AUTO
  CODE
  SELF.Fmt = Exp:Print
  IF ~SELF.StartFile() THEN RETURN 0 .                    ! opens the printer
  IF ~SELF.Q &= NULL
    LOOP i = 1 TO RECORDS(SELF.Q)
      GET(SELF.Q,i)
      IF ERRORCODE() THEN BREAK .
      SELF.AddRow()
    END
  END
  RETURN SELF.EndFile()


!  No REPORT structure means no built-in Clarion PrintPreviewClass - instead,
!  this builds the SAME PDF Exp:PDF would (temporarily switching Fmt/FileName)
!  into the user's temp folder, then lets EndFile()'s own OpenWhenDone handling
!  open it - so whatever the machine's default PDF viewer is becomes the
!  preview UI, at zero extra Win32 risk. Fmt/FileName/OpenWhenDone/EmailWhenDone
!  are restored afterwards, so this never disturbs how the caller has the
!  exporter set up - and the scratch file in TEMP never gets emailed.
ExportClass.PreviewOut PROCEDURE()
savedFmt      LONG,AUTO
savedFile     CSTRING(261),AUTO
savedOpen     BYTE,AUTO
savedEmail    BYTE,AUTO
tmp           CSTRING(261)
tsize         ULONG,AUTO
i             LONG,AUTO
ok            BYTE,AUTO
  CODE
  savedFmt  = SELF.Fmt
  savedFile = SELF.FileName
  savedOpen = SELF.OpenWhenDone
  savedEmail = SELF.EmailWhenDone

  tmp = ''
  tsize = exGetTempPath(SIZE(tmp),tmp)
  IF ~tsize OR tsize > SIZE(tmp)
    tmp = LONGPATH()                                    ! temp folder unavailable - use this instead
  END
  tmp = CLIP(tmp)
  IF LEN(tmp) AND tmp[LEN(tmp)] <> '\'
    tmp = CLIP(tmp) & '\'
  END
  tmp = CLIP(tmp) & 'ExportPreview.pdf'

  SELF.Fmt          = Exp:PDF
  SELF.FileName     = tmp
  SELF.OpenWhenDone = 1                                  ! EndFile() opens it for us
  SELF.EmailWhenDone = 0                                 ! never email a scratch file from TEMP

  ok = SELF.StartFile()
  IF ok
    IF ~SELF.Q &= NULL
      LOOP i = 1 TO RECORDS(SELF.Q)
        GET(SELF.Q,i)
        IF ERRORCODE() THEN BREAK .
        SELF.AddRow()
      END
    END
    ok = SELF.EndFile()
  END

  SELF.Fmt          = savedFmt
  SELF.FileName     = savedFile
  SELF.OpenWhenDone = savedOpen
  SELF.EmailWhenDone = savedEmail
  RETURN ok


!  A small, pure-Clarion page-setup dialog - no PAGESETUPDLG struct, so nothing
!  here depends on the exact byte layout of a Win32 DEVMODE. PDF honours all of
!  it; Print honours the margins and font size, but not orientation/paper -
!  a printed page follows the target printer's own configured default.
!  Orientation/Paper use a DROP list bound to a small QUEUE - the same idiom
!  Ask() uses for ?ExpFmt - rather than an OPTION/RADIO group, which some
!  Clarion versions insist on a literal string VALUE() for even when the bound
!  field is numeric.
ExportClass.PageSetup PROCEDURE()
OrientQ   QUEUE,PRE(OQ)
FName       STRING(20)
FId         LONG
          END
PaperQ    QUEUE,PRE(PQ)
FName       STRING(20)
FId         LONG
          END
Ok        BYTE(0)
Sel       LONG,AUTO
mL        REAL
mT        REAL
mR        REAL
mB        REAL
i         LONG,AUTO
PSWnd  WINDOW('Page setup'),AT(,,220,150),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI),CENTER,GRAY,SYSTEM,MODAL
         PROMPT('&Orientation:'),AT(10,12),USE(?PsP1)
         LIST,AT(10,24,120,10),USE(?PsOrient),DROP(5),FROM(OrientQ),FORMAT('116L(2)@s20@')
         PROMPT('&Paper (PDF only):'),AT(10,44),USE(?PsP2)
         LIST,AT(10,56,120,10),USE(?PsPaper),DROP(5),FROM(PaperQ),FORMAT('116L(2)@s20@')
         PROMPT('Margins, in inches:'),AT(140,10),USE(?PsP3)
         PROMPT('&Left'),AT(140,26),USE(?PsP4)
         ENTRY(@n5.2),AT(178,24,36,10),USE(mL)
         PROMPT('&Top'),AT(140,40),USE(?PsP5)
         ENTRY(@n5.2),AT(178,38,36,10),USE(mT)
         PROMPT('&Right'),AT(140,54),USE(?PsP6)
         ENTRY(@n5.2),AT(178,52,36,10),USE(mR)
         PROMPT('&Bottom'),AT(140,68),USE(?PsP7)
         ENTRY(@n5.2),AT(178,66,36,10),USE(mB)
         BUTTON('OK'),AT(94,124,54,14),USE(?PsOk),DEFAULT
         BUTTON('Cancel'),AT(154,124,54,14),USE(?PsCancel)
       END
  CODE
  OQ:FName = 'Portrait'  ; OQ:FId = Exp:Portrait  ; ADD(OrientQ)
  OQ:FName = 'Landscape' ; OQ:FId = Exp:Landscape ; ADD(OrientQ)
  PQ:FName = 'Letter'    ; PQ:FId = Exp:Letter    ; ADD(PaperQ)
  PQ:FName = 'A4'        ; PQ:FId = Exp:A4        ; ADD(PaperQ)
  mL = SELF.MarginLeft   / 1440.0
  mT = SELF.MarginTop    / 1440.0
  mR = SELF.MarginRight  / 1440.0
  mB = SELF.MarginBottom / 1440.0
  OPEN(PSWnd)
  Sel = 1
  LOOP i = 1 TO RECORDS(OrientQ)
    GET(OrientQ,i)
    IF OQ:FId = SELF.PageOrient THEN Sel = i ; BREAK .
  END
  ?PsOrient{PROP:Selected} = Sel
  Sel = 1
  LOOP i = 1 TO RECORDS(PaperQ)
    GET(PaperQ,i)
    IF PQ:FId = SELF.PagePaper THEN Sel = i ; BREAK .
  END
  ?PsPaper{PROP:Selected} = Sel
  ACCEPT
    CASE FIELD()
    OF ?PsOk
      IF EVENT() = EVENT:Accepted
        Ok = 1
        POST(EVENT:CloseWindow)
      END
    OF ?PsCancel
      IF EVENT() = EVENT:Accepted THEN POST(EVENT:CloseWindow) .
    END
  END
  IF Ok
    Sel = CHOICE(?PsOrient)                                 ! read the LIST while the window is still
    IF Sel                                                   ! open - CHOICE() after CLOSE() returns nothing
      GET(OrientQ,Sel)
      IF ~ERRORCODE() THEN SELF.PageOrient = OQ:FId .
    END
    Sel = CHOICE(?PsPaper)
    IF Sel
      GET(PaperQ,Sel)
      IF ~ERRORCODE() THEN SELF.PagePaper = PQ:FId .
    END
  END
  CLOSE(PSWnd)
  IF Ok
    IF mL < 0 THEN mL = 0 .
    IF mL > 5 THEN mL = 5 .
    IF mT < 0 THEN mT = 0 .
    IF mT > 5 THEN mT = 5 .
    IF mR < 0 THEN mR = 0 .
    IF mR > 5 THEN mR = 5 .
    IF mB < 0 THEN mB = 0 .
    IF mB > 5 THEN mB = 5 .
    SELF.MarginLeft   = mL * 1440
    SELF.MarginTop    = mT * 1440
    SELF.MarginRight  = mR * 1440
    SELF.MarginBottom = mB * 1440
  END
  RETURN Ok


! ############################################################################
!  Growable buffers
! ############################################################################
ExportClass.Need PROCEDURE(LONG pAdd)
cap  LONG,AUTO
nb   &STRING
  CODE
  IF SELF.BufLen + pAdd <= SELF.BufCap THEN RETURN .
  cap = SELF.BufCap
  IF cap < Exp:MinChunk THEN cap = Exp:MinChunk .
  LOOP WHILE cap < SELF.BufLen + pAdd
    cap += cap
  END
  nb &= NEW STRING(cap)
  IF SELF.BufLen THEN nb[1 : SELF.BufLen] = SELF.Buf[1 : SELF.BufLen] .
  IF ~SELF.Buf &= NULL THEN DISPOSE(SELF.Buf) .
  SELF.Buf   &= nb
  SELF.BufCap = cap


ExportClass.Cat PROCEDURE(STRING pText)
l  LONG,AUTO
  CODE
  l = LEN(pText)
  IF l <= 0 THEN RETURN .
  SELF.Need(l)
  SELF.Buf[SELF.BufLen+1 : SELF.BufLen+l] = pText[1 : l]
  SELF.BufLen += l


!  GrpBuf's own Need()/Cat() - SplitByGroup's per-group sheet is built up
!  entirely separately from the main sheet in SELF.Buf, on purpose: the two
!  are never in any way mixed, so nothing about the already-tested main-sheet
!  path (or any other format) is touched by this feature at all.
ExportClass.GrpNeed PROCEDURE(LONG pAdd)
cap  LONG,AUTO
nb   &STRING
  CODE
  IF SELF.GrpBufLen + pAdd <= SELF.GrpBufCap THEN RETURN .
  cap = SELF.GrpBufCap
  IF cap < Exp:MinChunk THEN cap = Exp:MinChunk .
  LOOP WHILE cap < SELF.GrpBufLen + pAdd
    cap += cap
  END
  nb &= NEW STRING(cap)
  IF SELF.GrpBufLen THEN nb[1 : SELF.GrpBufLen] = SELF.GrpBuf[1 : SELF.GrpBufLen] .
  IF ~SELF.GrpBuf &= NULL THEN DISPOSE(SELF.GrpBuf) .
  SELF.GrpBuf    &= nb
  SELF.GrpBufCap = cap


ExportClass.GrpCat PROCEDURE(STRING pText)
l  LONG,AUTO
  CODE
  l = LEN(pText)
  IF l <= 0 THEN RETURN .
  SELF.GrpNeed(l)
  SELF.GrpBuf[SELF.GrpBufLen+1 : SELF.GrpBufLen+l] = pText[1 : l]
  SELF.GrpBufLen += l


ExportClass.ArcNeed PROCEDURE(LONG pAdd)
cap  LONG,AUTO
nb   &STRING
  CODE
  IF SELF.ArcLen + pAdd <= SELF.ArcCap THEN RETURN .
  cap = SELF.ArcCap
  IF cap < Exp:MinChunk THEN cap = Exp:MinChunk .
  LOOP WHILE cap < SELF.ArcLen + pAdd
    cap += cap
  END
  nb &= NEW STRING(cap)
  IF SELF.ArcLen THEN nb[1 : SELF.ArcLen] = SELF.Arc[1 : SELF.ArcLen] .
  IF ~SELF.Arc &= NULL THEN DISPOSE(SELF.Arc) .
  SELF.Arc   &= nb
  SELF.ArcCap = cap


ExportClass.ArcCat PROCEDURE(STRING pText)
l  LONG,AUTO
  CODE
  l = LEN(pText)
  IF l <= 0 THEN RETURN .
  SELF.ArcNeed(l)
  SELF.Arc[SELF.ArcLen+1 : SELF.ArcLen+l] = pText[1 : l]
  SELF.ArcLen += l


ExportClass.U8Need PROCEDURE(LONG pSize)
  CODE
  IF pSize <= SELF.U8Cap THEN RETURN .
  IF ~SELF.U8 &= NULL THEN DISPOSE(SELF.U8) .
  SELF.U8   &= NEW STRING(pSize)
  SELF.U8Cap = pSize


ExportClass.FreeBuffers PROCEDURE
i  LONG,AUTO
  CODE
  IF ~SELF.Buf &= NULL THEN DISPOSE(SELF.Buf) .
  IF ~SELF.Arc &= NULL THEN DISPOSE(SELF.Arc) .
  IF ~SELF.U8  &= NULL THEN DISPOSE(SELF.U8)  .
  IF ~SELF.PdfContent &= NULL THEN DISPOSE(SELF.PdfContent) .
  IF ~SELF.GrpBuf &= NULL THEN DISPOSE(SELF.GrpBuf) .
  SELF.BufLen = 0 ; SELF.BufCap = 0
  SELF.ArcLen = 0 ; SELF.ArcCap = 0
  SELF.U8Len  = 0 ; SELF.U8Cap  = 0
  SELF.PdfContLen = 0 ; SELF.PdfContCap = 0
  SELF.GrpBufLen = 0 ; SELF.GrpBufCap = 0
  IF ~SELF.Parts   &= NULL THEN FREE(SELF.Parts)   .
  IF ~SELF.PdfObjs &= NULL THEN FREE(SELF.PdfObjs) .
  IF ~SELF.Sheets &= NULL
    LOOP i = 1 TO RECORDS(SELF.Sheets)
      GET(SELF.Sheets,i)
      IF ERRORCODE() THEN CYCLE .
      IF ~SELF.Sheets.SData &= NULL THEN DISPOSE(SELF.Sheets.SData) .
    END
    FREE(SELF.Sheets)
  END
  IF ~SELF.NumFmts &= NULL THEN FREE(SELF.NumFmts) .


ExportClass.Sep PROCEDURE()
  CODE
  IF SELF.Fmt = Exp:TSV THEN RETURN Exp:TAB .
  IF SELF.Delim         THEN RETURN SELF.Delim .
  RETURN ','


! ############################################################################
!  Escaping.  Each of these walks the value, copies the longest clean run in
!  one go and only then emits an escape - so ordinary data costs one Cat.
! ############################################################################
ExportClass.CatCsvField PROCEDURE(STRING pText,STRING pDelim)
l     LONG,AUTO
i     LONG,AUTO
run   LONG,AUTO
quote BYTE(0)
c     STRING(1)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  LOOP i = 1 TO l                                         ! RFC 4180: when must it be quoted
    c = pText[i]
    IF c = '"' OR c = pDelim OR c = '<13>' OR c = '<10>'
      quote = 1
      BREAK
    END
  END
  IF pText[1] = ' ' OR pText[l] = ' ' THEN quote = 1 .
  IF ~quote
    SELF.Cat(pText[1 : l])
    RETURN
  END
  SELF.Cat('"')
  run = 1
  LOOP i = 1 TO l
    IF pText[i] = '"'
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat('""')                                      ! a quote is doubled
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .
  SELF.Cat('"')


!  TSV has no quoting convention every reader agrees on, so nothing that would
!  break a row is allowed through.
ExportClass.CatFlatField PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
c    STRING(1)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    c = pText[i]
    IF c = '<9>' OR c = '<13>' OR c = '<10>'
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      IF ~(c = '<10>' AND i > 1 AND pText[i-1] = '<13>')  ! a CRLF pair is one space, not two
        SELF.Cat(' ')
      END
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


ExportClass.CatXmlText PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
v    LONG,AUTO
esc  CSTRING(9)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    v   = VAL(pText[i])
    esc = ''
    CASE v
    OF 38 ; esc = '&amp;'
    OF 60 ; esc = '&lt;'
    OF 62 ; esc = '&gt;'
    OF 34 ; esc = '&quot;'
    OF 39 ; esc = '&apos;'
    ELSE
      IF v < 32 AND v <> 9 AND v <> 10 AND v <> 13 THEN esc = ' ' . ! illegal in XML 1.0
    END
    IF esc
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat(esc)
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


!  GrpBuf's own CatXmlText() - identical escaping, into GrpBuf via GrpCat()
!  instead of Buf via Cat(), same reason GrpNeed()/GrpCat() exist at all.
ExportClass.GrpCatXmlText PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
v    LONG,AUTO
esc  CSTRING(9)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    v   = VAL(pText[i])
    esc = ''
    CASE v
    OF 38 ; esc = '&amp;'
    OF 60 ; esc = '&lt;'
    OF 62 ; esc = '&gt;'
    OF 34 ; esc = '&quot;'
    OF 39 ; esc = '&apos;'
    ELSE
      IF v < 32 AND v <> 9 AND v <> 10 AND v <> 13 THEN esc = ' ' . ! illegal in XML 1.0
    END
    IF esc
      IF i > run THEN SELF.GrpCat(pText[run : i-1]) .
      SELF.GrpCat(esc)
      run = i + 1
    END
  END
  IF l >= run THEN SELF.GrpCat(pText[run : l]) .


ExportClass.CatJsonText PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
v    LONG,AUTO
esc  CSTRING(9)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    v   = VAL(pText[i])
    esc = ''
    CASE v
    OF 34 ; esc = '\"'
    OF 92 ; esc = '\\'
    OF  8 ; esc = '\b'
    OF 12 ; esc = '\f'
    OF 10 ; esc = '\n'
    OF 13 ; esc = '\r'
    OF  9 ; esc = '\t'
    ELSE
      IF v < 32 THEN esc = '\u00' & SUB('0123456789abcdef',BSHIFT(v,-4)+1,1) & SUB('0123456789abcdef',BAND(v,15)+1,1) .
    END
    IF esc
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat(esc)
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


ExportClass.CatHtmlText PROCEDURE(STRING pText)
l    LONG,AUTO
i    LONG,AUTO
run  LONG,AUTO
esc  CSTRING(9)
c    STRING(1)
  CODE
  l = LEN(pText)
  IF ~l THEN RETURN .
  run = 1
  LOOP i = 1 TO l
    c   = pText[i]
    esc = ''
    CASE c
    OF '&' ; esc = '&amp;'
    OF '<' ; esc = '&lt;'
    OF '>' ; esc = '&gt;'
    OF '"' ; esc = '&quot;'
    END
    IF esc
      IF i > run THEN SELF.Cat(pText[run : i-1]) .
      SELF.Cat(esc)
      run = i + 1
    END
  END
  IF l >= run THEN SELF.Cat(pText[run : l]) .


! ############################################################################
!  Names
! ############################################################################
!  'Cust Name' -> 'Cust_Name'.  XML element names cannot hold spaces or start
!  with a digit, and JSON keys read better the same way.
ExportClass.SafeTag PROCEDURE(STRING pText,LONG pCol)
s   CSTRING(65)
o   CSTRING(65)
i   LONG,AUTO
c   STRING(1)
  CODE
  s = CLIP(LEFT(pText))
  o = ''
  LOOP i = 1 TO LEN(s)
    IF LEN(o) >= 60 THEN BREAK .
    c = s[i]
    IF (c >= 'A' AND c <= 'Z') OR (c >= 'a' AND c <= 'z') OR (c >= '0' AND c <= '9') OR c = '_'
      o = o & c
    ELSIF LEN(o) AND o[LEN(o)] <> '_'
      o = o & '_'
    END
  END
  LOOP WHILE LEN(o) AND o[LEN(o)] = '_'
    o = SUB(o,1,LEN(o)-1)
  END
  IF ~LEN(o)
    IF pCol THEN RETURN 'Column' & pCol .
    RETURN 'Data'
  END
  IF o[1] >= '0' AND o[1] <= '9' THEN o = '_' & o .
  RETURN o


!  Excel: 31 characters, and none of  []:*?/\
ExportClass.SheetName PROCEDURE(STRING pText)
s  CSTRING(65)
i  LONG,AUTO
  CODE
  s = CLIP(LEFT(pText))
  IF ~s THEN s = 'Data' .
  LOOP i = 1 TO LEN(s)
    IF INSTRING(s[i],'[]:*?/\',1,1) THEN s[i] = ' ' .
  END
  s = CLIP(LEFT(s))
  IF LEN(s) > 31 THEN s = SUB(s,1,31) .
  IF ~s THEN s = 'Data' .
  RETURN s


ExportClass.ColRef PROCEDURE(LONG pCol)
n  LONG,AUTO
r  CSTRING(5)
m  LONG,AUTO
  CODE
  n = pCol
  r = ''
  IF n < 1 THEN RETURN 'A' .
  LOOP WHILE n > 0
    m = n - 1
    r = CHR(65 + m - INT(m/26)*26) & r
    n = INT(m/26)
  END
  RETURN r


! ############################################################################
!  Text encoding
! ############################################################################
ExportClass.IsAscii PROCEDURE(*STRING pData,LONG pLen)
i  LONG,AUTO
  CODE
  LOOP i = 1 TO pLen
    IF VAL(pData[i]) > 127 THEN RETURN 0 .
  END
  RETURN 1


!  ANSI (the machine's code page) -> UTF-8, into SELF.U8 / SELF.U8Len.
!  Pure-ASCII text is already valid UTF-8, so the common case copies straight
!  through and never touches the API.
ExportClass.ToUTF8 PROCEDURE(*STRING pData,LONG pLen)
nW  SIGNED,AUTO
nU  SIGNED,AUTO
W   &STRING
  CODE
  SELF.U8Len = 0
  IF pLen <= 0
    SELF.U8Need(16)
    RETURN
  END
  IF SELF.IsAscii(pData,pLen)
    SELF.U8Need(pLen)
    SELF.U8[1 : pLen] = pData[1 : pLen]
    SELF.U8Len = pLen
    RETURN
  END
  W &= NEW STRING(pLen * 2 + 4)                           ! 1 byte in -> at most 1 wide char
  nW = exMB2WC(Exp:CP_ACP,0,pData,pLen,W,pLen)
  IF nW > 0
    SELF.U8Need(pLen * 3 + 8)                             ! 1 wide char -> at most 3 UTF-8 bytes
    nU = exWC2MB(Exp:CP_UTF8,0,W,nW,SELF.U8,SELF.U8Cap,0,0)
    IF nU > 0 THEN SELF.U8Len = nU .
  END
  DISPOSE(W)
  IF ~SELF.U8Len                                          ! conversion refused - ship the bytes as-is
    SELF.U8Need(pLen)
    SELF.U8[1 : pLen] = pData[1 : pLen]
    SELF.U8Len = pLen
  END


! ############################################################################
!  Disk
! ############################################################################
!  Writes to a TEMP file next to the target, then swaps it into place with one
!  atomic MoveFileEx (MOVEFILE_REPLACE_EXISTING). A viewer that still has the
!  target open from a previous export (SELF.OpenWhenDone opens it right after
!  writing) never sees a half-written file this way - it keeps reading its
!  already-open handle to the old content until it re-opens the path, at
!  which point the swap is long since complete. Writing straight over the
!  live path with CREATE_ALWAYS truncates it to 0 bytes the instant it opens,
!  which a viewer can catch mid-write and report as "failed to load".
ExportClass.WriteDisk PROCEDURE(STRING pFile,*STRING pData,LONG pLen)
h     LONG,AUTO
nm    CSTRING(261)
tmp   CSTRING(265)
wr    ULONG,AUTO
  CODE
  nm  = CLIP(LEFT(pFile))
  tmp = CLIP(nm) & '.tmp'

  h  = exCreateFile(tmp,40000000h,7,0,2,80h,0)              ! GENERIC_WRITE, CREATE_ALWAYS, NORMAL
  IF h = 0 OR h = -1
    SELF.ErrCode = 10
    SELF.ErrText = SELF.Txt(Txt:CantCreate) & Exp:CRLF & Exp:CRLF & CLIP(nm) & Exp:CRLF & Exp:CRLF & |
                   SELF.Txt(Txt:CantCreate2)
    RETURN 0
  END
  IF pLen > 0
    wr = 0
    IF ~exWriteFile(h,pData,pLen,wr,0) OR wr <> pLen
      exCloseHandle(h)
      exDeleteFile(tmp)
      SELF.ErrCode = 11
      SELF.ErrText = SELF.Txt(Txt:CantWrite) & Exp:CRLF & Exp:CRLF & CLIP(nm) & Exp:CRLF & Exp:CRLF & |
                     SELF.Txt(Txt:CantWrite2)
      RETURN 0
    END
  END
  exCloseHandle(h)

  IF ~exMoveFileEx(tmp,nm,9)                                ! MOVEFILE_REPLACE_EXISTING + MOVEFILE_WRITE_THROUGH
    exDeleteFile(tmp)
    SELF.ErrCode = 12
    SELF.ErrText = SELF.Txt(Txt:CantWrite) & Exp:CRLF & Exp:CRLF & CLIP(nm) & Exp:CRLF & Exp:CRLF & |
                   SELF.Txt(Txt:CantWrite2)
    RETURN 0
  END
  RETURN 1


ExportClass.ShellOpen PROCEDURE(STRING pFile)
op  CSTRING(8)
fn  CSTRING(261)
pm  CSTRING(2)
dr  CSTRING(2)
  CODE
  op = 'open'
  fn = CLIP(LEFT(pFile))
  pm = ''
  dr = ''
  IF ~fn THEN RETURN .
  exShellExec(0,op,fn,pm,dr,1)                            ! SW_SHOWNORMAL


!  Opens a new message in whatever mail client is registered as the default
!  Simple MAPI provider (Outlook, Windows Mail, and most others), with pFile
!  already attached, SELF.EmailSubject (blank = SELF.Title) as the subject and
!  SELF.EmailBody as the note text. MAPI_DIALOG (flag 8) leaves the compose
!  window open for the user to pick a recipient and press Send themselves -
!  nothing goes out silently. Result 1 means the user closed that window
!  without sending, which is not a failure; anything else is reported the
!  same way a write failure would be, but without undoing an export that
!  already wrote its file successfully.
ExportClass.EmailFile PROCEDURE(STRING pFile)
Fd    GROUP,PRE(Fd)
ulReserved          ULONG
flFlags             ULONG
nPosition           LONG
lpszPathName        LONG
lpszFileName        LONG
lpFileType          LONG
      END
Mm    GROUP,PRE(Mm)
ulReserved          ULONG
lpszSubject         LONG
lpszNoteText        LONG
lpszMessageType     LONG
lpszDateReceived    LONG
lpszConversationID  LONG
flFlags             ULONG
lpOriginator        LONG
nRecipCount         ULONG
lpRecips            LONG
nFileCount          ULONG
lpFiles             LONG
      END
nm    CSTRING(261)
subj  CSTRING(129)
body  CSTRING(1025)
dll   CSTRING(16)
fn    CSTRING(16)
hMapi LONG,AUTO
rc    LONG,AUTO
  CODE
  nm = CLIP(LEFT(pFile))
  IF ~nm THEN RETURN .
  subj = CLIP(SELF.EmailSubject)
  IF ~subj THEN subj = CLIP(SELF.Title) .
  body = SELF.EmailBody

  CLEAR(Fd)
  Fd:lpszPathName = ADDRESS(nm)
  Fd:nPosition    = -1                                    ! "just attach it" - no inline OLE position

  CLEAR(Mm)
  Mm:lpszSubject  = ADDRESS(subj)
  Mm:lpszNoteText = ADDRESS(body)
  Mm:nFileCount   = 1
  Mm:lpFiles      = ADDRESS(Fd)

  IF SELF.EmailToFront THEN rc = exAllowSetForegroundWindow(-1) .  ! -1 = ASFW_ANY - let Outlook's own window win the foreground fight
  IF ~exMAPISendMailFp
    dll = 'MAPI32.DLL'
    fn  = 'MAPISendMail'
    hMapi = exLoadLibrary(dll)
    IF hMapi THEN exMAPISendMailFp = exGetProcAddress(hMapi,fn) .
  END
  IF exMAPISendMailFp
    rc = exMAPISendMail(0,0,Mm,8,0)                         ! flag 8 = MAPI_DIALOG
  ELSE
    rc = 2                                                ! no Simple MAPI on this machine - reported like any failure
  END
  IF rc <> 0 AND rc <> 1                                  ! 0 = handed to the client, 1 = user cancelled - neither is a failure
    SELF.ErrCode = 13
    SELF.ErrText = SELF.Txt(Txt:CantEmail)
    IF SELF.Confirm THEN SELF.Note(SELF.ErrText,SELF.Txt(Txt:EmailFailTitle),ICON:Exclamation) .
  END


! ############################################################################
!  ZIP  (the .xlsx container)
! ############################################################################
ExportClass.CrcInit PROCEDURE
i  LONG,AUTO
j  LONG,AUTO
c  ULONG,AUTO
  CODE
  LOOP i = 0 TO 255
    c = i
    LOOP j = 1 TO 8
      IF BAND(c,1)
        c = BXOR(BSHIFT(c,-1),0EDB88320h)
      ELSE
        c = BSHIFT(c,-1)
      END
    END
    SELF.CrcTab[i+1] = c
  END
  SELF.CrcReady = 1


ExportClass.CRC32 PROCEDURE(*STRING pData,LONG pLen)
crc  ULONG,AUTO
i    LONG,AUTO
  CODE
  IF ~SELF.CrcReady THEN SELF.CrcInit() .
  crc = 0FFFFFFFFh
  LOOP i = 1 TO pLen
    crc = BXOR(BSHIFT(crc,-8),SELF.CrcTab[ BAND(BXOR(crc,VAL(pData[i])),0FFh) + 1 ])
  END
  RETURN BXOR(crc,0FFFFFFFFh)


ExportClass.Le16 PROCEDURE(ULONG pVal)
G  GROUP
V    USHORT
   END
S  STRING(2),OVER(G)
  CODE
  G.V = pVal
  RETURN S


ExportClass.Le32 PROCEDURE(ULONG pVal)
G  GROUP
V    ULONG
   END
S  STRING(4),OVER(G)
  CODE
  G.V = pVal
  RETURN S


!  One archive member:  local header + the bytes.  Its central-directory entry
!  is remembered in SELF.Parts and written by ZipFinish.
ExportClass.ZipAdd PROCEDURE(STRING pName,*STRING pData,LONG pLen)
nm    CSTRING(65)
crc   ULONG,AUTO
ofs   ULONG,AUTO
dt    ULONG,AUTO
tm    ULONG,AUTO
secs  LONG,AUTO
hh    LONG,AUTO
mi    LONG,AUTO
ss    LONG,AUTO
dy    LONG,AUTO
meth  USHORT(0)
clen  LONG,AUTO
cbuf  &STRING
  COMPILE('_EndDeflateObj_',_ExportDeflate_)
Deflater  CompressClass
  _EndDeflateObj_
  CODE
  nm   = CLIP(pName)
  crc  = SELF.CRC32(pData,pLen)
  ofs  = SELF.ArcLen
  clen = pLen
  cbuf &= NULL
  dy   = TODAY()
  secs = INT((CLOCK() - 1) / 100)
  hh   = INT(secs / 3600)
  mi   = INT((secs - hh * 3600) / 60)
  ss   = secs - hh * 3600 - mi * 60
  tm   = BSHIFT(hh,11) + BSHIFT(mi,5) + INT(ss / 2)
  dt   = BSHIFT(YEAR(dy) - 1980,9) + BSHIFT(MONTH(dy),5) + DAY(dy)

  COMPILE('_EndDeflateRun_',_ExportDeflate_)
  IF pLen > 0
    Deflater.Format = Cmp:Raw                             ! raw DEFLATE is ZIP method 8
    Deflater.Level  = 6
    cbuf &= NEW STRING(Deflater.MaxCompressed(pLen))
    clen  = Deflater.Compress(pData,pLen,cbuf)
    IF clen > 0 AND clen < pLen
      meth = 8
    ELSE                                                  ! it did not help - store it
      DISPOSE(cbuf)
      clen = pLen
      meth = 0
    END
  END
  _EndDeflateRun_

  SELF.ArcCat('PK<3,4>')
  SELF.ArcCat(SELF.Le16(20))                              ! version needed to extract
  SELF.ArcCat(SELF.Le16(0))                               ! general purpose flags
  SELF.ArcCat(SELF.Le16(meth))
  SELF.ArcCat(SELF.Le16(tm))
  SELF.ArcCat(SELF.Le16(dt))
  SELF.ArcCat(SELF.Le32(crc))
  SELF.ArcCat(SELF.Le32(clen))
  SELF.ArcCat(SELF.Le32(pLen))
  SELF.ArcCat(SELF.Le16(LEN(nm)))
  SELF.ArcCat(SELF.Le16(0))                               ! extra field length
  SELF.ArcCat(nm)
  IF clen > 0
    SELF.ArcNeed(clen)
    IF meth = 8
      SELF.Arc[SELF.ArcLen+1 : SELF.ArcLen+clen] = cbuf[1 : clen]
    ELSE
      SELF.Arc[SELF.ArcLen+1 : SELF.ArcLen+clen] = pData[1 : clen]
    END
    SELF.ArcLen += clen
  END
  IF ~cbuf &= NULL THEN DISPOSE(cbuf) .

  SELF.Parts.EName  = nm
  SELF.Parts.ECrc   = crc
  SELF.Parts.ECSize = clen
  SELF.Parts.EUSize = pLen
  SELF.Parts.EOfs   = ofs
  SELF.Parts.EMeth  = meth
  ADD(SELF.Parts)


ExportClass.ZipFinish PROCEDURE
i     LONG,AUTO
cdOfs ULONG,AUTO
cdLen ULONG,AUTO
  CODE
  cdOfs = SELF.ArcLen
  LOOP i = 1 TO RECORDS(SELF.Parts)
    GET(SELF.Parts,i)
    SELF.ArcCat('PK<1,2>')
    SELF.ArcCat(SELF.Le16(20))                            ! version made by
    SELF.ArcCat(SELF.Le16(20))                            ! version needed
    SELF.ArcCat(SELF.Le16(0))                             ! flags
    SELF.ArcCat(SELF.Le16(SELF.Parts.EMeth))
    SELF.ArcCat(SELF.Le16(0))                             ! time  - kept 0 here, set in the local header
    SELF.ArcCat(SELF.Le16(0))                             ! date
    SELF.ArcCat(SELF.Le32(SELF.Parts.ECrc))
    SELF.ArcCat(SELF.Le32(SELF.Parts.ECSize))
    SELF.ArcCat(SELF.Le32(SELF.Parts.EUSize))
    SELF.ArcCat(SELF.Le16(LEN(SELF.Parts.EName)))
    SELF.ArcCat(SELF.Le16(0))                             ! extra
    SELF.ArcCat(SELF.Le16(0))                             ! comment
    SELF.ArcCat(SELF.Le16(0))                             ! disk number
    SELF.ArcCat(SELF.Le16(0))                             ! internal attributes
    SELF.ArcCat(SELF.Le32(0))                             ! external attributes
    SELF.ArcCat(SELF.Le32(SELF.Parts.EOfs))
    SELF.ArcCat(SELF.Parts.EName)
  END
  cdLen = SELF.ArcLen - cdOfs
  SELF.ArcCat('PK<5,6>')                                  ! end of central directory
  SELF.ArcCat(SELF.Le16(0))
  SELF.ArcCat(SELF.Le16(0))
  SELF.ArcCat(SELF.Le16(RECORDS(SELF.Parts)))
  SELF.ArcCat(SELF.Le16(RECORDS(SELF.Parts)))
  SELF.ArcCat(SELF.Le32(cdLen))
  SELF.ArcCat(SELF.Le32(cdOfs))
  SELF.ArcCat(SELF.Le16(0))                               ! archive comment length


! ############################################################################
!  .xlsx  -  a real OOXML workbook, assembled here
! ############################################################################
!  Everything StartFile() used to do for Exp:XLSX directly, factored out so
!  StartSheet() can call it too, once per sheet, in a multi-sheet workbook -
!  resets the running totals/grouping state and writes the worksheet preamble
!  (<worksheet>, the frozen heading pane, <cols>, <sheetData>, the heading row
!  itself) into SELF.Buf. A single-sheet export ends up calling this exactly
!  once, the same as it always has.
ExportClass.XlsxSheetBegin PROCEDURE()
i     LONG,AUTO
n     LONG,AUTO
out   LONG,AUTO
w     LONG,AUTO
dec   LONG,AUTO
fmtIdx LONG,AUTO
  CODE
  n = SELF.Columns()
  IF SELF.Totals OR SELF.TotalsAvg OR SELF.TotalsMin OR SELF.TotalsMax OR SELF.TotalsCnt   ! zero the per-column running stats
    LOOP i = 1 TO 64                                     ! DIM(64), same cap as the USED columns
      SELF.ColSum[i]   = 0
      SELF.ColMin[i]   = 0
      SELF.ColMax[i]   = 0
      SELF.ColCount[i] = 0
    END
  END
!   ---- subtotal / group rows: find which USED column (if any) breaks on ----
  SELF.GroupCol      = 0
  SELF.GroupPrev     = ''
  SELF.GroupFirstRow = 0
  SELF.GroupHasRow   = 0
  LOOP i = 1 TO 64
    SELF.GrpSum[i] = 0 ; SELF.GrpMin[i] = 0 ; SELF.GrpMax[i] = 0 ; SELF.GrpCount[i] = 0
  END
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    IF SELF.Cols.GroupBy THEN SELF.GroupCol = out .
!   ---- decimal-preserving / parenthesised-negative number format, if this
!   ---- column actually needs one - everything else keeps today's default
    IF out <= 64
      SELF.ColStyleN[out] = 0                             ! today's default: no style attribute at all
      SELF.ColStyleT[out] = 2                              ! today's default: the bold/bordered total style
      IF SELF.Cols.IsNum
        dec = SELF.PicDecimals(SELF.Cols.Pic)
        IF dec > 0 OR SELF.NegativeParens
          fmtIdx = SELF.XlsxRegisterNumFmt(dec)
          GET(SELF.NumFmts,fmtIdx)
          SELF.ColStyleN[out] = SELF.NumFmts.StyleN
          SELF.ColStyleT[out] = SELF.NumFmts.StyleT
        END
      END
    END
  END
  SELF.XlsxRow = CHOOSE(SELF.Headers <> 0,2,1)              ! next row to write - right after the heading, if any
  SELF.Cat('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & Exp:CRLF)
  SELF.Cat('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
  IF SELF.Headers                                       ! keep the heading row on screen
    SELF.Cat('<sheetViews><sheetView workbookViewId="0">' & |
             '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>' & |
             '</sheetView></sheetViews>')
  END
  SELF.Cat('<sheetFormatPr defaultRowHeight="15"/>')
  SELF.Cat('<cols>')                                    ! carry the on-screen widths across
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    w = SELF.Cols.Width / 4 + 2
    IF w < 6  THEN w = 6  .
    IF w > 70 THEN w = 70 .
    SELF.Cat('<col min="' & out & '" max="' & out & '" width="' & w & '" customWidth="1"/>')
  END
  SELF.Cat('</cols><sheetData>')
  IF SELF.Headers
    SELF.Cat('<row r="1">')
    out = 0
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      out += 1
      SELF.Cat('<c r="' & SELF.ColRef(out) & '1" s="1" t="inlineStr"><is><t>')
      SELF.CatXmlText(SELF.HeaderText(i))
      SELF.Cat('</t></is></c>')
    END
    SELF.Cat('</row>')
  END


!  Everything EndFile() used to do for Exp:XLSX directly, factored out so
!  EndSheet() can call it too: the final group's subtotal, the grand total
!  row(s), and closing </sheetData>/<autoFilter/>/</worksheet>. Leaves the
!  finished sheet sitting in SELF.Buf - XlsxStashSheet() moves it from there.
ExportClass.XlsxSheetEnd PROCEDURE()
last  LONG,AUTO
  CODE
  IF SELF.GroupCol AND SELF.GroupHasRow                   ! the last group never saw a "next row" to trigger its break
    SELF.XlsxSubtotalRow(SELF.GroupPrev,SELF.GroupFirstRow,SELF.XlsxRow - 1)
    IF SELF.SplitByGroup                                  ! and its own separate sheet needs closing too
      SELF.GrpSheetEnd(SELF.GrpFirstRow,SELF.GrpXlsxRow - 1)
      SELF.GrpStashSheet(SELF.GroupPrev)
    END
  END
  IF SELF.Headers AND SELF.RowsOut                         ! the true last row BEFORE any grand-total rows are added
    last = SELF.XlsxRow - 1
  END
  IF (SELF.Totals OR SELF.TotalsAvg OR SELF.TotalsMin OR SELF.TotalsMax OR SELF.TotalsCnt) AND SELF.RowsOut AND SELF.TotalsCount()
    SELF.XlsxTotalsRow()                                  ! must land INSIDE <sheetData> - before it closes
  END
  SELF.Cat('</sheetData>')
  IF SELF.Headers AND SELF.RowsOut                         ! <autoFilter> must be a sibling AFTER </sheetData>, per the OOXML schema's fixed child order
    SELF.Cat('<autoFilter ref="A1:' & SELF.ColRef(SELF.Selected()) & last & '"/>')
  END
  SELF.Cat('</worksheet>')


!  Writes one bold row summarising the group that just finished - one cell per
!  USED column, in the SAME row: every Tot-ticked numeric column gets a
!  SUBTOTAL() formula (whichever of Sum/Avg/Min/Max/Count is enabled, all in
!  the same row since a group only gets one line) over just that group's own
!  row range; the LEFTMOST column always gets "<label> <group value>" (e.g.
!  "Total East") regardless of which column is actually the group-by column;
!  and every other column gets an empty but STYLED cell, so the row's top
!  border draws as one continuous line across the whole width rather than
!  breaking wherever a column has nothing to show.
!  SUBTOTAL(), not a plain SUM()/COUNT()/etc, even though a single group's own
!  range never contains another subtotal and so would compute an identical
!  value either way - the grand total's own SUBTOTAL() call, spanning every
!  group's row here, only skips a cell it recognises as ANOTHER SUBTOTAL()
!  formula. Excel's nested-exclusion triggers off the cell's OWN formula,
!  never off what that formula computes, so a plain function here would
!  silently let the grand total double-count every group.
!  Consumes and advances SELF.XlsxRow itself, the same way a data row does.
ExportClass.XlsxSubtotalRow PROCEDURE(STRING pGroupLabel,LONG pFrow,LONG pLrow)
i      LONG,AUTO
n      LONG,AUTO
out    LONG,AUTO
trow   LONG,AUTO
kind   LONG,AUTO
enabled BYTE,AUTO
subN   CSTRING(3)                                            ! SUBTOTAL()'s function_num for this row's kind
val    DECIMAL(20,6),AUTO
  CODE
  IF pLrow < pFrow THEN RETURN .                            ! an empty group (shouldn't happen, but stay safe)
  n = SELF.Columns()
  IF ~n THEN RETURN .
  trow = SELF.XlsxRow

  SELF.Cat('<row r="' & trow & '">')
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ERRORCODE() THEN CYCLE .
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    IF out > 64 THEN BREAK .
    IF out = 1                                              ! always the leftmost column, not the group column itself
      SELF.Cat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '" t="inlineStr"><is><t>')
      SELF.CatXmlText(CLIP(SELF.TotalsLabel) & ' ' & CLIP(pGroupLabel))
      SELF.Cat('</t></is></c>')
    ELSIF SELF.Cols.IsNum AND SELF.Cols.Total AND SELF.GrpCount[out] > 0
!     one cell, one line, but it may need to show more than one kind's value -
!     Excel cells only hold one formula, so where more than one of Sum/Avg/
!     Min/Max/Count is enabled, the cell shows the FIRST enabled kind's
!     formula (Sum takes priority, then Average, then Min, then Max, then
!     Count).
      LOOP kind = 1 TO 5
        CASE kind
        OF 1 ; enabled = SELF.Totals    ; subN = '9' ; val = SELF.GrpSum[out]
        OF 2 ; enabled = SELF.TotalsAvg ; subN = '1' ; val = SELF.GrpSum[out] / SELF.GrpCount[out]
        OF 3 ; enabled = SELF.TotalsMin ; subN = '5' ; val = SELF.GrpMin[out]
        OF 4 ; enabled = SELF.TotalsMax ; subN = '4' ; val = SELF.GrpMax[out]
        OF 5 ; enabled = SELF.TotalsCnt ; subN = '2' ; val = SELF.GrpCount[out]
        END
        IF enabled THEN BREAK .
      END
      IF enabled
!       SUBTOTAL(), not a plain function - a single group's own range never
!       contains ANOTHER subtotal, so this computes the identical value a
!       plain SUM()/COUNT()/etc would - but it ALSO makes this cell
!       recognisable to the GRAND total's own SUBTOTAL() call later, which
!       spans every group's row here and needs to skip it to avoid double-
!       counting. A plain function here would defeat that entirely: Excel's
!       nested-exclusion only ever triggers off another cell ALSO being a
!       SUBTOTAL() formula, never off what that formula happens to compute.
        SELF.Cat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '"><f>SUBTOTAL(' & CLIP(subN) & ',' & |
                 SELF.ColRef(out) & pFrow & ':' & SELF.ColRef(out) & pLrow & ')</f><v>' & |
                 CLIP(LEFT(val)) & '</v></c>')
      ELSE
        SELF.Cat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '"/>')     ! nothing to show here, but still bordered
      END
    ELSE
      SELF.Cat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '"/>')       ! blank, styled - keeps the line unbroken
    END
  END
  SELF.Cat('</row>')
  SELF.XlsxRow += 1


!  Appends up to five bold rows under the data, one row per enabled summary
!  kind (Sum, Average, Minimum, Maximum, Count, always in that order), one
!  cell per USED column in each row:
!    - a numeric column ticked for totals gets a real formula for that row's
!      kind - =SUM(), =AVERAGE(), =MIN(), =MAX(), or =COUNT() over the data
!      range, or the equivalent =SUBTOTAL(n,...) form when subtotal/group
!      rows are also in use, since SUBTOTAL() ignores any other SUBTOTAL()
!      results already inside its own range - the grand total this way still
!      comes out correct instead of double-counting every group's own
!      subtotal - with the value AddRow() already accumulated as the cached
!      <v> (so a reader that never recalculates still shows a number)
!    - the first column NOT part of that row's calculation gets that row's
!      label (SELF.TotalsLabel / AvgLabel / MinLabel / MaxLabel / CntLabel)
!    - every other column is left blank
!  Called from EndFile(), between </sheetData> and </worksheet>, only when at
!  least one of the five is turned on and at least one USED numeric column is
!  ticked.
ExportClass.XlsxTotalsRow PROCEDURE()
i      LONG,AUTO
n      LONG,AUTO
out    LONG,AUTO
frow   LONG,AUTO                                            ! first data row (after the heading, if any)
lrow   LONG,AUTO                                            ! last data row actually written (incl. subtotal rows)
trow   LONG,AUTO                                            ! the row currently being written
wrote  BYTE,AUTO                                             ! this row's label has been placed
kind   LONG,AUTO                                             ! 1=Sum 2=Average 3=Minimum 4=Maximum 5=Count
enabled BYTE,AUTO
fn     CSTRING(11)                                           ! the Excel function name for this row
subN   CSTRING(3)                                            ! SUBTOTAL()'s function_num for this row's kind
lbl    CSTRING(41)                                           ! this row's label
val    DECIMAL(20,6),AUTO
  CODE
  n = SELF.Columns()
  IF ~n THEN RETURN .
  frow = CHOOSE(SELF.Headers <> 0,2,1)
  lrow = SELF.XlsxRow - 1                                    ! whatever was actually last written - data or a subtotal row
  trow = lrow

  LOOP kind = 1 TO 5
    CASE kind
    OF 1 ; enabled = SELF.Totals    ; fn = 'SUM'     ; subN = '9' ; lbl = SELF.TotalsLabel
    OF 2 ; enabled = SELF.TotalsAvg ; fn = 'AVERAGE' ; subN = '1' ; lbl = SELF.AvgLabel
    OF 3 ; enabled = SELF.TotalsMin ; fn = 'MIN'     ; subN = '5' ; lbl = SELF.MinLabel
    OF 4 ; enabled = SELF.TotalsMax ; fn = 'MAX'     ; subN = '4' ; lbl = SELF.MaxLabel
    OF 5 ; enabled = SELF.TotalsCnt ; fn = 'COUNT'   ; subN = '2' ; lbl = SELF.CntLabel
    END
    IF ~enabled THEN CYCLE .

    trow += 1
    wrote = 0
    out = 0
    SELF.Cat('<row r="' & trow & '">')
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ERRORCODE() THEN CYCLE .
      IF ~SELF.Cols.Use THEN CYCLE .
      out += 1
      IF out > 64 THEN BREAK .                              ! ColSum's cap - matches the USED-column cap elsewhere
      IF SELF.Cols.IsNum AND SELF.Cols.Total AND SELF.ColCount[out] > 0
        CASE kind
        OF 1 ; val = SELF.ColSum[out]
        OF 2 ; val = SELF.ColSum[out] / SELF.ColCount[out]
        OF 3 ; val = SELF.ColMin[out]
        OF 4 ; val = SELF.ColMax[out]
        OF 5 ; val = SELF.ColCount[out]
        END
        IF SELF.GroupCol                                    ! subtotal rows are mixed into this range - use SUBTOTAL()
          SELF.Cat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '"><f>SUBTOTAL(' & CLIP(subN) & ',' & |
                   SELF.ColRef(out) & frow & ':' & SELF.ColRef(out) & lrow & ')</f><v>' & |
                   CLIP(LEFT(val)) & '</v></c>')
        ELSE
          SELF.Cat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '"><f>' & CLIP(fn) & '(' & |
                   SELF.ColRef(out) & frow & ':' & SELF.ColRef(out) & lrow & ')</f><v>' & |
                   CLIP(LEFT(val)) & '</v></c>')
        END
      ELSIF ~wrote AND CLIP(lbl)
        wrote = 1
        SELF.Cat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '" t="inlineStr"><is><t>')
        SELF.CatXmlText(CLIP(lbl))
        SELF.Cat('</t></is></c>')
      END
    END
    SELF.Cat('</row>')
  END


!  Escapes a short value (a sheet name, for instance) for use INSIDE an XML
!  attribute - the same five characters CatXmlText handles for element text,
!  just returned as a STRING instead of appended to SELF.Buf, since this is
!  needed while a small fixed part like workbook.xml is still being built up
!  in a local CSTRING rather than streamed straight into the buffer.
ExportClass.XmlAttr PROCEDURE(STRING pText)
o   CSTRING(200)
l   LONG,AUTO
i   LONG,AUTO
v   LONG,AUTO
  CODE
  l = LEN(pText)
  o = ''
  LOOP i = 1 TO l
    v = VAL(pText[i])
    CASE v
    OF 38 ; o = CLIP(o) & '&amp;'
    OF 60 ; o = CLIP(o) & '&lt;'
    OF 62 ; o = CLIP(o) & '&gt;'
    OF 34 ; o = CLIP(o) & '&quot;'
    OF 39 ; o = CLIP(o) & '&apos;'
    ELSE
      IF v < 32 AND v <> 9 THEN CYCLE .                   ! illegal in XML 1.0
      o = CLIP(o) & pText[i]
    END
  END
  RETURN CLIP(o)


!  Moves the sheet StartSheet()/StartFile() just built in SELF.Buf into
!  SELF.Sheets, UTF-8 already applied, and frees SELF.Buf so the next sheet
!  (or nothing, for a single-sheet export) starts clean. Also de-duplicates
!  the tab name against every sheet already stashed - Excel refuses a
!  workbook with two identically-named tabs - by appending " (2)", " (3)"
!  and so on, same idea as Windows renaming a second copy of a file.
ExportClass.XlsxStashSheet PROCEDURE(STRING pName)
nm    CSTRING(65)
base  CSTRING(65)
n     LONG,AUTO
i     LONG,AUTO
dup   BYTE,AUTO
  CODE
  IF SELF.Sheets &= NULL THEN SELF.Sheets &= NEW ExportSheetQueue .
  base = SELF.SheetName(pName)
  nm   = base
  n    = 1
  LOOP                                                     ! keep trying until nm doesn't collide
    dup = 0
    LOOP i = 1 TO RECORDS(SELF.Sheets)
      GET(SELF.Sheets,i)
      IF ERRORCODE() THEN CYCLE .
      IF UPPER(CLIP(SELF.Sheets.SName)) = UPPER(CLIP(nm))
        dup = 1
        BREAK
      END
    END
    IF ~dup THEN BREAK .
    n += 1
    nm = SUB(base,1,31 - LEN(CLIP(' (' & n & ')'))) & ' (' & n & ')'
  END

  SELF.ToUTF8(SELF.Buf,SELF.BufLen)                        ! this sheet's XML -> UTF-8
  SELF.Sheets.SName = nm
  SELF.Sheets.SData &= NEW STRING(CHOOSE(SELF.U8Len > 0,SELF.U8Len,1))
  IF SELF.U8Len THEN SELF.Sheets.SData[1 : SELF.U8Len] = SELF.U8[1 : SELF.U8Len] .
  SELF.Sheets.SLen = SELF.U8Len
  ADD(SELF.Sheets)

  IF ~SELF.Buf &= NULL THEN DISPOSE(SELF.Buf) .            ! ready for the next sheet
  SELF.BufLen = 0 ; SELF.BufCap = 0
  IF ~SELF.U8 &= NULL THEN DISPOSE(SELF.U8) .
  SELF.U8Len = 0 ; SELF.U8Cap = 0


! ############################################################################
!  SplitByGroup - one EXTRA sheet per distinct group value, alongside the
!  main sheet, built as the SAME AddRow() walk goes past (no second pass over
!  the data, no separate StartSheet()/EndSheet() calls from the caller - the
!  group-break detection AddRow() already does for the inline subtotal rows
!  triggers this too). Everything here works on GrpBuf/GrpXlsxRow, entirely
!  separate from SELF.Buf/SELF.XlsxRow, so none of it can affect the main
!  sheet even if something here were wrong.
! ############################################################################

!  The worksheet preamble for the group whose first row AddRow() just saw -
!  same shape as XlsxSheetBegin(), into GrpBuf instead of SELF.Buf. Does NOT
!  touch SELF.GroupCol/ColSum/etc - those are the MAIN sheet's own state,
!  already set up by XlsxSheetBegin() once at the start of the whole export.
ExportClass.GrpSheetBegin PROCEDURE()
i     LONG,AUTO
n     LONG,AUTO
out   LONG,AUTO
w     LONG,AUTO
  CODE
  n = SELF.Columns()
  SELF.GrpXlsxRow = CHOOSE(SELF.Headers <> 0,2,1)
  SELF.GrpFirstRow = SELF.GrpXlsxRow                        ! THIS sheet's own first data row - never the main sheet's coordinate
  SELF.GrpCat('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & Exp:CRLF)
  SELF.GrpCat('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
  IF SELF.Headers
    SELF.GrpCat('<sheetViews><sheetView workbookViewId="0">' & |
                '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>' & |
                '</sheetView></sheetViews>')
  END
  SELF.GrpCat('<sheetFormatPr defaultRowHeight="15"/>')
  SELF.GrpCat('<cols>')
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    w = SELF.Cols.Width / 4 + 2
    IF w < 6  THEN w = 6  .
    IF w > 70 THEN w = 70 .
    SELF.GrpCat('<col min="' & out & '" max="' & out & '" width="' & w & '" customWidth="1"/>')
  END
  SELF.GrpCat('</cols><sheetData>')
  IF SELF.Headers
    SELF.GrpCat('<row r="1">')
    out = 0
    LOOP i = 1 TO n
      GET(SELF.Cols,i)
      IF ~SELF.Cols.Use THEN CYCLE .
      out += 1
      SELF.GrpCat('<c r="' & SELF.ColRef(out) & '1" s="1" t="inlineStr"><is><t>')
      SELF.GrpCatXmlText(SELF.HeaderText(i))
      SELF.GrpCat('</t></is></c>')
    END
    SELF.GrpCat('</row>')
  END


!  This group's own Sum/Avg/Min/Max row(s) (whichever are enabled - the SAME
!  four checkboxes the main sheet and its inline subtotal rows already use),
!  then closes the sheet. A plain SUM()/AVERAGE()/MIN()/MAX() is correct
!  here, not SUBTOTAL() - this sheet holds exactly one group's own rows, so
!  there is no other subtotal anywhere inside its own range to double-count.
ExportClass.GrpSheetEnd PROCEDURE(LONG pFrow,LONG pLrow)
i      LONG,AUTO
n      LONG,AUTO
out    LONG,AUTO
trow   LONG,AUTO
kind   LONG,AUTO
enabled BYTE,AUTO
fn     CSTRING(11)
lbl    CSTRING(41)
val    DECIMAL(20,6),AUTO
wrote  BYTE,AUTO
  CODE
  n = SELF.Columns()
  IF n AND (SELF.Totals OR SELF.TotalsAvg OR SELF.TotalsMin OR SELF.TotalsMax OR SELF.TotalsCnt) AND pLrow >= pFrow
    trow = SELF.GrpXlsxRow
    LOOP kind = 1 TO 5
      CASE kind
      OF 1 ; enabled = SELF.Totals    ; fn = 'SUM'     ; lbl = SELF.TotalsLabel
      OF 2 ; enabled = SELF.TotalsAvg ; fn = 'AVERAGE' ; lbl = SELF.AvgLabel
      OF 3 ; enabled = SELF.TotalsMin ; fn = 'MIN'     ; lbl = SELF.MinLabel
      OF 4 ; enabled = SELF.TotalsMax ; fn = 'MAX'     ; lbl = SELF.MaxLabel
      OF 5 ; enabled = SELF.TotalsCnt ; fn = 'COUNT'   ; lbl = SELF.CntLabel
      END
      IF ~enabled THEN CYCLE .
      trow += 1
      wrote = 0
      out = 0
      SELF.GrpCat('<row r="' & trow & '">')
      LOOP i = 1 TO n
        GET(SELF.Cols,i)
        IF ERRORCODE() THEN CYCLE .
        IF ~SELF.Cols.Use THEN CYCLE .
        out += 1
        IF out > 64 THEN BREAK .
        IF SELF.Cols.IsNum AND SELF.Cols.Total AND SELF.GrpCount[out] > 0
          CASE kind
          OF 1 ; val = SELF.GrpSum[out]
          OF 2 ; val = SELF.GrpSum[out] / SELF.GrpCount[out]
          OF 3 ; val = SELF.GrpMin[out]
          OF 4 ; val = SELF.GrpMax[out]
          OF 5 ; val = SELF.GrpCount[out]
          END
          SELF.GrpCat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '"><f>' & CLIP(fn) & '(' & |
                      SELF.ColRef(out) & pFrow & ':' & SELF.ColRef(out) & pLrow & ')</f><v>' & |
                      CLIP(LEFT(val)) & '</v></c>')
        ELSIF ~wrote AND CLIP(lbl)
          wrote = 1
          SELF.GrpCat('<c r="' & SELF.ColRef(out) & trow & '" s="' & SELF.ColStyleT[out] & '" t="inlineStr"><is><t>')
          SELF.GrpCatXmlText(CLIP(lbl))
          SELF.GrpCat('</t></is></c>')
        END
      END
      SELF.GrpCat('</row>')
    END
    SELF.GrpXlsxRow = trow + 1
  END
  SELF.GrpCat('</sheetData>')
  IF SELF.Headers AND pLrow >= pFrow
    SELF.GrpCat('<autoFilter ref="A1:' & SELF.ColRef(SELF.Selected()) & (pLrow) & '"/>')
  END
  SELF.GrpCat('</worksheet>')


!  Moves GrpBuf into SELF.Sheets, named after the group's own value (through
!  the same SheetName()/dedup logic XlsxStashSheet() uses, so a group sheet
!  can never collide with the main sheet's tab name either). Frees GrpBuf
!  afterwards so the next group starts clean.
ExportClass.GrpStashSheet PROCEDURE(STRING pGroupValue)
nm    CSTRING(65)
base  CSTRING(65)
n     LONG,AUTO
i     LONG,AUTO
dup   BYTE,AUTO
  CODE
  IF SELF.Sheets &= NULL THEN SELF.Sheets &= NEW ExportSheetQueue .
  base = SELF.SheetName(pGroupValue)
  nm   = base
  n    = 1
  LOOP
    dup = 0
    LOOP i = 1 TO RECORDS(SELF.Sheets)
      GET(SELF.Sheets,i)
      IF ERRORCODE() THEN CYCLE .
      IF UPPER(CLIP(SELF.Sheets.SName)) = UPPER(CLIP(nm))
        dup = 1
        BREAK
      END
    END
    IF ~dup THEN BREAK .
    n += 1
    nm = SUB(base,1,31 - LEN(CLIP(' (' & n & ')'))) & ' (' & n & ')'
  END

  SELF.ToUTF8(SELF.GrpBuf,SELF.GrpBufLen)
  SELF.Sheets.SName = nm
  SELF.Sheets.SData &= NEW STRING(CHOOSE(SELF.U8Len > 0,SELF.U8Len,1))
  IF SELF.U8Len THEN SELF.Sheets.SData[1 : SELF.U8Len] = SELF.U8[1 : SELF.U8Len] .
  SELF.Sheets.SLen = SELF.U8Len
  ADD(SELF.Sheets)

  IF ~SELF.GrpBuf &= NULL THEN DISPOSE(SELF.GrpBuf) .
  SELF.GrpBufLen = 0 ; SELF.GrpBufCap = 0
  IF ~SELF.U8 &= NULL THEN DISPOSE(SELF.U8) .
  SELF.U8Len = 0 ; SELF.U8Cap = 0


!  SplitByGroup stashes each group's sheet as its own break happens, which
!  always finishes BEFORE the main sheet gets its own turn at EndFile() - so
!  by the time the main sheet is stashed, it lands at the END of SELF.Sheets,
!  not the front. This shifts every OTHER entry down one slot and puts the
!  just-stashed last entry (the main sheet) back at position 1, so it stays
!  the workbook's first, default tab - "keep the main sheet as is" means its
!  position too, not just its content.
ExportClass.XlsxMoveLastToFirst PROCEDURE()
n        LONG,AUTO
i        LONG,AUTO
mainName CSTRING(65)
mainData &STRING
mainLen  LONG,AUTO
tmpName  CSTRING(65)
tmpData  &STRING
tmpLen   LONG,AUTO
  CODE
  n = RECORDS(SELF.Sheets)
  IF n <= 1 THEN RETURN .

  GET(SELF.Sheets,n)                                      ! the main sheet - just stashed, currently last
  mainName = SELF.Sheets.SName
  mainData &= SELF.Sheets.SData
  mainLen  = SELF.Sheets.SLen

  LOOP i = n TO 2 BY -1                                   ! shift every other entry down one position
    GET(SELF.Sheets,i-1)
    tmpName = SELF.Sheets.SName
    tmpData &= SELF.Sheets.SData
    tmpLen  = SELF.Sheets.SLen
    GET(SELF.Sheets,i)
    SELF.Sheets.SName = tmpName
    SELF.Sheets.SData &= tmpData
    SELF.Sheets.SLen  = tmpLen
    PUT(SELF.Sheets)
  END

  GET(SELF.Sheets,1)
  SELF.Sheets.SName = mainName
  SELF.Sheets.SData &= mainData
  SELF.Sheets.SLen  = mainLen
  PUT(SELF.Sheets)


!  How many decimal places a Clarion @N picture shows. The digits right
!  after the picture's own '.' (however that picture spells its sign/width -
!  @n-15.2, @n_9.2, @n6.2 all read the same here) are a NUMBER, not a count
!  of characters - "@n6.2" means 2 decimal places, from parsing "2" as the
!  value two, not from there being one digit character in the token. That
!  distinction only stops mattering by coincidence for single-digit decimal
!  counts (1-9) and matters for real once anything shows 10+ decimal places.
!  Blank or a picture with no '.' at all means 0 - an integer column, which
!  needs no custom format since Excel's own General already shows it
!  correctly.
ExportClass.PicDecimals PROCEDURE(STRING pPic)
p    CSTRING(33)
i    LONG,AUTO
dot  LONG,AUTO
endp LONG,AUTO
n    LONG,AUTO
  CODE
  p = CLIP(pPic)
  IF ~p THEN RETURN 0 .
  dot = INSTRING('.',p,1,1)
  IF ~dot THEN RETURN 0 .
  endp = dot
  LOOP i = dot+1 TO LEN(p)
    IF p[i] >= '0' AND p[i] <= '9'
      endp = i
    ELSE
      BREAK
    END
  END
  IF endp = dot THEN RETURN 0 .                             ! nothing but non-digits after the '.'
  n = SUB(p,dot+1,endp-dot)                                 ! the digit run's VALUE, not its length
  RETURN n


!  '0', '0.00', '0.000' ... for pDecimals = 0, 2, 3 ... - the bare Excel
!  format code, before SELF.NegativeParens' extra ';(...)' section (added by
!  the caller, since that section is the SAME code repeated in parentheses).
ExportClass.XlsxNumFmtCode PROCEDURE(LONG pDecimals)
s   CSTRING(21)
i   LONG,AUTO
  CODE
  s = '0'
  IF pDecimals > 0
    s = CLIP(s) & '.'
    LOOP i = 1 TO pDecimals
      s = CLIP(s) & '0'
    END
  END
  RETURN CLIP(s)


!  Finds the SELF.NumFmts row already covering (pDecimals, SELF.NegativeParens
!  as it stands right now), or creates one - a fresh numFmtId in Excel's
!  custom range (164+), and a pair of cellXfs indices (StyleN for an ordinary
!  cell, StyleT for a bold/bordered total cell) that XlsxWrite() will turn
!  into real <numFmt>/<xf> entries once, for the whole workbook, however many
!  sheets shared it. Returns the row's OWN position, used as a lookup handle.
ExportClass.XlsxRegisterNumFmt PROCEDURE(LONG pDecimals)
i  LONG,AUTO
n  LONG,AUTO
  CODE
  IF SELF.NumFmts &= NULL THEN SELF.NumFmts &= NEW ExportNumFmtQueue .
  LOOP i = 1 TO RECORDS(SELF.NumFmts)
    GET(SELF.NumFmts,i)
    IF ERRORCODE() THEN CYCLE .
    IF SELF.NumFmts.Decimals = pDecimals AND SELF.NumFmts.Parens = SELF.NegativeParens
      RETURN i
    END
  END
  n = RECORDS(SELF.NumFmts)
  SELF.NumFmts.Decimals = pDecimals
  SELF.NumFmts.Parens   = SELF.NegativeParens
  SELF.NumFmts.NumFmtId = 164 + n
  SELF.NumFmts.StyleN   = 3 + n * 2                       ! styles 0,1,2 already exist - these start right after
  SELF.NumFmts.StyleT   = 4 + n * 2
  ADD(SELF.NumFmts)
  RETURN n + 1


!  The worksheet is already sitting in SELF.Buf (StartFile/AddRow/EndFile built
!  it).  The five remaining parts are small and fixed, so they are put together
!  here and everything is zipped in one pass.
!  tmp builds each part, then it is copied into the fixed STRING the ZipAdd /
!  ToUTF8 *STRING parameters need (a CSTRING will not bind to *STRING).
!  Zips whatever is waiting in SELF.Sheets - one entry for a plain single-
!  sheet export, or however many StartSheet()/EndSheet() built for a
!  workbook. tmp is sized generously (content-types and workbook.xml both
!  grow with the sheet count) but StartSheet() already refuses a 101st sheet,
!  so this never has more than 100 short, similar lines to hold.
ExportClass.XlsxWrite PROCEDURE()
tmp   CSTRING(32768)
part  STRING(32768)
plen  LONG,AUTO
i     LONG,AUTO
n     LONG,AUTO
nf    LONG,AUTO
code  CSTRING(21)
fmtStr CSTRING(45)
numFmtsXml CSTRING(8192)
extraXfs   CSTRING(16384)
xfCount    LONG,AUTO
  CODE
  IF SELF.Parts &= NULL THEN RETURN 0 .
  FREE(SELF.Parts)
  SELF.ArcLen = 0
  n = RECORDS(SELF.Sheets)
  IF ~n THEN RETURN 0 .                                   ! nothing was ever stashed - StartSheet()/EndSheet() never ran

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">' & |
         '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>' & |
         '<Default Extension="xml" ContentType="application/xml"/>' & |
         '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>' & |
         '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
  LOOP i = 1 TO n
    tmp = CLIP(tmp) & '<Override PartName="/xl/worksheets/sheet' & i & |
          '.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
  END
  tmp = CLIP(tmp) & '</Types>'
  plen = LEN(CLIP(tmp))
  part = tmp
  SELF.ZipAdd('[Content_Types].xml',part,plen)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">' & |
         '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>' & |
         '</Relationships>'
  plen = LEN(tmp)
  part = tmp
  SELF.ZipAdd('_rels/.rels',part,plen)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"' & |
         ' xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">' & |
         '<sheets>'
  LOOP i = 1 TO n
    GET(SELF.Sheets,i)
    tmp = CLIP(tmp) & '<sheet name="' & SELF.XmlAttr(CLIP(SELF.Sheets.SName)) & '" sheetId="' & i & '" r:id="rId' & i & '"/>'
  END
  tmp = CLIP(tmp) & '</sheets></workbook>'
  plen = LEN(CLIP(tmp))
  part = tmp
  SELF.ToUTF8(part,plen)                                  ! a sheet name may not be ASCII
  SELF.ZipAdd('xl/workbook.xml',SELF.U8,SELF.U8Len)

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
  LOOP i = 1 TO n
    tmp = CLIP(tmp) & '<Relationship Id="rId' & i & |
          '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet' & i & '.xml"/>'
  END
  tmp = CLIP(tmp) & '<Relationship Id="rId' & (n+1) & |
        '" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>' & |
        '</Relationships>'
  plen = LEN(CLIP(tmp))
  part = tmp
  SELF.ZipAdd('xl/_rels/workbook.xml.rels',part,plen)

  numFmtsXml = ''
  extraXfs   = ''
  IF ~SELF.NumFmts &= NULL
    LOOP nf = 1 TO RECORDS(SELF.NumFmts)
      GET(SELF.NumFmts,nf)
      IF ERRORCODE() THEN CYCLE .
      code = SELF.XlsxNumFmtCode(SELF.NumFmts.Decimals)
      fmtStr = code
      IF SELF.NumFmts.Parens THEN fmtStr = CLIP(fmtStr) & ';(' & CLIP(code) & ')' .
      numFmtsXml = CLIP(numFmtsXml) & '<numFmt numFmtId="' & SELF.NumFmts.NumFmtId & '" formatCode="' & SELF.XmlAttr(fmtStr) & '"/>'
      extraXfs = CLIP(extraXfs) & '<xf numFmtId="' & SELF.NumFmts.NumFmtId & '" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>'
      extraXfs = CLIP(extraXfs) & '<xf numFmtId="' & SELF.NumFmts.NumFmtId & '" fontId="1" fillId="0" borderId="1" xfId="0" applyNumberFormat="1" applyFont="1" applyBorder="1"/>'
    END
  END
  xfCount = 3 + RECORDS(SELF.NumFmts) * 2

  tmp = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>' & |
         '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
  IF RECORDS(SELF.NumFmts) > 0
    tmp = CLIP(tmp) & '<numFmts count="' & RECORDS(SELF.NumFmts) & '">' & CLIP(numFmtsXml) & '</numFmts>'
  END
  tmp = CLIP(tmp) & |
         '<fonts count="2">' & |
         '<font><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font>' & |
         '<font><b/><sz val="11"/><color theme="1"/><name val="Calibri"/><family val="2"/></font>' & |
         '</fonts>' & |
         '<fills count="2"><fill><patternFill patternType="none"/></fill>' & |
         '<fill><patternFill patternType="gray125"/></fill></fills>' & |
         '<borders count="2">' & |
         '<border><left/><right/><top/><bottom/><diagonal/></border>' & |
         '<border><left/><right/><top style="thin"><color indexed="64"/></top><bottom/><diagonal/></border>' & |
         '</borders>' & |
         '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>' & |
         '<cellXfs count="' & xfCount & '">' & |
         '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>' & |
         '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/>' & |
         '<xf numFmtId="0" fontId="1" fillId="0" borderId="1" xfId="0" applyFont="1" applyBorder="1"/>' & |
         CLIP(extraXfs) & |
         '</cellXfs>' & |
         '<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>' & |
         '</styleSheet>'
  plen = LEN(CLIP(tmp))
  part = tmp
  SELF.ZipAdd('xl/styles.xml',part,plen)

  LOOP i = 1 TO n                                          ! each sheet, last and largest, in order
    GET(SELF.Sheets,i)
    SELF.ZipAdd('xl/worksheets/sheet' & i & '.xml',SELF.Sheets.SData,SELF.Sheets.SLen)
  END

  LOOP i = 1 TO n                                          ! done with every stashed sheet now
    GET(SELF.Sheets,i)
    IF ~SELF.Sheets.SData &= NULL THEN DISPOSE(SELF.Sheets.SData) .
  END
  FREE(SELF.Sheets)

  SELF.ZipFinish()
  RETURN SELF.WriteDisk(SELF.FileName,SELF.Arc,SELF.ArcLen)


! ############################################################################
!  Print  -  plain GDI: CreateDC on SELF.PrinterName or the Windows default
!  printer, then StartDoc/StartPage/TextOut/EndPage/EndDoc. No REPORT
!  structure and no Win32 struct of any kind (deliberately - a hand-laid-out
!  PRINTDLGA was tried here first and crashed; CreateDCA takes plain strings
!  instead, so there is nothing left whose binary layout has to be guessed).
!  The column widths come from the LIST's own on-screen widths, exactly the
!  way the .xlsx column widths do.
! ############################################################################

!  Cols.Width (dialog units) -> PrnColX/PrnColW (device pixels), proportional,
!  filling the printable width. Same idea as the .xlsx <col> widths.
ExportClass.PrnColumnWidths PROCEDURE()
i    LONG,AUTO
n    LONG,AUTO
tot  LONG,AUTO
x    LONG,AUTO
w    LONG,AUTO
out  LONG,AUTO
  CODE
  n = SELF.Columns()
  tot = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    w = SELF.Cols.Width
    IF w < 20 THEN w = 20 .                               ! a hidden column still gets a fair share
    tot += w
  END
  IF ~tot THEN tot = 1 .
  x = SELF.PrnMarginL
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    IF out > 64 THEN BREAK .                              ! PrnColX/W DIM(64) ceiling
    w = SELF.Cols.Width
    IF w < 20 THEN w = 20 .
    SELF.PrnColX[out] = x
    SELF.PrnColW[out] = SELF.PrnPageW * w / tot
    x += SELF.PrnColW[out]
  END
  SELF.PrnColN = out


!  Opens a device context on the printer and starts the print job. No Win32
!  struct is involved at all - GetDefaultPrinterA fills a plain buffer, and
!  CreateDCA takes plain string parameters - so there is nothing here whose
!  binary layout has to be guessed. This trades away the OS Print common
!  dialog (which needs the much larger, harder-to-verify PRINTDLGA structure)
!  for reliability: it prints straight to SELF.PrinterName, or to Windows'
!  configured default printer when that is blank.
ExportClass.PrnBegin PROCEDURE()
Di   GROUP
cbSize               LONG
lpszDocName          LONG
lpszOutput           LONG
lpszDatatype         LONG
fwType               LONG
     END
face   CSTRING(33)
doc    CSTRING(65)
pname  CSTRING(261)
drv    CSTRING(9)
psize  LONG
  CODE
  drv = 'WINSPOOL'
  IF CLIP(SELF.PrinterName)
    pname = CLIP(SELF.PrinterName)
  ELSE
    pname = ''
    psize = SIZE(pname)
    IF ~exGetDefaultPrinter(pname,psize)
      SELF.ErrCode = 20
      SELF.ErrText = SELF.Txt(Txt:NoPrinter)
      RETURN 0
    END
  END

  SELF.PrnDC = exCreateDC(drv,pname,0,0)
  IF ~SELF.PrnDC
    SELF.ErrCode = 20
    SELF.ErrText = SELF.Txt(Txt:NoPrinter)
    RETURN 0
  END

  face = CLIP(SELF.FontFace)
  IF ~face THEN face = 'Arial' .
  SELF.PrnDpiX = exGetDeviceCaps(SELF.PrnDC,Prn:LOGPIXELSX)
  SELF.PrnDpiY = exGetDeviceCaps(SELF.PrnDC,Prn:LOGPIXELSY)
  IF SELF.PrnDpiX < 1 THEN SELF.PrnDpiX = 96 .
  IF SELF.PrnDpiY < 1 THEN SELF.PrnDpiY = 96 .
  SELF.PrnFont  = exCreateFont(-(SELF.FontSize * SELF.PrnDpiY / 72),0,0,0,400,0,0,0,0,0,0,0,0,face)
  SELF.PrnFontB = exCreateFont(-(SELF.FontSize * SELF.PrnDpiY / 72),0,0,0,700,0,0,0,0,0,0,0,0,face)

  SELF.PrnMarginL = SELF.MarginLeft   * SELF.PrnDpiX / 1440
  SELF.PrnMarginT = SELF.MarginTop    * SELF.PrnDpiY / 1440
  SELF.PrnPageW   = exGetDeviceCaps(SELF.PrnDC,Prn:HORZRES) - SELF.PrnMarginL - |
                    (SELF.MarginRight  * SELF.PrnDpiX / 1440)
  SELF.PrnPageH   = exGetDeviceCaps(SELF.PrnDC,Prn:VERTRES) - SELF.PrnMarginT - |
                    (SELF.MarginBottom * SELF.PrnDpiY / 1440)
  SELF.PrnRowH    = (SELF.FontSize + 6) * SELF.PrnDpiY / 72
  SELF.PrnColumnWidths()

  doc = CLIP(SELF.Title)
  IF ~doc THEN doc = SELF.Txt(Txt:ExportWord) .
  CLEAR(Di)
  Di.cbSize = SIZE(Di)
  Di.lpszDocName = ADDRESS(doc)
  IF exStartDoc(SELF.PrnDC,Di) <= 0
    exDeleteDC(SELF.PrnDC)
    SELF.PrnDC = 0
    SELF.ErrCode = 21
    SELF.ErrText = SELF.Txt(Txt:NoPrinter)
    RETURN 0
  END

  SELF.PrnPage = 0
  SELF.PrnNewPage()
  RETURN 1


!  StartPage, and repeat the heading row on every page but the first's blank
!  start (PrnPage=0 means "no page open yet", so nothing to EndPage first).
ExportClass.PrnNewPage PROCEDURE()
  CODE
  IF SELF.PrnPage THEN exEndPage(SELF.PrnDC) .
  exStartPage(SELF.PrnDC)
  SELF.PrnPage += 1
  SELF.PrnY = SELF.PrnMarginT
  IF SELF.Headers THEN SELF.PrnHeader() .


ExportClass.PrnHeader PROCEDURE()
i    LONG,AUTO
n    LONG,AUTO
out  LONG,AUTO
  CODE
  n = SELF.Columns()
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    SELF.PrnCell(out,SELF.HeaderText(i),1)
  END
  SELF.PrnY += SELF.PrnRowH


!  One row from the QUEUE BUFFER, paginating first if it will not fit.
ExportClass.PrnRow PROCEDURE()
i    LONG,AUTO
n    LONG,AUTO
out  LONG,AUTO
  CODE
  IF ~SELF.PrnDC THEN RETURN .
  n = SELF.Columns()
  IF SELF.PrnY + SELF.PrnRowH > SELF.PrnMarginT + SELF.PrnPageH THEN SELF.PrnNewPage() .
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    SELF.PrnCell(out,SELF.CellText(i),0)
  END
  SELF.PrnY += SELF.PrnRowH


!  One cell, left-aligned, clipped (by character count, measured against the
!  real selected font) so nothing overruns into the next column.
ExportClass.PrnCell PROCEDURE(LONG pCol,STRING pText,BYTE pBold)
Sz    GROUP
cx      LONG
cy      LONG
      END
s     CSTRING(261)
prev  LONG,AUTO
pad   LONG,AUTO
  CODE
  IF pCol < 1 OR pCol > SELF.PrnColN THEN RETURN .
  IF pBold
    prev = exSelectObject(SELF.PrnDC,SELF.PrnFontB)
  ELSE
    prev = exSelectObject(SELF.PrnDC,SELF.PrnFont)
  END
  exSetBkMode(SELF.PrnDC,Prn:TRANSPARENT)
  s = CLIP(LEFT(pText))
  pad = SELF.PrnDpiX / 36                                 ! ~2pt of breathing room each side
  LOOP WHILE LEN(CLIP(s)) > 1
    exGetTextExtent(SELF.PrnDC,s,LEN(CLIP(s)),Sz)
    IF Sz.cx <= SELF.PrnColW[pCol] - pad * 2 THEN BREAK .
    s = SUB(s,1,LEN(CLIP(s))-1)
  END
  exTextOut(SELF.PrnDC,SELF.PrnColX[pCol] + pad,SELF.PrnY,s,LEN(CLIP(s)))
  exSelectObject(SELF.PrnDC,prev)


!  EndPage/EndDoc, release the fonts and the DC. Always safe to call even if
!  PrnBegin never got as far as opening a DC (StartFile already checked, but
!  EndFile calls this unconditionally once Started was ever set).
ExportClass.PrnEnd PROCEDURE()
  CODE
  IF ~SELF.PrnDC
    SELF.PagesOut = 0
    RETURN 0
  END
  exEndPage(SELF.PrnDC)
  exEndDoc(SELF.PrnDC)
  IF SELF.PrnFont  THEN exDeleteObject(SELF.PrnFont)  .
  IF SELF.PrnFontB THEN exDeleteObject(SELF.PrnFontB) .
  exDeleteDC(SELF.PrnDC)
  SELF.PagesOut = SELF.PrnPage
  SELF.PrnDC    = 0
  SELF.PrnFont  = 0
  SELF.PrnFontB = 0
  RETURN 1


! ############################################################################
!  PDF  -  a hand-built file: objects + a cross-reference table, the same
!  technique as the .xlsx ZIP above. Base-14 standard fonts (Helvetica /
!  Helvetica-Bold) - nothing is embedded, so every PDF reader already has them.
!
!  Object numbers are fixed up front (1=Catalog, 2=Pages, 3=Helvetica,
!  4=Helvetica-Bold, 5.. = one Page + one Content stream per printed page), so
!  every reference is correct the moment it is written - only the Pages tree's
!  Kids/Count and the xref table itself have to wait for the last page.
! ############################################################################

!  Cols.Width -> PdfColX/PdfColW, in points, proportional - same idea as Print.
ExportClass.PdfColumnWidths PROCEDURE()
i       LONG,AUTO
n       LONG,AUTO
tot     LONG,AUTO
x       LONG,AUTO
w       LONG,AUTO
out     LONG,AUTO
usableW LONG,AUTO
  CODE
  n = SELF.Columns()
  tot = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    w = SELF.Cols.Width
    IF w < 20 THEN w = 20 .
    tot += w
  END
  IF ~tot THEN tot = 1 .
  usableW = SELF.PdfPageW - (SELF.MarginLeft/20) - (SELF.MarginRight/20)
  x = SELF.MarginLeft/20
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    IF out > 64 THEN BREAK .                              ! PdfColX/W DIM(64) ceiling
    w = SELF.Cols.Width
    IF w < 20 THEN w = 20 .
    SELF.PdfColX[out] = x
    SELF.PdfColW[out] = usableW * w / tot
    x += SELF.PdfColW[out]
  END
  SELF.PdfColN = out


!  Page size/margins, the two font objects (Catalog and Pages come last, once
!  Kids/Count are known - see PdfFinish), and the first page.
ExportClass.PdfBegin PROCEDURE()
  CODE
  IF SELF.PagePaper = Exp:A4
    IF SELF.PageOrient = Exp:Landscape
      SELF.PdfPageW = 842 ; SELF.PdfPageH = 595
    ELSE
      SELF.PdfPageW = 595 ; SELF.PdfPageH = 842
    END
  ELSE                                                     ! Letter
    IF SELF.PageOrient = Exp:Landscape
      SELF.PdfPageW = 792 ; SELF.PdfPageH = 612
    ELSE
      SELF.PdfPageW = 612 ; SELF.PdfPageH = 792
    END
  END
  SELF.PdfRowH       = SELF.FontSize + 6
  SELF.PdfCatalogObj = 1
  SELF.PdfPagesObj   = 2
  SELF.PdfFontObj    = 3
  SELF.PdfFontBObj   = 4
  SELF.PdfNextObj    = 5
  SELF.PdfKids       = ''
  SELF.PdfPage       = 0
  SELF.PdfTruncated  = 0
  SELF.PdfContLen    = 0
  SELF.ArcLen        = 0
  SELF.PdfDictOpen   = CHR(60) & CHR(60)                  ! '<<' built at runtime - see the .inc comment on this field
  IF ~SELF.PdfObjs &= NULL THEN FREE(SELF.PdfObjs) .

  SELF.ArcCat('%PDF-1.4' & Exp:CRLF & '%' & CHR(226) & CHR(227) & CHR(207) & CHR(211) & Exp:CRLF)
  SELF.PdfBeginObj(SELF.PdfFontObj)
  SELF.ArcCat(SELF.PdfDictOpen & ' /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>' & |
              Exp:CRLF & 'endobj' & Exp:CRLF)
  SELF.PdfBeginObj(SELF.PdfFontBObj)
  SELF.ArcCat(SELF.PdfDictOpen & ' /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold /Encoding /WinAnsiEncoding >>' & |
              Exp:CRLF & 'endobj' & Exp:CRLF)

  SELF.PdfColumnWidths()
  SELF.PdfNewPage()
  RETURN 1


!  Close the page in progress (if any), open the next Page object (its number
!  is fixed now, so /Contents already points at the right place), and start
!  its content stream with the title (page 1 only) and the heading row.
ExportClass.PdfNewPage PROCEDURE()
pageObj  LONG,AUTO
  CODE
  IF SELF.PdfPage THEN SELF.PdfClosePage() .
  SELF.PdfPage += 1
  IF SELF.PdfPage > Exp:PdfPageCap                        ! PdfPageObjs' DIM ceiling - stop making new pages,
    SELF.PdfTruncated = 1                                 ! but PdfPage itself keeps counting so PdfFinish knows
    RETURN                                                ! how many rows never got a page at all
  END
  pageObj = SELF.PdfNextObj ; SELF.PdfNextObj += 1
  SELF.PdfContObj = SELF.PdfNextObj ; SELF.PdfNextObj += 1
  SELF.PdfPageObjs[SELF.PdfPage] = pageObj
  SELF.PdfKids = SELF.PdfKids & SELF.PdfNum(pageObj) & ' 0 R '  ! NEVER CLIP() the left side here - it would eat
                                                                  ! the trailing space this line just added, and
                                                                  ! the NEXT entry would run straight into this
                                                                  ! one's 'R' with no separator: '5 0 R7 0 R9 0 R'
                                                                  ! instead of '5 0 R 7 0 R 9 0 R' - exactly the
                                                                  ! corruption a strict PDF reader chokes on.

  SELF.PdfBeginObj(pageObj)
  SELF.ArcCat(SELF.PdfDictOpen & ' /Type /Page /Parent ' & SELF.PdfNum(SELF.PdfPagesObj) & ' 0 R /MediaBox [0 0 ' & |
              SELF.PdfNum(SELF.PdfPageW) & ' ' & SELF.PdfNum(SELF.PdfPageH) & ']' & |
              ' /Resources ' & SELF.PdfDictOpen & ' /Font ' & SELF.PdfDictOpen & ' /F1 ' & SELF.PdfNum(SELF.PdfFontObj) & ' 0 R /F2 ' & SELF.PdfNum(SELF.PdfFontBObj) & ' 0 R >> >>' & |
              ' /Contents ' & SELF.PdfNum(SELF.PdfContObj) & ' 0 R >>' & Exp:CRLF & 'endobj' & Exp:CRLF)

  SELF.PdfContLen = 0
  IF ~SELF.PdfContent &= NULL
    DISPOSE(SELF.PdfContent)
    SELF.PdfContCap = 0
  END
  SELF.PdfY = SELF.MarginTop / 20
  IF SELF.PdfPage = 1 AND CLIP(SELF.Title)
    SELF.PdfContCat('BT /F2 ' & SELF.PdfNum(SELF.TitleSize) & ' Tf 1 0 0 1 ' & SELF.PdfNum(SELF.MarginLeft/20) & ' ' & |
                     SELF.PdfNum(SELF.PdfPageH - SELF.PdfY - SELF.TitleSize) & ' Tm (' & |
                     SELF.PdfEscape(CLIP(SELF.Title)) & ') Tj ET' & Exp:CRLF)
    SELF.PdfY += SELF.TitleSize + 6
  END
  IF SELF.Headers THEN SELF.PdfHeader() .


!  Flush the just-finished page's content stream into its own PDF object.
!  Safe to call with nothing open (PdfFinish calls it unconditionally).
ExportClass.PdfClosePage PROCEDURE()
  CODE
  IF ~SELF.PdfContObj THEN RETURN .
  SELF.PdfBeginObj(SELF.PdfContObj)
  SELF.ArcCat(SELF.PdfDictOpen & ' /Length ' & SELF.PdfNum(SELF.PdfContLen) & ' >>' & Exp:CRLF & 'stream' & Exp:CRLF)
  IF SELF.PdfContLen > 0 THEN SELF.ArcCat(SELF.PdfContent[1 : SELF.PdfContLen]) .
  SELF.ArcCat(Exp:CRLF & 'endstream' & Exp:CRLF & 'endobj' & Exp:CRLF)
  SELF.PdfContObj = 0


ExportClass.PdfHeader PROCEDURE()
i    LONG,AUTO
n    LONG,AUTO
out  LONG,AUTO
  CODE
  n = SELF.Columns()
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    SELF.PdfCell(out,SELF.HeaderText(i),1)
  END
  SELF.PdfY += SELF.PdfRowH


!  One row from the QUEUE BUFFER, paginating first if it will not fit.
ExportClass.PdfRow PROCEDURE()
i    LONG,AUTO
n    LONG,AUTO
out  LONG,AUTO
  CODE
  n = SELF.Columns()
  IF SELF.PdfY + SELF.PdfRowH > SELF.PdfPageH - (SELF.MarginBottom/20) THEN SELF.PdfNewPage() .
  out = 0
  LOOP i = 1 TO n
    GET(SELF.Cols,i)
    IF ~SELF.Cols.Use THEN CYCLE .
    out += 1
    SELF.PdfCell(out,SELF.CellText(i),0)
  END
  SELF.PdfY += SELF.PdfRowH


!  One cell: clip it to the column width (Helvetica AFM metrics), then emit an
!  absolutely-positioned BT..Tm..Tj..ET block - simpler and safer than relative
!  Td moves shared across many cells.
ExportClass.PdfCell PROCEDURE(LONG pCol,STRING pText,BYTE pBold)
s    CSTRING(261)
x    LONG,AUTO
y    LONG,AUTO
fnt  CSTRING(3)
  CODE
  IF ~SELF.PdfContObj THEN RETURN .                       ! no page is open - past the cap, nothing left to write into
  IF pCol < 1 OR pCol > SELF.PdfColN THEN RETURN .
  s = SELF.PdfClip(CLIP(LEFT(pText)),SELF.FontSize,pBold,SELF.PdfColW[pCol] - 4)
  IF ~CLIP(s) THEN RETURN .
  x = SELF.PdfColX[pCol] + 2
  y = SELF.PdfPageH - (SELF.PdfY + SELF.FontSize + 2)
  fnt = CHOOSE(pBold = 1,'F2','F1')
  SELF.PdfContCat('BT /' & fnt & ' ' & SELF.PdfNum(SELF.FontSize) & ' Tf 1 0 0 1 ' & SELF.PdfNum(x) & ' ' & SELF.PdfNum(y) & ' Tm (' & |
                   SELF.PdfEscape(s) & ') Tj ET' & Exp:CRLF)


!  Flush the last page, write the Pages tree and Catalog (their Kids/Count are
!  only known now), then the cross-reference table and trailer, and the file.
ExportClass.PdfFinish PROCEDURE()
i        LONG,AUTO
j        LONG,AUTO
maxObj   LONG,AUTO
xrefOfs  ULONG,AUTO
ofs      ULONG,AUTO
found    BYTE,AUTO
realPages LONG,AUTO                                        ! how many pages actually GOT created - Kids/Count and
                                                             ! PagesOut all need to agree with reality, not with
                                                             ! however many times PdfNewPage() was ever CALLED
  CODE
  SELF.PdfClosePage()
  realPages = CHOOSE(SELF.PdfPage < Exp:PdfPageCap,SELF.PdfPage,Exp:PdfPageCap)
  SELF.PdfBeginObj(SELF.PdfPagesObj)
  SELF.ArcCat(SELF.PdfDictOpen & ' /Type /Pages /Kids [' & CLIP(SELF.PdfKids) & '] /Count ' & SELF.PdfNum(realPages) & ' >>' & |
              Exp:CRLF & 'endobj' & Exp:CRLF)
  SELF.PdfBeginObj(SELF.PdfCatalogObj)
  SELF.ArcCat(SELF.PdfDictOpen & ' /Type /Catalog /Pages ' & SELF.PdfNum(SELF.PdfPagesObj) & ' 0 R >>' & Exp:CRLF & 'endobj' & Exp:CRLF)

  maxObj = 0
  LOOP i = 1 TO RECORDS(SELF.PdfObjs)
    GET(SELF.PdfObjs,i)
    IF SELF.PdfObjs.PNum > maxObj THEN maxObj = SELF.PdfObjs.PNum .
  END

  xrefOfs = SELF.ArcLen
  SELF.ArcCat('xref' & Exp:CRLF & '0 ' & SELF.PdfNum(maxObj+1) & Exp:CRLF)
  SELF.ArcCat('0000000000 65535 f' & Exp:CRLF)
  LOOP i = 1 TO maxObj
    found = 0
    LOOP j = 1 TO RECORDS(SELF.PdfObjs)
      GET(SELF.PdfObjs,j)
      IF SELF.PdfObjs.PNum = i
        ofs = SELF.PdfObjs.POfs
        found = 1
        BREAK
      END
    END
    IF found
      SELF.ArcCat(SELF.PdfPad10(ofs) & ' 00000 n' & Exp:CRLF)
    ELSE
      SELF.ArcCat('0000000000 00000 f' & Exp:CRLF)
    END
  END
  SELF.ArcCat('trailer' & Exp:CRLF & SELF.PdfDictOpen & ' /Size ' & SELF.PdfNum(maxObj+1) & ' /Root ' & SELF.PdfNum(SELF.PdfCatalogObj) & ' 0 R >>' & Exp:CRLF)
  SELF.ArcCat('startxref' & Exp:CRLF & SELF.PdfNum(xrefOfs) & Exp:CRLF & '%%EOF' & Exp:CRLF)

  SELF.PagesOut = realPages
  RETURN SELF.WriteDisk(SELF.FileName,SELF.Arc,SELF.ArcLen)


!  A LONG turned into a plain decimal string by hand - no leading/trailing
!  padding, no thousands separator, nothing Clarion's own default numeric-to-
!  string conversion might otherwise apply when a number is concatenated with
!  '&'. A strict reader like Chrome's PDFium has none of Acrobat's tolerance
!  for a stray padded or grouped digit sequence in an object number, /Length,
!  a coordinate, or an xref count - so every number written into the PDF goes
!  through this instead of a raw '&'.
ExportClass.PdfNum PROCEDURE(LONG pVal)
s     STRING(16)
v     LONG,AUTO
neg   BYTE,AUTO
d     LONG,AUTO
  CODE
  v = pVal
  neg = 0
  IF v < 0
    neg = 1
    v = -v
  END
  IF v = 0 THEN RETURN '0' .
  s = ''
  LOOP WHILE v > 0
    d = v - INT(v/10)*10
    s = CHR(48+d) & CLIP(s)
    v = INT(v/10)
  END
  IF neg THEN RETURN '-' & CLIP(s) .
  RETURN CLIP(s)


!  "N 0 obj" - records where it starts (SELF.Arc's current length) so PdfFinish
!  can build the cross-reference table afterwards.
ExportClass.PdfBeginObj PROCEDURE(LONG pNum)
  CODE
  IF SELF.PdfObjs &= NULL THEN SELF.PdfObjs &= NEW ExportPdfQueue .
  SELF.PdfObjs.PNum = pNum
  SELF.PdfObjs.POfs = SELF.ArcLen
  ADD(SELF.PdfObjs)
  SELF.ArcCat(SELF.PdfNum(pNum) & ' 0 obj' & Exp:CRLF)


!  A byte offset, zero-padded to exactly 10 digits - the xref table's format.
ExportClass.PdfPad10 PROCEDURE(ULONG pVal)
s  STRING(10)
v  ULONG,AUTO
d  LONG,AUTO
i  LONG,AUTO
  CODE
  s = '0000000000'
  v = pVal
  i = 10
  LOOP WHILE v > 0 AND i >= 1
    d = v - INT(v/10)*10
    s[i] = CHR(48 + d)
    v = INT(v/10)
    i -= 1
  END
  RETURN s


ExportClass.PdfContNeed PROCEDURE(LONG pAdd)
cap  LONG,AUTO
nb   &STRING
  CODE
  IF SELF.PdfContLen + pAdd <= SELF.PdfContCap THEN RETURN .
  cap = SELF.PdfContCap
  IF cap < 4096 THEN cap = 4096 .
  LOOP WHILE cap < SELF.PdfContLen + pAdd
    cap += cap
  END
  nb &= NEW STRING(cap)
  IF SELF.PdfContLen THEN nb[1 : SELF.PdfContLen] = SELF.PdfContent[1 : SELF.PdfContLen] .
  IF ~SELF.PdfContent &= NULL THEN DISPOSE(SELF.PdfContent) .
  SELF.PdfContent &= nb
  SELF.PdfContCap = cap


ExportClass.PdfContCat PROCEDURE(STRING pText)
l  LONG,AUTO
  CODE
  l = LEN(pText)
  IF l <= 0 THEN RETURN .
  SELF.PdfContNeed(l)
  SELF.PdfContent[SELF.PdfContLen+1 : SELF.PdfContLen+l] = pText[1 : l]
  SELF.PdfContLen += l


!  Backslash, parentheses and raw line breaks are the only things PDF's literal
!  string syntax requires escaping. Values come from FORMAT()/CLIP() in the
!  machine's own code page; that is close enough to WinAnsiEncoding for the
!  Latin-1 range every European code page shares with it.
ExportClass.PdfEscape PROCEDURE(STRING pText)
l  LONG,AUTO
i  LONG,AUTO
o  CSTRING(521)
c  STRING(1)
  CODE
  o = ''
  l = LEN(pText)
  LOOP i = 1 TO l
    IF LEN(CLIP(o)) > 500 THEN BREAK .
    c = pText[i]
    CASE c
    OF '(' ; o = CLIP(o) & '\('
    OF ')' ; o = CLIP(o) & '\)'
    OF '\' ; o = CLIP(o) & '\\'
    OF '<13>' OROF '<10>' ; o = CLIP(o) & ' '
    ELSE
      o = CLIP(o) & c
    END
  END
  RETURN o


!  Helvetica's standard AFM widths (1/1000 em) for printable ASCII. Bold is
!  approximated as 8% wider - close enough for clipping decisions, which is
!  all this is used for; it never affects file validity, only where a long
!  value gets cut off.
ExportClass.PdfStrWidth PROCEDURE(STRING pText,LONG pSize,BYTE pBold)
Wid  LONG,DIM(95)
i    LONG,AUTO
v    LONG,AUTO
tot  LONG,AUTO
  CODE
  Wid[1]  = 278 ; Wid[2]  = 278 ; Wid[3]  = 355 ; Wid[4]  = 556 ; Wid[5]  = 556   ! sp ! " # $
  Wid[6]  = 889 ; Wid[7]  = 667 ; Wid[8]  = 191 ; Wid[9]  = 333 ; Wid[10] = 333   ! % & ' ( )
  Wid[11] = 389 ; Wid[12] = 584 ; Wid[13] = 278 ; Wid[14] = 333 ; Wid[15] = 278   ! * + , - .
  Wid[16] = 278 ; Wid[17] = 556 ; Wid[18] = 556 ; Wid[19] = 556 ; Wid[20] = 556   ! / 0 1 2 3
  Wid[21] = 556 ; Wid[22] = 556 ; Wid[23] = 556 ; Wid[24] = 556 ; Wid[25] = 556   ! 4 5 6 7 8
  Wid[26] = 556 ; Wid[27] = 278 ; Wid[28] = 278 ; Wid[29] = 584 ; Wid[30] = 584   ! 9 : ; < =
  Wid[31] = 584 ; Wid[32] = 556 ; Wid[33] = 1015; Wid[34] = 667 ; Wid[35] = 667   ! > ? @ A B
  Wid[36] = 722 ; Wid[37] = 722 ; Wid[38] = 667 ; Wid[39] = 611 ; Wid[40] = 778   ! C D E F G
  Wid[41] = 722 ; Wid[42] = 278 ; Wid[43] = 500 ; Wid[44] = 667 ; Wid[45] = 556   ! H I J K L
  Wid[46] = 833 ; Wid[47] = 722 ; Wid[48] = 778 ; Wid[49] = 667 ; Wid[50] = 778   ! M N O P Q
  Wid[51] = 722 ; Wid[52] = 667 ; Wid[53] = 611 ; Wid[54] = 722 ; Wid[55] = 667   ! R S T U V
  Wid[56] = 944 ; Wid[57] = 667 ; Wid[58] = 667 ; Wid[59] = 611 ; Wid[60] = 278   ! W X Y Z [
  Wid[61] = 278 ; Wid[62] = 278 ; Wid[63] = 469 ; Wid[64] = 556 ; Wid[65] = 333   ! \ ] ^ _ `
  Wid[66] = 556 ; Wid[67] = 556 ; Wid[68] = 500 ; Wid[69] = 556 ; Wid[70] = 556   ! a b c d e
  Wid[71] = 278 ; Wid[72] = 556 ; Wid[73] = 556 ; Wid[74] = 222 ; Wid[75] = 222   ! f g h i j
  Wid[76] = 500 ; Wid[77] = 222 ; Wid[78] = 833 ; Wid[79] = 556 ; Wid[80] = 556   ! k l m n o
  Wid[81] = 556 ; Wid[82] = 556 ; Wid[83] = 333 ; Wid[84] = 500 ; Wid[85] = 278   ! p q r s t
  Wid[86] = 556 ; Wid[87] = 500 ; Wid[88] = 722 ; Wid[89] = 500 ; Wid[90] = 500   ! u v w x y
  Wid[91] = 500 ; Wid[92] = 334 ; Wid[93] = 260 ; Wid[94] = 334 ; Wid[95] = 584   ! z { | } ~

  tot = 0
  LOOP i = 1 TO LEN(pText)
    v = VAL(pText[i]) - 31                                ! index into Wid[], 1 = space(32)
    IF v < 1 OR v > 95 THEN v = 5 .                        ! outside 32..126 - use "$"-ish average
    tot += Wid[v]
  END
  IF pBold THEN tot = tot * 108 / 100 .
  RETURN tot * pSize / 1000


!  Truncate a value so it fits pMaxWidth points at pSize/pBold - used instead
!  of a PDF clipping path, which would need its own graphics-state save/restore
!  around every cell for no visible benefit at this column width.
ExportClass.PdfClip PROCEDURE(STRING pText,LONG pSize,BYTE pBold,LONG pMaxWidth)
s  CSTRING(261)
  CODE
  IF pMaxWidth <= 0 THEN RETURN '' .
  s = CLIP(LEFT(pText))
  LOOP WHILE LEN(CLIP(s)) > 1
    IF SELF.PdfStrWidth(CLIP(s),pSize,pBold) <= pMaxWidth THEN BREAK .
    s = SUB(s,1,LEN(CLIP(s))-1)
  END
  RETURN s
