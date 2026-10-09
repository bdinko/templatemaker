# -*- coding: utf-8 -*-
# The words of docs/myWordDoc-template.html, English and Spanish side by side.
# Each section is a function of g (make_docs' helpers: clw, bi, sp, shot).

FOOT_EN = ("myWordDoc - Programmer's Documentation. Written from the shipped source "
           "(wdoc.c, WordDocClass.inc/.clw, WordDocTools.inc/.clw, myWordDoc.tpl). "
           "Regenerate with <code>python examples/myWordDoc/docgen/make_docs.py</code>.")
FOOT_ES = ("myWordDoc - Documentaci\u00f3n del programador. Escrita a partir del c\u00f3digo distribuido "
           "(wdoc.c, WordDocClass.inc/.clw, WordDocTools.inc/.clw, myWordDoc.tpl). "
           "Se regenera con <code>python examples/myWordDoc/docgen/make_docs.py</code>.")

REF_CONV = '''      <div class="en">
      <p>The examples assume these declarations:</p>
      <pre>  <span class="k">INCLUDE</span>(<span class="s">'WordDocClass.INC'</span>),<span class="k">ONCE</span>
  <span class="k">INCLUDE</span>(<span class="s">'WordDocTools.INC'</span>),<span class="k">ONCE</span>
Doc1     WordDocClass            <span class="c">! an editor on a window (or a hidden document)</span>
Search   RtfSearchClass
Font     RtfFontClass
Text     RtfTextClass
Html     RtfHtmlClass
Md       RtfMarkdownClass
Merge    RtfMergeClass</pre>
      <ul>
        <li>Positions are <b>0-based character positions</b>; a paragraph break counts as one.</li>
        <li>Sizes in <b>twips</b> are 1/1440 inch: 720 = half an inch, 1440 = an inch.</li>
        <li>Colours are Clarion colours (<code>COLOR:Red</code>, <code>0F0FFFFh</code>); <code>COLOR:None</code> means automatic.</li>
        <li>Methods marked <code>PROC</code> can be called as a statement, ignoring the result.</li>
      </ul>
      </div>
      <div class="es">
      <p>Los ejemplos suponen estas declaraciones:</p>
      <pre>  <span class="k">INCLUDE</span>(<span class="s">'WordDocClass.INC'</span>),<span class="k">ONCE</span>
  <span class="k">INCLUDE</span>(<span class="s">'WordDocTools.INC'</span>),<span class="k">ONCE</span>
Doc1     WordDocClass            <span class="c">! un editor en una ventana (o un documento oculto)</span>
Search   RtfSearchClass
Font     RtfFontClass
Text     RtfTextClass
Html     RtfHtmlClass
Md       RtfMarkdownClass
Merge    RtfMergeClass</pre>
      <ul>
        <li>Las posiciones son <b>posiciones de car\u00e1cter desde 0</b>; un salto de p\u00e1rrafo cuenta como uno.</li>
        <li>Los tama\u00f1os en <b>twips</b> son 1/1440 de pulgada: 720 = media pulgada, 1440 = una pulgada.</li>
        <li>Los colores son colores de Clarion (<code>COLOR:Red</code>, <code>0F0FFFFh</code>); <code>COLOR:None</code> significa autom\u00e1tico.</li>
        <li>Los m\u00e9todos con <code>PROC</code> se pueden llamar como sentencia, ignorando el resultado.</li>
      </ul>
      </div>'''

NAV = [
    ('h1', 'over', 'Overview', 'Resumen'),
    ('grp', 'Getting it in', 'Puesta en marcha'),
    ('h2', 'install', 'Install &amp; register', 'Instalar y registrar'),
    ('h2', 'templates', 'The four templates', 'Las cuatro plantillas'),
    ('grp', 'The editor', 'El editor'),
    ('h2', 'editor', 'On a window', 'En una ventana'),
    ('h2', 'toolbar', 'Toolbar &amp; keys', 'Barra y teclas'),
    ('h2', 'storage', 'One BLOB, plain RTF', 'Un BLOB, RTF normal'),
    ('h2', 'undo', 'Undo', 'Deshacer'),
    ('grp', 'Printing', 'Impresi\u00f3n'),
    ('h2', 'report', 'In a REPORT', 'En un REPORT'),
    ('h2', 'flow', 'WD:Flow and WD:Pages', 'WD:Flow y WD:Pages'),
    ('h2', 'wmf', 'Why WMF', 'Por qu\u00e9 WMF'),
    ('grp', 'RTF tool classes', 'Clases RTF'),
    ('h2', 'tools', 'Six classes', 'Seis clases'),
    ('h2', 'search', 'Find &amp; replace', 'Buscar y reemplazar'),
    ('h2', 'fonts', 'Fonts', 'Fuentes'),
    ('h2', 'text', 'Plain text', 'Texto plano'),
    ('h2', 'html', 'HTML &amp; Markdown', 'HTML y Markdown'),
    ('h2', 'merge', 'Mail merge', 'Combinar correspondencia'),
    ('grp', 'Inside', 'Por dentro'),
    ('h2', 'inside', 'How it is built', 'C\u00f3mo est\u00e1 hecho'),
    ('h2', 'tests', 'Demos &amp; tests', 'Demos y pruebas'),
    ('grp', 'Reference', 'Referencia'),
    ('h2', 'ref', 'Class reference', 'Referencia de clases'),
    ('h2', 'quirks', 'Known limits', 'L\u00edmites conocidos'),
    ('h2', 'trouble', 'Troubleshooting', 'Problemas'),
]

HERO = '''    <header class="hero">
      <h1>myWordDoc</h1>
      <p class="en">A <b>word processor for Clarion</b>, stored in a <b>BLOB</b>, that also <b>prints through a Clarion
         REPORT</b>. Fonts, colours, lists, pictures and tables; search and replace, fonts in use, plain text, HTML,
         Markdown and mail merge from code. No COM, no OCX, no DLL to ship: the control is C compiled into your exe by
         Clarion's own compiler.</p>
      <p class="es">Un <b>procesador de textos para Clarion</b>, guardado en un <b>BLOB</b>, que adem\u00e1s <b>imprime con un
         REPORT de Clarion</b>. Fuentes, colores, listas, im\u00e1genes y tablas; buscar y reemplazar, fuentes usadas, texto plano,
         HTML, Markdown y combinaci\u00f3n de correspondencia desde c\u00f3digo. Sin COM, sin OCX, sin DLL que distribuir: el control
         es C que compila dentro de tu exe el propio compilador de Clarion.</p>
      <span class="pill en">RTF in a BLOB \u00b7 vector printing \u00b7 fills the page \u00b7 6 tool classes \u00b7 one-step undo \u00b7 EN / ES</span>
      <span class="pill es">RTF en un BLOB \u00b7 impresi\u00f3n vectorial \u00b7 llena la p\u00e1gina \u00b7 6 clases \u00b7 deshacer en un paso \u00b7 EN / ES</span>
    </header>'''


def s_over(g):
    return '''      <div class="en">
      <p class="lead">Drop the editor on a form, point it at a BLOB, and users get a real word processor. Put the report
        extension on a report and every record's document prints, as vectors, filling each page.</p>
      <table>
        <tr><th>&nbsp;</th><th>myWordDoc</th></tr>
        <tr><td>Needs a DLL / OCX / COM</td><td><b>No</b>: <code>wdoc.c</code> is compiled into the exe by Clarion</td></tr>
        <tr><td>Storage</td><td>Ordinary RTF in one BLOB: Word and WordPad open it</td></tr>
        <tr><td>Editing</td><td>Fonts, sizes, bold/italic/underline/strike, colour, highlight, alignment, bullets, numbering, indents, pictures, tables</td></tr>
        <tr><td>Printing</td><td>Through a Clarion REPORT, as vector metafiles; starts in the room left on a page</td></tr>
        <tr><td>From code</td><td>Search &amp; replace, fonts, plain text, HTML, Markdown, mail merge</td></tr>
        <tr><td>Undo</td><td>Ctrl+Z / toolbar; a whole tool operation is one step</td></tr>
        <tr><td>Templates</td><td>Editor control, report extension, print code template, global extension (ABC)</td></tr>
      </table>
      </div>
      <div class="es">
      <p class="lead">Pon el editor en un formulario, ap\u00fantalo a un BLOB, y el usuario tiene un procesador de textos de verdad.
        Pon la extensi\u00f3n en un informe y se imprime el documento de cada registro, en vectorial, llenando cada p\u00e1gina.</p>
      <table>
        <tr><th>&nbsp;</th><th>myWordDoc</th></tr>
        <tr><td>Necesita DLL / OCX / COM</td><td><b>No</b>: Clarion compila <code>wdoc.c</code> dentro del exe</td></tr>
        <tr><td>Almacenamiento</td><td>RTF normal en un BLOB: lo abren Word y WordPad</td></tr>
        <tr><td>Edici\u00f3n</td><td>Fuentes, tama\u00f1os, negrita/cursiva/subrayado/tachado, color, resaltado, alineaci\u00f3n, vi\u00f1etas, numeraci\u00f3n, sangr\u00edas, im\u00e1genes, tablas</td></tr>
        <tr><td>Impresi\u00f3n</td><td>Con un REPORT de Clarion, como metarchivos vectoriales; empieza en el hueco libre de la p\u00e1gina</td></tr>
        <tr><td>Desde c\u00f3digo</td><td>Buscar y reemplazar, fuentes, texto plano, HTML, Markdown, combinaci\u00f3n de correspondencia</td></tr>
        <tr><td>Deshacer</td><td>Ctrl+Z / barra; una operaci\u00f3n de herramienta entera es un paso</td></tr>
        <tr><td>Plantillas</td><td>Control de editor, extensi\u00f3n de informe, plantilla de c\u00f3digo, extensi\u00f3n global (ABC)</td></tr>
      </table>
      </div>
''' + g['shot']('myWordDoc-tools-window.png',
                'The editor with the tool classes attached: every "Clarion" highlighted by one call, and the font under the caret shown below.',
                'El editor con las clases de herramientas: cada "Clarion" resaltado con una llamada y la fuente bajo el cursor abajo.')


