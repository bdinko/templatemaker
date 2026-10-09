! ============================================================================
!  Tools - the WordDocTools classes, one at a time, without AppGen.
!
!    Tools.exe            a window: the editor with find / replace / highlight,
!                         the font under the caret, and export to HTML,
!                         Markdown and text
!    Tools.exe AUTO       headless checks of every class -> tools_result.ini,
!                         and the exports in tools_out\
! ============================================================================
  PROGRAM

  INCLUDE('WordDocClass.INC'),ONCE
  INCLUDE('WordDocTools.INC'),ONCE

  MAP
AutoTest     PROCEDURE()
ToolsWindow  PROCEDURE(BYTE pEs=0)
DescribeEs   PROCEDURE(*RtfFontClass pFont),STRING
Check        PROCEDURE(STRING pKey,BYTE pOk,STRING pGot)
Has          PROCEDURE(STRING pText,STRING pPart),BYTE
    MODULE('kernel32')
CreateDirectoryA PROCEDURE(*CSTRING,LONG),LONG,PASCAL,RAW,PROC,NAME('CreateDirectoryA')
    END
  END

ResultFile   CSTRING(261)
Fails        LONG
OrdNumber    LONG                 ! a "file field" for the merge test (BIND)

  CODE
  ResultFile = LONGPATH() & '\tools_result.ini'
  CASE UPPER(CLIP(COMMAND(1)))
  OF 'AUTO'
    AutoTest()
  OF 'ES'
    ToolsWindow(TRUE)                              ! the window in Spanish, for the docs
  ELSE
    ToolsWindow()
  END

Check PROCEDURE(STRING pKey,BYTE pOk,STRING pGot)
L:G  STRING(300)
L:I  LONG
  CODE
  L:G = pGot
  LOOP L:I = 1 TO LEN(CLIP(L:G))
    IF VAL(L:G[L:I]) < 32 THEN L:G[L:I] = '|'.
  END
  PUTINI('tools', pKey, CHOOSE(pOk <> 0, 'ok', 'FAIL') & ' ' & CLIP(L:G), ResultFile)
  IF NOT pOk THEN Fails += 1.

Has PROCEDURE(STRING pText,STRING pPart)
  CODE
  RETURN CHOOSE(INSTRING(pPart, pText, 1, 1) > 0)

