#TEMPLATE(myWordDoc,'myWordDoc - a word processor on a window, stored in a BLOB, printed on reports - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myWordDoc
#!
#!  A real word processor on a Clarion window - fonts, colours, alignment,
#!  bullets, numbering, indents, pictures and tables - kept as RTF in one BLOB
#!  field, and printed through an ordinary Clarion REPORT. No COM, no OCX,
#!  nothing to register on the customer's machine.
#!
#!  HOW IT WORKS
#!      wdoc.c - which CLARION'S OWN C COMPILER builds straight into your exe -
#!      registers a host window that paints its own toolbar and holds the
#!      Windows text engine (RichEdit, msftedit.dll, the engine behind WordPad)
#!      as its editing surface. The control is created over a placeholder REGION
#!      when the window opens and FOLLOWS that region from then on: a window
#!      resizer may move or stretch it, a TAB may hide it, DISABLE may grey it.
#!      That is why the class is handed every event.
#!
#!      On a report the same engine runs invisibly: the document is cut into
#!      pages the size of a report IMAGE control, each page is drawn into a
#!      vector metafile, the IMAGE is pointed at it and its DETAIL band is
#!      PRINTed once per page. The text stays sharp and PDFs stay small.
#!
#!  THE TEMPLATES
#!    myWordDocGlobal  (APPLICATION) - OPTIONAL. Makes WordDocClass available to
#!                     the whole application, for hand-written code. Every other
#!                     template here pulls the class in by itself.
#!    myWordDocEditor  (CONTROL)     - the word processor on a window, bound to a
#!                     BLOB. On an update form it is saved with the record.
#!                     MULTI - as many per window as you like.
#!    myWordDocReport  (EXTENSION)   - prints a BLOB on an ABC Report procedure,
#!                     as many pages as the document needs, for every record.
#!    myWordDocPrintBlob (CODE)      - the same print loop, dropped into any
#!                     embed of your choosing.
#!
#!  REQUIRED FILES: copy these (shipped beside this .tpl) to a folder on the
#!  Clarion redirection path (the app folder, or \clarion12\accessory\libsrc\win),
#!  saved as ANSI with CRLF line endings:
#!      WordDocClass.inc   WordDocClass.clw   wdoc.c
#!      WordDocTools.inc   WordDocTools.clw   (the RTF tool classes)
#!  WordDocClass.clw is pulled into the build by its LINK attribute and compiles
#!  wdoc.c itself, so there is nothing to add to the project.
#!
#!  API (the object is ordinary Clarion data - call it from any embed):
#!    WordDoc1.GetText()              the plain text, for searching or indexing
#!    WordDoc1.Modified()             edited since it was loaded or saved
#!    WordDoc1.InsertText('...')      at the caret; also InsertImage/InsertTable
#!    WordDoc1.SetReadOnly(TRUE)      lock it, e.g. for a user without rights
#!-----------------------------------------------------------------------------
#!#############################################################################
#!  GLOBAL EXTENSION - myWordDocGlobal
#!#############################################################################
#EXTENSION(myWordDocGlobal,'myWordDoc - Global (optional, add once per application)'),APPLICATION,HLP('~myWordDoc.htm')
#SHEET
  #TAB('&General')
    #BOXED('myWordDoc')
      #DISPLAY('myWordDoc Global - Version 1.0')
      #DISPLAY('')
      #DISPLAY('Makes WordDocClass and the RTF tool classes (search,')
      #DISPLAY('fonts, text, HTML, Markdown, merge) available to every')
      #DISPLAY('procedure in the application, for hand-written code.')
      #DISPLAY('')
      #DISPLAY('This extension is OPTIONAL: the editor control, the report')
      #DISPLAY('extension and the print code template all pull the class in')
      #DISPLAY('by themselves.')
      #DISPLAY('')
      #DISPLAY('IMPORTANT: copy WordDocClass.inc/.clw, WordDocTools.inc/.clw')
      #DISPLAY('and wdoc.c to the redirection path, saved as ANSI.')
      #PROMPT('&Disable myWordDoc everywhere',CHECK),%wdGloDisable,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Notes')
      #DISPLAY('Documents are stored as RTF, so a BLOB written here opens in')
      #DISPLAY('Word, and any RTF you load into a BLOB shows in the editor.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%wdGloDisable=0)