def s_install(g):
    return '''      <div class="en">
      <p>Five source files and one template:</p>
      <div class="filetree">templates/myWordDoc/<br>
&nbsp;&nbsp;template/win/<br>
&nbsp;&nbsp;&nbsp;&nbsp;myWordDoc.tpl &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;the AppGen templates<br>
&nbsp;&nbsp;libsrc/win/<br>
&nbsp;&nbsp;&nbsp;&nbsp;wdoc.c &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;the control and the tools engine (C)<br>
&nbsp;&nbsp;&nbsp;&nbsp;WordDocClass.inc / .clw &nbsp;the editor class<br>
&nbsp;&nbsp;&nbsp;&nbsp;WordDocTools.inc / .clw &nbsp;the six RTF tool classes</div>
      <ol>
        <li>Copy the five source files to <code>accessory\\libsrc\\win</code> (or any folder on the redirection path), saved as
          <b>ANSI with CRLF</b> line endings.</li>
        <li>Copy <code>myWordDoc.tpl</code> to <code>accessory\\template\\win</code> and register it (Setup &rarr; Template Registry &rarr; Register).</li>
        <li>Restart the IDE so it reads the new template, then regenerate.</li>
      </ol>
      <p>There is nothing to add to a project: <code>WordDocClass.clw</code> carries <code>PRAGMA('compile(wdoc.c)')</code>, and each
        class has a <code>LINK</code> attribute, so the C and the Clarion modules come in by themselves.
        <code>msftedit.dll</code> ships with every Windows since XP SP1.</p>
      <div class="callout tip"><b>Hand-coded program</b>Just <code>INCLUDE('WordDocClass.INC'),ONCE</code> and, for the tools,
        <code>INCLUDE('WordDocTools.INC'),ONCE</code>.</div>
      </div>
      <div class="es">
      <p>Cinco ficheros fuente y una plantilla:</p>
      <div class="filetree">templates/myWordDoc/<br>
&nbsp;&nbsp;template/win/<br>
&nbsp;&nbsp;&nbsp;&nbsp;myWordDoc.tpl &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;las plantillas de AppGen<br>
&nbsp;&nbsp;libsrc/win/<br>
&nbsp;&nbsp;&nbsp;&nbsp;wdoc.c &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;el control y el motor de las herramientas (C)<br>
&nbsp;&nbsp;&nbsp;&nbsp;WordDocClass.inc / .clw &nbsp;la clase del editor<br>
&nbsp;&nbsp;&nbsp;&nbsp;WordDocTools.inc / .clw &nbsp;las seis clases RTF</div>
      <ol>
        <li>Copia los cinco ficheros fuente en <code>accessory\\libsrc\\win</code> (o cualquier carpeta del redirection), guardados en
          <b>ANSI con finales CRLF</b>.</li>
        <li>Copia <code>myWordDoc.tpl</code> en <code>accessory\\template\\win</code> y reg\u00edstrala (Setup &rarr; Template Registry &rarr; Register).</li>
        <li>Reinicia el IDE para que lea la plantilla nueva y vuelve a generar.</li>
      </ol>
      <p>No hay que a\u00f1adir nada al proyecto: <code>WordDocClass.clw</code> lleva <code>PRAGMA('compile(wdoc.c)')</code> y cada clase tiene
        atributo <code>LINK</code>, as\u00ed que el C y los m\u00f3dulos Clarion entran solos. <code>msftedit.dll</code> viene con todo Windows desde XP SP1.</p>
      <div class="callout tip"><b>Programa a mano</b>Basta con <code>INCLUDE('WordDocClass.INC'),ONCE</code> y, para las herramientas,
        <code>INCLUDE('WordDocTools.INC'),ONCE</code>.</div>
      </div>'''


def s_templates(g):
    return '''      <div class="en">
      <table>
        <tr><th>Template</th><th>Kind</th><th>What it does</th></tr>
        <tr><td><code>myWordDocGlobal</code></td><td>application extension (optional)</td><td>Includes the editor class and the tool classes in every procedure, for hand code. One switch turns myWordDoc off everywhere.</td></tr>
        <tr><td><code>myWordDocEditor</code></td><td>control template on a REGION</td><td>The editor on a window or form, tied to a BLOB field. MULTI.</td></tr>
        <tr><td><code>myWordDocReport</code></td><td>report extension</td><td>Prints each record's BLOB document through a report IMAGE.</td></tr>
        <tr><td><code>myWordDocPrintBlob</code></td><td>code template</td><td>The same print loop, in any embed you choose.</td></tr>
      </table>
      </div>
      <div class="es">
      <table>
        <tr><th>Plantilla</th><th>Tipo</th><th>Qu\u00e9 hace</th></tr>
        <tr><td><code>myWordDocGlobal</code></td><td>extensi\u00f3n de aplicaci\u00f3n (opcional)</td><td>Incluye la clase del editor y las clases RTF en todos los procedimientos, para c\u00f3digo propio. Un interruptor desactiva myWordDoc en toda la aplicaci\u00f3n.</td></tr>
        <tr><td><code>myWordDocEditor</code></td><td>plantilla de control sobre una REGION</td><td>El editor en una ventana o formulario, ligado a un campo BLOB. MULTI.</td></tr>
        <tr><td><code>myWordDocReport</code></td><td>extensi\u00f3n de informe</td><td>Imprime el documento BLOB de cada registro con un IMAGE del informe.</td></tr>
        <tr><td><code>myWordDocPrintBlob</code></td><td>plantilla de c\u00f3digo</td><td>El mismo bucle de impresi\u00f3n, en el embed que quieras.</td></tr>
      </table>
      </div>'''


