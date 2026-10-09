#!/bin/bash
# Regenerate NotifyGen from the TXA with the installed notifications template,
# then compile it. Proves the template end to end: prompts -> generated code ->
# a running program. (Re-imports every time: ClarionCL only regenerates modules
# it thinks changed. The Main call is patched in because a TXA import leaves the
# application's first procedure unset.)
set -e
cd "$(dirname "$0")"
CL=/c/clarion12/bin/ClarionCL.exe
MSB="C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe"
rm -f NotifyGen.app NotifyGen.clw NOTIFYGEN001.CLW NOTIFYGEN001.INC NOTIFYGEN_BC.CLW NotifyGen_BC0.CLW
rm -rf obj
"$CL" -win -au -ai NotifyGen.app NotifyGen.txa >/dev/null 2>&1
"$CL" -win -au -ag NotifyGen.app 2>&1 | grep -E "successfully|error" || true
[ -f NOTIFYGEN001.CLW ] || { echo "!! generate produced no module"; exit 1; }
python - <<'PYEOF'
import io
p = 'NotifyGen.clw'
s = io.open(p, 'r', newline='', encoding='latin-1').read()
marker = "!--- Application Global and Exported Procedure Definitions"
assert s.count(marker) == 1
s = s.replace(marker, "     INCLUDE('NOTIFYGEN001.INC'),ONCE\r\n" + marker)
s = s.replace("  INIMgr.Update\r\n", "  Main\r\n  INIMgr.Update\r\n", 1)   # after %ProgramSetup, as in a real app
io.open(p, 'w', newline='', encoding='latin-1').write(s)
PYEOF
mkdir -p images && cp ../images/*.png images/ && cp ../chat-reply.ntf .
"$MSB" NotifyGen.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 \
       -p:ClarionBinPath="C:\clarion12\bin" -v:m 2>&1 | grep -E " error|warning" | sed 's/ \[C:.*//' || true
ls -l NotifyGen.exe
