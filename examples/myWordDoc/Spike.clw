! ============================================================================
!  Spike - proves WordDocClass + wdoc.c end to end, without AppGen.
!
!    Spike.exe            the editor on a window (BLOB in Docs.tps)
!    Spike.exe AUTO       headless API checks  -> spike_result.ini
!    Spike.exe REPORT     prints sample.rtf through a REPORT into PROP:Preview
!                         and copies the page metafiles out as rpt_page<n>.wmf
! ============================================================================
  PROGRAM

  INCLUDE('WordDocClass.INC'),ONCE

  MAP
AutoTest     PROCEDURE()
ReportTest   PROCEDURE()
EmfTest      PROCEDURE()
PasteTest    PROCEDURE()
EditorWindow PROCEDURE()
PutR         PROCEDURE(STRING pKey,STRING pValue)
  END

Docs         FILE,DRIVER('TOPSPEED'),NAME('Docs.tps'),PRE(DOC),CREATE
PKey           KEY(DOC:Id),PRIMARY
Body           BLOB,BINARY
Record         RECORD
Id               LONG
Title            STRING(60)
               END
             END

ResultFile   CSTRING(261)

  CODE
  ResultFile = LONGPATH() & '\spike_result.ini'
  CASE UPPER(CLIP(COMMAND(1)))
  OF 'AUTO'
    AutoTest()
  OF 'REPORT'
    ReportTest()
  OF 'EMF'
    EmfTest()
  OF 'PASTE'
    PasteTest()
  ELSE
    EditorWindow()
  END

PutR PROCEDURE(STRING pKey,STRING pValue)
  CODE
  PUTINI('spike', pKey, pValue, ResultFile)

!------------------------------------------------------------------------------
AutoTest PROCEDURE()
Doc    WordDocClass
Doc2   WordDocClass
L:S    STRING(2000)
L:N    LONG
  CODE
  REMOVE(ResultFile)
  PutR('sizes', Doc.StructSizes())
  PutR('hidden', Doc.InitHidden())
  PutR('err', Doc.Err)

  Doc.LoadString('Hello world from Clarion.')
  PutR('len_plain', Doc.Length())

  Doc.SelectAll()
  Doc.Bold(WD:On)
  PutR('bold_after_on', Doc.GetFormat(1))
  Doc.Bold(WD:Toggle)
  PutR('bold_after_toggle', Doc.GetFormat(1))
  Doc.SetFontSize(16)
  PutR('size_x10', Doc.GetFormat(5))
  Doc.SetFont('Georgia')
  PutR('face', Doc.GetFont())
  Doc.SetAlign(WD:Center)
  PutR('align', Doc.GetFormat(8))
  Doc.SetList(WD:Bullets)
  PutR('list', Doc.GetFormat(9))
  Doc.SetList(WD:NoList)
  Doc.SetColor(COLOR:Red)
  PutR('color', Doc.GetFormat(6))

  Doc.SelectText(-1, -1)                           ! caret to the end
  Doc.InsertText('<13,10>')
  PutR('table', Doc.InsertTable(2, 3))
  PutR('image_png', Doc.InsertImage('test.png'))
  PutR('image_jpg', Doc.InsertImage('test.jpg'))
  PutR('image_bmp', Doc.InsertImage('test.bmp'))
  PutR('image_missing', Doc.InsertImage('nope.png'))

  L:S = Doc.GetRtf()
  PutR('rtf_head', SUB(L:S, 1, 40))
  PutR('rtf_has_pngblip', CHOOSE(INSTRING('\pngblip', Doc.GetRtf(), 1, 1) > 0))
  PutR('rtf_has_table', CHOOSE(INSTRING('\trowd', Doc.GetRtf(), 1, 1) > 0))
  PutR('find', Doc.Find('world'))

  ! ---- BLOB round trip through a real TopSpeed record ----
  REMOVE(Docs)
  CREATE(Docs)
  OPEN(Docs)
  PutR('open_err', ERRORCODE())
  CLEAR(DOC:Record)
  DOC:Id = 1
  DOC:Title = 'Spike'
  Doc.SaveBlob(DOC:Body)
  PutR('blob_size', DOC:Body{PROP:Size})
  ADD(Docs)
  PutR('add_err', ERRORCODE())
  CLEAR(DOC:Record)
  DOC:Body{PROP:Size} = 0
  DOC:Id = 1
  GET(Docs, DOC:PKey)
  PutR('get_err', ERRORCODE())
  PutR('blob_size_back', DOC:Body{PROP:Size})
  Doc2.InitHidden()
  Doc2.LoadBlob(DOC:Body)
  PutR('text_match', CHOOSE(Doc2.GetText() = Doc.GetText()))
  PutR('text_back', SUB(Doc2.GetText(), 1, 40))
  CLOSE(Docs)

  ! ---- pages ----
  L:N = Doc.Paginate(9360, 2880)                   ! 6.5in x 2in chunks
  PutR('pages_2in', L:N)
  PutR('page1_used', Doc.PageUsedHeight(1))
  PutR('page_last_used', Doc.PageUsedHeight(L:N))
  L:S = Doc.RenderPage(1)
  PutR('emf1', L:S)
  COPY(CLIP(L:S), 'page1.wmf')
  PutR('emf1_copy_err', ERRORCODE())

  Doc2.Kill()
  Doc.Kill()
  PutR('done', 1)