def s_editor(g):
    code_en = '''Doc1     WordDocClass
  CODE
  OPEN(Window)
  Doc1.PageWidth = WD:LetterWidth     ! lines break where the printer will break them
  Doc1.PageView = TRUE
  Doc1.Init(0{PROP:Handle}, ?DocRegion)
  Doc1.LoadBlob(DOC:Body)
  ACCEPT
    Doc1.TakeEvent()                  ! every event: follows resizes and TABs
  END
  Doc1.SaveBlob(DOC:Body)             ! then write the record
  Doc1.Kill()
  CLOSE(Window)'''
    code_es = '''Doc1     WordDocClass
  CODE
  OPEN(Window)
  Doc1.PageWidth = WD:LetterWidth     ! las l\u00edneas parten donde partir\u00e1 la impresora
  Doc1.PageView = TRUE
  Doc1.Init(0{PROP:Handle}, ?DocRegion)
  Doc1.LoadBlob(DOC:Body)
  ACCEPT
    Doc1.TakeEvent()                  ! en cada evento: sigue al redimensionado y a los TAB
  END
  Doc1.SaveBlob(DOC:Body)             ! y despu\u00e9s graba el registro
  Doc1.Kill()
  CLOSE(Window)'''
    return ('''      <div class="en">
      <p>Populate <b>myWordDocEditor</b> on the form, size the region and pick the <b>BLOB field</b>.</p>
      <ul>
        <li><b>General</b>: object name; <i>Save it with the record</i> (Insert, or Change when the document was edited).</li>
        <li><b>Appearance</b>: toolbar, read only, page view, page width (Letter, A4, custom twips or the window), default font and size.</li>
      </ul>
      <p>It generates: the load right after the window opens (read only on a View request); <code>TakeEvent</code> so the editor follows the
        region as the resizer moves, hides or disables it; <code>SaveBlob</code> in TakeCompleted, just before ABC writes the record; and
        <code>Kill</code>. An untouched form closes without an update. The field must be a dictionary BLOB.</p>
      <p>The same by hand:</p>
      </div>
      <div class="es">
      <p>Pon <b>myWordDocEditor</b> en el formulario, dimensiona la regi\u00f3n y elige el <b>campo BLOB</b>.</p>
      <ul>
        <li><b>General</b>: nombre del objeto; <i>Save it with the record</i> (al insertar, o al cambiar si el documento se edit\u00f3).</li>
        <li><b>Appearance</b>: barra, solo lectura, vista de p\u00e1gina, ancho de p\u00e1gina (Letter, A4, twips a medida o la ventana), fuente y tama\u00f1o por defecto.</li>
      </ul>
      <p>Genera: la carga justo al abrir la ventana (solo lectura si se pide Ver); <code>TakeEvent</code> para que el editor siga a la regi\u00f3n
        cuando el resizer la mueve, la oculta o la deshabilita; <code>SaveBlob</code> en TakeCompleted, justo antes de que ABC grabe el
        registro; y <code>Kill</code>. Un formulario sin tocar se cierra sin actualizar. El campo debe ser un BLOB del diccionario.</p>
      <p>Lo mismo a mano:</p>
      </div>
      ''' + g['bi'](g['clw'](code_en), g['clw'](code_es)) + '\n'
        + '''      <figure class="shots" style="display:block">
        <img class="shot en" src="myWordDoc-demo-form.png" alt="The generated form">
        <img class="shot es" src="myWordDoc-demo-form.png" alt="El formulario generado">
        <figcaption style="text-align:left"><span class="en">The generated <code>UpdateDoc</code> form of the AppGen demo
          (<code>examples/myWordDoc/WordDemo</code>), editing the letter stored in the record's BLOB.</span><span class="es">El
          formulario <code>UpdateDoc</code> generado de la demo de AppGen (<code>examples/myWordDoc/WordDemo</code>), editando la
          carta guardada en el BLOB del registro. La demo generada est\u00e1 en ingl\u00e9s.</span></figcaption>
      </figure>''')


def s_toolbar(g):
    return '''      <div class="en">
      <p>Font and size boxes, <b>B</b> <i>I</i> <u>U</u> <s>S</s>, text colour and highlight (the Windows colour dialog),
        left/centre/right/justify, bullets, numbering, outdent/indent, insert picture (PNG, JPEG, BMP, EMF, WMF), insert table
        (a menu of sizes), undo and redo. The buttons light up for the formatting under the caret, and the font and size boxes go
        blank when the selection mixes several. It wraps onto a second row when the control is narrow.</p>
      <p>Everything RichEdit knows works too: <kbd>Ctrl</kbd>+<kbd>B</kbd>/<kbd>I</kbd>/<kbd>U</kbd>, <kbd>Ctrl</kbd>+<kbd>L</kbd>/<kbd>E</kbd>/<kbd>R</kbd>/<kbd>J</kbd>,
        <kbd>Ctrl</kbd>+<kbd>Z</kbd>/<kbd>Y</kbd>, the clipboard (including <b>pasting a picture</b>), Tab and Enter.</p>
      <p>Set <code>PageWidth</code> (<code>WD:LetterWidth</code>, <code>WD:A4Width</code> or twips) and lines wrap <b>exactly where the
        printer will</b>: text is measured on the default printer, as WordPad does. <code>PageView = TRUE</code> shows the document as a
        sheet of that width on a grey desk. Every toolbar operation is also a method, so you can hide the toolbar
        (<code>ShowToolbar = FALSE</code>) and drive it from your own buttons.</p>
      </div>
      <div class="es">
      <p>Cajas de fuente y tama\u00f1o, <b>N</b> <i>K</i> <u>S</u> <s>T</s>, color de texto y resaltado (el di\u00e1logo de color de Windows),
        izquierda/centro/derecha/justificado, vi\u00f1etas, numeraci\u00f3n, quitar/a\u00f1adir sangr\u00eda, insertar imagen (PNG, JPEG, BMP, EMF, WMF),
        insertar tabla (un men\u00fa de tama\u00f1os), deshacer y rehacer. Los botones se iluminan seg\u00fan el formato bajo el cursor, y las
        cajas de fuente y tama\u00f1o quedan en blanco si la selecci\u00f3n mezcla varios. Pasa a una segunda fila si el control es estrecho.</p>
      <p>Funciona todo lo que sabe RichEdit: <kbd>Ctrl</kbd>+<kbd>B</kbd>/<kbd>I</kbd>/<kbd>U</kbd>, <kbd>Ctrl</kbd>+<kbd>L</kbd>/<kbd>E</kbd>/<kbd>R</kbd>/<kbd>J</kbd>,
        <kbd>Ctrl</kbd>+<kbd>Z</kbd>/<kbd>Y</kbd>, el portapapeles (incluido <b>pegar una imagen</b>), Tab y Enter.</p>
      <p>Pon <code>PageWidth</code> (<code>WD:LetterWidth</code>, <code>WD:A4Width</code> o twips) y las l\u00edneas parten <b>exactamente donde
        partir\u00e1 la impresora</b>: el texto se mide en la impresora predeterminada, como hace WordPad. <code>PageView = TRUE</code> muestra
        el documento como una hoja de ese ancho sobre un fondo gris. Cada operaci\u00f3n de la barra es tambi\u00e9n un m\u00e9todo, as\u00ed que puedes
        ocultar la barra (<code>ShowToolbar = FALSE</code>) y manejarlo con tus botones.</p>
      </div>'''


def s_storage(g):
    return '''      <div class="en">
      <p>The BLOB holds ordinary RTF, so Word and WordPad open it, and pictures travel inside it (<code>{\\pict\\pngblip ...}</code>).
        A BLOB holding plain text (not starting with <code>{\\rtf</code>) loads as plain text, so an existing MEMO-style column can be
        switched over without a conversion.</p>
      ''' + g['clw']("Doc1.LoadBlob(DOC:Body)        ! after the window opens\nDoc1.SaveBlob(DOC:Body)        ! before the record is written") + '''
      <div class="callout warn"><b>Reports and processes: re-read the record</b>A VIEW read never fills a BLOB; it keeps the previous
        record's. The report extension and the code template GET the record by its primary key before loading it. Do the same in your own loops.</div>
      </div>
      <div class="es">
      <p>El BLOB guarda RTF normal, as\u00ed que lo abren Word y WordPad, y las im\u00e1genes viajan dentro (<code>{\\pict\\pngblip ...}</code>).
        Un BLOB con texto plano (que no empieza por <code>{\\rtf</code>) se carga como texto, as\u00ed que una columna tipo MEMO se puede pasar
        sin conversi\u00f3n.</p>
      ''' + g['clw']("Doc1.LoadBlob(DOC:Body)        ! al abrir la ventana\nDoc1.SaveBlob(DOC:Body)        ! antes de grabar el registro") + '''
      <div class="callout warn"><b>Informes y procesos: vuelve a leer el registro</b>Una lectura de VIEW nunca rellena un BLOB; conserva
        el del registro anterior. La extensi\u00f3n de informe y la plantilla de c\u00f3digo hacen GET por la clave primaria antes de cargarlo. Haz lo mismo en tus bucles.</div>
      </div>'''


