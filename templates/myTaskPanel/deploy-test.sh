#!/bin/sh
# Copies the template set into C:\clarion12\accessory (the headless test install)
# and re-registers it. CRLF enforced.
cd "$(dirname "$0")"
for f in template/win/myTaskPanel.tpl libsrc/win/MyTaskPanel.inc libsrc/win/MyTaskPanel.clw libsrc/win/mtpd2d.c; do sed -i 's/\r$//; s/$/\r/' $f; done
cp template/win/myTaskPanel.tpl /c/clarion12/accessory/template/win/
cp libsrc/win/MyTaskPanel.inc libsrc/win/MyTaskPanel.clw libsrc/win/mtpd2d.c /c/clarion12/accessory/libsrc/win/
/c/clarion12/bin/ClarionCL.exe -tr "C:\clarion12\accessory\template\win\myTaskPanel.tpl" && echo registered
