# -*- coding: utf-8 -*-
"""Builds docs/myWordDoc-template.html and docs/myWordDoc-reference.html.

    python examples/myWordDoc/docgen/make_docs.py

The pages use the house layout (CSS taken verbatim from docs/xQuickFilter-template.html):
dark sidebar, hero, English/Espanol toggle, callouts, coloured Clarion code.
The reference is generated from ref_data.py, which follows the .inc files.
"""
import html
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
DOCS = os.path.join(ROOT, 'docs')
sys.path.insert(0, HERE)
import ref_data as R            # noqa: E402
import page_text as T           # noqa: E402

# ---------------------------------------------------------------------------
house = open(os.path.join(DOCS, 'xQuickFilter-template.html'), encoding='utf-8').read()
CSS = house[house.index('<style>'):house.index('</style>') + len('</style>')]
CSS = CSS.replace('</style>', '  h4{font-size:13.5px;margin:18px 0 4px;color:var(--navy);text-transform:uppercase;letter-spacing:.5px}\n'
                  '  .sig{font-family:"Cascadia Code",Consolas,monospace;font-size:13.5px;color:var(--navy);font-weight:600;'
                  'margin:18px 0 2px;padding-top:8px;border-top:1px dashed var(--line)}\n'
                  '  td code{white-space:nowrap}\n</style>')

KEYWORDS = set('''IF THEN ELSE ELSIF END LOOP TO WHILE UNTIL BREAK CYCLE CODE RETURN CASE OF OROF PROCEDURE CLASS
INCLUDE ONCE MAP MODULE ACCEPT OPEN CLOSE PRINT BIND MESSAGE TRUE FALSE NOT AND OR NEW DISPOSE ADD GET DO
ROUTINE EXIT CHOOSE CLIP LEFT FORMAT ENABLE DISABLE RUN SETTARGET'''.split())
TYPES = set('LONG STRING CSTRING BYTE REAL BLOB REPORT QUEUE WINDOW'.split())


def clw(code):
    """HTML for a block of Clarion: strings .s, comments .c, keywords .k, types .t"""
    out = []
    for line in code.split('\n'):
        i, n, buf = 0, len(line), []
        while i < n:
            ch = line[i]
            if ch == "'":
                j = i + 1
                while j < n:
                    if line[j] == "'" and j + 1 < n and line[j + 1] == "'":
                        j += 2
                        continue
                    if line[j] == "'":
                        break
                    j += 1
                buf.append('<span class="s">' + html.escape(line[i:j + 1], False) + '</span>')
                i = j + 1
            elif ch == '!':
                buf.append('<span class="c">' + html.escape(line[i:], False) + '</span>')
                i = n
            elif ch.isalpha() or ch == '_':
                j = i
                while j < n and (line[j].isalnum() or line[j] in '_:#'):
                    j += 1
                w = line[i:j]
                prev = line[i - 1] if i else ' '
                if prev not in '.?' and w.upper() == w and w in KEYWORDS:
                    buf.append('<span class="k">' + w + '</span>')
                elif prev not in '.?' and w in TYPES:
                    buf.append('<span class="t">' + w + '</span>')
                else:
                    buf.append(html.escape(w, False))
                i = j
            else:
                buf.append(html.escape(ch, False))
                i += 1
        out.append(''.join(buf))
    return '<pre>' + '\n'.join(out) + '</pre>'


def bi(en, es, tag='div'):
    return '<%s class="en">%s</%s><%s class="es">%s</%s>' % (tag, en, tag, tag, es, tag)


def sp(en, es):
    return bi(en, es, 'span')