def s_undo(g):
    en = '''Search.ReplaceAll('Acme Ltd', 'Acme Limited')
Search.Undo()                     ! all of them back: the same as Ctrl+Z or Doc1.Undo()
IF Doc1.CanUndo() THEN ENABLE(?UndoBtn) ELSE DISABLE(?UndoBtn).

Doc1.BeginUndoGroup()             ! your own edits as one step
Doc1.InsertText('Dear ' & CLIP(CUS:Name) & ',')
Doc1.SelectText(0, 4)
Doc1.Bold(WD:On)
Doc1.EndUndoGroup()               ! pairs nest

Doc1.ClearUndo()                  ! forget the history
Doc1.SetUndoLimit(500)            ! keep more than the default 100 steps'''
    es = '''Search.ReplaceAll('Acme SL', 'Acme S.L.')
Search.Undo()                     ! vuelven todos: igual que Ctrl+Z o Doc1.Undo()
IF Doc1.CanUndo() THEN ENABLE(?UndoBtn) ELSE DISABLE(?UndoBtn).

Doc1.BeginUndoGroup()             ! tus propias ediciones como un paso
Doc1.InsertText('Estimado ' & CLIP(CLI:Nombre) & ':')
Doc1.SelectText(0, 8)
Doc1.Bold(WD:On)
Doc1.EndUndoGroup()               ! los pares se anidan

Doc1.ClearUndo()                  ! olvidar el historial
Doc1.SetUndoLimit(500)            ! m\u00e1s pasos que los 100 de serie'''
    return ('''      <div class="en">
      <p>Ctrl+Z / Ctrl+Y, the toolbar arrows and <code>Undo()</code> / <code>Redo()</code>. <b>Each tool operation is one step</b>: a
        <code>ReplaceAll</code> of 19 words, <code>SetFontAll</code>, <code>ScaleSizes</code>, <code>ReplaceFont</code>,
        <code>HighlightAll</code> or a whole <code>Merge</code> comes back with one Ctrl+Z. Loading a document clears the history, so
        Undo never reaches back into the previous record.</p>
      </div>
      <div class="es">
      <p>Ctrl+Z / Ctrl+Y, las flechas de la barra y <code>Undo()</code> / <code>Redo()</code>. <b>Cada operaci\u00f3n de herramienta es un
        paso</b>: un <code>ReplaceAll</code> de 19 palabras, <code>SetFontAll</code>, <code>ScaleSizes</code>, <code>ReplaceFont</code>,
        <code>HighlightAll</code> o un <code>Merge</code> entero se deshace con un Ctrl+Z. Cargar un documento vac\u00eda el historial, as\u00ed
        que Deshacer nunca vuelve al registro anterior.</p>
      </div>
      ''' + g['bi'](g['clw'](en), g['clw'](es)) + '''
      <div class="callout note"><b class="en">How</b><b class="es">C\u00f3mo</b><span class="en">The grouping is the text engine's own undo
        (TOM <code>BeginEditCollection</code>, Windows 8 and later). On older Windows undo still works, one change at a time.</span><span class="es">La
        agrupaci\u00f3n es el propio deshacer del motor de texto (TOM <code>BeginEditCollection</code>, Windows 8 o posterior). En Windows anteriores
        el deshacer sigue funcionando, cambio a cambio.</span></div>''')


def s_report(g):
    en = '''Doc1.InitHidden()                                   ! once, after OPEN(Report)
...
GET(Docs, DOC:PKey)                                 ! a VIEW read does not fill a BLOB
Doc1.LoadBlob(DOC:Body)
LOOP Page# = 1 TO Doc1.PaginateForReport(Report, ?DocImage, WD:Flow)
  Doc1.PreparePage(Report, ?DocImage, Page#)        ! piece N into the IMAGE
  PRINT(RPT:DocBand)
END
...
Doc1.Kill()                                         ! deletes the temporary files'''
    es = '''Doc1.InitHidden()                                   ! una vez, tras OPEN(Report)
...
GET(Docs, DOC:PKey)                                 ! una lectura de VIEW no rellena el BLOB
Doc1.LoadBlob(DOC:Body)
LOOP Page# = 1 TO Doc1.PaginateForReport(Report, ?DocImage, WD:Flow)
  Doc1.PreparePage(Report, ?DocImage, Page#)        ! el trozo N en el IMAGE
  PRINT(RPT:DocBand)
END
...
Doc1.Kill()                                         ! borra los ficheros temporales'''
    return ('''      <div class="en">
      <p>Put an empty <b>IMAGE</b> in a DETAIL band, as wide as the document and as tall as the most one page can hold. Add
        <b>myWordDocReport</b> and pick the BLOB and the IMAGE (the band is found from it). Choose whether the document prints before or
        after the record's other detail bands. The extension takes the band out of ABC's own print loop, so it never prints twice, and
        for each record it re-reads the record, loads the document and prints it. <b>myWordDocPrintBlob</b> does the same in any embed:
        name the report, the IMAGE and the band, and set the band's Detail Filter to <code>False</code>.</p>
      <p>By hand:</p>
      </div>
      <div class="es">
      <p>Pon un <b>IMAGE</b> vac\u00edo en una banda DETAIL, tan ancho como el documento y tan alto como quepa en una p\u00e1gina. A\u00f1ade
        <b>myWordDocReport</b> y elige el BLOB y el IMAGE (la banda se deduce de \u00e9l). Elige si el documento se imprime antes o despu\u00e9s
        de las otras bandas del registro. La extensi\u00f3n saca la banda del bucle de impresi\u00f3n de ABC, as\u00ed que nunca sale dos veces, y
        para cada registro lo vuelve a leer, carga el documento y lo imprime. <b>myWordDocPrintBlob</b> hace lo mismo en cualquier embed:
        indica el informe, el IMAGE y la banda, y pon el Detail Filter de la banda a <code>False</code>.</p>
      <p>A mano:</p>
      </div>
      ''' + g['bi'](g['clw'](en), g['clw'](es)) + '''
      <figure class="shots" style="display:block">
        <img class="shot en" src="myWordDoc-demo-report.png" alt="Three records through the generated report">
        <img class="shot es" src="myWordDoc-demo-report.png" alt="Tres registros con el informe generado">
        <figcaption style="text-align:left"><span class="en">The generated <code>PrintDocs</code> report over three records: the letter
          starts right under its title on page 1, fills every page, and the third note follows straight after it.</span><span class="es">El
          informe <code>PrintDocs</code> generado con tres registros: la carta empieza justo bajo su t\u00edtulo en la p\u00e1gina 1, llena cada
          p\u00e1gina y la tercera nota sale justo detr\u00e1s (demo en ingl\u00e9s).</span></figcaption>
      </figure>''')


def s_flow(g):
    return ('''      <div class="en">
      <p><b><code>WD:Flow</code></b> (the templates' default, <i>Fill the room left on each page, line by line</i>) cuts the document
        <b>one line per piece</b>. Each line prints as its own band, the height of that line, and the report engine places every band
        itself: on this page if it fits, on the next if not. So a long document starts in whatever room the previous record left, fills
        that page, carries on over as many pages as it needs, and whatever prints next follows straight on.</p>
      <p><b><code>WD:Pages</code></b> (the class default) cuts pieces the size of the IMAGE. A piece that won't fit in the room left
        starts a new page, which can leave most of a page empty; <i>Shrink the last piece</i> trims the final piece to its text.</p>
      </div>
      <div class="es">
      <p><b><code>WD:Flow</code></b> (lo que usan las plantillas por defecto, <i>Fill the room left on each page, line by line</i>) corta
        el documento <b>en un trozo por l\u00ednea</b>. Cada l\u00ednea se imprime como su propia banda, de la altura de esa l\u00ednea, y el motor de
        informes coloca cada banda: en esta p\u00e1gina si cabe, en la siguiente si no. As\u00ed un documento largo empieza en el hueco que dej\u00f3
        el registro anterior, llena esa p\u00e1gina, sigue en las que haga falta, y lo siguiente sale justo detr\u00e1s.</p>
      <p><b><code>WD:Pages</code></b> (el valor por defecto de la clase) corta trozos del tama\u00f1o del IMAGE. Un trozo que no cabe en el
        hueco empieza p\u00e1gina nueva, lo que puede dejar casi una p\u00e1gina vac\u00eda; <i>Shrink the last piece</i> recorta el \u00faltimo trozo a su texto.</p>
      </div>
''' + g['shot']('myWordDoc-flow-vs-pages.png', 'The same three records printed both ways: 4 pages with WD:Pages, 3 with WD:Flow.',
                'Los mismos tres registros impresos de las dos formas: 4 p\u00e1ginas con WD:Pages, 3 con WD:Flow.') + '''
      <div class="callout warn"><b class="en">Keep the IMAGE alone in its band</b><b class="es">Deja el IMAGE solo en su banda</b>
        <span class="en">In WD:Flow the band is cut down to each line, and the IMAGE's top is moved to 0 while printing. A line is never
        split: a picture or table row that doesn't fit moves to the next page whole, as in Word.</span><span class="es">En WD:Flow la banda
        se recorta a cada l\u00ednea y el IMAGE se sube a 0 mientras imprime. Una l\u00ednea nunca se parte: una imagen o una fila de tabla que no
        cabe pasa entera a la p\u00e1gina siguiente, como en Word.</span></div>
      <div class="en"><p>Why line by line: a Clarion REPORT cannot tell a program how much room is left on a page, and it moves a band that
        doesn't fit whole to the next page. Letting the engine place one line at a time avoids both, and nothing has to be measured.</p></div>
      <div class="es"><p>Por qu\u00e9 l\u00ednea a l\u00ednea: un REPORT de Clarion no puede decirle a un programa cu\u00e1nto sitio queda en la p\u00e1gina, y
        mueve entera a la p\u00e1gina siguiente una banda que no cabe. Dejar que el motor coloque una l\u00ednea cada vez evita las dos cosas y no
        hay que medir nada.</p></div>''')


