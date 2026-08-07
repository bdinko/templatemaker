import io, re, sys

# Add BrowseGridGlobal to the program, and BrowseGrid to BrowseStudents, in a
# TXA exported from a COPY of School. Nothing here touches the real app.
p = "school.txa"
d = io.open(p, encoding="latin-1").read()

# --- the global extension, right after the program's [COMMON] --------------
if "NAME BrowseGrid BrowseGridGlobal" not in d:
    m = re.search(r"\[PROGRAM\]\r?\n\[COMMON\]\r?\n(?:.*?\r?\n)?", d)
    anchor = m.group(0)
    d = d.replace(anchor, anchor + "[ADDITION]\nNAME BrowseGrid BrowseGridGlobal\n[INSTANCE]\nINSTANCE 1\n[PROMPTS]\n%bgGDisable LONG  (0)\n", 1)
    print("global extension added after:", repr(anchor[:40]))

# --- the procedure extension on BrowseStudents ------------------------------
i = d.index("[PROCEDURE]\nNAME BrowseStudents") if "[PROCEDURE]\nNAME BrowseStudents" in d \
    else d.index("[PROCEDURE]\r\nNAME BrowseStudents")
# insert just before that procedure's [WINDOW], which is where additions end
j = d.index("[WINDOW]", i)
add = """[ADDITION]
NAME BrowseGrid BrowseGrid
[INSTANCE]
INSTANCE 99
[PROMPTS]
%bgDisable LONG  (0)
%bgObject DEFAULT  ('Grid1')
%bgList DEFAULT  ('?Browse:1')
%bgQueue DEFAULT  ('Queue:Browse:1')
%bgFrozen LONG  (1)
%bgFont DEFAULT  ('Segoe UI')
%bgSize LONG  (9)
%bgRowH LONG  (0)
%bgHdrH LONG  (0)
%bgCBack LONG  (16777215)
%bgCBand LONG  (16054270)
%bgCGrid LONG  (15393450)
%bgCText LONG  (2041651)
%bgCHdrBack LONG  (2832970)
%bgCHdrText LONG  (16777215)
%bgCSelBack LONG  (3107765)
%bgCSelText LONG  (16777215)
"""
d = d[:j] + add + d[j:]
io.open(p, "w", encoding="latin-1", newline="").write(d)
print("BrowseGrid added to BrowseStudents")