def page(fname, title, brand_en, brand_es, nav, hero, body, foot_en, foot_es):
    navhtml = []
    for item in nav:
        if item[0] == 'grp':
            navhtml.append('    <div class="grp">%s</div>' % sp(item[1], item[2]))
        else:
            cls = ' class="h2"' if item[0] == 'h2' else ''
            navhtml.append('    <a href="#%s"%s>%s</a>' % (item[1], cls, sp(item[2], item[3])))
    doc = '''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s</title>
%(css)s
</head>
<body>
<div class="wrap">
  <nav>
    <div class="brand"><h1>myWordDoc</h1><span class="en">%(be)s</span><span class="es">%(bs)s</span></div>
%(nav)s
  </nav>

  <main>
%(hero)s

    <div class="langbar">
      <button id="btn-en" onclick="setLang('en')">English</button>
      <button id="btn-es" onclick="setLang('es')">Español</button>
    </div>

    <div class="body">
%(body)s
    </div>
    <footer>
      <span class="en">%(fe)s</span>
      <span class="es">%(fs)s</span>
    </footer>
  </main>
</div>
<script>
  function setLang(l){
    document.documentElement.setAttribute('data-lang', l);
    document.getElementById('btn-en').classList.toggle('on', l==='en');
    document.getElementById('btn-es').classList.toggle('on', l==='es');
    try{ localStorage.setItem('mc-lang', l); }catch(e){}
  }
  var saved='en';
  try{ saved = localStorage.getItem('mc-lang') || (navigator.language||'en').slice(0,2); }catch(e){}
  setLang(saved==='es' ? 'es' : 'en');
</script>
</body>
</html>
''' % dict(title=title, css=CSS, be=brand_en, bs=brand_es, nav='\n'.join(navhtml), hero=hero,
           body=body, fe=foot_en, fs=foot_es)
    check(fname, doc)
    open(os.path.join(DOCS, fname), 'w', encoding='utf-8', newline='\n').write(doc)
    print('wrote', fname, len(doc), 'bytes')


def check(fname, doc):
    """balanced tags, every #anchor exists, equal EN/ES blocks, images exist"""
    ids = set(re.findall(r'id="([^"]+)"', doc))
    for a in re.findall(r'href="#([^"]+)"', doc):
        assert a in ids, (fname, 'dangling anchor', a)
    for t in ('div', 'section', 'table', 'pre', 'span', 'p', 'figure', 'ul', 'ol', 'tr', 'td', 'th', 'code', 'b'):
        o = len(re.findall(r'<%s[\s>]' % t, doc))
        c = doc.count('</%s>' % t)
        assert o == c, (fname, 'unbalanced', t, o, c)
    en = len(re.findall(r'class="[^"]*\ben\b', doc))
    es = len(re.findall(r'class="[^"]*\bes\b', doc))
    assert en == es, (fname, 'en/es blocks differ', en, es)
    for src in re.findall(r'src="([^"]+)"', doc):
        assert os.path.exists(os.path.join(DOCS, src)), (fname, 'missing image', src)


def section(sid, h_en, h_es, inner):
    return ('    <section id="%s">\n      <h2>%s <a href="#%s" class="top">#</a></h2>\n%s\n    </section>\n'
            % (sid, sp(h_en, h_es), sid, inner))


def shot(base, cap_en, cap_es, es_suffix=True):
    es_src = base.replace('.png', '-es.png') if es_suffix else base
    return ('      <figure class="shots" style="display:block">\n'
            '        <img class="shot en" src="%s" alt="%s">\n'
            '        <img class="shot es" src="%s" alt="%s">\n'
            '        <figcaption style="text-align:left">%s</figcaption>\n'
            '      </figure>' % (base, html.escape(re.sub('<[^>]+>', '', cap_en)), es_src,
                                html.escape(re.sub('<[^>]+>', '', cap_es)), sp(cap_en, cap_es)))


# ---------------------------------------------------------------------------
# the reference page
def ref_member(sig, en, es, code, code_es=None):
    s = '      <div class="sig">%s</div>\n' % html.escape(sig, False)
    s += '      ' + bi('<p>%s</p>' % en, '<p>%s</p>' % es) + '\n'
    if code_es and code_es != code:
        s += '      ' + bi(clw(code), clw(code_es)) + '\n'
    else:
        s += '      ' + clw(code) + '\n'
    return s


def prop_table(rows):
    th = ('<tr><th>%s</th><th>%s</th><th>%s</th><th>%s</th></tr>'
          % (sp('Property', 'Propiedad'), sp('Type', 'Tipo'), sp('Meaning', 'Significado'), sp('Example', 'Ejemplo')))
    out = ['      <table>', '        ' + th]
    for name, typ, en, es, ex in rows:
        out.append('        <tr><td><code>%s</code></td><td>%s</td><td>%s</td><td><code>%s</code></td></tr>'
                   % (name, typ, sp(en, es), html.escape(ex, False)))
    out.append('      </table>')
    return '\n'.join(out)