def s_wmf(g):
    return '''      <div class="en">
      <p>Each piece is drawn by RichEdit (<code>EM_FORMATRANGE</code>) into an enhanced metafile and written as a <b>placeable WMF</b>:
        an <code>.emf</code> on a report IMAGE prints nothing, while the report engine plays a WMF's records straight into the page, so
        text stays vector and PDFs stay small. <code>wdoc.c</code> fixes three things the conversion gets wrong:</p>
      <ol>
        <li><b>Pictures disappear</b>: RichEdit draws them with AlphaBlend, which WMF cannot express. They are composited onto white at
          200 dpi and written as STRETCHDIB records.</li>
        <li><b>The WMF is huge</b>: the converter hides a full copy of the EMF in comment records (11 MB for one page with a picture).
          They are dropped.</li>
        <li><b>Bullets print as "?"</b>: RichEdit draws them as U+2981 and symbol-font characters as U+F0xx. They are mapped into the ANSI range.</li>
      </ol>
      <p>Text is <b>measured on the default printer</b>, not the 96-dpi screen, so lines break in the editor exactly where they print.</p>
      </div>
      <div class="es">
      <p>RichEdit dibuja cada trozo (<code>EM_FORMATRANGE</code>) en un metarchivo mejorado que se escribe como <b>WMF placeable</b>:
        un <code>.emf</code> en un IMAGE de informe no imprime nada, mientras que el motor de informes reproduce los registros de un WMF
        directamente en la p\u00e1gina, as\u00ed el texto sigue siendo vectorial y los PDF son peque\u00f1os. <code>wdoc.c</code> arregla tres cosas
        que la conversi\u00f3n hace mal:</p>
      <ol>
        <li><b>Desaparecen las im\u00e1genes</b>: RichEdit las dibuja con AlphaBlend, que WMF no puede expresar. Se componen sobre blanco a
          200 ppp y se escriben como registros STRETCHDIB.</li>
        <li><b>El WMF es enorme</b>: el conversor esconde una copia entera del EMF en registros de comentario (11 MB para una p\u00e1gina con
          una imagen). Se eliminan.</li>
        <li><b>Las vi\u00f1etas salen como "?"</b>: RichEdit las dibuja como U+2981 y los caracteres de fuentes de s\u00edmbolos como U+F0xx. Se
          traducen al rango ANSI.</li>
      </ol>
      <p>El texto se <b>mide en la impresora predeterminada</b>, no en la pantalla de 96 ppp, as\u00ed que las l\u00edneas parten en el editor
        exactamente donde se imprimen.</p>
      </div>'''


def s_tools(g):
    en = '''Search.Attach(Doc1)               ! the editor on the window: the user sees every change
! - or -
Text.LoadBlob(DOC:Body)           ! its own hidden document (also LoadString, LoadFile)
...
Search.SaveBlob(DOC:Body)         ! keep the changes (also SaveFile, GetRtf)'''
    es = '''Search.Attach(Doc1)               ! el editor de la ventana: el usuario ve cada cambio
! - o bien -
Text.LoadBlob(DOC:Body)           ! su propio documento oculto (tambi\u00e9n LoadString, LoadFile)
...
Search.SaveBlob(DOC:Body)         ! guardar los cambios (tambi\u00e9n SaveFile, GetRtf)'''
    return ('''      <div class="en">
      <table>
        <tr><th>Class</th><th>What it does</th></tr>
        <tr><td><code>RtfSearchClass</code></td><td>find, next/previous, count, replace, replace all, highlight every hit, the text around a hit</td></tr>
        <tr><td><code>RtfFontClass</code></td><td>the font, size, style and colour at a position or in the selection; fonts in use; replace a font; set or scale every size</td></tr>
        <tr><td><code>RtfTextClass</code></td><td>readable plain text (lists, table cells); word/character/paragraph/picture/table counts; excerpts; text to RTF</td></tr>
        <tr><td><code>RtfHtmlClass</code></td><td>an HTML page or an e-mail fragment, pictures embedded or written as files</td></tr>
        <tr><td><code>RtfMarkdownClass</code></td><td>headings, emphasis, lists, tables, pictures</td></tr>
        <tr><td><code>RtfMergeClass</code></td><td>fills <code>[[Name]]</code> placeholders from your values or from BIND()ed fields</td></tr>
      </table>
      <p>Every class works on a document one of two ways. On a live editor the tools put the user's selection and scroll position back
        when they finish; Find, FindNext and FindPrevious move to the hit on purpose. Positions are 0-based character positions, the
        same ones <code>SelectText</code> takes.</p>
      </div>
      <div class="es">
      <table>
        <tr><th>Clase</th><th>Qu\u00e9 hace</th></tr>
        <tr><td><code>RtfSearchClass</code></td><td>buscar, siguiente/anterior, contar, reemplazar, reemplazar todo, resaltar cada coincidencia, el texto alrededor</td></tr>
        <tr><td><code>RtfFontClass</code></td><td>la fuente, tama\u00f1o, estilo y color en una posici\u00f3n o en la selecci\u00f3n; fuentes usadas; cambiar una fuente; fijar o escalar los tama\u00f1os</td></tr>
        <tr><td><code>RtfTextClass</code></td><td>texto plano legible (listas, celdas); recuentos de palabras, caracteres, p\u00e1rrafos, im\u00e1genes y tablas; extractos; texto a RTF</td></tr>
        <tr><td><code>RtfHtmlClass</code></td><td>una p\u00e1gina HTML o un fragmento para un correo, con las im\u00e1genes incrustadas o en ficheros</td></tr>
        <tr><td><code>RtfMarkdownClass</code></td><td>t\u00edtulos, \u00e9nfasis, listas, tablas, im\u00e1genes</td></tr>
        <tr><td><code>RtfMergeClass</code></td><td>rellena marcadores <code>[[Nombre]]</code> con tus valores o con campos ligados con BIND()</td></tr>
      </table>
      <p>Todas trabajan sobre un documento de una de dos formas. En un editor vivo, al terminar devuelven la selecci\u00f3n y el
        desplazamiento del usuario; Find, FindNext y FindPrevious se mueven a la coincidencia a prop\u00f3sito. Las posiciones son posiciones
        de car\u00e1cter desde 0, las mismas que usa <code>SelectText</code>.</p>
      </div>
      ''' + g['bi'](g['clw'](en), g['clw'](es)))


def s_search(g):
    en = '''Search.Attach(Doc1)
Search.WholeWord = TRUE
IF Search.Find('invoice') >= 0                  ! first hit, selected and scrolled into view
  MESSAGE(Search.Count('invoice') & ' found. The first: ' & Search.Context(30))
END
Search.FindNext()                               ! goes round to the top while Wrap is on
Search.ReplaceAll('Acme Ltd', 'Acme Limited')   ! each keeps its formatting; one Undo
Search.Replace('colour', 'color')               ! Word's Replace button: find, then replace + next
Search.HighlightAll('urgent', COLOR:Yellow)     ! COLOR:None takes it off'''
    es = '''Search.Attach(Doc1)
Search.WholeWord = TRUE
IF Search.Find('factura') >= 0                  ! primera coincidencia, seleccionada y visible
  MESSAGE(Search.Count('factura') & ' encontradas. La primera: ' & Search.Context(30))
END
Search.FindNext()                               ! vuelve al principio mientras Wrap est\u00e9 activo
Search.ReplaceAll('Acme SL', 'Acme S.L.')       ! cada una conserva su formato; un Deshacer
Search.Replace('color', 'colour')               ! el bot\u00f3n Reemplazar de Word: busca, luego reemplaza y sigue
Search.HighlightAll('urgente', COLOR:Yellow)    ! COLOR:None lo quita'''
    return g['bi'](g['clw'](en), g['clw'](es)) + '''
      <div class="en"><p><code>FoundAt</code> / <code>FoundEnd</code> give the last hit and <code>TextAt(From, To)</code> any range.
        <code>SelectHits = FALSE</code> searches without moving the user's selection. A replacement takes the formatting of the text it
        replaces, so a bold name stays bold.</p></div>
      <div class="es"><p><code>FoundAt</code> / <code>FoundEnd</code> dan la \u00faltima coincidencia y <code>TextAt(Desde, Hasta)</code>
        cualquier rango. <code>SelectHits = FALSE</code> busca sin mover la selecci\u00f3n del usuario. Lo reemplazado toma el formato del texto
        al que sustituye, as\u00ed que un nombre en negrita sigue en negrita.</p></div>'''