INCLUDE('WordDocClass.INC'),ONCE
INCLUDE('WordDocTools.INC'),ONCE
#ENDAT
#!
#!#############################################################################
#!  CONTROL TEMPLATE - myWordDocEditor
#!  The word processor sitting ON the window. Drops an empty REGION as the
#!  placeholder; the control is created over that rectangle when the window
#!  opens and follows it from then on.
#!#############################################################################
#CONTROL(myWordDocEditor,'myWordDoc - Word processor on the window (stored in a BLOB)'),WINDOW,MULTI,DESCRIPTION('Word processor for ' & %wdBlob),HLP('~myWordDoc.htm')
#! the placeholder - an empty REGION. Its feq auto-uniques on multi-drop and is
#! captured in the #ATSTART below, so several editors on one window each find
#! their own rectangle.
  CONTROLS
    REGION,AT(,,300,180),USE(?WordDocRegion)
  END
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable this editor',CHECK),%wdDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%wdObject,REQ,DEFAULT('WordDoc' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('Where the document is kept')
      #PROMPT('&BLOB field:',FIELD),%wdBlob
      #DISPLAY('A BLOB from the dictionary. Leave it blank to load and')
      #DISPLAY('save the document yourself (LoadBlob / SaveBlob / LoadFile).')
      #ENABLE(%wdBlob<>'')
        #PROMPT('&Save it with the record (update forms)',CHECK),%wdAutoSave,DEFAULT(1),AT(10)
      #ENDENABLE
      #DISPLAY('Saved just before the record is written, on Insert and on')
      #DISPLAY('Change - only when the BLOB belongs to the primary table.')
    #ENDBOXED
  #ENDTAB
  #TAB('&Appearance')
    #BOXED('Editor')
      #PROMPT('Show the formatting &toolbar',CHECK),%wdToolbar,DEFAULT(1),AT(10)
      #PROMPT('&Read only',CHECK),%wdReadOnly,DEFAULT(0),AT(10)
      #DISPLAY('A form opened to View a record is always read only.')
      #PROMPT('&Page view (the printed width on a grey desk)',CHECK),%wdPageView,DEFAULT(0),AT(10)
    #ENDBOXED
    #BOXED('Page width')
      #PROMPT('&Lines are as wide as:',DROP('A Letter page, 1in margins (6.5in)[L]|An A4 page, 1in margins (6.27in)[A]|A custom width[C]|The window (no page width)[W]')),%wdPageWidth,DEFAULT('L')
      #ENABLE(%wdPageWidth='C')
        #PROMPT('&Custom width (twips, 1440 = 1in):',SPIN(@n6,1440,31680,144)),%wdPageCustom,DEFAULT(9360)
      #ENDENABLE
    #ENDBOXED
    #BOXED('New documents')
      #DISPLAY('Leave blank / 0 for Segoe UI 11.')
      #PROMPT('Default &font:',@s31),%wdFont,DEFAULT('')
      #PROMPT('Default si&ze (points):',SPIN(@n2,0,72,1)),%wdSize,DEFAULT(0)
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Capture this instance's placeholder feq, check the BLOB really is one, and
#! decide whether it is saved with the record (only a BLOB of the primary table
#! of an update procedure is).
#ATSTART
  #DECLARE(%wdPlace)
  #FOR(%Control),WHERE(%ControlInstance=%ActiveTemplateInstance)
    #SET(%wdPlace,%Control)
  #ENDFOR
  #DECLARE(%wdSaveWithRecord)
  #SET(%wdSaveWithRecord,0)
  #DECLARE(%wdUpdFile)
  #SET(%wdUpdFile,%wdFormFile())
  #IF(%wdDisable=0 AND %wdBlob)
    #FIND(%Field,%wdBlob)
    #IF(UPPER(%Field)<>UPPER(%wdBlob))
      #ERROR(%Procedure & ': myWordDoc - ' & %wdBlob & ' is not a dictionary field')
    #ELSIF(%FieldType<>'BLOB')
      #ERROR(%Procedure & ': myWordDoc - ' & %wdBlob & ' is a ' & %FieldType & ', not a BLOB')
    #ELSIF(%wdAutoSave AND %wdUpdFile AND UPPER(%File)=UPPER(%wdUpdFile))
      #SET(%wdSaveWithRecord,1)
    #ENDIF
  #ENDIF
  #DECLARE(%wdWidthExpr)
  #CASE(%wdPageWidth)
  #OF('L')
    #SET(%wdWidthExpr,'WD:LetterWidth')
  #OF('A')
    #SET(%wdWidthExpr,'WD:A4Width')
  #OF('C')
    #SET(%wdWidthExpr,%wdPageCustom)
  #ELSE
    #SET(%wdWidthExpr,'0')
  #ENDCASE