def build_reference():
    nav = [('h1', 'conv', 'Conventions', 'Convenciones'), ('h1', 'equates', 'Equates', 'Equates'),
           ('grp', 'WordDocClass', 'WordDocClass')]
    body = []
    body.append(section('conv', 'Conventions', 'Convenciones', T.REF_CONV))
    rows = ['      <table>', '        <tr><th>Equate</th><th>%s</th><th>%s</th></tr>' % (sp('Value', 'Valor'), sp('Used with', 'Uso'))]
    for name, val, en, es in R.EQUATES:
        rows.append('        <tr><td><code>%s</code></td><td>%s</td><td>%s</td></tr>' % (name, val, sp(en, es)))
    rows.append('      </table>')
    body.append(section('equates', 'Equates', 'Equates', '\n'.join(rows) + '\n      ' + clw(R.EQUATES_CODE)))

    inner = ['      <h3>%s</h3>' % sp('Properties - set before Init', 'Propiedades - antes de Init'),
             prop_table(R.WORDDOC_PROPS_BEFORE),
             '      <h3>%s</h3>' % sp('Properties - read only', 'Propiedades - solo lectura'),
             prop_table(R.WORDDOC_PROPS_RO)]
    body.append(section('wd-props', 'WordDocClass: properties', 'WordDocClass: propiedades', '\n'.join(inner)))
    nav.append(('h2', 'wd-props', 'Properties', 'Propiedades'))
    for k, ((g_en, g_es), members) in enumerate(R.WORDDOC_GROUPS):
        sid = 'wd-%d' % k
        nav.append(('h2', sid, g_en, g_es))
        body.append(section(sid, 'WordDocClass: ' + g_en.lower(), 'WordDocClass: ' + g_es.lower(),
                            ''.join(ref_member(*m) for m in members)))

    nav.append(('grp', 'Tool classes', 'Clases de herramientas'))
    nav.append(('h2', 'base', 'RtfToolBase (every tool)', 'RtfToolBase (todas)'))
    body.append(section('base', 'RtfToolBase: shared by every tool', 'RtfToolBase: común a todas',
                        '      ' + bi('<p>Every tool class inherits these.</p>', '<p>Todas las clases de herramientas los heredan.</p>') + '\n'
                        + ''.join(ref_member(*m) for m in R.BASE)))
    for sid, name, (d_en, d_es), props, methods in R.TOOLS:
        nav.append(('h2', sid, name, name))
        inner = '      ' + bi('<p class="lead">%s</p>' % d_en, '<p class="lead">%s</p>' % d_es) + '\n'
        inner += '      <h3>%s</h3>\n' % sp('Properties', 'Propiedades') + prop_table(props) + '\n'
        inner += '      <h3>%s</h3>\n' % sp('Methods', 'Métodos') + ''.join(ref_member(*m) for m in methods)
        body.append(section(sid, name, name, inner))

    hero = ('    <header class="hero">\n      <h1>myWordDoc - class reference</h1>\n'
            '      ' + bi('<p>Every public property and method of <b>WordDocClass</b> and the six RTF tool classes, in the order the '
                          '<code>.inc</code> files declare them, each with what it does and a line of Clarion that uses it. '
                          'The guide is in <a href="myWordDoc-template.html" style="color:#fff;text-decoration:underline">myWordDoc-template.html</a>.</p>',
                          '<p>Todas las propiedades y métodos públicos de <b>WordDocClass</b> y de las seis clases RTF, en el orden en que los '
                          'declaran los <code>.inc</code>, cada uno con lo que hace y una línea de Clarion que lo usa. '
                          'La guía está en <a href="myWordDoc-template.html" style="color:#fff;text-decoration:underline">myWordDoc-template.html</a>.</p>', 'div')
            + '\n      <span class="pill en">WordDocClass · RtfToolBase · RtfSearchClass · RtfFontClass · RtfTextClass · RtfHtmlClass · RtfMarkdownClass · RtfMergeClass</span>'
            '\n      <span class="pill es">WordDocClass · RtfToolBase · RtfSearchClass · RtfFontClass · RtfTextClass · RtfHtmlClass · RtfMarkdownClass · RtfMergeClass</span>'
            '\n    </header>')
    page('myWordDoc-reference.html', 'myWordDoc - Class reference / Referencia de clases',
         'Class reference', 'Referencia de clases', nav, hero, ''.join(body), T.FOOT_EN, T.FOOT_ES)


def build_template():
    body = ''.join(section(sid, h_en, h_es, inner(globals())) for sid, h_en, h_es, inner in T.SECTIONS)
    page('myWordDoc-template.html', "myWordDoc - Programmer's Documentation / Documentación del programador",
         "Programmer's Documentation", 'Documentación del programador', T.NAV, T.HERO, body, T.FOOT_EN, T.FOOT_ES)


if __name__ == '__main__':
    build_reference()
    build_template()