!------------------------------------------------------------------------------
AutoTest PROCEDURE()
Search   RtfSearchClass
Font     RtfFontClass
Text     RtfTextClass
Html     RtfHtmlClass
Md       RtfMarkdownClass
Merge    RtfMergeClass
L:N      LONG
L:M      LONG
L:P      LONG
L:S      STRING(400)
L:Big    &STRING
L:Rtf    STRING(2000)
L:Dir    CSTRING(261)
  CODE
  REMOVE(ResultFile)
  L:Dir = 'tools_out'
  CreateDirectoryA(L:Dir, 0)
  L:Dir = 'tools_out\img'
  CreateDirectoryA(L:Dir, 0)

  ! ---- RtfSearchClass ------------------------------------------------------
  Search.LoadFile('sample.rtf')
  L:N = Search.Count('clarion')
  Search.MatchCase = TRUE
  L:M = Search.Count('clarion')
  Search.MatchCase = FALSE
  Check('search.count', CHOOSE(L:N >= 3 AND L:M = 0), L:N & ' any case, ' & L:M & ' lower case')
  L:P = Search.Find('Clarion')
  Check('search.find', CHOOSE(L:P > 0 AND Search.TextAt(Search.FoundAt, Search.FoundEnd) = 'Clarion'), L:P & ' ' & Search.TextAt(Search.FoundAt, Search.FoundEnd))
  Check('search.context', Has(Search.Context(20), 'Clarion'), Search.Context(20))
  L:N = Search.FindNext()
  Check('search.next', CHOOSE(L:N > L:P), L:N)
  L:M = Search.FindPrevious()
  Check('search.previous', CHOOSE(L:M = L:P), L:M)
  Search.WholeWord = TRUE
  Check('search.wholeword', CHOOSE(Search.Count('Clar') = 0 AND Search.Count('Clarion') > 0), Search.Count('Clar') & '/' & Search.Count('Clarion'))
  Search.WholeWord = FALSE
  L:N = Search.Count('customer')
  L:M = Search.ReplaceAll('customer', 'client')
  Check('search.replaceall', CHOOSE(L:M = L:N AND L:N > 0 AND Search.Count('customer') = 0 AND Search.Count('client') >= L:N), L:N & ' -> ' & L:M)
  ! Replace: the first call finds, each later call replaces one and finds the next
  L:N = Search.Count('client')
  Search.Replace('client', 'reader')
  Search.Replace('client', 'reader')
  Check('search.replace', CHOOSE(Search.Count('client') = L:N - 1 AND Search.Count('reader') = 1), Search.Count('client') & ' left')
  L:N = Search.HighlightAll('BLOB')
  Font.Attach(Search.Doc)
  Font.Read(Search.Find('BLOB'))
  Check('search.highlight', CHOOSE(L:N > 0 AND Font.Highlight = COLOR:Yellow), L:N & ' hits, highlight ' & Font.Highlight)
  Search.HighlightAll('BLOB', COLOR:None)
  Font.Read(Search.Find('BLOB'))
  Check('search.unhighlight', CHOOSE(Font.Highlight = COLOR:None), Font.Highlight)
  Search.SaveFile('tools_out\replaced.rtf')
  Font.Kill()

  ! ---- RtfFontClass -------------------------------------------------------
  Font.LoadFile('sample.rtf')
  Font.Read(0)
  Check('font.read', CHOOSE(Font.Face = 'Georgia' AND Font.Size = 20 AND Font.Bold = 1 AND Font.Italic = 0 AND Font.Color = 0AF401EH), Font.Describe() & ' colour ' & Font.Color)
  Check('font.describe', CHOOSE(Font.Describe() = 'Georgia 20pt, bold'), Font.Describe())
  L:N = Font.FontCount()
  Check('font.list', CHOOSE(L:N >= 2 AND Has(Font.FontList(), 'Georgia') AND Has(Font.FontList(), 'Segoe UI')), L:N & ': ' & Font.FontList())
  Check('font.main', CHOOSE(Font.MainFont() = 'Segoe UI'), Font.MainFont())
  L:N = Font.ReplaceFont('Georgia', 'Cambria')
  Font.Read(0)
  Check('font.replace', CHOOSE(L:N > 0 AND Font.Face = 'Cambria' AND NOT Has(Font.FontList(), 'Georgia')), L:N & ' runs, ' & Font.FontList())
  Font.ScaleSizes(150)
  Font.Read(0)
  Check('font.scale', CHOOSE(Font.Size = 30), Font.Size)
  Font.SetFontAll('Arial')
  Check('font.setall', CHOOSE(Font.FontList() = 'Arial'), Font.FontList())
  Font.SetFontRange(0, 8, 'Courier New', 9)
  Font.Read(2)
  Check('font.range', CHOOSE(Font.Face = 'Courier New' AND Font.Size = 9), Font.Describe())
  Font.Read(-1)                                    ! the selection: the caret, untouched by the tools
  Check('font.selection', CHOOSE(Font.Face <> ''), Font.Describe())

  ! ---- RtfTextClass -------------------------------------------------------
  Text.LoadFile('sample.rtf')
  L:Big &= NEW STRING(LEN(Text.ToText()))
  L:Big = Text.ToText()
  Text.SaveText('tools_out\sample.txt')
  Check('text.start', CHOOSE(SUB(L:Big, 1, 15) = 'Customer letter'), SUB(L:Big, 1, 40))
  Check('text.bullets', Has(L:Big, '<13,10>- Formatting'), '')
  Check('text.cells', Has(L:Big, '<9>'), '')
  DISPOSE(L:Big)
  Check('text.counts', CHOOSE(Text.WordCount() > 100 AND Text.CharCount() > Text.CharCount(FALSE) AND Text.ParagraphCount() > 5), |
        Text.WordCount() & ' words, ' & Text.CharCount() & ' chars, ' & Text.CharCount(FALSE) & ' without spaces, ' & Text.ParagraphCount() & ' paragraphs')
  Check('text.objects', CHOOSE(Text.PictureCount() = 1 AND Text.TableCount() = 1), Text.PictureCount() & ' picture(s), ' & Text.TableCount() & ' table(s)')
  L:S = Text.Excerpt(60)
  Check('text.excerpt', CHOOSE(LEN(CLIP(L:S)) <= 63 AND SUB(CLIP(L:S), LEN(CLIP(L:S)) - 2, 3) = '...'), L:S)
  Check('text.isrtf', CHOOSE(Text.IsRtf(Text.GetRtf()) AND NOT Text.IsRtf('hello')), '')
  L:S = 'Line one {{braces} \back' & '<13,10>' & 'Caf' & CHR(233) & '<9>tab'
  Text.LoadString(Text.TextToRtf(L:S, 'Georgia', 12))
  Text.ListPrefixes = FALSE
  Check('text.roundtrip', CHOOSE(Text.ToText() = CLIP(L:S)), Text.ToText())
  Font.Attach(Text.Doc)
  Font.Read(0)
  Check('text.torftfont', CHOOSE(Font.Face = 'Georgia' AND Font.Size = 12), Font.Describe())
  Font.Kill()

  ! numbered list + Markdown/HTML of it
  L:Rtf = '{{\rtf1\ansi\deff0{{\fonttbl{{\f0 Segoe UI;}}' & |
          '{{\pard\f0\fs22 Steps:\par}' & |
          '{{\pard{{\pntext 1.\tab}{{\*\pn\pnlvlbody\pnf0\pnindent360\pnstart1\pndec{{\pntxta.}}\fi-360\li360\f0\fs22 Open the file\par}' & |
          '{{\pard{{\pntext 2.\tab}{{\*\pn\pnlvlbody\pnf0\pnindent360\pnstart1\pndec{{\pntxta.}}\fi-360\li360\f0\fs22 Print it\par}' & |
          '{{\pard\f0\fs22 Done.\par}}'
  Text.ListPrefixes = TRUE
  Text.LoadString(L:Rtf)
  L:S = Text.ToText()
  Check('text.numbers', CHOOSE(Has(L:S, '1. Open the file') AND Has(L:S, '2. Print it')), L:S)

  ! ---- RtfHtmlClass -------------------------------------------------------
  Html.LoadFile('sample.rtf')
  Html.Title = 'Customer letter'
  Html.SaveHtml('tools_out\sample.html')
  Html.LoadFile('sample_es.rtf')
  Html.Title = 'Carta al cliente'
  Html.SaveHtml('tools_out\sample_es.html')
  Html.LoadFile('sample.rtf')
  Html.Title = 'Customer letter'
  L:Big &= NEW STRING(LEN(Html.ToHtml()))
  L:Big = Html.ToHtml()
  Check('html.page', CHOOSE(SUB(L:Big, 1, 15) = '<<!DOCTYPE html>' AND Has(L:Big, '<<title>Customer letter<</title>')), SUB(L:Big, 1, 15))
  Check('html.table', Has(L:Big, '<<table'), '')
  Check('html.picture', Has(L:Big, '<<img alt="picture 1" src="data:image/png;base64,iVBOR'), '')
  Check('html.list', Has(L:Big, '<<ul'), '')
  Check('html.bold', Has(L:Big, '<<b>Formatting<</b>'), '')
  Check('html.colour', Has(L:Big, 'color:#1E40AF'), '')
  Check('html.highlight', Has(L:Big, 'background-color:#FFFF00'), '')
  Check('html.headfont', Has(L:Big, 'font-family:''Georgia'''), '')
  DISPOSE(L:Big)
  Html.FullPage = FALSE
  L:S = Html.ToHtml()
  Check('html.fragment', CHOOSE(SUB(L:S, 1, 4) = '<<div'), SUB(L:S, 1, 40))
  Html.FullPage = TRUE
  Html.ImageFolder = 'tools_out\img'
  Html.ImageUrl = 'img/'
  Html.SaveHtml('tools_out\sample_files.html')
  Check('html.imagefile', CHOOSE(EXISTS('tools_out\img\image1.png') AND Has(Html.ToHtml(), 'src="img/image1.png"')), '')
  Html.LoadString(L:Rtf)
  Check('html.ol', Has(Html.ToHtml(), '<<ol style="margin:0;" type="1" start="1">'), '')

  ! pictures that are not PNG/JPEG are drawn and encoded as PNG
  Html.LoadFile('sample.rtf')
  Html.Doc.Paginate(WD:LetterWidth, 5000)
  Html.Doc.RenderPageTo(1, 'tools_out\page1.emf')
  Html.Doc.RenderPageTo(1, 'tools_out\page1.wmf')
  Html.LoadString('Pictures:')
  Html.Doc.SelectText(99999, 99999)
  Html.Doc.InsertImage('test.bmp')
  L:N = Html.Doc.InsertImage('tools_out\page1.emf', 4000)
  L:M = Html.Doc.InsertImage('tools_out\page1.wmf', 4000)
  Html.Doc.Paginate(WD:LetterWidth, 14000)
  Html.Doc.RenderPageTo(1, 'tools_out\pictures_page.wmf')
  L:Dir = 'tools_out\pics'
  CreateDirectoryA(L:Dir, 0)
  Html.ImageFolder = 'tools_out\pics'
  Html.ImageUrl = 'pics/'
  Html.SaveHtml('tools_out\pictures.html')
  Html.Doc.SaveFile('tools_out\pictures.rtf')
  Text.Attach(Html.Doc)
  Check('html.convert', CHOOSE(EXISTS('tools_out\pics\image1.png') AND EXISTS('tools_out\pics\image2.png') AND EXISTS('tools_out\pics\image3.png')), Text.PictureCount() & ' pictures in the document')
  Text.Kill()
  Html.ImageFolder = ''
  Html.ImageUrl = ''

  ! ---- RtfMarkdownClass ---------------------------------------------------
  Md.LoadFile('sample.rtf')
  Md.SaveMarkdown('tools_out\sample.md')
  L:Big &= NEW STRING(LEN(Md.ToMarkdown()))
  L:Big = Md.ToMarkdown()
  Check('md.heading', CHOOSE(SUB(L:Big, 1, 17) = '# Customer letter'), SUB(L:Big, 1, 30))
  Check('md.bullet', Has(L:Big, '- **Formatting**'), '')
  Check('md.table', Has(L:Big, '| --- |'), '')
  Check('md.picture', Has(L:Big, '![picture 1](data:image/png;base64,'), '')
  DISPOSE(L:Big)
  Md.LoadString(L:Rtf)
  L:S = Md.ToMarkdown()
  Check('md.numbers', CHOOSE(Has(L:S, '1. Open the file') AND Has(L:S, '2. Print it')), L:S)

  ! ---- RtfMergeClass ------------------------------------------------------
  Merge.LoadString('{{\rtf1\ansi\deff0{{\fonttbl{{\f0 Segoe UI;}}\f0\fs22 Dear \b [[Name]]\b0 , order [[ORD:Number]] ships [[When]]. [[Unknown]]\par}')
  Merge.SetField('Name', 'Ana Lopez')
  Merge.SetField('When', 'on Monday')
  OrdNumber = 4711
  BIND('ORD:Number', OrdNumber)
  Check('merge.fields', CHOOSE(Merge.FieldCount() = 4 AND Merge.FieldName(1) <> ''), Merge.FieldCount() & ' fields')
  Check('merge.missing', CHOOSE(Merge.Missing() = 'Unknown'), Merge.Missing())
  L:N = Merge.Merge()
  Text.Attach(Merge.Doc)
  Text.ListPrefixes = FALSE
  Check('merge.result', CHOOSE(L:N = 3 AND Text.ToText() = 'Dear Ana Lopez, order 4711 ships on Monday. [[Unknown]]'), L:N & ': ' & Text.ToText())
  Font.Attach(Merge.Doc)
  Font.Read(6)
  Check('merge.keepsbold', CHOOSE(Font.Bold = 1), Font.Describe())
  Merge.BlankUnknown = TRUE
  Merge.Merge()
  Check('merge.blank', CHOOSE(Text.ToText() = 'Dear Ana Lopez, order 4711 ships on Monday. '), Text.ToText())
  Text.Kill()
  Font.Kill()

  ! ---- Undo: every tool operation is ONE step ------------------------------
  Search.LoadFile('sample.rtf')
  Check('undo.afterload', CHOOSE(NOT Search.CanUndo()), 'nothing to undo after a load')
  L:N = Search.ReplaceAll('Clarion', 'CLARION')
  Search.MatchCase = TRUE
  Search.Undo()
  Check('undo.replaceall', CHOOSE(L:N > 10 AND Search.Count('Clarion') = L:N AND Search.Count('CLARION') = 0), L:N & ' replaced, one Undo -> ' & Search.Count('Clarion') & ' back')
  Search.Redo()
  Check('undo.redo', CHOOSE(Search.Count('CLARION') = L:N), Search.Count('CLARION'))
  Search.Undo()
  Search.MatchCase = FALSE
  Font.Attach(Search.Doc)
  Font.SetFontAll('Arial', 14)
  Search.Undo()
  Check('undo.setfontall', CHOOSE(Has(Font.FontList(), 'Georgia') AND Font.MainFont() = 'Segoe UI'), Font.FontList())
  Search.HighlightAll('BLOB')
  Search.Undo()
  Font.Read(Search.Find('BLOB'))
  Check('undo.highlight', CHOOSE(Font.Highlight = COLOR:None), Font.Highlight)
  Font.ScaleSizes(200)
  Font.ReplaceFont('Georgia', 'Cambria')
  Search.Undo()
  Font.Read(0)
  Check('undo.steps', CHOOSE(Font.Face = 'Georgia' AND Font.Size = 40), 'one Undo takes back only the last tool: ' & Font.Describe())
  Search.Undo()
  Font.Read(0)
  Check('undo.steps2', CHOOSE(Font.Size = 20), Font.Describe())
  ! your own edits grouped
  Search.Doc.BeginUndoGroup()
  Search.Doc.SelectText(0, 0)
  Search.Doc.InsertText('One ')
  Search.Doc.InsertText('two ')
  Search.Doc.SelectText(0, 3)
  Search.Doc.Bold(WD:On)
  Search.Doc.EndUndoGroup()
  Search.Undo()
  Check('undo.group', CHOOSE(Search.Count('One two') = 0 AND Search.TextAt(0, 8) = 'Customer'), Search.TextAt(0, 15))
  Font.Kill()
  Merge.LoadString('{{\rtf1\ansi\deff0{{\fonttbl{{\f0 Segoe UI;}}\f0\fs22 Dear [[Name]], see you [[When]].\par}')
  Merge.SetField('Name', 'Ana')
  Merge.SetField('When', 'soon')
  Merge.Merge()
  Merge.Undo()
  Check('undo.merge', CHOOSE(Merge.FieldCount() = 2), Merge.FieldCount() & ' placeholders back after one Undo')

  PUTINI('tools', 'fails', Fails, ResultFile)