#ENDAT
#!
#! The class goes in at PROGRAM-module global scope: a procedure in a MEMBER
#! module can see PROGRAM globals but not per-module custom declarations.
#AT(%AfterGlobalIncludes),WHERE(%wdDisable=0)
INCLUDE('WordDocClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%wdDisable=0 AND %wdPlace)
%[20]wdObject WordDocClass                          ! word processor over %wdPlace
#ENDAT
#!
#! After SELF.Open(window) (priority 8000) and before the resizer is set up
#! (8125). The record is already in the buffer by now - fetched by the browse
#! for a Change, primed for an Insert.
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8110),WHERE(%wdDisable=0 AND %wdPlace),DESCRIPTION('myWordDoc - create ' & %wdObject)
%wdObject.ShowToolbar = %wdToolbar
#IF(%wdSaveWithRecord)
%wdObject.ReadOnly    = CHOOSE(%wdReadOnly OR SELF.Request = ViewRecord)
#ELSE
%wdObject.ReadOnly    = %wdReadOnly
#ENDIF
%wdObject.PageView    = %wdPageView
%wdObject.PageWidth   = %wdWidthExpr
#IF(%wdFont)
%wdObject.DefaultFont = '%wdFont'
#ENDIF
#IF(%wdSize)
%wdObject.DefaultSize = %wdSize
#ENDIF
#IF(%wdBlob)
IF %wdObject.Init(0{PROP:Handle}, %wdPlace)
  %wdObject.LoadBlob(%wdBlob)
END
#ELSE
%wdObject.Init(0{PROP:Handle}, %wdPlace)
#ENDIF
#EMBED(%wdAfterInit,'myWordDoc - after the editor is created and loaded'),%ActiveTemplateInstance,HIDE
#ENDAT
#!
#! EVERY event - field events too, so a TAB change is seen - and AFTER the
#! parent call (5000), so the resizer has already moved the region. Inside the
#! framework's LOOP (2500) and before its "IF ReturnValue THEN RETURN" (7500).
#AT(%WindowManagerMethodCodeSection,'TakeEvent','(),BYTE'),PRIORITY(6000),WHERE(%wdDisable=0 AND %wdPlace),DESCRIPTION('myWordDoc - ' & %wdObject & ' follows its region')
%wdObject.TakeEvent()
#ENDAT
#!
#! Before the parent call writes the record (5000), after the SaveButton's
#! LOOP scaffolding (2500) and before a transaction frame starts (4000). On a
#! Change, only an edited document is written - the BLOB write is what tells
#! ABC the record changed, so an untouched form still closes without a PUT.
#AT(%WindowManagerMethodCodeSection,'TakeCompleted','(),BYTE'),PRIORITY(3500),WHERE(%wdDisable=0 AND %wdPlace AND %wdSaveWithRecord),DESCRIPTION('myWordDoc - save ' & %wdObject & ' into ' & %wdBlob)
IF SELF.Request = InsertRecord OR (SELF.Request <> ViewRecord AND SELF.Request <> DeleteRecord AND %wdObject.Modified())
  %wdObject.SaveBlob(%wdBlob)
