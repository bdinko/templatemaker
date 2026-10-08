#!/bin/bash
# Build Spike.exe, Flow.exe and Tools.exe from the template's class files (copied in, CRLF).
set -e
cd "$(dirname "$0")"
MSB="C:/Windows/Microsoft.NET/Framework/v4.0.30319/MSBuild.exe"
for f in WordDocClass.inc WordDocClass.clw WordDocTools.inc WordDocTools.clw wdoc.c; do
  sed 's/\r$//; s/$/\r/' ../../templates/myWordDoc/libsrc/win/$f > $f
done
for p in Spike Flow Tools; do
  sed -i 's/\r$//; s/$/\r/' $p.clw
  rm -rf obj
  "$MSB" $p.cwproj -t:Build -p:Configuration=Debug -p:Platform=Win32 \
         -p:ClarionBinPath="C:\clarion12\bin" -v:m 2>&1 | grep -iE "error|warning" || true
done
ls -l Spike.exe Flow.exe Tools.exe
