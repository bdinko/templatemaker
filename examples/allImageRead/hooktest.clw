  PROGRAM
!  The template's wheel hook, on its own, with nothing else in the way. The
!  driver sends WM_CLOSE: if the window shuts down, the chain is intact; if it
!  sits there, the callback is swallowing messages.
  MAP
Main PROCEDURE
    AirImg_WheelProc(ULONG,ULONG,ULONG,LONG),LONG,PASCAL
    AirImg_HookWheel(LONG,LONG),BYTE,PROC
    AirImg_DropWheel(LONG),LONG,PROC
    MODULE('win32')
      airApi_SetProp(ULONG hWnd,LONG lpString,LONG hData),LONG,PASCAL,PROC,NAME('SetPropA')
      airApi_GetProp(ULONG hWnd,LONG lpString),LONG,PASCAL,NAME('GetPropA')
      airApi_RemoveProp(ULONG hWnd,LONG lpString),LONG,PASCAL,PROC,NAME('RemovePropA')
      airApi_CallWndProc(LONG lpPrevWndFunc,ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam),LONG,PASCAL,NAME('CallWindowProcA')
    END
  END
  INCLUDE('EQUATES.CLW'),ONCE

AirImg:WheelUp       EQUATE(EVENT:User + 216)
AirImg:WheelDown     EQUATE(EVENT:User + 217)
AirImg:CtrlUp        EQUATE(EVENT:User + 218)
AirImg:CtrlDown      EQUATE(EVENT:User + 219)

  CODE
  Main

Main PROCEDURE
Win     WINDOW('HookTest'),AT(,,240,120),SYSTEM,GRAY,TIMER(100)
          REGION,AT(4,4,230,110),USE(?Rgn)
        END
hooked  BYTE
saved   LONG
msgs    LONG
ticks   LONG
  CODE
  OPEN(Win)
  saved = Win{PROP:WndProc}
  IF AirImg_HookWheel(Win{PROP:Handle},Win{PROP:WndProc})
    hooked = 1
    Win{PROP:WndProc} = ADDRESS(AirImg_WheelProc)
  END
  Win{PROP:Text} = 'HookTest hooked=' & hooked & ' saved=' & saved
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      ticks += 1
      IF ticks > 40 THEN POST(EVENT:CloseWindow).             ! a long stop, so WM_CLOSE gets its chance
    END
  END
  IF hooked
    Win{PROP:WndProc} = AirImg_DropWheel(Win{PROP:Handle})
  END
  CLOSE(Win)

AirImg_HookWheel PROCEDURE(LONG pHwnd,LONG pOldProc)
prop CSTRING('AirImgOldWndProc')
  CODE
  IF ~pHwnd THEN RETURN 0.
  IF airApi_GetProp(pHwnd,ADDRESS(prop)) THEN RETURN 0.
  airApi_SetProp(pHwnd,ADDRESS(prop),pOldProc)
  RETURN 1

AirImg_DropWheel PROCEDURE(LONG pHwnd)
prop CSTRING('AirImgOldWndProc')
old  LONG,AUTO
  CODE
  IF ~pHwnd THEN RETURN 0.
  old = airApi_GetProp(pHwnd,ADDRESS(prop))
  airApi_RemoveProp(pHwnd,ADDRESS(prop))
  RETURN old

AirImg_WheelProc PROCEDURE(ULONG hWnd,ULONG wMsg,ULONG wParam,LONG lParam)
WM_MOUSEWHEEL EQUATE(020Ah)
MK_CONTROL    EQUATE(0008h)
prop CSTRING('AirImgOldWndProc')
old  LONG,AUTO
dz   LONG,AUTO
  CODE
  old = airApi_GetProp(hWnd,ADDRESS(prop))
  IF wMsg = WM_MOUSEWHEEL
    dz = BSHIFT(BAND(wParam,0FFFF0000h),-16)
    IF dz > 32767 THEN dz -= 65536.
    IF BAND(wParam,MK_CONTROL)
      IF dz > 0
        POST(AirImg:CtrlUp)
      ELSIF dz < 0
        POST(AirImg:CtrlDown)
      END
    ELSE
      IF dz > 0
        POST(AirImg:WheelUp)
      ELSIF dz < 0
        POST(AirImg:WheelDown)
      END
    END
  END
  IF old
    RETURN airApi_CallWndProc(old,hWnd,wMsg,wParam,lParam)
  END
  RETURN 0