END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(1),WHERE(%wdDisable=0 AND %wdPlace),DESCRIPTION('myWordDoc - destroy ' & %wdObject)
%wdObject.Kill()
#ENDAT
#!
#!#############################################################################
#!  EXTENSION - myWordDocReport
#!  Prints a BLOB on an ABC Report procedure: for every record the document is
#!  cut into pages the size of an IMAGE control, and that IMAGE's DETAIL band is
#!  PRINTed once per page.
#!#############################################################################
#EXTENSION(myWordDocReport,'myWordDoc - Print a BLOB document on this report'),PROCEDURE,MULTI,DESCRIPTION('myWordDoc - print ' & %wrBlob & ' through ' & %wrImage),HLP('~myWordDoc.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Disable',CHECK),%wrDisable,DEFAULT(0),AT(10)
      #PROMPT('&Object name:',@s64),%wrObject,REQ,DEFAULT('WordDocRpt' & %ActiveTemplateInstance)
    #ENDBOXED
    #BOXED('What is printed, and where')
      #PROMPT('&BLOB field:',FIELD),%wrBlob,REQ
      #PROMPT('Report &image:',FROM(%ReportControl,%ReportControlType='IMAGE',%ReportControl)),%wrImage,REQ
      #DISPLAY('An empty IMAGE in a DETAIL band, as wide as the document')
      #DISPLAY('and as tall as the most one report page can hold.')
      #PROMPT('&Detail band:',FROM(%ReportControl,%ReportControlType='DETAIL',%ReportControl)),%wrBand
      #DISPLAY('Blank = the band that holds the image. Give it a USE label.')
      #DISPLAY('The report no longer prints this band by itself - it is')
      #DISPLAY('printed here, once per page. Keep the image alone in it.')
    #ENDBOXED
    #BOXED('Options')
      #PROMPT('&Cut the document:',DROP('Fill the room left on each page, line by line[F]|In pieces the size of the image[P]')),%wrCut,DEFAULT('F')
      #ENABLE(%wrCut='P')
        #PROMPT('&Shrink the last piece to the text it holds',CHECK),%wrShrink,DEFAULT(1),AT(10)
      #ENDENABLE
      #PROMPT('&Print the document:',DROP('After the record''s other detail bands[A]|Before the record''s other detail bands[B]')),%wrOrder,DEFAULT('A')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#! Resolve the band (blank = the image's parent), its PRINT label and the
#! report prefix, check the BLOB, and take the band out of the report's own
#! detail printing.
#ATSTART
  #DECLARE(%wrReady)
  #DECLARE(%wrBandFeq)
  #DECLARE(%wrBandLabel)
  #DECLARE(%wrPre)
  #DECLARE(%wrReget)
  #SET(%wrReady,0)
  #IF(%wrDisable=0)
    #IF(UPPER(%ProcedureTemplate)<>'REPORT')
      #ERROR(%Procedure & ': myWordDocReport belongs on a Report procedure')
    #ELSE
      #FIND(%Field,%wrBlob)
      #IF(UPPER(%Field)<>UPPER(%wrBlob))
        #ERROR(%Procedure & ': myWordDocReport - ' & %wrBlob & ' is not a dictionary field')
      #ELSIF(%FieldType<>'BLOB')
        #ERROR(%Procedure & ': myWordDocReport - ' & %wrBlob & ' is a ' & %FieldType & ', not a BLOB')
      #ELSE
        #CALL(%wdKeyedGet,%wrReget)
        #CALL(%wrResolveBand,%wrBandFeq)
        #IF(%wrReget='')
          #ERROR(%Procedure & ': myWordDocReport - the table of ' & %wrBlob & ' needs a primary key')
        #ELSIF(%wrBandFeq='')
          #ERROR(%Procedure & ': myWordDocReport - the image must sit in a DETAIL band with a USE label')
        #ELSE
          #FIX(%ReportControl,%wrBandFeq)
          #SET(%wrBandLabel,%ReportControlLabel)
          #SET(%wrPre,EXTRACT(%ReportStatement,'PRE'))
          #IF(%wrPre)
            #SET(%wrPre,SUB(%wrPre,5,LEN(%wrPre)-5))
          #ENDIF
          #IF(%wrPre)
            #SET(%wrBandLabel,%wrPre & ':' & %wrBandLabel)
          #ENDIF
          #SET(%DetailFilterExternal,'False')
          #SET(%DetailFilterExclusive,1)
          #SET(%wrReady,1)
        #ENDIF
      #ENDIF
    #ENDIF
  #ENDIF
#ENDAT
#!
#! The Report procedure clears every band's external filter before it gathers
#! symbols, so set it again here - the same two steps ABC's own Child File
#! extension uses (ABREPORT.TPW, ReportChildFiles). An external filter of
#! 'False' drops the band from BOTH of the report's detail PRINT loops.
#AT(%GatherSymbols),WHERE(%wrDisable=0 AND UPPER(%ProcedureTemplate)='REPORT')
  #DECLARE(%wrGatherBand)
  #CALL(%wrResolveBand,%wrGatherBand)
  #IF(%wrGatherBand)
    #FIX(%ReportControl,%wrGatherBand)
    #SET(%DetailFilterExternal,'False')
    #SET(%DetailFilterExclusive,1)
  #ENDIF
