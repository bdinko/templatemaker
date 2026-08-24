# -*- coding: latin-1 -*-
"""The page shell for the emailTo manual: nav, headings and the drift checks.

    python build-docs.py

Volume 4 is generated from the shipped sources by extract.py, so a signature
in the manual cannot drift from the signature in the build.  The build fails
loudly on drift: a nav entry that points at no heading, a heading in no nav,
or a class member with no worked example.
"""
import io
import os
import re
import sys
import html as _html

sys.dont_write_bytecode = True   # no __pycache__ beside the manual

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import extract                      # noqa: E402
from examples_data import EXAMPLES  # noqa: E402
from lang import (LANG, T, is_es, fname, VOLUME_TITLES,   # noqa: E402
                  VOLUME_BLURBS, PAGE_TITLES, DESCRIPTIONS)

PROBLEMS = []

CSS = io.open(os.path.join(HERE, '_doc.css'), encoding='utf-8', newline='').read()
JS = io.open(os.path.join(HERE, '_doc.js'), encoding='utf-8', newline='').read()

# ---------------------------------------------------------------- helpers
def esc(s):
    return _html.escape(s or '')


def slug(s):
    return re.sub(r'[^a-z0-9]+', '-', s.lower()).strip('-')


def code(txt, lang='clarion'):
    return ('<pre class="code" data-lang="%s"><code>%s</code></pre>'
            % (lang, esc(txt.strip('\n'))))


def usecode(txt):
    return '<pre class="code code--use" data-lang="use"><code>%s</code></pre>' % esc(txt)


def note(kind, title, body):
    #  'note' is the neutral one and takes the base style, so it gets no
    #  modifier class - an empty note--note rule would only look like an
    #  oversight to the next person reading the stylesheet.
    mod = '' if kind == 'note' else ' note--' + kind
    return ('<aside class="note%s"><p class="note__t">%s</p>'
            '<div class="note__b">%s</div></aside>' % (mod, esc(title), body))


def table(head, rows, cls=''):
    th = ''.join('<th>%s</th>' % h for h in head)
    tr = ''.join('<tr>%s</tr>' % ''.join('<td>%s</td>' % c for c in r) for r in rows)
    return ('<div class="tw"><table class="%s"><thead><tr>%s</tr></thead>'
            '<tbody>%s</tbody></table></div>' % (cls, th, tr))


#  Headings take HTML, exactly as p() does - a heading is author-written, never
#  user input, and escaping it turned a deliberate &mdash; into four literal
#  characters on the page AND in the sidebar that quotes it back.
def h2(aid, text):
    return '<h2 id="%s">%s</h2>' % (aid, text)


def h3(aid, text):
    return '<h3 id="%s">%s</h3>' % (aid, text)


def p(text):
    return '<p>%s</p>' % text


# ---------------------------------------------------------------- volumes
VOLUME_FILES = ['getting-started.html', 'programmers-guide.html',
                'template-guide.html', 'reference.html']


def volumes():
    """The four volumes, named in whichever language is being built."""
    return [(f, T(*VOLUME_TITLES[f]), T(*VOLUME_BLURBS[f])) for f in VOLUME_FILES]

#  Published, each volume is its own page at its own address, so a relative
#  filename never reaches the next one.  Filled in after the first publish.
#  Both language sets.  A volume links to its own language throughout, and
#  reaches its twin through the one switch at the top of the sidebar.
PUBLISHED = {}
for _f in VOLUME_FILES:
    PUBLISHED[_f] = _f
    PUBLISHED[_f.replace('.html', '-es.html')] = _f.replace('.html', '-es.html')

_urls = os.path.join(HERE, 'published-urls.txt')
if os.path.exists(_urls):
    for line in io.open(_urls, encoding='utf-8'):
        line = line.strip()
        if line and '=' in line and not line.startswith('#'):
            k, v = line.split('=', 1)
            PUBLISHED[k.strip()] = v.strip()


def href(target, current):
    t = fname(target)                       # stay inside the language being built
    return '#' if t == current else PUBLISHED.get(t, t)


def volnav(current):
    out = ['<ul class="vols">']
    for i, (fn, name, blurb) in enumerate(volumes()):
        here = ' class="here"' if fn == current else ''
        out.append('<li><a href="%s"%s>%d. %s<small>%s</small></a></li>'
                   % (href(fn, current), here, i + 1, esc(name), esc(blurb)))
    out.append('</ul>')
    return ''.join(out)


def headings(body):
    """Every anchored id in the body, with the words actually printed above it."""
    out = {}
    for m in re.finditer(r'<h([23]) id="([^"]+)"[^>]*>(.*?)</h\1>', body, re.S):
        txt = re.sub(r'<span class="k">.*?</span>', '', m.group(3), flags=re.S)
        out[m.group(2)] = re.sub(r'\s+', ' ', re.sub(r'<[^>]+>', '', txt)).strip()
    return out