!------------------------------------------------------------------------------
ToolsWindow PROCEDURE(BYTE pEs=0)
Doc        WordDocClass
Search     RtfSearchClass
Font       RtfFontClass
Text       RtfTextClass
Html       RtfHtmlClass
Md         RtfMarkdownClass
L:Find     STRING(60)
L:With     STRING(60)
L:Status   STRING(200)
L:Info     STRING(200)
L:Dir      CSTRING(261)

Window WINDOW('WordDocTools'),AT(,,560,330),CENTER,GRAY,SYSTEM,FONT('Segoe UI',9),RESIZE,TIMER(25)
         PROMPT('Find:'),AT(6,8),USE(?FindPrompt)
         ENTRY(@s60),AT(30,6,90,12),USE(L:Find)
         BUTTON('&Find'),AT(124,5,34,14),USE(?FindBtn)
         BUTTON('&Next'),AT(160,5,34,14),USE(?NextBtn)
         BUTTON('&Prev'),AT(196,5,34,14),USE(?PrevBtn)
         PROMPT('Replace with:'),AT(238,8),USE(?WithPrompt)
         ENTRY(@s60),AT(286,6,80,12),USE(L:With)
         BUTTON('&Replace'),AT(370,5,40,14),USE(?ReplaceBtn)
         BUTTON('Replace &all'),AT(412,5,48,14),USE(?AllBtn)
         BUTTON('&Highlight all'),AT(462,5,52,14),USE(?MarkBtn)
         REGION,AT(6,24,548,264),USE(?DocRegion)
         STRING(@s200),AT(6,292,548,10),USE(L:Status)
         STRING(@s200),AT(6,302,548,10),USE(L:Info)
         BUTTON('Fonts used'),AT(6,314,50,14),USE(?FontsBtn)
         BUTTON('All in Georgia'),AT(58,314,56,14),USE(?GeorgiaBtn)
         BUTTON('Bigger (120%)'),AT(116,314,56,14),USE(?BiggerBtn)
         BUTTON('Counts'),AT(174,314,40,14),USE(?CountBtn)
         BUTTON('Save as HTML'),AT(330,314,56,14),USE(?HtmlBtn)
         BUTTON('Save as Markdown'),AT(388,314,66,14),USE(?MdBtn)
         BUTTON('Save as text'),AT(456,314,50,14),USE(?TxtBtn)
         BUTTON('Close'),AT(508,314,46,14),USE(?CloseBtn),STD(STD:Close)
       END
  CODE
  L:Dir = LONGPATH()
  OPEN(Window)
  Doc.PageWidth = WD:LetterWidth
  Doc.PageView = TRUE
  Doc.Init(0{PROP:Handle}, ?DocRegion)
  IF pEs
    0{PROP:Text} = 'WordDocTools - clases RTF'
    ?FindPrompt{PROP:Text} = 'Buscar:'
    ?FindBtn{PROP:Text} = '&Buscar'
    ?NextBtn{PROP:Text} = '&Sig.'
    ?PrevBtn{PROP:Text} = '&Ant.'
    ?WithPrompt{PROP:Text} = 'Reemplazar por:'
    ?ReplaceBtn{PROP:Text} = '&Reemplazar'
    ?AllBtn{PROP:Text} = '&Todos'
    ?MarkBtn{PROP:Text} = 'Res&altar todos'
    ?FontsBtn{PROP:Text} = 'Fuentes'
    ?GeorgiaBtn{PROP:Text} = 'Todo en Georgia'
    ?BiggerBtn{PROP:Text} = 'M' & CHR(225) & 's grande'
    ?CountBtn{PROP:Text} = 'Contar'
    ?HtmlBtn{PROP:Text} = 'Guardar HTML'
    ?MdBtn{PROP:Text} = 'Guardar Markdown'
    ?TxtBtn{PROP:Text} = 'Guardar texto'
    ?CloseBtn{PROP:Text} = 'Cerrar'
    Doc.LoadFile('sample_es.rtf')
  ELSE
    Doc.LoadFile('sample.rtf')
  END
  Search.Attach(Doc)                               ! every tool works on the editor itself
  Font.Attach(Doc)
  Text.Attach(Doc)
  Html.Attach(Doc)
  Md.Attach(Doc)
  L:Find = 'Clarion'
  L:With = 'Clarion 12'
  DISPLAY
  ACCEPT
    Doc.TakeEvent()
    CASE EVENT()
    OF EVENT:Timer
      Font.Read()                                  ! what font am I on?
      IF pEs
        IF L:Status <> 'Cursor: ' & DescribeEs(Font)
          L:Status = 'Cursor: ' & DescribeEs(Font)
          DISPLAY(?L:Status)
        END
      ELSIF L:Status <> 'Caret: ' & Font.Describe()
        L:Status = 'Caret: ' & Font.Describe()
        DISPLAY(?L:Status)
      END
    END
    CASE ACCEPTED()
    OF ?FindBtn
      IF Search.Find(L:Find) < 0
        L:Info = '"' & CLIP(L:Find) & '" is not in the document'
      ELSE
        L:Info = Search.Count(L:Find) & ' found. First at ' & Search.FoundAt & ': ' & Search.Context(30)
      END
      DISPLAY(?L:Info)
    OF ?NextBtn
      Search.What = CLIP(L:Find)
      IF Search.FindNext() >= 0 THEN L:Info = 'At ' & Search.FoundAt & ': ' & Search.Context(30); DISPLAY(?L:Info).
    OF ?PrevBtn
      Search.What = CLIP(L:Find)
      IF Search.FindPrevious() >= 0 THEN L:Info = 'At ' & Search.FoundAt & ': ' & Search.Context(30); DISPLAY(?L:Info).
    OF ?ReplaceBtn
      Search.Replace(L:Find, L:With)
    OF ?AllBtn
      L:Info = Search.ReplaceAll(L:Find, L:With) & ' replaced'
      DISPLAY(?L:Info)
    OF ?MarkBtn
      L:Info = Search.HighlightAll(L:Find) & CHOOSE(pEs <> 0, ' resaltados', ' highlighted')
      DISPLAY(?L:Info)
    OF ?FontsBtn
      L:Info = Font.FontCount() & ' fonts: ' & Font.FontList() & '. Most of the text: ' & Font.MainFont()
      DISPLAY(?L:Info)
    OF ?GeorgiaBtn
      Font.SetFontAll('Georgia')
    OF ?BiggerBtn
      Font.ScaleSizes(120)
    OF ?CountBtn
      L:Info = Text.WordCount() & ' words, ' & Text.CharCount() & ' characters, ' & Text.ParagraphCount() & ' paragraphs, ' & |
               Text.PictureCount() & ' picture(s), ' & Text.TableCount() & ' table(s)'
      DISPLAY(?L:Info)
    OF ?HtmlBtn
      Html.Title = 'WordDocTools'
      IF Html.SaveHtml(L:Dir & '\tools_window.html')
        RUN('explorer "' & L:Dir & '\tools_window.html"')
      END
    OF ?MdBtn
      IF Md.SaveMarkdown(L:Dir & '\tools_window.md') THEN RUN('notepad "' & L:Dir & '\tools_window.md"').
    OF ?TxtBtn
      IF Text.SaveText(L:Dir & '\tools_window.txt') THEN RUN('notepad "' & L:Dir & '\tools_window.txt"').
    END
  END
  Doc.Kill()
  CLOSE(Window)


! Font.Describe() in Spanish (the class itself describes in English)
DescribeEs PROCEDURE(*RtfFontClass pFont)
L:S  CSTRING(200)
  CODE
  L:S = CHOOSE(pFont.Face = '', 'fuentes mezcladas', pFont.Face)
  IF pFont.Size = 0
    L:S = L:S & ', tama' & CHR(241) & 'os mezclados'
  ELSE
    L:S = L:S & ' ' & pFont.Size & ' pt'
  END
  IF pFont.Bold = 1 THEN L:S = L:S & ', negrita'.
  IF pFont.Italic = 1 THEN L:S = L:S & ', cursiva'.
  IF pFont.Underline = 1 THEN L:S = L:S & ', subrayado'.
  IF pFont.Strike = 1 THEN L:S = L:S & ', tachado'.
  RETURN L:S
