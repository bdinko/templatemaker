# -*- coding: latin-1 -*-
"""Build the emailTo manual: four volumes, in English and Spanish.

    python build-docs.py

Eight pages, published as eight artifacts. The reference volume is generated
from the shipped sources by extract.py, so a signature in the manual cannot
drift from the signature in the build.

The build FAILS LOUDLY rather than warning softly. It refuses to finish if a
nav entry points at no heading, a heading sits in no nav, a public member
carries no worked line of code, an example names a member that no longer
exists, or an English one-liner has gained no Spanish twin. Add a method and
the build tells you the manual is behind the code; remove one and it tells you
the manual is ahead of it.
"""
import sys
import os

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from shell import PROBLEMS, EXAMPLES, check_examples   # noqa: E402
import lang                                     # noqa: E402

BUILDS = [('en', 'English'), ('es', 'Espanol')]


def build(langcode):
    lang.LANG[0] = langcode
    if langcode == 'es':
        import content_es as C
    else:
        import content_en as C
    return [
        ('getting-started',   C.build_getting_started()),
        ('programmers-guide', C.build_programmers_guide()),
        ('template-guide',    C.build_template_guide()),
        ('reference',         C.build_reference()),
    ]


if __name__ == '__main__':
    for code, name in BUILDS:
        print('%s:' % name)
        suffix = '' if code == 'en' else '-es'
        for base, size in build(code):
            print('  %-26s %7d bytes' % (base + suffix + '.html', size))
        print('')

    real = check_examples()

    if PROBLEMS:
        print('%d problem(s) - the manual has drifted from the code:' % len(PROBLEMS))
        for x in PROBLEMS:
            print('   ', x)
        raise SystemExit(1)

    print('no drift, both languages: every nav entry lands on a heading, every')
    print('heading is in a nav, all %d public members carry a worked example' % len(real))
    print('and every example names one that exists, and every English one-liner')
    print('has a Spanish twin.')
