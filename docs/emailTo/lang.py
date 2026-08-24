# -*- coding: utf-8 -*-
"""Language plumbing for the manual.

Every authored string in the manual is written as a pair, `T(english,
spanish)`, and each volume is built twice - once per language - into its own
page. Two pages rather than one page with a toggle, because the heading ids
have to stay unique for the anchors, the sidebar and the drift checks to keep
working, and because each volume then stays the size it already is.
"""

LANG = ['en']          # the build sets this; a list so builders see the change


def T(en, es):
    """Pick the wording for the language being built."""
    return es if LANG[0] == 'es' else en


def is_es():
    return LANG[0] == 'es'


#  filename -> (english file, spanish file)
def fname(base):
    return base if LANG[0] == 'en' else base.replace('.html', '-es.html')


VOLUME_TITLES = {
    'getting-started.html':   ('Getting Started', 'Primeros pasos'),
    'programmers-guide.html': ("Programmer's Guide", 'Guía del programador'),
    'template-guide.html':    ('Template Guide', 'Guía de plantillas'),
    'reference.html':         ('Reference', 'Referencia'),
}

VOLUME_BLURBS = {
    'getting-started.html':   ('Install it and send the first message',
                               'Instalarlo y enviar el primer mensaje'),
    'programmers-guide.html': ('How it works, and how to make it do things',
                               'Cómo funciona, y cómo hacer que haga cosas'),
    'template-guide.html':    ('Every template, tab, prompt and embed',
                               'Cada plantilla, pestaña, campo y embed'),
    'reference.html':         ('Every class, method, property and equate',
                               'Cada clase, método, propiedad y equate'),
}

PAGE_TITLES = {
    'getting-started.html':   ('emailTo Getting Started', 'emailTo Primeros pasos'),
    'programmers-guide.html': ("emailTo Programmer's Guide", 'emailTo Guía del programador'),
    'template-guide.html':    ('emailTo Template Guide', 'emailTo Guía de plantillas'),
    'reference.html':         ('emailTo Reference', 'emailTo Referencia'),
}

DESCRIPTIONS = {
    'getting-started.html': (
        'Volume 1 of the emailTo manual: install the classes, send the first message, '
        'and set up OAuth2 with Google or Microsoft step by step.',
        'Volumen 1 del manual de emailTo: instalar las clases, enviar el primer mensaje '
        'y configurar OAuth2 con Google o Microsoft paso a paso.'),
    'programmers-guide.html': (
        'Volume 2 of the emailTo manual: the object model, MIME, OAuth2 with PKCE, and '
        'the Clarion behaviour that bit us on the way.',
        'Volumen 2 del manual de emailTo: el modelo de objetos, MIME, OAuth2 con PKCE y '
        'el comportamiento de Clarion con el que tropezamos.'),
    'template-guide.html': (
        'Volume 3 of the emailTo manual: every template, tab and prompt, and the code '
        'the generator writes into your application.',
        'Volumen 3 del manual de emailTo: cada plantilla, pestaña y campo, y el código '
        'que el generador escribe en su aplicación.'),
    'reference.html': (
        'Volume 4 of the emailTo manual: every class, method, property and equate, '
        'generated from the sources with a worked line of code each.',
        'Volumen 4 del manual de emailTo: cada clase, método, propiedad y equate, '
        'generado desde las fuentes con una línea de código real en cada uno.'),
}