def s_fonts(g):
    en = '''Font.Attach(Doc1)
Font.Read()                          ! the selection; Font.Read(Pos) reads one character
?Status{PROP:Text} = Font.Describe() ! 'Georgia 12pt, bold, italic'
Font.FontList()                      ! 'Georgia, Segoe UI' - only characters you can see count
Font.MainFont()                      ! the font most of the text is in
Font.ReplaceFont('Comic Sans MS', 'Segoe UI')
Font.SetFontAll('Calibri', 11)       ! '' or 0 leaves that part as it is
Font.ScaleSizes(120)                 ! every size 20% bigger, headings with it'''
    es = '''Font.Attach(Doc1)
Font.Read()                          ! la selecci\u00f3n; Font.Read(Pos) lee un car\u00e1cter
?Status{PROP:Text} = Font.Describe() ! 'Georgia 12pt, bold, italic' (en ingl\u00e9s)
Font.FontList()                      ! 'Georgia, Segoe UI' - solo cuentan los caracteres visibles
Font.MainFont()                      ! la fuente de la mayor parte del texto
Font.ReplaceFont('Comic Sans MS', 'Segoe UI')
Font.SetFontAll('Calibri', 11)       ! '' o 0 deja esa parte como est\u00e1
Font.ScaleSizes(120)                 ! todos los tama\u00f1os un 20% mayores, t\u00edtulos incluidos'''
    return g['bi'](g['clw'](en), g['clw'](es)) + '''
      <div class="en"><p>Over a selection that mixes styles a property says so: <code>Face</code> is blank, <code>Size</code> 0,
        <code>Bold</code> and the other on/off values -1, <code>Color</code> or <code>Highlight</code> -2.
        <code>Color = COLOR:None</code> means automatic.</p></div>
      <div class="es"><p>Si la selecci\u00f3n mezcla estilos, la propiedad lo indica: <code>Face</code> vac\u00edo, <code>Size</code> 0,
        <code>Bold</code> y los dem\u00e1s s\u00ed/no a -1, <code>Color</code> o <code>Highlight</code> a -2. <code>Color = COLOR:None</code>
        significa autom\u00e1tico.</p></div>'''


def s_text(g):
    en = '''Text.LoadBlob(DOC:Body)
DOC:PlainText = Text.ToText()        ! a search index, a LIST column, an SMS
DOC:Summary = Text.Excerpt(120)      ! one line, cut at a word, with '...'
L:Info = Text.WordCount() & ' words, ' & Text.CharCount() & ' characters'
Doc1.LoadString(Text.TextToRtf(NOTE:Memo, 'Georgia', 12))   ! a MEMO into the editor'''
    es = '''Text.LoadBlob(DOC:Body)
DOC:TextoPlano = Text.ToText()       ! un \u00edndice de b\u00fasqueda, una columna, un SMS
DOC:Resumen = Text.Excerpt(120)      ! una l\u00ednea, cortada en una palabra, con '...'
L:Info = Text.WordCount() & ' palabras, ' & Text.CharCount() & ' caracteres'
Doc1.LoadString(Text.TextToRtf(NOTA:Memo, 'Georgia', 12))   ! un MEMO en el editor'''
    return g['bi'](g['clw'](en), g['clw'](es)) + '''
      <div class="en"><p>Bullets become <code>- </code>, numbered items <code>1.</code> <code>b.</code> <code>iv.</code>, table cells are
        separated by TAB. <code>ListPrefixes</code>, <code>Bullet</code>, <code>TabCells</code>, <code>PictureMarks</code> and
        <code>Utf8</code> change that.</p>
      <pre>What it can do
- Formatting - bold, italic, underline, strike, colour and highlight.
Product&#9;Units&#9;Revenue
Widgets&#9;1,200&#9;$14,400</pre></div>
      <div class="es"><p>Las vi\u00f1etas pasan a <code>- </code>, los elementos numerados a <code>1.</code> <code>b.</code> <code>iv.</code>, y
        las celdas se separan con TAB. <code>ListPrefixes</code>, <code>Bullet</code>, <code>TabCells</code>, <code>PictureMarks</code> y
        <code>Utf8</code> lo cambian.</p>
      <pre>Lo que sabe hacer
- Formato - negrita, cursiva, subrayado, tachado, color y resaltado.
Producto&#9;Unidades&#9;Ingresos
Tornillos&#9;1.200&#9;14.400 \u20ac</pre></div>'''


def s_html(g):
    en = '''Html.LoadBlob(DOC:Body)
Html.Title = DOC:Title
Html.SaveHtml('letter.html')      ! a complete UTF-8 page
Html.FullPage = FALSE             ! only a <div>, for the body of an e-mail
Html.ImageFolder = 'C:\\Site\\img' ! pictures as files instead of data: URIs ...
Html.ImageUrl = 'img/'            ! ... linked as img/image1.png
Md.LoadBlob(DOC:Body)
Md.SaveMarkdown('letter.md')      ! headings, lists, tables, pictures'''
    es = '''Html.LoadBlob(DOC:Body)
Html.Title = DOC:Titulo
Html.SaveHtml('carta.html')       ! una p\u00e1gina UTF-8 completa
Html.FullPage = FALSE             ! solo un <div>, para el cuerpo de un correo
Html.ImageFolder = 'C:\\Web\\img'  ! im\u00e1genes como ficheros en vez de data: URI ...
Html.ImageUrl = 'img/'            ! ... enlazadas como img/image1.png
Md.LoadBlob(DOC:Body)
Md.SaveMarkdown('carta.md')       ! t\u00edtulos, listas, tablas, im\u00e1genes'''
    return g['bi'](g['clw'](en), g['clw'](es)) + '\n' + g['shot'](
        'myWordDoc-tools-html.png', 'sample.rtf as HTML in a browser: fonts, colours, highlight, list, picture and table kept.',
        'sample_es.rtf como HTML en un navegador: se conservan fuentes, colores, resaltado, lista, imagen y tabla.') + '''
      <div class="en"><p>Styles are inline, so the HTML survives mail clients that drop <code>&lt;style&gt;</code> blocks. PNG and JPEG
        pictures are copied byte for byte; EMF, WMF and BMP are drawn at twice their size and saved as PNG through GDI+. In Markdown a
        short paragraph in large type becomes a heading (<code>#</code> at 1.6 times the body size, <code>##</code> at 1.3, <code>###</code>
        at 1.12 when all bold), and emphasis markers stay next to the words.</p></div>
      <div class="es"><p>Los estilos van en l\u00ednea, as\u00ed que el HTML sobrevive a los clientes de correo que quitan los bloques
        <code>&lt;style&gt;</code>. Las im\u00e1genes PNG y JPEG se copian byte a byte; EMF, WMF y BMP se dibujan al doble de tama\u00f1o y se guardan
        como PNG con GDI+. En Markdown, un p\u00e1rrafo corto en letra grande pasa a t\u00edtulo (<code>#</code> a 1,6 veces el cuerpo,
        <code>##</code> a 1,3, <code>###</code> a 1,12 si es todo negrita), y las marcas de \u00e9nfasis quedan pegadas a las palabras.</p></div>'''


