"""Read the emailTo sources and hand back the API as data.

The reference volume is generated from this, never hand-written, so a
signature in the manual cannot drift from the signature in the build.
"""
import io
import os
import re

SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                   '..', '..', 'templates', 'emailTo')

INCS = ['EmailNetClass.inc', 'EmailMsgClass.inc', 'EmailToClass.inc',
        'EmailJsonClass.inc', 'EmailApiClass.inc']


def _read(name):
    with io.open(os.path.join(SRC, name), encoding='latin-1', newline='') as fh:
        text = fh.read().replace('\r\n', '\n')
    #  Fold Clarion's line continuation away before anything is parsed. Read a
    #  line at a time, a prototype that wraps is invisible - which is exactly
    #  how EmailApiClass.Row, the method for adding a provider, stayed out of
    #  the reference volume without the drift check noticing.
    return re.sub(r'\|[ \t]*\n[ \t]*', ' ', text)


def equates():
    """Every NAME EQUATE(value) in the includes, grouped by its prefix."""
    groups = {}
    for inc in INCS:
        section = ''
        for line in _read(inc).split('\n'):
            m = re.match(r'^!\s*-+\s*(.+?)\s*-+\s*$', line)
            if m:
                section = m.group(1)
                continue
            m = re.match(r'^([A-Za-z_][A-Za-z0-9_]*:[A-Za-z0-9_]+)\s+EQUATE\(([^)]*)\)\s*'
                         r'(?:!\s*(.*))?$', line)
            if not m:
                continue
            name, value, comment = m.group(1), m.group(2), (m.group(3) or '').strip()
            prefix = name.split(':')[0]
            groups.setdefault(prefix, {'inc': inc, 'section': section, 'items': []})
            groups[prefix]['items'].append((name, value, comment))
    return groups


def queues():
    """The TYPEd QUEUE structures callers actually touch."""
    out = []
    for inc in INCS:
        text = _read(inc)
        for m in re.finditer(r'^(\w+)\s+QUEUE,TYPE\s*$(.*?)^\s+END\s*$',
                             text, re.S | re.M):
            fields = []
            for fl in m.group(2).split('\n'):
                fm = re.match(r'^(\w+)\s+(&?[A-Z]+(?:\([^)]*\))?(?:,\w+)*)\s*'
                              r'(?:!\s*(.*))?$', fl.strip() and fl or '')
                if fm:
                    fields.append((fm.group(1), fm.group(2), (fm.group(3) or '').strip()))
            out.append((m.group(1), inc, fields))
    return out


def groups():
    """The TYPEd GROUP structures (the account)."""
    out = []
    for inc in INCS:
        text = _read(inc)
        for m in re.finditer(r'^(\w+)\s+GROUP,TYPE\s*$(.*?)^\s+END\s*$',
                             text, re.S | re.M):
            fields = []
            for fl in m.group(2).split('\n'):
                fm = re.match(r'^(\w+)\s+([A-Z]+(?:\([^)]*\))?(?:,\w+)*)\s*'
                              r'(?:!\s*(.*))?$', fl.strip() and fl or '')
                if fm:
                    fields.append((fm.group(1), fm.group(2), (fm.group(3) or '').strip()))
            out.append((m.group(1), inc, fields))
    return out


def classes():
    """Each CLASS with its properties and methods, in declaration order.

    A member is a property when its type is not PROCEDURE.  Trailing "!"
    comments become the member's one-line description, and a run of comment
    lines immediately above a member is folded in too, so the manual reads
    what the source says rather than what somebody remembered.
    """
    out = []
    for inc in INCS:
        text = _read(inc)
        for m in re.finditer(
                r'^(\w+)\s+CLASS,TYPE,MODULE\(\'([^\']+)\'\)[^\n]*\n(.*?)^\s+END\s*$',
                text, re.S | re.M):
            cname, module, body = m.group(1), m.group(2), m.group(3)
            props, meths, pending, section = [], [], [], ''
            for line in body.split('\n'):
                if not line.strip():
                    pending = []
                    continue
                sm = re.match(r'^!\s*-+\s*(.+?)\s*-+\s*$', line)
                if sm:
                    section = sm.group(1).strip()
                    pending = []
                    continue
                if line.lstrip().startswith('!'):
                    pending.append(line.lstrip()[1:].strip())
                    continue
                mm = re.match(r'^(\w+)\s+(PROCEDURE\(.*?\)|PROCEDURE)((?:,[A-Z]+(?:\([^)]*\))?)*)\s*'
                              r'(?:!\s*(.*))?$', line)
                if mm:
                    doc = (mm.group(4) or '').strip()
                    attrs = mm.group(3) or ''
                    meths.append({'name': mm.group(1),
                                  'sig': mm.group(2) + attrs,
                                  'attrs': attrs,
                                  'private': 'PRIVATE' in attrs,
                                  'doc': doc,
                                  'lead': ' '.join(pending),
                                  'section': section})
                    pending = []
                    continue
                pm = re.match(r'^(\w+)\s+(&?[A-Za-z]+(?:\([^)]*\))?(?:,[A-Z]+(?:\([^)]*\))?)*)\s*'
                              r'(?:!\s*(.*))?$', line)
                if pm and pm.group(2) != 'PROCEDURE':
                    props.append({'name': pm.group(1),
                                  'type': pm.group(2),
                                  'private': 'PRIVATE' in pm.group(2),
                                  'doc': (pm.group(3) or '').strip(),
                                  'lead': ' '.join(pending),
                                  'section': section})
                    pending = []
                    continue
                pending = []
            out.append({'name': cname, 'module': module, 'inc': inc,
                        'props': props, 'methods': meths})
    return out


def c_api():
    """The functions emailc.c exports, taken from the MAP that binds them."""
    text = _read('EmailNetClass.clw')
    m = re.search(r"MODULE\('emailc\.c'\)(.*?)^\s+END", text, re.S | re.M)
    if not m:
        return []
    out = []
    for line in m.group(1).split('\n'):
        fm = re.match(r'^(\w+)\s+(PROCEDURE\([^)]*\))((?:,\w+(?:\([^)]*\))?)*)', line.strip())
        if fm:
            out.append((fm.group(1), fm.group(2) + (fm.group(3) or '')))
    return out


if __name__ == '__main__':
    cs = classes()
    for c in cs:
        print('%-18s %2d properties  %2d methods   (%s)'
              % (c['name'], len(c['props']), len(c['methods']), c['inc']))
    print('equate groups :', ', '.join(sorted(equates())))
    print('queues        :', ', '.join(q[0] for q in queues()))
    print('groups        :', ', '.join(g[0] for g in groups()))
    print('C functions   :', len(c_api()))
    pub = 0
    for c in cs:
        pub += len([p for p in c['props'] if not p['private']])
        pub += len([m for m in c['methods'] if not m['private']])
    print('public members needing a worked example:', pub)
