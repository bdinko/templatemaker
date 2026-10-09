#!/bin/bash
# Regenerate TaskPanelGen from the TXA with the installed myTaskPanel template
# (C:\clarion12\accessory), then compile it. Proves prompts -> generated code ->
# a program. Re-imports every time (ClarionCL only regenerates modules it thinks
# changed); the first procedure is patched in because a TXA import leaves it unset.
set -e
cd "$(dirname "$0")"
CL=/c/clarion12/bin/ClarionCL.exe
MSB="C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe"
rm -f TaskPanelGen.app TaskPanelGen.clw TASKPANELGEN0*.CLW TASKPANELGEN0*.INC TASKPANELGEN_BC*.CLW TaskPanelGen_BC*.CLW
rm -rf obj
"$CL" -win -au -ai TaskPanelGen.app TaskPanelGen.txa >import.log 2>&1 || true
"$CL" -win -au -ag TaskPanelGen.app >gen.log 2>&1 || true
grep -iE "error|warn" gen.log import.log || true
[ -f TASKPANELGEN001.CLW ] || { echo "!! generate produced no module"; cat gen.log; exit 1; }
python - <<'PYEOF'
import io
p = 'TaskPanelGen.clw'
s = io.open(p, 'r', newline='', encoding='latin-1').read()
marker = "!--- Application Global and Exported Procedure Definitions"
if "INCLUDE('TASKPANELGEN001.INC')" not in s:
    s = s.replace(marker, "     INCLUDE('TASKPANELGEN001.INC'),ONCE\r\n" + marker)
if "  Main\r\n  INIMgr.Update" not in s:
    s = s.replace("  INIMgr.Update\r\n", "  Main\r\n  INIMgr.Update\r\n", 1)
io.open(p, 'w', newline='', encoding='latin-1').write(s)
PYEOF
"$MSB" TaskPanelGen.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 \
       -p:ClarionBinPath="C:\clarion12\bin" -v:m 2>&1 | grep -E " error|warning" | sed 's/ \[C:.*//' || true
ls -l TaskPanelGen.exe