def s_merge(g):
    en = '''Merge.LoadBlob(TPL:Body)          ! the template letter: "Dear [[CUS:Name]], ... [[When]]"
BIND(CUS:Record)                  ! BIND()ed fields fill their placeholders by themselves
Merge.SetField('When', 'on ' & FORMAT(ORD:ShipDate, @D17))
IF Merge.Missing() <> ''          ! placeholders nothing will fill
  MESSAGE('No value for: ' & Merge.Missing())
END
Merge.Merge()                     ! each value takes its placeholder's formatting
Merge.SaveBlob(LET:Body)          ! the finished letter'''
    es = '''Merge.LoadBlob(PLA:Body)          ! la carta modelo: "Estimado [[CLI:Nombre]], ... [[Fecha]]"
BIND(CLI:Record)                  ! los campos con BIND() rellenan solos sus marcadores
Merge.SetField('Fecha', FORMAT(PED:FechaEnvio, @D17))
IF Merge.Missing() <> ''          ! marcadores que nada rellenar\u00e1
  MESSAGE('Sin valor para: ' & Merge.Missing())
END
Merge.Merge()                     ! cada valor toma el formato de su marcador
Merge.SaveBlob(CAR:Body)          ! la carta terminada'''
    return g['bi'](g['clw'](en), g['clw'](es)) + '''
      <div class="callout tip"><b class="en">One copy per record</b><b class="es">Una copia por registro</b><span class="en">Merge into a
        fresh copy of the template each time: LoadBlob, Merge, SaveBlob. FieldOpen / FieldClose change the [[ ]] markers;
        BlankUnknown empties the placeholders nothing filled.</span><span class="es">Combina siempre sobre una copia nueva de la plantilla:
        LoadBlob, Merge, SaveBlob. FieldOpen / FieldClose cambian los marcadores [[ ]]; BlankUnknown vac\u00eda los que nadie rellen\u00f3.</span></div>'''


def s_inside(g):
    return '''      <div class="en">
      <p><code>wdoc.c</code> registers its own window class (<code>myWordDocHost</code>) whose window procedure paints the toolbar and
        holds the editing surface: <b>RICHEDIT50W</b> in <code>msftedit.dll</code>, the engine behind WordPad, used as a component for
        typing, line breaking, selection, undo, the clipboard and RTF. The host is its parent, so RichEdit's notifications come to our
        window procedure and the Clarion window is never subclassed. Every Win32 call is bound with LoadLibrary/GetProcAddress, so there
        is no import library. A document created with no parent window is invisible: that is what reports and the tool classes use.</p>
      <table>
        <tr><th>Detail</th><th>Why it matters</th></tr>
        <tr><td>Structures packed on 2 bytes</td><td>Clarion's C compiler packs structs on 2-byte boundaries, so the hole Win32 leaves in CHARFORMAT2 is spelled out. <code>StructSizes()</code> checks it: 84188.</td></tr>
        <tr><td>IRichEditOleCallback</td><td>RichEdit keeps BMP, EMF and WMF pictures as OLE objects and drops them silently unless its owner hands it storage. wdoc.c registers the callback, as WordPad does.</td></tr>
        <tr><td><code>GT_RAWTEXT</code></td><td>The tools read the raw text, where table rows are U+FFF9 &hellip; U+FFFB, cells end in U+0007 and a picture is U+FFFC, so every index is a real character position.</td></tr>
        <tr><td>Run walking</td><td>A stretch with one look is found by doubling the selection while RichEdit reports one format, then halving back to the edge: a few messages per run, not one per character.</td></tr>
        <tr><td>TOM edit collections</td><td>Each tool operation runs between BeginEditCollection and EndEditCollection, so it is one undo step.</td></tr>
      </table>
      </div>
      <div class="es">
      <p><code>wdoc.c</code> registra su propia clase de ventana (<code>myWordDocHost</code>), cuyo procedimiento pinta la barra y
        contiene la superficie de edici\u00f3n: <b>RICHEDIT50W</b> de <code>msftedit.dll</code>, el motor de WordPad, usado como componente para
        escribir, partir l\u00edneas, seleccionar, deshacer, el portapapeles y el RTF. El anfitri\u00f3n es su padre, as\u00ed que las notificaciones de
        RichEdit llegan a nuestro procedimiento y la ventana Clarion nunca se subclasifica. Cada llamada Win32 se enlaza con
        LoadLibrary/GetProcAddress, sin biblioteca de importaci\u00f3n. Un documento creado sin ventana padre es invisible: eso es lo que usan
        los informes y las clases de herramientas.</p>
      <table>
        <tr><th>Detalle</th><th>Por qu\u00e9 importa</th></tr>
        <tr><td>Estructuras empaquetadas a 2 bytes</td><td>El compilador C de Clarion empaqueta a 2 bytes, as\u00ed que el hueco que deja Win32 en CHARFORMAT2 est\u00e1 escrito a mano. <code>StructSizes()</code> lo comprueba: 84188.</td></tr>
        <tr><td>IRichEditOleCallback</td><td>RichEdit guarda las im\u00e1genes BMP, EMF y WMF como objetos OLE y las descarta en silencio si su due\u00f1o no le da almacenamiento. wdoc.c registra el callback, como WordPad.</td></tr>
        <tr><td><code>GT_RAWTEXT</code></td><td>Las herramientas leen el texto en bruto, donde las filas son U+FFF9 &hellip; U+FFFB, las celdas acaban en U+0007 y una imagen es U+FFFC, as\u00ed cada \u00edndice es una posici\u00f3n real.</td></tr>
        <tr><td>Recorrido de tramos</td><td>Un tramo con un mismo aspecto se encuentra doblando la selecci\u00f3n mientras RichEdit informa un solo formato y luego partiendo a la mitad hasta el borde: pocos mensajes por tramo, no uno por car\u00e1cter.</td></tr>
        <tr><td>Colecciones de edici\u00f3n TOM</td><td>Cada operaci\u00f3n de herramienta va entre BeginEditCollection y EndEditCollection, as\u00ed que es un solo paso de deshacer.</td></tr>
      </table>
      </div>'''


def s_tests(g):
    return '''      <div class="en">
      <table>
        <tr><th>Program</th><th>What it proves</th></tr>
        <tr><td><code>examples/myWordDoc/Spike.exe AUTO</code></td><td>30 headless checks of the class: struct layout, every format getter after its setter, tables, pictures, Find, a BLOB round trip through a TopSpeed record, pagination, metafiles.</td></tr>
        <tr><td><code>Spike.exe REPORT</code></td><td>Prints sample.rtf through a REPORT into PROP:Preview and copies the pages out.</td></tr>
        <tr><td><code>Flow.exe</code> [<code>PAGES</code>] [<code>ES</code>]</td><td>A note, the long letter and another note in one report, as WD:Flow or WD:Pages: the comparison image above.</td></tr>
        <tr><td><code>Tools.exe AUTO</code></td><td>60 checks of the tool classes and undo, with every export written to <code>tools_out\\</code>.</td></tr>
        <tr><td><code>Tools.exe</code> [<code>ES</code>]</td><td>The window in the screenshots: find, replace, highlight, the font under the caret, the exports.</td></tr>
        <tr><td><code>WordDemo/build_demo.sh</code></td><td>The templates through AppGen: dictionary, TXA import, generate, compile; browse, form and two reports.</td></tr>
      </table>
      <p>Build them with <code>examples/myWordDoc/build.sh</code> (32-bit MSBuild, Clarion 12).</p>
      </div>
      <div class="es">
      <table>
        <tr><th>Programa</th><th>Qu\u00e9 demuestra</th></tr>
        <tr><td><code>examples/myWordDoc/Spike.exe AUTO</code></td><td>30 comprobaciones sin ventana de la clase: estructuras, cada lectura de formato tras su escritura, tablas, im\u00e1genes, Find, un BLOB de ida y vuelta por un registro TopSpeed, paginaci\u00f3n, metarchivos.</td></tr>
        <tr><td><code>Spike.exe REPORT</code></td><td>Imprime sample.rtf con un REPORT en PROP:Preview y copia las p\u00e1ginas.</td></tr>
        <tr><td><code>Flow.exe</code> [<code>PAGES</code>] [<code>ES</code>]</td><td>Una nota, la carta larga y otra nota en un informe, con WD:Flow o WD:Pages: la imagen comparativa de arriba.</td></tr>
        <tr><td><code>Tools.exe AUTO</code></td><td>60 comprobaciones de las clases RTF y del deshacer, con cada exportaci\u00f3n escrita en <code>tools_out\\</code>.</td></tr>
        <tr><td><code>Tools.exe</code> [<code>ES</code>]</td><td>La ventana de las capturas: buscar, reemplazar, resaltar, la fuente bajo el cursor, las exportaciones.</td></tr>
        <tr><td><code>WordDemo/build_demo.sh</code></td><td>Las plantillas pasando por AppGen: diccionario, importaci\u00f3n TXA, generaci\u00f3n y compilaci\u00f3n; browse, formulario y dos informes.</td></tr>
      </table>
      <p>Se compilan con <code>examples/myWordDoc/build.sh</code> (MSBuild de 32 bits, Clarion 12).</p>
      </div>'''