!------------------------------------------------------------------------------
ReportTest PROCEDURE()
Doc    WordDocClass
PrevQ  QUEUE
FName    STRING(260)
       END
L:N    LONG
L:I    LONG
Rpt    REPORT,AT(1000,1000,6500,9000),PRE(RPT),THOUS,FONT('Arial',10)
Head     DETAIL,AT(0,0,6500,500),USE(?Head)
           STRING('myWordDoc report test - text before the document'),AT(0,100,6500,300),USE(?HeadS),FONT(,12,,FONT:bold)
         END
Detail   DETAIL,AT(0,0,6500,8000),USE(?Detail)
           IMAGE,AT(0,0,6500,8000),USE(?DocImg)
         END
Tail     DETAIL,AT(0,0,6500,400),USE(?Tail)
           STRING('--- printed straight after the document ---'),AT(0,100,6500,300),USE(?TailS)
         END
       END
  CODE
  Doc.InitHidden()
  IF NOT Doc.LoadFile('sample.rtf')
    PutR('report', 'no sample.rtf')
    RETURN
  END
  OPEN(Rpt)
  Rpt{PROP:Preview} = PrevQ.FName
  PRINT(RPT:Head)
  L:N = Doc.PaginateForReport(Rpt, ?DocImg)
  PutR('report_pages', L:N)
  LOOP L:I = 1 TO L:N
    Doc.PreparePage(Rpt, ?DocImg, L:I)
    PRINT(RPT:Detail)
  END
  PRINT(RPT:Tail)
  ENDPAGE(Rpt)
  PutR('preview_pages', RECORDS(PrevQ))
  LOOP L:I = 1 TO RECORDS(PrevQ)
    GET(PrevQ, L:I)
    COPY(CLIP(PrevQ.FName), 'rpt_page' & L:I & '.wmf')
  END
  CLOSE(Rpt)
  Doc.Kill()

