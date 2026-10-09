#!/bin/sh
# Copies the class from templates/myTaskPanel, converts to CRLF, builds both demos.
cd "$(dirname "$0")"
for f in MyTaskPanel.inc MyTaskPanel.clw mtpd2d.c; do cp ../../templates/myTaskPanel/libsrc/win/$f .; done
for f in *.clw *.inc *.c; do sed -i 's/\r$//; s/$/\r/' "$f"; done
MSB32="C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe"
for p in ${@:-TaskPanelDemo TaskPanelDemoDX}; do
  rm -rf obj
  "$MSB32" $p.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 -p:ClarionBinPath="C:\clarion12\bin" -v:m -nologo 2>&1 | grep -E "error|warning|Error|->" | grep -v "^\s*$" | head -40
done