def s_ref(g):
    return '''      <div class="en">
      <p>Every public property, method and equate of <b>WordDocClass</b> and the six tool classes, each with its signature, what it does
        and a line of Clarion: <a href="myWordDoc-reference.html"><b>myWordDoc-reference.html</b></a>.</p>
      </div>
      <div class="es">
      <p>Todas las propiedades, m\u00e9todos y equates p\u00fablicos de <b>WordDocClass</b> y de las seis clases RTF, cada uno con su firma, lo
        que hace y una l\u00ednea de Clarion: <a href="myWordDoc-reference.html"><b>myWordDoc-reference.html</b></a>.</p>
      </div>'''


def s_quirks(g):
    return '''      <div class="en">
      <table>
        <tr><th>Limit</th><th>Why</th><th>Workaround</th></tr>
        <tr><td>GIF, TIFF and ICO cannot be inserted from the toolbar</td><td>RTF has no blip type for them</td><td>Convert to PNG, or paste them (the clipboard gives RichEdit a bitmap)</td></tr>
        <tr><td>Printed text is limited to the ANSI code page</td><td>WMF text records are 8-bit</td><td>Fine for Western languages; Greek/Cyrillic/CJK show on screen and in the BLOB, not in print</td></tr>
        <tr><td>Printed pictures are 200 dpi</td><td>keeps pages and PDFs small</td><td><code>PIC_DPI</code> in wdoc.c</td></tr>
        <tr><td>No headers, footers or page numbers inside the document</td><td>the document is a band, not a page</td><td>use the REPORT's own header and footer</td></tr>
        <tr><td>WD:Flow keeps a paragraph's space-before at the top of a page</td><td>each line prints exactly as laid out</td><td>barely visible; use WD:Pages if it matters</td></tr>
        <tr><td>Undo comes back one change at a time on Windows 7</td><td>TOM edit collections need RichEdit 8 (Windows 8+)</td><td>none needed; it still works</td></tr>
        <tr><td><code>RtfFontClass.Describe</code> is English</td><td>it is a convenience string</td><td>build your own text from the properties</td></tr>
      </table>
      </div>
      <div class="es">
      <table>
        <tr><th>L\u00edmite</th><th>Por qu\u00e9</th><th>Soluci\u00f3n</th></tr>
        <tr><td>GIF, TIFF e ICO no se pueden insertar desde la barra</td><td>RTF no tiene tipo de imagen para ellos</td><td>Convi\u00e9rtelos a PNG, o p\u00e9galos (el portapapeles le da a RichEdit un mapa de bits)</td></tr>
        <tr><td>El texto impreso se limita a la p\u00e1gina de c\u00f3digos ANSI</td><td>los registros de texto WMF son de 8 bits</td><td>Bien para idiomas occidentales; griego/cir\u00edlico/CJK se ven en pantalla y en el BLOB, no al imprimir</td></tr>
        <tr><td>Las im\u00e1genes se imprimen a 200 ppp</td><td>mantiene peque\u00f1os p\u00e1ginas y PDF</td><td><code>PIC_DPI</code> en wdoc.c</td></tr>
        <tr><td>Sin cabeceras, pies ni n\u00fameros de p\u00e1gina dentro del documento</td><td>el documento es una banda, no una p\u00e1gina</td><td>usa la cabecera y el pie del REPORT</td></tr>
        <tr><td>WD:Flow conserva el espacio anterior de un p\u00e1rrafo al principio de p\u00e1gina</td><td>cada l\u00ednea se imprime tal cual se maquet\u00f3</td><td>apenas se nota; usa WD:Pages si importa</td></tr>
        <tr><td>En Windows 7 el deshacer va cambio a cambio</td><td>las colecciones de TOM necesitan RichEdit 8 (Windows 8+)</td><td>no hace falta; sigue funcionando</td></tr>
        <tr><td><code>RtfFontClass.Describe</code> est\u00e1 en ingl\u00e9s</td><td>es una cadena de conveniencia</td><td>compone tu propio texto con las propiedades</td></tr>
      </table>
      </div>'''


def s_trouble(g):
    return '''      <div class="en">
      <table>
        <tr><th>Symptom</th><th>Cause and cure</th></tr>
        <tr><td><code>Illegal data type</code> on the class declaration</td><td>A source file saved with Unix line endings. Clarion source must be <b>CRLF</b>.</td></tr>
        <tr><td>The template does not appear after copying it</td><td>Register it, then <b>restart the IDE</b>: it reads the registry at start-up.</td></tr>
        <tr><td>Every record prints the same document</td><td>A VIEW read does not fill BLOBs. Tick <i>Re-read the record by its primary key</i> (code template) or GET the record yourself.</td></tr>
        <tr><td>The report prints the band twice</td><td>The band is also printed by ABC. The extension handles it; with the code template set the band's Detail Filter to <code>False</code>.</td></tr>
        <tr><td>Other controls in the document band vanish or move</td><td>In WD:Flow the band is cut to each line. Keep the IMAGE alone in its band.</td></tr>
        <tr><td><code>Doc1.Err</code> is not 0 after Init</td><td>The step that failed: -4 msftedit.dll missing, -6 no display device, -10/-11/-12 a window could not be created.</td></tr>
      </table>
      </div>
      <div class="es">
      <table>
        <tr><th>S\u00edntoma</th><th>Causa y soluci\u00f3n</th></tr>
        <tr><td><code>Illegal data type</code> en la declaraci\u00f3n de la clase</td><td>Un fichero fuente guardado con finales de l\u00ednea Unix. El c\u00f3digo Clarion debe ser <b>CRLF</b>.</td></tr>
        <tr><td>La plantilla no aparece tras copiarla</td><td>Reg\u00edstrala y <b>reinicia el IDE</b>: lee el registro al arrancar.</td></tr>
        <tr><td>Todos los registros imprimen el mismo documento</td><td>Una lectura de VIEW no rellena los BLOB. Marca <i>Re-read the record by its primary key</i> (plantilla de c\u00f3digo) o haz t\u00fa el GET.</td></tr>
        <tr><td>El informe imprime la banda dos veces</td><td>ABC tambi\u00e9n imprime la banda. La extensi\u00f3n lo resuelve; con la plantilla de c\u00f3digo pon el Detail Filter de la banda a <code>False</code>.</td></tr>
        <tr><td>Otros controles de la banda del documento desaparecen o se mueven</td><td>En WD:Flow la banda se recorta a cada l\u00ednea. Deja el IMAGE solo en su banda.</td></tr>
        <tr><td><code>Doc1.Err</code> distinto de 0 tras Init</td><td>El paso que fall\u00f3: -4 falta msftedit.dll, -6 sin dispositivo de pantalla, -10/-11/-12 no se pudo crear una ventana.</td></tr>
      </table>
      </div>'''


SECTIONS = [
    ('over', 'Overview', 'Resumen', s_over),
    ('install', 'Install &amp; register', 'Instalar y registrar', s_install),
    ('templates', 'The four templates', 'Las cuatro plantillas', s_templates),
    ('editor', 'The editor on a window', 'El editor en una ventana', s_editor),
    ('toolbar', 'Toolbar, keys and page view', 'Barra, teclas y vista de p\u00e1gina', s_toolbar),
    ('storage', 'One BLOB, plain RTF', 'Un BLOB, RTF normal', s_storage),
    ('undo', 'Undo', 'Deshacer', s_undo),
    ('report', 'Printing in a REPORT', 'Imprimir en un REPORT', s_report),
    ('flow', 'WD:Flow and WD:Pages', 'WD:Flow y WD:Pages', s_flow),
    ('wmf', 'Why WMF, and what the conversion needed', 'Por qu\u00e9 WMF y qu\u00e9 necesit\u00f3 la conversi\u00f3n', s_wmf),
    ('tools', 'RTF tool classes', 'Clases RTF', s_tools),
    ('search', 'RtfSearchClass: find and replace', 'RtfSearchClass: buscar y reemplazar', s_search),
    ('fonts', 'RtfFontClass: which font am I on?', 'RtfFontClass: \u00bfen qu\u00e9 fuente estoy?', s_fonts),
    ('text', 'RtfTextClass: plain text', 'RtfTextClass: texto plano', s_text),
    ('html', 'RtfHtmlClass and RtfMarkdownClass', 'RtfHtmlClass y RtfMarkdownClass', s_html),
    ('merge', 'RtfMergeClass: mail merge', 'RtfMergeClass: combinar correspondencia', s_merge),
    ('inside', 'How it is built', 'C\u00f3mo est\u00e1 hecho', s_inside),
    ('tests', 'Demos and tests', 'Demos y pruebas', s_tests),
    ('ref', 'Class reference', 'Referencia de clases', s_ref),
    ('quirks', 'Known limits', 'L\u00edmites conocidos', s_quirks),
    ('trouble', 'Troubleshooting', 'Problemas', s_trouble),
]