!------------------------------------------------------------------------------
EditorWindow PROCEDURE()
Doc    WordDocClass
Win    WINDOW('myWordDoc - spike'),AT(,,520,340),CENTER,GRAY,SYSTEM,MAX,RESIZE,FONT('Segoe UI',9),IMM
         STRING('Document title:'),AT(8,9),USE(?TitleP)
         ENTRY(@s60),AT(66,7,200,11),USE(DOC:Title)
         REGION,AT(8,24,504,290),USE(?DocRegion)
         BUTTON('&Save'),AT(352,320,50,14),USE(?Save)
         BUTTON('&Reload'),AT(406,320,50,14),USE(?Reload)
         BUTTON('Close'),AT(462,320,50,14),USE(?Close)
         STRING(''),AT(8,323,300),USE(?Status)
       END
  CODE
  OPEN(Docs)
  IF ERRORCODE()
    CREATE(Docs)
    OPEN(Docs)
  END
  CLEAR(DOC:Record)
  DOC:Id = 1
  GET(Docs, DOC:PKey)
  IF ERRORCODE()
    CLEAR(DOC:Record)
    DOC:Id = 1
    DOC:Title = 'Welcome'
    ADD(Docs)
  END
  OPEN(Win)
  Doc.PageView = CHOOSE(UPPER(COMMAND(1)) = 'PAGE')
  Doc.PageWidth = WD:LetterWidth
  Doc.Init(0{PROP:Handle}, ?DocRegion)
  IF DOC:Body{PROP:Size} > 0
    Doc.LoadBlob(DOC:Body)
  ELSE
    Doc.LoadFile('sample.rtf')
  END
  IF UPPER(COMMAND(1)) = 'CLICK' THEN Doc.SelectAll(); Doc.Focus().
  ACCEPT
    IF Doc.TakeEvent()
      ?Status{PROP:Text} = 'Edited - not saved'
    END
    CASE EVENT()
    OF EVENT:Sized
      ?DocRegion{PROP:Width} = 0{PROP:Width} - 16
      ?DocRegion{PROP:Height} = 0{PROP:Height} - 50
      ?Save{PROP:Ypos} = 0{PROP:Height} - 20
      ?Reload{PROP:Ypos} = 0{PROP:Height} - 20
      ?Close{PROP:Ypos} = 0{PROP:Height} - 20
      ?Save{PROP:Xpos} = 0{PROP:Width} - 168
      ?Reload{PROP:Xpos} = 0{PROP:Width} - 114
      ?Close{PROP:Xpos} = 0{PROP:Width} - 58
      ?Status{PROP:Ypos} = 0{PROP:Height} - 17
      Doc.Reposition()
    END
    CASE ACCEPTED()
    OF ?Save
      Doc.SaveBlob(DOC:Body)
      PUT(Docs)
      ?Status{PROP:Text} = 'Saved ' & DOC:Body{PROP:Size} & ' bytes of RTF to the BLOB'
    OF ?Reload
      Doc.LoadBlob(DOC:Body)
      ?Status{PROP:Text} = 'Reloaded from the BLOB'
    OF ?Close
      BREAK
    END
  END
  PutR('editor_text', SUB(Doc.GetText(), 1, 40))
  PutR('editor_modified', Doc.Modified())
  Doc.Kill()
  CLOSE(Win)
  CLOSE(Docs)

!------------------------------------------------------------------------------
EmfTest PROCEDURE()
Doc    WordDocClass
L:S    STRING(300)
  CODE
  Doc.InitHidden()
  Doc.LoadFile('sample.rtf')
  PutR('emf_pages', Doc.Paginate(9360, 12960))
  L:S = Doc.RenderPage(1)
  COPY(CLIP(L:S), 'sample_p1.wmf')
  PutR('emf_to', Doc.RenderPageTo(1, LONGPATH() & '\sample_p1.emf'))
  Doc.Kill()

!------------------------------------------------------------------------------
PasteTest PROCEDURE()
Doc    WordDocClass
  CODE
  Doc.InitHidden()
  Doc.LoadString('Before ')
  Doc.SelectText(-1, -1)
  Doc.PasteText()
  PutR('paste_len', Doc.Length())
  PutR('paste_pict', CHOOSE(INSTRING('\pict', Doc.GetRtf(), 1, 1) > 0))
  PutR('paste_rtf_size', LEN(Doc.GetRtf()))
  Doc.SaveFile('paste.rtf')
  Doc.Kill()