def secnav(groups, titles):
    #  The sidebar prints the heading itself, never a second wording of it:
    #  two hand-kept lists drift, and a reader who clicks one wording and
    #  lands under another believes the link is broken.
    out = []
    for group, items in groups:
        if group:
            out.append('<p class="nav__g">%s</p>' % esc(group))
        out.append('<ul class="nav__l">')
        for aid, label in items:
            #  titles[] was scraped back out of the rendered <h2>/<h3>, so it is
            #  ALREADY escaped - esc() on it a second time is what put a literal
            #  "&mdash;" in the sidebar. Only the hand-written fallback is raw.
            text = titles[aid] if aid in titles else esc(label)
            out.append('<li><a href="#%s">%s</a></li>' % (aid, text))
        out.append('</ul>')
    return ''.join(out)


def nextcards(names):
    cards = []
    for h in names:
        for fn, name, blurb in volumes():
            if fn == h:
                tgt = fname(fn)
                cards.append('<a href="%s"><b>%s &rarr;</b><span>%s</span></a>'
                             % (PUBLISHED.get(tgt, tgt), esc(name), esc(blurb)))
    return '<div class="next">%s</div>' % ''.join(cards)


def foot():
    return T('emailTo &mdash; four volumes. The reference is generated from the five '
             'include files, so its signatures are the ones in the build.',
             'emailTo &mdash; cuatro vol&uacute;menes. La referencia se genera a '
             'partir de los cinco archivos include, de modo que sus firmas son las '
             'que est&aacute;n en la compilaci&oacute;n.')


def langswitch(base):
    #  The one link that crosses languages.  It names the OTHER language in
    #  that language - the only wording a reader looking for it will recognise.
    if is_es():
        target, label, code = PUBLISHED.get(base, base), 'English', 'en'
    else:
        es = base.replace('.html', '-es.html')
        target, label, code = PUBLISHED.get(es, es), 'Espa&ntilde;ol', 'es'
    return '<a class="langsw" href="%s" hreflang="%s">%s</a>' % (target, code, label)


def public_members():
    """Every public member the sources actually declare, as "Class.Member"."""
    out = set()
    for c in extract.classes():
        for kind in ('props', 'methods'):
            for m in c.get(kind, []):
                if not m.get('private'):
                    out.add('%s.%s' % (c['name'], m['name']))
    return out


def check_examples():
    """An example for a member that no longer exists is drift too.

    The build already refused to finish when a member had no example. It said
    nothing about the other direction, so an example outlived its method twice
    over - and was still being counted in the "N members" chip.
    """
    real = public_members()
    for key in sorted(set(EXAMPLES) - real):
        PROBLEMS.append('examples_data.py: %s has an example but is not a '
                        'public member of any class' % key)
    return real


def page(base, title, eyebrow, heading, sub, chips, groups, body, showfilter=False):
    filename = fname(base)
    titles = headings(body)
    linked = [aid for _, items in groups for aid, _ in items]
    for aid in linked:
        if aid not in titles:
            PROBLEMS.append('%s: the nav points at #%s, which is not a heading'
                            % (filename, aid))
    for aid in titles:
        if aid not in linked:
            PROBLEMS.append('%s: heading #%s (%s) is in no nav'
                            % (filename, aid, titles[aid]))
    nav = langswitch(base) + volnav(filename)
    if showfilter:
        nav += ('<label class="ui" style="font-size:11px;color:var(--faint);'
                'letter-spacing:.08em;text-transform:uppercase" for="filter">Filter</label>'
                '<input id="filter" class="filter" type="search" '
                'placeholder="SendSimple, Attach&hellip;" autocomplete="off">')
    nav += secnav(groups, titles)
    chiphtml = ''.join('<span class="chip">%s</span>' % c for c in chips)
    doc = ('<meta charset="utf-8">'                 # the Spanish volumes depend on it
           '<title>%s</title>\n'
           '<meta name="viewport" content="width=device-width,initial-scale=1">\n'
           '<link rel="preconnect" href="https://fonts.googleapis.com">\n'
           '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
           '<link rel="stylesheet" href="https://fonts.googleapis.com/css2?'
           'family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500;600&'
           'family=IBM+Plex+Serif:wght@400;600&display=swap">\n'
           '<style>%s</style>\n'
           '<div class="wrap">\n<nav class="side">\n'
           '  <p class="brand"><b>emailTo</b></p>\n%s\n</nav>\n'
           '<main class="main">\n'
           '  <header class="hero"><div class="inner">\n'
           '    <p class="eyebrow">%s</p>\n    <h1>%s</h1>\n    <p class="sub">%s</p>\n'
           '    <div class="chips">%s</div>\n'
           '  </div></header>\n  <div class="inner">%s\n'
           '    <footer>%s</footer>\n'
           '  </div>\n</main>\n</div>\n<script>%s</script>\n'
           % (esc(title), CSS, nav, esc(eyebrow), esc(heading), sub, chiphtml,
              body, foot(), JS))
    io.open(os.path.join(HERE, filename), 'w', encoding='utf-8', newline='\n').write(doc)
    return len(doc)