#ENDAT
#!
#AT(%AfterGlobalIncludes),WHERE(%wrDisable=0)
INCLUDE('WordDocClass.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%wrReady)
%[20]wrObject WordDocClass                          ! prints %wrBlob through %wrImage
WDPage:%[13]wrObject LONG                                  ! page being printed
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Init','(),BYTE'),PRIORITY(8110),WHERE(%wrReady),DESCRIPTION('myWordDoc - create ' & %wrObject)
%wrObject.InitHidden()                                   ! an invisible document, no window
#ENDAT
#!
#! The report's own detail PRINTs are generated at priority 6000 of this
#! method; 5900 / 6100 put the document before / after them.
#AT(%ProcessManagerMethodCodeSection,'TakeRecord','(),BYTE'),PRIORITY(5900),WHERE(%wrReady AND %wrOrder='B'),DESCRIPTION('myWordDoc - print ' & %wrBlob)
#INSERT(%wdPrintLoop,%wrObject,%wrBlob,%Report,%wrImage,%wrBandLabel,%wrShrink,'WDPage:' & %wrObject,%wrReget,%wrCut)
#ENDAT
#AT(%ProcessManagerMethodCodeSection,'TakeRecord','(),BYTE'),PRIORITY(6100),WHERE(%wrReady AND %wrOrder<>'B'),DESCRIPTION('myWordDoc - print ' & %wrBlob)
#INSERT(%wdPrintLoop,%wrObject,%wrBlob,%Report,%wrImage,%wrBandLabel,%wrShrink,'WDPage:' & %wrObject,%wrReget,%wrCut)
#ENDAT
#!
#! Kill deletes the page metafiles from %TEMP%. ThisWindow.Kill runs after the
#! report is closed and previewed, so every page has been used by then.
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(1),WHERE(%wrReady),DESCRIPTION('myWordDoc - destroy ' & %wrObject)
%wrObject.Kill()
#ENDAT
#!
#!#############################################################################
#!  CODE TEMPLATE - myWordDocPrintBlob
#!  The print loop on its own, for any embed: a hand-coded report, a Process
#!  procedure, a report that prints several documents per record...
#!#############################################################################
#CODE(myWordDocPrintBlob,'myWordDoc - Print a BLOB document on a report (one band per page)'),DESCRIPTION('myWordDoc - print ' & %wcBlob & ' through ' & %wcImage),HLP('~myWordDoc.htm')
#SHEET
  #TAB('&General')
    #BOXED('Object')
      #PROMPT('&Object name:',@s64),%wcObject,REQ,DEFAULT('WordDocPrint' & %ActiveTemplateInstance)
      #PROMPT('&Declare it here (a hidden document of its own)',CHECK),%wcDeclare,DEFAULT(1),AT(10)
      #DISPLAY('Untick to print with an object declared elsewhere, e.g. by')
      #DISPLAY('the myWordDocReport extension.')
    #ENDBOXED
    #BOXED('What is printed, and where')
      #PROMPT('&BLOB field:',FIELD),%wcBlob,REQ
      #PROMPT('&Report label:',@s64),%wcReport,REQ,DEFAULT('Report')
      #PROMPT('Report &image (field equate):',@s64),%wcImage,REQ,DEFAULT('?Image1')
      #PROMPT('&Band to PRINT (label):',@s64),%wcBand,REQ,DEFAULT('RPT:Detail1')
      #DISPLAY('The detail band that holds the image, as PRINT names it -')
      #DISPLAY('with the report prefix. Do not let the report print it too.')
      #PROMPT('&Cut the document:',DROP('Fill the room left on each page, line by line[F]|In pieces the size of the image[P]')),%wcCut,DEFAULT('F')
      #ENABLE(%wcCut='P')
        #PROMPT('&Shrink the last piece to the text it holds',CHECK),%wcShrink,DEFAULT(1),AT(10)
      #ENDENABLE
      #PROMPT('Re-read the record by its &primary key first',CHECK),%wcReget,DEFAULT(1),AT(10)
      #DISPLAY('Needed inside a report or process loop: a VIEW read never')
      #DISPLAY('fills a BLOB - it keeps the previous record''s.')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!-----------------------------------------------------------------------------
#ATSTART
  #DECLARE(%wcRegetExpr)
  #IF(%wcReget)
    #FIND(%Field,%wcBlob)
    #CALL(%wdKeyedGet,%wcRegetExpr)
    #IF(%wcRegetExpr='')
      #ERROR(%Procedure & ': myWordDocPrintBlob - the table of ' & %wcBlob & ' has no primary key to re-read it by')
    #ENDIF
  #ENDIF
#ENDAT
#AT(%AfterGlobalIncludes)
INCLUDE('WordDocClass.INC'),ONCE
#ENDAT
#AT(%DataSection)
  #IF(%wcDeclare)
%[20]wcObject WordDocClass                          ! prints %wcBlob through %wcImage
  #ENDIF
WDPrint%ActiveTemplateInstance:Page    LONG
#ENDAT
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(1),WHERE(%wcDeclare)
%wcObject.Kill()
#ENDAT
#IF(%wcDeclare)
IF NOT %wcObject.Alive() THEN %wcObject.InitHidden().
#ENDIF
#INSERT(%wdPrintLoop,%wcObject,%wcBlob,%wcReport,%wcImage,%wcBand,%wcShrink,'WDPrint' & %ActiveTemplateInstance & ':Page',%wcRegetExpr,%wcCut)
#!
#!#############################################################################
#!  GROUPS
#!#############################################################################
#! The print loop, shared by the report extension and the code template.
#!
#! The keyed GET matters: a VIEW NEXT never fills a BLOB - it keeps the
#! PREVIOUS record's - and an ABC report reads through a VIEW. The class puts a
#! shrunk last-page IMAGE back to its designed size and forces the IMAGE to
#! re-read its file, so several documents can share one report.
#GROUP(%wdPrintLoop,%pObj,%pBlob,%pRpt,%pImg,%pBand,%pShrink,%pPage,%pReget,%pCut)
#IF(%pReget)
GET(%pReget)                                            ! a VIEW read leaves BLOBs untouched - fetch this record's
#ENDIF
%pObj.LoadBlob(%pBlob)
#IF(%pCut='P')
LOOP %pPage = 1 TO %pObj.PaginateForReport(%pRpt, %pImg, WD:Pages)
  %pObj.PreparePage(%pRpt, %pImg, %pPage, %pShrink)
#ELSE
LOOP %pPage = 1 TO %pObj.PaginateForReport(%pRpt, %pImg, WD:Flow)   ! line by line: fills the room left on the page
  %pObj.PreparePage(%pRpt, %pImg, %pPage)
#ENDIF
  PRINT(%pBand)
END
#!
#! The band that carries the document: the one named, or else the DETAIL that
#! holds the image. Blank when neither is a DETAIL with a USE label.
#GROUP(%wrResolveBand,*%pBand)
#SET(%pBand,%wrBand)
#IF(%pBand='')
  #FIX(%ReportControl,%wrImage)
  #IF(%ReportControl=%wrImage AND %ReportControlParentType='DETAIL')
    #SET(%pBand,%ReportControlParent)
  #ENDIF
#ENDIF
#IF(%pBand)
  #FIX(%ReportControl,%pBand)
  #IF(%ReportControl<>%pBand OR %ReportControlType<>'DETAIL')
    #SET(%pBand,'')
  #ENDIF
#ENDIF
#!
#! The table an update form saves: the primary file of the procedure's ABC
#! SaveButton. Blank on a window that is not an update form. (A control
#! template's own %Primary is ITS primary - always blank here.)
#GROUP(%wdFormFile),PRESERVE
#FIX(%ActiveTemplate,'SaveButton(ABC)')
#IF(%ActiveTemplate='SaveButton(ABC)')
  #FOR(%ActiveTemplateInstance)
    #CONTEXT(%Procedure,%ActiveTemplateInstance)
      #RETURN(%Primary)
    #ENDCONTEXT
  #ENDFOR
#ENDIF
#RETURN('')
#!
#! 'File, PrimaryKey' for a keyed GET of the table %File is fixed on (the caller
#! has just done #FIND(%Field,<blob>)). Blank when the table has no primary key.
#GROUP(%wdKeyedGet,*%pOut)
#SET(%pOut,'')
#FOR(%Key),WHERE(%KeyPrimary)
  #SET(%pOut,%File & ', ' & %Key)
  #BREAK
#ENDFOR
#!-----------------------------------------------------------------------------
#! End of myWordDoc template set
#!-----------------------------------------------------------------------------
