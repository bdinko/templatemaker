#!/bin/bash
# Proves templates/myWordDoc/template/win/myWordDoc.tpl end to end, headless:
#   register (parse check) -> dictionary from WordDemoDict.dctx -> import
#   WordDemo.txa -> generate -> compile WordDemo.exe with 32-bit MSBuild.
#
# Nothing is copied into any Clarion install. AppGen finds the template through
# a LOCAL redirection file (CLARION120.RED, written here, = the install's own
# file with this repo's template folder put first). The registry only stores
# the template's file NAME, so outside this folder the entry cannot be
# resolved - the script therefore unregisters myWordDoc again on the way out,
# leaving the install's registry exactly as it found it.
#
#   ./build_demo.sh          everything
#   ./build_demo.sh keep     ...but leave myWordDoc registered
set -e
cd "$(dirname "$0")"
HERE_W="$(pwd -W)"
TPL_DIR_W="$(cd ../../../templates/myWordDoc/template/win && pwd -W)"
CL=/c/clarion12/bin/ClarionCL.exe
MSB="C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe"

unregister() { [ "$1" = keep ] || "$CL" -win -tu myWordDoc >/dev/null 2>&1 || true; }
trap "unregister $1" EXIT

echo "== local redirection (template folder first) =="
python - "$TPL_DIR_W" <<'PYEOF'
import io, sys
s = io.open(r'C:\clarion12\bin\CLARION120.RED', 'r', newline='').read()
s = s.replace('[Common]\r\n', '[Common]\r\n*.tp? = ' + sys.argv[1].replace('/', '\\') + '\r\n', 1)
io.open('CLARION120.RED', 'w', newline='').write(s)
PYEOF

echo "== register (parse check) =="
OUT=$("$CL" -win -tr "$(echo "$TPL_DIR_W/myWordDoc.tpl" | sed 's#/#\\#g')" 2>&1 | grep -v CLCE004 || true)
[ -z "$OUT" ] && echo "   clean" || { echo "$OUT"; exit 1; }

echo "== dictionary =="
# a BLOB in a .dctx is DataType="MEMO" with Binary and NO Size
if [ ! -f WordDemo.dct ] || [ WordDemoDict.dctx -nt WordDemo.dct ]; then
  rm -f WordDemo.dct
  "$CL" -win -au -di WordDemo.dct WordDemoDict.dctx >/dev/null 2>&1
fi
ls -l WordDemo.dct | awk '{print "   " $5 " bytes"}'

echo "== import TXA (fresh app every time) =="
rm -f WordDemo.app WordDemo.clw WordDemo0*.clw WORDDEMO0*.INC WORDDEMO_BC.CLW WordDemo_BC0.CLW WORDDEMO.EXP
rm -rf obj map; rm -f WordDemo.exe
"$CL" -win -au -ai WordDemo.app WordDemo.txa >/dev/null 2>&1

echo "== generate =="
GEN=$("$CL" -win -au -ag WordDemo.app 2>&1 || true)
echo "$GEN" | grep -E "error|Unknown|successfully" | sed 's/^/   /'
echo "$GEN" | grep -q "error" && exit 1
grep -q "WordDocRpt1.PaginateForReport" WordDemo00*.clw || { echo "!! not generated from the repo template"; exit 1; }

echo "== patch in the call to Main (a TXA import leaves the first procedure unset) =="
python - <<'PYEOF'
import io
p = 'WordDemo.clw'
s = io.open(p, 'r', newline='', encoding='latin-1').read()
marker = "!--- Application Global and Exported Procedure Definitions"
assert s.count(marker) == 1, "marker count changed"
s = s.replace(marker, "     INCLUDE('WORDDEMO001.INC'),ONCE\r\n" + marker)
call = "  INIMgr.Update"
assert s.count(call) >= 1, "INIMgr.Update not found"
s = s.replace(call, "  Main\r\n" + call, 1)
io.open(p, 'w', newline='', encoding='latin-1').write(s)
print("   ok")
PYEOF

echo "== class files beside the app (CRLF) =="
for f in WordDocClass.inc WordDocClass.clw WordDocTools.inc WordDocTools.clw wdoc.c; do
  sed 's/\r$//; s/$/\r/' ../../../templates/myWordDoc/libsrc/win/$f > $f
done

echo "== project =="
python - <<'PYEOF'
import io, glob
mods = sorted(set(glob.glob('WordDemo*.clw') + glob.glob('WORDDEMO*.CLW')), key=str.lower)
items = ''.join('    <Compile Include="%s" />\r\n' % m for m in mods)
proj = io.open('WordDemo.cwproj.in', 'r', newline='').read().replace('@COMPILE@', items)
io.open('WordDemo.cwproj', 'w', newline='').write(proj)
print('   ' + ' '.join(mods))
PYEOF

echo "== compile =="
"$MSB" WordDemo.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 \
       -p:ClarionBinPath="C:\clarion12\bin" -v:m 2>&1 | grep -E "error|warning" | grep -v "MSB" || true
[ -f WordDemo.exe ] && ls -l WordDemo.exe | awk '{print "   WordDemo.exe " $5 " bytes"}' || { echo "!! no exe"; exit 1; }
