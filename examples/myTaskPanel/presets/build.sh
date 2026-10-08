#!/bin/bash
# The PRESETS harness: registers a test copy of myTaskPanel.tpl whose #ATSTART
# runs every preset (they are IDE buttons, which ClarionCL cannot press), then
# generates and compiles TaskPanelPre. Re-register the real template afterwards
# (templates/myTaskPanel/deploy-test.sh).
set -e
cd "$(dirname "$0")"
CL=/c/clarion12/bin/ClarionCL.exe
cp ../../../templates/myTaskPanel/libsrc/win/{MyTaskPanel.inc,MyTaskPanel.clw,mtpd2d.c} /c/clarion12/accessory/libsrc/win/
cp myTaskPanel.tpl /c/clarion12/accessory/template/win/myTaskPanel.tpl
"$CL" -tr "C:\clarion12\accessory\template\win\myTaskPanel.tpl"
rm -f TaskPanelPre.app TASKPANELPRE* TaskPanelPre.clw TaskPanelPre_BC*; rm -rf obj
"$CL" -win -au -ai TaskPanelPre.app TaskPanelPre.txa >import.log 2>&1 || true
"$CL" -win -au -ag TaskPanelPre.app >gen.log 2>&1 || true
grep -iE " error" gen.log && exit 1 || true
python - <<'PYEOF'
import io
p='TaskPanelPre.clw'
s=io.open(p,'r',newline='',encoding='latin-1').read()
m="!--- Application Global and Exported Procedure Definitions"
if "INCLUDE('TASKPANELPRE001.INC')" not in s:
    s=s.replace(m,"     INCLUDE('TASKPANELPRE001.INC'),ONCE\r\n"+m)
if "  Main\r\n  INIMgr.Update" not in s:              # AppGen already calls it when the TXA names it
    s=s.replace("  INIMgr.Update\r\n","  Main\r\n  INIMgr.Update\r\n",1)
io.open(p,'w',newline='',encoding='latin-1').write(s)
PYEOF
"C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe" TaskPanelPre.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin" -v:m 2>&1 | grep -E " error|warning" | sed 's/ \[C:.*//' || true
ls -l TaskPanelPre.exe
