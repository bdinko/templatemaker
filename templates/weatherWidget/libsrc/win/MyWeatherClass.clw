! ============================================================================
!  MyWeatherClass - implementation.  See MyWeatherClass.inc for the overview.
!
!  Everything on the card is DRAWN: the sky is a gradient of thin boxes, the
!  sun is an ellipse with eight rays, the moon is a disc with the sky punched
!  back out of it, and a cloud is three puffs over a flat base. There are no
!  image files, so there is nothing to install beside the executable.
!
!  This file must be stored ANSI, with CRLF line endings. The Spanish strings
!  spell their accents as Clarion <nnn> escapes rather than raw high bytes, so
!  no editor can quietly rewrite the file as UTF-8 and turn every accent into
!  a question mark (225 = a-acute, 233 = e-acute, 237 = i-acute, 241 = n-tilde,
!  243 = o-acute, 250 = u-acute, 176 = the degree sign).
! ============================================================================
  MEMBER()

  MAP
    MODULE('win32')
      wxModuleFile( LONG hModule, *CSTRING lpFilename, ULONG nSize ),ULONG,RAW,PASCAL,NAME('GetModuleFileNameA')
      wxTempPath( ULONG nSize, *CSTRING lpBuffer ),ULONG,RAW,PASCAL,NAME('GetTempPathA')
      wxCreateProcess(LONG,LONG,LONG,LONG,LONG,ULONG,LONG,LONG,LONG,LONG),LONG,PASCAL,PROC,NAME('CreateProcessA')
      wxWaitObject(LONG,ULONG),LONG,PASCAL,PROC,NAME('WaitForSingleObject')
      wxCloseHandle(LONG),LONG,PASCAL,PROC,NAME('CloseHandle')
!  The answer is read back with the file API rather than a Clarion FILE, so
!  the class does not oblige the application to carry the DOS driver just to
!  show the weather. Every parameter is a LONG and everything that is really
!  a pointer is passed as ADDRESS(x) - the portable mapping that never puts a
!  string descriptor where the API wants an address.
      wxCreateFile(LONG,ULONG,ULONG,LONG,ULONG,ULONG,LONG),LONG,PASCAL,NAME('CreateFileA')
      wxReadFile(LONG,LONG,ULONG,LONG,LONG),LONG,PASCAL,PROC,NAME('ReadFile')
    END
  END

  INCLUDE('MyWeatherClass.INC'),ONCE
  INCLUDE('EQUATES.CLW'),ONCE
  INCLUDE('KEYCODES.CLW'),ONCE

Wx:PlaceHours      EQUATE(24)                   ! a resolved place is good for a day


! ############################################################################
!  Lifetime
! ############################################################################
MyWeatherClass.Construct PROCEDURE
  CODE
  SELF.Locate       = Wx:ByIP
  SELF.Units        = Wx:Metric
  SELF.Language     = Wx:English
  SELF.Days         = 5
  SELF.Timeout      = 6
  SELF.CacheMinutes = 30
  SELF.OnFail       = Wx:FailCached
  SELF.Persist      = 1
  SELF.ShowFeels    = 1
  SELF.ShowHumidity = 1
  SELF.ShowWind     = 1
  SELF.ShowPrecip   = 1
  SELF.ShowSun      = 1


! ############################################################################
!  The three you actually call
! ############################################################################
!  A reading, from the cache when it is young enough and from the network
!  otherwise. A failed download is not fatal: whatever the INI still holds is
!  put back and flagged Stale, so a program that starts with no connection
!  still has something to show.
MyWeatherClass.Fetch PROCEDURE()
age    LONG,AUTO
cached BYTE,AUTO
  CODE
  SELF.Err   = ''
  SELF.Stale = 0
  IF SELF.Days > Wx:MaxDays THEN SELF.Days = Wx:MaxDays .
  IF SELF.Timeout < 1  THEN SELF.Timeout = 1  .
  IF SELF.Timeout > 60 THEN SELF.Timeout = 60 .

! ---- what is already on disk ----------------------------------------------
  age    = 99999999                                         ! "older than any cache setting"
  cached = SELF.LoadCache()
  IF cached
    age = (TODAY() - SELF.AsOfDate) * 1440 + INT((CLOCK() - SELF.AsOfTime) / 6000)
    IF age < 0 THEN age = 0 .                               ! the clock went backwards
    IF SELF.CacheMinutes > 0 AND age <= SELF.CacheMinutes
      SELF.Ok = 1                                           ! young enough - no network at all
      RETURN 1
    END
  END

! ---- the place ------------------------------------------------------------
!  A place is worth keeping for a day: an IP lookup or a geocode that has not
!  aged out saves a whole round trip at every start-up.
  IF SELF.Locate <> Wx:ByLatLon
    IF ~cached OR (~SELF.Lat AND ~SELF.Lon) OR (age > Wx:PlaceHours * 60)
      IF ~SELF.FindPlace()
        SELF.Ok = 0
        IF cached
          SELF.LoadCache()                                  ! FindPlace trod on the fields
          SELF.Stale = 1
          SELF.Ok    = 1
        END
        RETURN SELF.Ok
      END
    END
  END

! ---- the weather ----------------------------------------------------------
  IF SELF.GetWeather()
    SELF.Ok       = 1
    SELF.AsOfDate = TODAY()
    SELF.AsOfTime = CLOCK()
    IF SELF.Persist THEN SELF.SaveCache() .
    RETURN 1
  END

  SELF.Ok = 0
  IF cached
    SELF.LoadCache()
    SELF.Stale = 1
    SELF.Ok    = 1
  ELSE
!  Nothing to show and nothing kept. Drop whatever the last successful fetch
!  left behind, or the fault card is laid out for a forecast it cannot draw.
    SELF.NDays = 0
    SELF.Temp  = 0
    SELF.Taken = ''
  END
  RETURN SELF.Ok


!  The same, with the cache stepped over - what the Refresh button calls.
MyWeatherClass.Refresh PROCEDURE()
keep LONG,AUTO
  CODE
  keep = SELF.CacheMinutes
  SELF.CacheMinutes = 0
  SELF.Fetch()
  SELF.CacheMinutes = keep
  RETURN SELF.Ok


!  Fetch, then put the card on the screen. Returns 1 if a card was shown.
MyWeatherClass.Ask PROCEDURE()
secs   LONG,AUTO
h      LONG,AUTO
wy     LONG,AUTO
WxWnd WINDOW('Weather'),AT(,,352,272),FONT('Segoe UI',9,,FONT:regular,CHARSET:ANSI), |
        CENTER,GRAY,SYSTEM,MODAL,ALRT(EscKey)
        IMAGE,AT(0,0,352,244),USE(?WxCanvas)
        BUTTON(''),AT(8,250,60,15),USE(?WxRefresh)
        STRING(''),AT(74,254),USE(?WxNote),FONT('Segoe UI',8,080726BH),TRN
        BUTTON(''),AT(290,250,54,15),USE(?WxClose),STD(STD:Close)
      END
  CODE
  IF SELF.Language <> Wx:Spanish THEN SELF.Language = Wx:English .
  SELF.Closed = 0
  SELF.Fetch()
!  Three ways to behave when the network let us down:
!    Silent - no card at all, fresh reading or not
!    Cached - the card, showing whatever the INI still held (the default)
!    Show   - the card either way, with the fault written on it
  IF ~SELF.Ok AND SELF.OnFail <> Wx:FailShow THEN RETURN 0 .
  IF SELF.Stale AND SELF.OnFail = Wx:FailSilent THEN RETURN 0 .

  h = SELF.CardH()
  OPEN(WxWnd)
  0{PROP:Text}          = CHOOSE(CLIP(SELF.Title) <> '',CLIP(SELF.Title),SELF.Txt(WTx:Weather))
  ?WxRefresh{PROP:Text} = SELF.Txt(WTx:Refresh)
  ?WxClose{PROP:Text}   = SELF.Txt(WTx:Close)
!  The card is as tall as its contents, so the window has to follow it down -
!  and a window resized after OPEN keeps the position CENTER gave the old
!  size, which is why it is re-centred by hand here.
  ?WxCanvas{PROP:Height} = h
  ?WxRefresh{PROP:Ypos}  = h + 6
  ?WxClose{PROP:Ypos}    = h + 6
  ?WxNote{PROP:Ypos}     = h + 10
  0{PROP:Height}         = h + 28
  wy = 0{PROP:Ypos}                                         ! a PROP read hands back a STRING - land it in a LONG first
  0{PROP:Ypos}           = wy + INT((272 - h - 28) / 2)     ! keep the middle CENTER picked, now that it is shorter
  SELF.Draw(WxWnd,?WxCanvas)

  secs = SELF.AutoClose
  IF secs > 0
    0{PROP:Timer} = 100                                     ! one tick a second
    DO ShowCount
  END
  ACCEPT
    CASE EVENT()
    OF EVENT:Timer
      secs -= 1
      IF secs <= 0
        POST(EVENT:CloseWindow)
      ELSE
        DO ShowCount
      END
    OF EVENT:AlertKey
      IF KEYCODE() = EscKey
        SELF.Closed = 1
        POST(EVENT:CloseWindow)
      END
    OF EVENT:CloseWindow
      IF secs > 0 THEN SELF.Closed = 1 .                    ! it was not the clock that did it
    END
    CASE FIELD()
    OF ?WxRefresh
      IF EVENT() = EVENT:Accepted
        0{PROP:Timer}      = 0                              ! the user is here - stop the countdown
        secs               = 0
        ?WxNote{PROP:Text} = ''
        DISPLAY(?WxNote)
        SELF.Refresh()
        SELF.Draw(WxWnd,?WxCanvas)
      END
    OF ?WxClose
      IF EVENT() = EVENT:Accepted THEN SELF.Closed = 1 .
    END
  END
  CLOSE(WxWnd)
  RETURN 1

ShowCount ROUTINE
  ?WxNote{PROP:Text} = CLIP(SELF.Txt(WTx:Closing)) & ' ' & secs & ' s'
  DISPLAY(?WxNote)


! ############################################################################
!  Talking to the internet
! ############################################################################
!  Run curl.exe, HIDDEN and SYNCHRONOUSLY, and read what it wrote into
!  SELF.Json. curl ships with Windows 10 and 11 in %SystemRoot%\System32.
!
!  Hidden + synchronous is CreateProcessA with CREATE_NO_WINDOW plus
!  STARTF_USESHOWWINDOW / SW_HIDE, then WaitForSingleObject - the prototypes
!  and the two GROUP layouts are the ones CapeSoft OddJob uses (OddJobEq.inc
!  305-310 and 328-349), and the same launcher myQR downloads its PNG with.
!
!  Returns 1 when there is a body to parse. It says nothing about whether the
!  body is the answer you wanted - the parser decides that.
MyWeatherClass.Download PROCEDURE(STRING pUrl)
loc:Cmd    CSTRING(5120)                                    ! CreateProcessA writes back into this - size it generously
loc:File   CSTRING(261)
loc:Dir    CSTRING(261)
loc:Ok     LONG,AUTO
n          ULONG,AUTO
h          LONG,AUTO                                        ! the open file
got        ULONG,AUTO                                       ! bytes ReadFile just handed over
buf        STRING(4096)
si         GROUP                                            ! STARTUPINFOA - OddJobEq.inc:328-347
cb           ULONG
lpReserved   LONG(0)
lpDesktop    LONG(0)
lpTitle      LONG(0)
dwX          ULONG
dwY          ULONG
dwXSize      ULONG
dwYSize      ULONG
dwXChars     ULONG
dwYChars     ULONG
dwFill       ULONG
dwFlags      ULONG
wShowWindow  SHORT(0)
cbReserved2  SHORT(0)
lpReserved2  LONG(0)
hStdInput    LONG
hStdOutput   LONG
hStdError    LONG
           END
pi         GROUP                                            ! PROCESS_INFORMATION - OddJobEq.inc:305-310
hProcess     LONG
hThread      LONG
dwProcessId  ULONG
dwThreadId   ULONG
           END
STARTF_USESHOWWINDOW EQUATE(00000001h)
SW_HIDE              EQUATE(0)
CREATE_NO_WINDOW     EQUATE(08000000h)
INFINITE             EQUATE(0FFFFFFFFh)
GENERIC_READ         EQUATE(80000000h)
FILE_SHARE_READ      EQUATE(00000001h)
OPEN_EXISTING        EQUATE(3)
FILE_ATTR_NORMAL     EQUATE(00000080h)
INVALID_HANDLE       EQUATE(-1)
  CODE
  SELF.Json = ''
! ---- somewhere to put the answer ------------------------------------------
  loc:Dir = ''
  n = wxTempPath(255,loc:Dir)
  IF ~n OR n > 254 THEN loc:Dir = '.\' .
  IF loc:Dir[LEN(loc:Dir) : LEN(loc:Dir)] <> '\' THEN loc:Dir = CLIP(loc:Dir) & '\' .
  loc:File = CLIP(loc:Dir) & 'myWeather_' & CLOCK() & '.json'
  REMOVE(loc:File)

! ---- fetch it -------------------------------------------------------------
!  -s silent, -L follow redirects, --max-time so a hung server cannot hold the
!  program up for ever, -o writes the body. <34> is a double quote: Windows
!  argument quoting wants double quotes, not apostrophes.
  loc:Cmd = 'curl -s -L --max-time ' & SELF.Timeout & |
            ' -o <34>' & CLIP(loc:File) & '<34> <34>' & CLIP(pUrl) & '<34>'
  si.cb          = SIZE(si)
  si.dwFlags     = STARTF_USESHOWWINDOW
  si.wShowWindow = SW_HIDE
  loc:Ok = wxCreateProcess(0,ADDRESS(loc:Cmd),0,0,0,CREATE_NO_WINDOW,0,0,ADDRESS(si),ADDRESS(pi))
  IF ~loc:Ok                                                ! curl.exe is not there
    SELF.Err = SELF.Txt(WTx:NoCurl)
    REMOVE(loc:File)
    RETURN 0
  END
  wxWaitObject(pi.hProcess,INFINITE)
  wxCloseHandle(pi.hThread)
  wxCloseHandle(pi.hProcess)

! ---- read it back ---------------------------------------------------------
  IF ~EXISTS(loc:File)
    SELF.Err = SELF.Txt(WTx:Offline)
    RETURN 0
  END
  h = wxCreateFile(ADDRESS(loc:File),GENERIC_READ,FILE_SHARE_READ,0,OPEN_EXISTING,FILE_ATTR_NORMAL,0)
  IF h = INVALID_HANDLE OR ~h
    SELF.Err = SELF.Txt(WTx:Offline)
    REMOVE(loc:File)
    RETURN 0
  END
  LOOP
    got = 0
    IF ~wxReadFile(h,ADDRESS(buf),SIZE(buf),ADDRESS(got),0) THEN BREAK .
    IF got < 1 THEN BREAK .                                 ! end of file
    IF LEN(SELF.Json) + got > SIZE(SELF.Json) - 1 THEN BREAK .   ! never overrun the buffer
    SELF.Json = SELF.Json & buf[1 : got]
  END
  wxCloseHandle(h)
  REMOVE(loc:File)
  IF LEN(SELF.Json) < 2
    SELF.Err = SELF.Txt(WTx:Offline)
    RETURN 0
  END
  RETURN 1


!  Turn whatever the caller configured into a latitude and a longitude.
!    Wx:ByIP    - ipwho.is looks up the public address this machine goes out on
!    Wx:ByCity  - Open-Meteo's geocoder turns 'Monterrey' into coordinates
!  Both are free and neither needs a key. Sets Place as a side effect.
MyWeatherClass.FindPlace PROCEDURE()
f    LONG,AUTO
t    LONG,AUTO
nm   CSTRING(65)
reg  CSTRING(65)
cty  CSTRING(65)
  CODE
  CASE SELF.Locate
  OF Wx:ByCity
    IF LEN(CLIP(SELF.City)) = 0
      SELF.Err = SELF.Txt(WTx:NoPlace)
      RETURN 0
    END
    IF ~SELF.Download('https://geocoding-api.open-meteo.com/v1/search?count=1&format=json&language=' & |
                      CHOOSE(SELF.Language = Wx:Spanish,'es','en') & |
                      '&name=' & CLIP(SELF.UrlEnc(SELF.City)))
      RETURN 0
    END
    IF ~SELF.Sect('results',f,t)                       ! no such place
      SELF.Err = SELF.Txt(WTx:NoPlace)
      RETURN 0
    END
    SELF.Lat = SELF.Num('latitude',f,t)
    SELF.Lon = SELF.Num('longitude',f,t)
    nm  = SELF.Ansi(SELF.Str('name',f,t))
    reg = SELF.Ansi(SELF.Str('admin1',f,t))
    cty = SELF.Ansi(SELF.Str('country',f,t))
  ELSE
    IF ~SELF.Download('https://ipwho.is/')
      RETURN 0
    END
    SELF.Lat = SELF.Num('latitude',1,0)
    SELF.Lon = SELF.Num('longitude',1,0)
    nm  = SELF.Ansi(SELF.Str('city',1,0))
    reg = SELF.Ansi(SELF.Str('region',1,0))
    cty = SELF.Ansi(SELF.Str('country',1,0))
  END

  IF ~SELF.Lat AND ~SELF.Lon
    SELF.Err = SELF.Txt(WTx:NoPlace)
    RETURN 0
  END
!  'Monterrey, Mexico' reads better than 'Monterrey, Nuevo Leon, Mexico', so
!  the region is only used when the service gave us no country.
  SELF.Place = CLIP(nm)
  IF LEN(CLIP(cty))
    SELF.Place = CLIP(SELF.Place) & CHOOSE(LEN(CLIP(nm)) > 0,', ','') & CLIP(cty)
  ELSIF LEN(CLIP(reg))
    SELF.Place = CLIP(SELF.Place) & CHOOSE(LEN(CLIP(nm)) > 0,', ','') & CLIP(reg)
  END
  RETURN 1


!  Coordinates in, a reading out. One request, everything the card shows.
MyWeatherClass.GetWeather PROCEDURE()
url  CSTRING(512)
la   CSTRING(32)
lo   CSTRING(32)
f    LONG,AUTO
t    LONG,AUTO
df   LONG,AUTO
dt   LONG,AUTO
i    LONG,AUTO
iso  CSTRING(32)
  CODE
!  The coordinates are written by Clarion's own numeric-to-string conversion,
!  NOT by FORMAT: every @N picture groups with commas, and '25,692.35' in a
!  query string is not a latitude.
  la = SELF.Lat
  lo = SELF.Lon
  url = 'https://api.open-meteo.com/v1/forecast?latitude=' & CLIP(la)                       |
      & '&longitude=' & CLIP(lo)                                                            |
      & '&current=temperature_2m,relative_humidity_2m,apparent_temperature,is_day,'         |
      & 'precipitation,weather_code,wind_speed_10m,wind_direction_10m'                      |
      & '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset'          |
      & '&timezone=auto&forecast_days=' & CHOOSE(SELF.Days > 0,SELF.Days,1)
  IF SELF.Units = Wx:Imperial
    url = CLIP(url) & '&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch'
  END
  IF ~SELF.Download(url) THEN RETURN 0 .

! ---- now ------------------------------------------------------------------
!  "current_units" sits in front of "current" in the body and repeats every
!  key with the unit as its value, so every read is bounded to the section it
!  belongs to - an unbounded search for temperature_2m finds the word "C".
  IF ~SELF.Sect('current',f,t)
    SELF.Err = SELF.Txt(WTx:NoWeather)
    RETURN 0
  END
  SELF.Temp     = SELF.Num('temperature_2m',f,t)
  SELF.Feels    = SELF.Num('apparent_temperature',f,t)
  SELF.Humidity = SELF.Num('relative_humidity_2m',f,t)
  SELF.Precip   = SELF.Num('precipitation',f,t)
  SELF.WCode    = SELF.Num('weather_code',f,t)
  SELF.Wind     = SELF.Num('wind_speed_10m',f,t)
  SELF.WindDir  = SELF.Num('wind_direction_10m',f,t)
  SELF.IsDay    = SELF.Num('is_day',f,t)
  SELF.Zone     = SELF.Str('timezone',1,f)                  ! top level, before "current"
!  The reading's own time, already in the place's zone (the request asks for
!  timezone=auto). That is what belongs beside the zone name on the card - the
!  clock on THIS machine says nothing about what time it is where the weather
!  is, and Tokyo weather stamped with a Mexican breakfast time reads as a bug.
  SELF.Taken    = SELF.IsoTime(SELF.Str('time',f,t))

! ---- the days ahead -------------------------------------------------------
  SELF.NDays = 0
  IF SELF.Days > 0 AND SELF.Sect('daily',df,dt)
    LOOP i = 1 TO SELF.Days
      iso = SELF.ArrStr('time',i,df,dt)
      IF ~CLIP(iso) THEN BREAK .
      SELF.DDate[i] = SELF.IsoDate(iso)
      SELF.DCode[i] = SELF.ArrNum('weather_code',i,df,dt)
      SELF.DHi[i]   = SELF.ArrNum('temperature_2m_max',i,df,dt)
      SELF.DLo[i]   = SELF.ArrNum('temperature_2m_min',i,df,dt)
      SELF.NDays    = i
    END
    SELF.Sunrise = SELF.IsoTime(SELF.ArrStr('sunrise',1,df,dt))
    SELF.Sunset  = SELF.IsoTime(SELF.ArrStr('sunset',1,df,dt))
  END
  RETURN 1


! ############################################################################
!  Reading JSON without a JSON parser
! ############################################################################
!  Open-Meteo's answers are flat, machine-written and predictable: no key ever
!  appears twice inside the same object, and the only nesting is one level of
!  named sections. That is small enough to read with INSTRING and a hand-rolled
!  number scanner, which keeps the class dependency-free.
!
!  Sect finds a named section and hands back the character range it spans, so
!  every other read can be bounded - which is what stops "temperature_2m" in
!  the units block from answering for the one in the reading.
MyWeatherClass.Sect PROCEDURE(STRING pTag,*LONG pFrom,*LONG pTo)
p  LONG,AUTO
q  LONG,AUTO
k  CSTRING(64)
  CODE
  pFrom = 0
  pTo   = 0
  k = '"' & CLIP(pTag) & '":'
  p = INSTRING(k,SELF.Json,1,1)
  IF ~p THEN RETURN 0 .
  p = SELF.Skip(p + LEN(k))
  IF p > LEN(SELF.Json) THEN RETURN 0 .
  IF SELF.Json[p : p] = '['                                 ! an array of objects - take the first
    p = SELF.Skip(p + 1)
  END
  IF p > LEN(SELF.Json) THEN RETURN 0 .
  IF SELF.Json[p : p] <> '{' THEN RETURN 0 .
  p = p + 1
  q = INSTRING('}',SELF.Json,1,p)                           ! these sections hold no objects
  IF ~q THEN q = LEN(SELF.Json) .
  pFrom = p
  pTo   = q
  RETURN 1


!  The number filed under "key", searched between pFrom and pTo (pTo = 0 means
!  "to the end"). 0 when there is no such key.
MyWeatherClass.Num PROCEDURE(STRING pTag,LONG pFrom,LONG pTo)
p  LONG,AUTO
k  CSTRING(64)
  CODE
  k = '"' & CLIP(pTag) & '":'
  IF pFrom < 1 THEN pFrom = 1 .
  IF pFrom > LEN(SELF.Json) THEN RETURN 0 .
  p = INSTRING(k,SELF.Json,1,pFrom)
  IF ~p THEN RETURN 0 .
  IF pTo > 0 AND p > pTo THEN RETURN 0 .
  RETURN SELF.NumAt(p + LEN(k))


!  Everything after a colon may be preceded by white space: Open-Meteo answers
!  compact, but ipwho.is pretty-prints, and '"city": "Monterrey"' does not
!  match a search for '"city":"'. This is what makes both readable.
MyWeatherClass.Skip PROCEDURE(LONG pPos)
i  LONG,AUTO
n  LONG,AUTO
c  STRING(1)
  CODE
  n = LEN(SELF.Json)
  i = pPos
  LOOP WHILE i <= n
    c = SELF.Json[i : i]
    IF c <> ' ' AND c <> '<9>' AND c <> '<13>' AND c <> '<10>' THEN BREAK .
    i = i + 1
  END
  RETURN i


!  The quoted string filed under "key". Returns '' for a missing key, and for
!  a key whose value is not a string (ipwho.is files its timezone as an
!  object, and this hands back nothing rather than a brace).
MyWeatherClass.Str PROCEDURE(STRING pTag,LONG pFrom,LONG pTo)
p  LONG,AUTO
q  LONG,AUTO
k  CSTRING(64)
  CODE
  k = '"' & CLIP(pTag) & '":'
  IF pFrom < 1 THEN pFrom = 1 .
  IF pFrom > LEN(SELF.Json) THEN RETURN '' .
  p = INSTRING(k,SELF.Json,1,pFrom)
  IF ~p THEN RETURN '' .
  IF pTo > 0 AND p > pTo THEN RETURN '' .
  p = SELF.Skip(p + LEN(k))
  IF p > LEN(SELF.Json) THEN RETURN '' .
  IF SELF.Json[p : p] <> '"' THEN RETURN '' .               ! the value is an object or a number
  p = p + 1
  q = INSTRING('"',SELF.Json,1,p)
  IF ~q OR q <= p THEN RETURN '' .
  RETURN SELF.Json[p : q - 1]


!  The pIdx'th number of the array filed under "key". Walks commas, and stops
!  at the closing bracket so a short array cannot bleed into the next one.
MyWeatherClass.ArrNum PROCEDURE(STRING pTag,LONG pIdx,LONG pFrom,LONG pTo)
p  LONG,AUTO
e  LONG,AUTO
i  LONG,AUTO
k  CSTRING(64)
  CODE
  k = '"' & CLIP(pTag) & '":'
  IF pFrom < 1 THEN pFrom = 1 .
  IF pFrom > LEN(SELF.Json) THEN RETURN 0 .
  p = INSTRING(k,SELF.Json,1,pFrom)
  IF ~p THEN RETURN 0 .
  IF pTo > 0 AND p > pTo THEN RETURN 0 .
  p = SELF.Skip(p + LEN(k))
  IF p > LEN(SELF.Json) THEN RETURN 0 .
  IF SELF.Json[p : p] <> '[' THEN RETURN 0 .
  p = p + 1
  e = INSTRING(']',SELF.Json,1,p)
  IF ~e THEN RETURN 0 .
  LOOP i = 2 TO pIdx
    p = INSTRING(',',SELF.Json,1,p)
    IF ~p OR p > e THEN RETURN 0 .
    p = p + 1
  END
  RETURN SELF.NumAt(p)


!  The pIdx'th string of the array filed under "key".
MyWeatherClass.ArrStr PROCEDURE(STRING pTag,LONG pIdx,LONG pFrom,LONG pTo)
p  LONG,AUTO
e  LONG,AUTO
q  LONG,AUTO
i  LONG,AUTO
k  CSTRING(64)
  CODE
  k = '"' & CLIP(pTag) & '":'
  IF pFrom < 1 THEN pFrom = 1 .
  IF pFrom > LEN(SELF.Json) THEN RETURN '' .
  p = INSTRING(k,SELF.Json,1,pFrom)
  IF ~p THEN RETURN '' .
  IF pTo > 0 AND p > pTo THEN RETURN '' .
  p = SELF.Skip(p + LEN(k))
  IF p > LEN(SELF.Json) THEN RETURN '' .
  IF SELF.Json[p : p] <> '[' THEN RETURN '' .
  p = p + 1
  e = INSTRING(']',SELF.Json,1,p)
  IF ~e THEN RETURN '' .
  LOOP i = 2 TO pIdx
    p = INSTRING(',',SELF.Json,1,p)
    IF ~p OR p > e THEN RETURN '' .
    p = p + 1
  END
  p = INSTRING('"',SELF.Json,1,p)                           ! the opening quote of this element
  IF ~p OR p > e THEN RETURN '' .
  p = p + 1
  q = INSTRING('"',SELF.Json,1,p)
  IF ~q OR q <= p THEN RETURN '' .
  RETURN SELF.Json[p : q - 1]


!  Read a JSON number at a position: optional minus, digits, optional fraction.
!  Written out rather than handed to DEFORMAT because DEFORMAT's behaviour
!  around the decimal point depends on the picture it is given, and a reading
!  of 28.7 degrees that silently became 287 would be a bad way to find out.
MyWeatherClass.NumAt PROCEDURE(LONG pPos)
i     LONG,AUTO
n     LONG,AUTO
c     STRING(1)
sgn   REAL,AUTO
val   REAL,AUTO
scale REAL,AUTO
seen  BYTE(0)
  CODE
  n   = LEN(SELF.Json)
  i   = pPos
  sgn = 1
  val = 0
  LOOP WHILE i <= n AND SELF.Json[i : i] = ' '
    i = i + 1
  END
  IF i <= n AND SELF.Json[i : i] = '-'
    sgn = -1
    i   = i + 1
  END
  LOOP WHILE i <= n
    c = SELF.Json[i : i]
    IF c < '0' OR c > '9' THEN BREAK .
    val  = val * 10 + VAL(c) - 48
    seen = 1
    i    = i + 1
  END
  IF i <= n AND SELF.Json[i : i] = '.'
    i     = i + 1
    scale = 1
    LOOP WHILE i <= n
      c = SELF.Json[i : i]
      IF c < '0' OR c > '9' THEN BREAK .
      scale = scale / 10
      val   = val + scale * (VAL(c) - 48)
      seen  = 1
      i     = i + 1
    END
  END
  IF ~seen THEN RETURN 0 .
  RETURN val * sgn


!  These services answer in UTF-8 and Clarion draws in the Windows ANSI code
!  page, so 'Nuevo Le<243>n' arrives as two bytes where one belongs. Everything
!  in the Latin-1 range folds back exactly; anything above it (Cyrillic, CJK)
!  has no ANSI equivalent and becomes a question mark rather than mojibake.
MyWeatherClass.Ansi PROCEDURE(STRING pUtf8)
src  CSTRING(257)
out  CSTRING(257)
i    LONG,AUTO
n    LONG,AUTO
c    LONG,AUTO
d    LONG,AUTO
  CODE
  src = CLIP(pUtf8)
  n   = LEN(src)
  i   = 1
  LOOP WHILE i <= n
    c = VAL(src[i : i])
    IF c < 128                                              ! plain ASCII
      out = out & src[i : i]
      i   = i + 1
    ELSIF c = 194 AND i < n                                 ! C2 xx -> U+0080..U+00BF
      out = out & CHR(VAL(src[i+1 : i+1]))
      i   = i + 2
    ELSIF c = 195 AND i < n                                 ! C3 xx -> U+00C0..U+00FF
      d   = VAL(src[i+1 : i+1]) + 64
      out = out & CHR(d)
      i   = i + 2
    ELSIF c >= 240                                          ! four-byte, out of reach
      out = out & '?'
      i   = i + 4
    ELSIF c >= 224                                          ! three-byte, out of reach
      out = out & '?'
      i   = i + 3
    ELSIF c >= 192                                          ! any other two-byte
      out = out & '?'
      i   = i + 2
    ELSE
      i = i + 1                                             ! a stray continuation byte
    END
    IF LEN(out) > 250 THEN BREAK .
  END
  RETURN out


!  '2026-07-31' -> a Clarion date. 0 if it is not one.
MyWeatherClass.IsoDate PROCEDURE(STRING pIso)
s  CSTRING(32)
  CODE
  s = CLIP(LEFT(pIso))
  IF LEN(s) < 10 THEN RETURN 0 .
  IF s[5 : 5] <> '-' OR s[8 : 8] <> '-' THEN RETURN 0 .
  RETURN DATE(s[6 : 7],s[9 : 10],s[1 : 4])


!  '2026-07-31T06:07' -> '06:07'. The service is already answering in the
!  place's own time zone, so there is nothing to convert.
MyWeatherClass.IsoTime PROCEDURE(STRING pIso)
s  CSTRING(32)
  CODE
  s = CLIP(LEFT(pIso))
  IF LEN(s) < 16 THEN RETURN '' .
  RETURN s[12 : 16]


!  Percent-encode a city name for the query string (RFC 3986 unreserved set).
MyWeatherClass.UrlEnc PROCEDURE(STRING pText)
in   CSTRING(129)
out  CSTRING(385)
i    LONG,AUTO
c    LONG,AUTO
hex  STRING('0123456789ABCDEF')
  CODE
  in = CLIP(LEFT(pText))
  LOOP i = 1 TO LEN(in)
    c = VAL(in[i : i])
    CASE c
    OF VAL('A') TO VAL('Z')
    OROF VAL('a') TO VAL('z')
    OROF VAL('0') TO VAL('9')
    OROF VAL('-') OROF VAL('_') OROF VAL('.') OROF VAL('~')
      out = out & in[i : i]
    OF VAL(' ')
      out = out & '%20'
    ELSE
      out = out & '%' & hex[ BAND(BSHIFT(c,-4),0Fh) + 1 ] & hex[ BAND(c,0Fh) + 1 ]
    END
  END
  RETURN out


! ############################################################################
!  Words
! ############################################################################
MyWeatherClass.Txt PROCEDURE(LONG pId)
  CODE
  IF SELF.Language = Wx:Spanish
    CASE pId
    OF WTx:Weather   ; RETURN 'El tiempo'
    OF WTx:Feels     ; RETURN 'Sensaci<243>n'
    OF WTx:Humidity  ; RETURN 'Humedad'
    OF WTx:Wind      ; RETURN 'Viento'
    OF WTx:Rain      ; RETURN 'Lluvia'
    OF WTx:Sunrise   ; RETURN 'Amanece'
    OF WTx:Sunset    ; RETURN 'Anochece'
    OF WTx:Refresh   ; RETURN '&Actualizar'
    OF WTx:Close     ; RETURN '&Cerrar'
    OF WTx:Closing   ; RETURN 'Se cierra en'
    OF WTx:AsOf      ; RETURN 'a las'
    OF WTx:Forecast  ; RETURN 'Pron<243>stico'
    OF WTx:NoWeather ; RETURN 'Sin datos del tiempo'
    OF WTx:LastKnown ; RETURN '<218>ltima lectura conocida'
    OF WTx:Source    ; RETURN 'Datos: Open-Meteo'
    OF WTx:Today     ; RETURN 'Hoy'
    OF WTx:NoCurl    ; RETURN 'No se encontr<243> curl.exe'
    OF WTx:NoPlace   ; RETURN 'No se pudo determinar el lugar'
    OF WTx:Offline   ; RETURN 'Sin conexi<243>n a internet'
    END
    RETURN ''
  END
  CASE pId
  OF WTx:Weather   ; RETURN 'Weather'
  OF WTx:Feels     ; RETURN 'Feels like'
  OF WTx:Humidity  ; RETURN 'Humidity'
  OF WTx:Wind      ; RETURN 'Wind'
  OF WTx:Rain      ; RETURN 'Rain'
  OF WTx:Sunrise   ; RETURN 'Sunrise'
  OF WTx:Sunset    ; RETURN 'Sunset'
  OF WTx:Refresh   ; RETURN '&Refresh'
  OF WTx:Close     ; RETURN '&Close'
  OF WTx:Closing   ; RETURN 'closing in'
  OF WTx:AsOf      ; RETURN 'as of'
  OF WTx:Forecast  ; RETURN 'Forecast'
  OF WTx:NoWeather ; RETURN 'No weather to show'
  OF WTx:LastKnown ; RETURN 'last known reading'
  OF WTx:Source    ; RETURN 'Data: Open-Meteo'
  OF WTx:Today     ; RETURN 'Today'
  OF WTx:NoCurl    ; RETURN 'curl.exe was not found'
  OF WTx:NoPlace   ; RETURN 'The place could not be worked out'
  OF WTx:Offline   ; RETURN 'No internet connection'
  END
  RETURN ''


!  The WMO present-weather code, in words. Open-Meteo documents the set it
!  uses; every code it can send has a line here.
MyWeatherClass.Describe PROCEDURE(LONG pCode)
  CODE
  IF SELF.Language = Wx:Spanish
    CASE pCode
    OF  0 ; RETURN 'Despejado'
    OF  1 ; RETURN 'Poco nuboso'
    OF  2 ; RETURN 'Parcialmente nublado'
    OF  3 ; RETURN 'Nublado'
    OF 45 ; RETURN 'Niebla'
    OF 48 ; RETURN 'Niebla helada'
    OF 51 ; RETURN 'Llovizna ligera'
    OF 53 ; RETURN 'Llovizna'
    OF 55 ; RETURN 'Llovizna intensa'
    OF 56 OROF 57 ; RETURN 'Llovizna helada'
    OF 61 ; RETURN 'Lluvia ligera'
    OF 63 ; RETURN 'Lluvia'
    OF 65 ; RETURN 'Lluvia intensa'
    OF 66 OROF 67 ; RETURN 'Lluvia helada'
    OF 71 ; RETURN 'Nieve ligera'
    OF 73 ; RETURN 'Nieve'
    OF 75 ; RETURN 'Nieve intensa'
    OF 77 ; RETURN 'Granos de nieve'
    OF 80 ; RETURN 'Chubascos ligeros'
    OF 81 ; RETURN 'Chubascos'
    OF 82 ; RETURN 'Chubascos fuertes'
    OF 85 ; RETURN 'Chubascos de nieve'
    OF 86 ; RETURN 'Nevadas fuertes'
    OF 95 ; RETURN 'Tormenta'
    OF 96 OROF 99 ; RETURN 'Tormenta con granizo'
    END
    RETURN 'Sin datos'
  END
  CASE pCode
  OF  0 ; RETURN 'Clear sky'
  OF  1 ; RETURN 'Mainly clear'
  OF  2 ; RETURN 'Partly cloudy'
  OF  3 ; RETURN 'Overcast'
  OF 45 ; RETURN 'Fog'
  OF 48 ; RETURN 'Freezing fog'
  OF 51 ; RETURN 'Light drizzle'
  OF 53 ; RETURN 'Drizzle'
  OF 55 ; RETURN 'Heavy drizzle'
  OF 56 OROF 57 ; RETURN 'Freezing drizzle'
  OF 61 ; RETURN 'Light rain'
  OF 63 ; RETURN 'Rain'
  OF 65 ; RETURN 'Heavy rain'
  OF 66 OROF 67 ; RETURN 'Freezing rain'
  OF 71 ; RETURN 'Light snow'
  OF 73 ; RETURN 'Snow'
  OF 75 ; RETURN 'Heavy snow'
  OF 77 ; RETURN 'Snow grains'
  OF 80 ; RETURN 'Light showers'
  OF 81 ; RETURN 'Showers'
  OF 82 ; RETURN 'Violent showers'
  OF 85 ; RETURN 'Snow showers'
  OF 86 ; RETURN 'Heavy snow showers'
  OF 95 ; RETURN 'Thunderstorm'
  OF 96 OROF 99 ; RETURN 'Thunderstorm with hail'
  END
  RETURN 'No reading'


!  Clarion counts days from 1800-12-28, so date MOD 7 gives the weekday with
!  0 = Sunday (verified: 1801-01-01 was a Thursday, and 4 MOD 7 = 4).
MyWeatherClass.DayName PROCEDURE(LONG pDate)
d  LONG,AUTO
  CODE
  IF ~pDate THEN RETURN '' .
  IF pDate = TODAY() THEN RETURN SELF.Txt(WTx:Today) .
  d = pDate % 7
  IF SELF.Language = Wx:Spanish
    CASE d
    OF 0 ; RETURN 'Dom'
    OF 1 ; RETURN 'Lun'
    OF 2 ; RETURN 'Mar'
    OF 3 ; RETURN 'Mi<233>'
    OF 4 ; RETURN 'Jue'
    OF 5 ; RETURN 'Vie'
    OF 6 ; RETURN 'S<225>b'
    END
    RETURN ''
  END
  CASE d
  OF 0 ; RETURN 'Sun'
  OF 1 ; RETURN 'Mon'
  OF 2 ; RETURN 'Tue'
  OF 3 ; RETURN 'Wed'
  OF 4 ; RETURN 'Thu'
  OF 5 ; RETURN 'Fri'
  OF 6 ; RETURN 'Sat'
  END
  RETURN ''


!  The compass point a bearing falls in - the direction the wind comes FROM,
!  which is what a bearing from a weather service always means.
MyWeatherClass.Compass PROCEDURE(LONG pDeg)
i  LONG,AUTO
  CODE
  i = INT(((pDeg % 360) + 11.25) / 22.5) % 16
  IF SELF.Language = Wx:Spanish
    CASE i
    OF  0 ; RETURN 'N'
    OF  1 ; RETURN 'NNE'
    OF  2 ; RETURN 'NE'
    OF  3 ; RETURN 'ENE'
    OF  4 ; RETURN 'E'
    OF  5 ; RETURN 'ESE'
    OF  6 ; RETURN 'SE'
    OF  7 ; RETURN 'SSE'
    OF  8 ; RETURN 'S'
    OF  9 ; RETURN 'SSO'
    OF 10 ; RETURN 'SO'
    OF 11 ; RETURN 'OSO'
    OF 12 ; RETURN 'O'
    OF 13 ; RETURN 'ONO'
    OF 14 ; RETURN 'NO'
    OF 15 ; RETURN 'NNO'
    END
    RETURN ''
  END
  CASE i
  OF  0 ; RETURN 'N'
  OF  1 ; RETURN 'NNE'
  OF  2 ; RETURN 'NE'
  OF  3 ; RETURN 'ENE'
  OF  4 ; RETURN 'E'
  OF  5 ; RETURN 'ESE'
  OF  6 ; RETURN 'SE'
  OF  7 ; RETURN 'SSE'
  OF  8 ; RETURN 'S'
  OF  9 ; RETURN 'SSW'
  OF 10 ; RETURN 'SW'
  OF 11 ; RETURN 'WSW'
  OF 12 ; RETURN 'W'
  OF 13 ; RETURN 'WNW'
  OF 14 ; RETURN 'NW'
  OF 15 ; RETURN 'NNW'
  END
  RETURN ''


!  A whole number of degrees and the degree sign. Clarion ROUNDS on assignment
!  to an integer (28.7 -> 29, -3.5 -> -4), and the plain conversion that
!  follows never puts a grouping comma in front of a temperature.
MyWeatherClass.TempText PROCEDURE(REAL pT)
v  LONG,AUTO
s  CSTRING(16)
  CODE
  v = pT
  s = v
  RETURN CLIP(s) & '<176>'


MyWeatherClass.UnitTemp PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.Units = Wx:Imperial,'F','C')


MyWeatherClass.UnitWind PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.Units = Wx:Imperial,'mph','km/h')


MyWeatherClass.UnitRain PROCEDURE()
  CODE
  RETURN CHOOSE(SELF.Units = Wx:Imperial,'in','mm')


! ############################################################################
!  Remembering the last reading
! ############################################################################
!  Two things are kept: the reading itself, and the place it was taken for.
!  The place is the expensive half - an IP lookup or a geocode - and it is
!  good for a day, so a program that starts twice in a morning only makes one
!  request the second time. The signature is what stops a cache taken for one
!  city (or in one unit) being shown for another.
MyWeatherClass.Signature PROCEDURE()
la  CSTRING(32)
lo  CSTRING(32)
  CODE
  CASE SELF.Locate
  OF Wx:ByCity
    RETURN 'C:' & CLIP(UPPER(SELF.City)) & '/' & SELF.Units
  OF Wx:ByLatLon
    la = SELF.Lat                                           ! plain conversion - no grouping commas
    lo = SELF.Lon
    RETURN 'L:' & CLIP(la) & ',' & CLIP(lo) & '/' & SELF.Units
  END
  RETURN 'IP/' & SELF.Units


MyWeatherClass.IniPath PROCEDURE()
nm  CSTRING(261)
n   ULONG,AUTO
i   LONG,AUTO
cut LONG(0)
  CODE
  IF CLIP(LEFT(SELF.IniFile)) THEN RETURN CLIP(LEFT(SELF.IniFile)) .
  nm = ''
  n  = wxModuleFile(0,nm,260)
  IF ~n THEN RETURN '' .
  LOOP i = LEN(nm) TO 1 BY -1
    IF nm[i : i] = '\' OR nm[i : i] = '/' THEN BREAK .
    IF nm[i : i] = '.' THEN cut = i; BREAK .
  END
  IF cut THEN nm = SUB(nm,1,cut-1) .
  RETURN CLIP(nm) & '.INI'


MyWeatherClass.IniSection PROCEDURE()
p  CSTRING(65)
  CODE
  p = CLIP(LEFT(SELF.Profile))
  IF ~p THEN RETURN 'myWeather' .
  RETURN 'myWeather_' & p


MyWeatherClass.SaveCache PROCEDURE()
f     CSTRING(261)
sect  CSTRING(80)
i     LONG,AUTO
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  IF ~CLIP(f) THEN RETURN .
  PUTINI(sect,'Sig',SELF.Signature(),f)
  PUTINI(sect,'Date',SELF.AsOfDate,f)
  PUTINI(sect,'Time',SELF.AsOfTime,f)
  PUTINI(sect,'Lat',SELF.Lat,f)
  PUTINI(sect,'Lon',SELF.Lon,f)
  PUTINI(sect,'Place',SELF.Place,f)
  PUTINI(sect,'Zone',SELF.Zone,f)
  PUTINI(sect,'Temp',SELF.Temp,f)
  PUTINI(sect,'Feels',SELF.Feels,f)
  PUTINI(sect,'Humidity',SELF.Humidity,f)
  PUTINI(sect,'Precip',SELF.Precip,f)
  PUTINI(sect,'Wind',SELF.Wind,f)
  PUTINI(sect,'WindDir',SELF.WindDir,f)
  PUTINI(sect,'Code',SELF.WCode,f)
  PUTINI(sect,'IsDay',SELF.IsDay,f)
  PUTINI(sect,'Taken',SELF.Taken,f)
  PUTINI(sect,'Sunrise',SELF.Sunrise,f)
  PUTINI(sect,'Sunset',SELF.Sunset,f)
  PUTINI(sect,'NDays',SELF.NDays,f)
  LOOP i = 1 TO SELF.NDays
    PUTINI(sect,'D' & i & 'Date',SELF.DDate[i],f)
    PUTINI(sect,'D' & i & 'Code',SELF.DCode[i],f)
    PUTINI(sect,'D' & i & 'Hi',SELF.DHi[i],f)
    PUTINI(sect,'D' & i & 'Lo',SELF.DLo[i],f)
  END


!  1 when a reading for THIS place, in THESE units, came back off the disk.
MyWeatherClass.LoadCache PROCEDURE()
f     CSTRING(261)
sect  CSTRING(80)
sig   CSTRING(97)
i     LONG,AUTO
  CODE
  IF ~SELF.Persist THEN RETURN 0 .
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  IF ~CLIP(f) THEN RETURN 0 .
  sig = GETINI(sect,'Sig','',f)
  IF ~CLIP(sig) OR CLIP(sig) <> CLIP(SELF.Signature()) THEN RETURN 0 .
  SELF.AsOfDate = GETINI(sect,'Date',0,f)
  IF ~SELF.AsOfDate THEN RETURN 0 .
  SELF.AsOfTime = GETINI(sect,'Time',0,f)
  IF SELF.Locate <> Wx:ByLatLon
    SELF.Lat    = GETINI(sect,'Lat',0,f)
    SELF.Lon    = GETINI(sect,'Lon',0,f)
  END
  SELF.Place    = GETINI(sect,'Place','',f)
  SELF.Zone     = GETINI(sect,'Zone','',f)
  SELF.Temp     = GETINI(sect,'Temp',0,f)
  SELF.Feels    = GETINI(sect,'Feels',0,f)
  SELF.Humidity = GETINI(sect,'Humidity',0,f)
  SELF.Precip   = GETINI(sect,'Precip',0,f)
  SELF.Wind     = GETINI(sect,'Wind',0,f)
  SELF.WindDir  = GETINI(sect,'WindDir',0,f)
  SELF.WCode    = GETINI(sect,'Code',0,f)
  SELF.IsDay    = GETINI(sect,'IsDay',1,f)
  SELF.Taken    = GETINI(sect,'Taken','',f)
  SELF.Sunrise  = GETINI(sect,'Sunrise','',f)
  SELF.Sunset   = GETINI(sect,'Sunset','',f)
  SELF.NDays    = GETINI(sect,'NDays',0,f)
  IF SELF.NDays > Wx:MaxDays THEN SELF.NDays = Wx:MaxDays .
  LOOP i = 1 TO SELF.NDays
    SELF.DDate[i] = GETINI(sect,'D' & i & 'Date',0,f)
    SELF.DCode[i] = GETINI(sect,'D' & i & 'Code',0,f)
    SELF.DHi[i]   = GETINI(sect,'D' & i & 'Hi',0,f)
    SELF.DLo[i]   = GETINI(sect,'D' & i & 'Lo',0,f)
  END
  RETURN 1


MyWeatherClass.ForgetCache PROCEDURE()
f     CSTRING(261)
sect  CSTRING(80)
  CODE
  f    = SELF.IniPath()
  sect = SELF.IniSection()
  IF ~CLIP(f) THEN RETURN .
  PUTINI(sect,'Sig','',f)
  PUTINI(sect,'Date','',f)


! ############################################################################
!  Drawing the card
! ############################################################################
!  How tall the card comes out - the window is sized from this, so the same
!  arithmetic has to hold for a card with no forecast and no readings strip.
MyWeatherClass.CardH PROCEDURE()
h  LONG,AUTO
  CODE
  h = Wx:HeadH
  IF ~SELF.Ok THEN RETURN h + 20 .                          ! the fault card is a headline, no readings
  IF SELF.ShowFeels OR SELF.ShowHumidity OR SELF.ShowWind OR SELF.ShowPrecip OR SELF.ShowSun
    h = h + Wx:StatH
  END
  IF SELF.Days > 0 AND SELF.NDays > 0 THEN h = h + Wx:CastH .
  RETURN h + 20                                             ! the attribution strip


MyWeatherClass.Draw PROCEDURE(WINDOW pWin,SIGNED pImage)
x  LONG,AUTO
y  LONG,AUTO
  CODE
  SELF.Canvas = pImage
  SETTARGET(pWin,pImage)                                    ! 0,0 is the image's top-left
  SELF.Base()                                               ! the grid every coordinate is in
  GETPOSITION(pImage,x,y,SELF.BaseW,SELF.BaseH)
  IF SELF.BaseW < 1 THEN SELF.BaseW = Wx:CardW .
  IF SELF.BaseH < 1 THEN SELF.BaseH = SELF.CardH() .
  SELF.Paint()
  SELF.Base()
  SETTARGET()


!  Blend two colours. Clarion holds a colour as 0BBGGRRh, so each channel has
!  to be pulled out, mixed and put back - and the bit operators are functions
!  here (BAND / BOR / BSHIFT), not the C punctuation.
MyWeatherClass.Mix PROCEDURE(LONG pC1,LONG pC2,LONG pPct)
r  LONG,AUTO
g  LONG,AUTO
b  LONG,AUTO
p  LONG,AUTO
  CODE
  p = pPct
  IF p < 0   THEN p = 0   .
  IF p > 100 THEN p = 100 .
  r = INT((BAND(pC1,0FFh)            * (100 - p) + BAND(pC2,0FFh)            * p) / 100)
  g = INT((BAND(BSHIFT(pC1,-8),0FFh) * (100 - p) + BAND(BSHIFT(pC2,-8),0FFh) * p) / 100)
  b = INT((BAND(BSHIFT(pC1,-16),0FFh)* (100 - p) + BAND(BSHIFT(pC2,-16),0FFh)* p) / 100)
  RETURN BOR(BOR(r,BSHIFT(g,8)),BSHIFT(b,16))


!  The sky colour at a given row of the header band.
MyWeatherClass.Sky PROCEDURE(LONG pY)
p  LONG,AUTO
  CODE
  p = INT(pY * 100 / Wx:HeadH)
  IF SELF.IsDay
    RETURN SELF.Mix(Wx:DaySky1,Wx:DaySky2,p)
  END
  RETURN SELF.Mix(Wx:NightSky1,Wx:NightSky2,p)


! ---------------------------------------------------------------------------
!  Text on a card drawn with mixed font sizes
! ---------------------------------------------------------------------------
!  Two facts about Clarion drawing have to be handled together here.
!
!  1. SHOW takes its colour from the current FONT, not from the pen -
!     SETPENCOLOR only reaches LINE / BOX / POLYGON / ELLIPSE. SETFONT(0,...)
!     sets the font of whatever SETTARGET last pointed at, and that is the
!     only handle there is on the colour of drawn text.
!
!  2. A dialog unit IS a fraction of that font's character cell (a quarter of
!     the average width, an eighth of the height). So the moment SETFONT
!     changes the size, every coordinate handed to SHOW, BOX or LINE means
!     something different - a 26pt heading drawn at y=40 lands three times
!     further down the card than the 9pt line above it.
!
!  The way out is to measure. GETPOSITION reports the canvas in the units of
!  the font that is current, so the canvas measured under the heading font
!  against the canvas measured under the base font IS the scale factor
!  between the two grids (probed: 400x300 base, 133x96 at 26pt bold, and
!  exactly 400x300 again when the base font goes back on).
!
!  So: geometry is always drawn with the base font on, Ink() picks the font
!  the next string wants and measures it, and Say() converts one base-grid
!  coordinate into that font's grid, draws, and puts the base font back.
MyWeatherClass.Base PROCEDURE()
  CODE
  SETFONT(0,Wx:Face,Wx:BaseFont,Wx:Ink,FONT:regular,CHARSET:ANSI)


MyWeatherClass.Ink PROCEDURE(LONG pSize,LONG pColor,BYTE pBold)
x  LONG,AUTO
y  LONG,AUTO
  CODE
  SELF.FSize  = pSize
  SELF.FColor = pColor
  SELF.FBold  = pBold
  SETFONT(0,Wx:Face,pSize,pColor,CHOOSE(pBold = 1,FONT:bold,FONT:regular),CHARSET:ANSI)
  GETPOSITION(SELF.Canvas,x,y,SELF.CurW,SELF.CurH)           ! the canvas, in THIS font's units
  IF SELF.CurW < 1 THEN SELF.CurW = SELF.BaseW .
  IF SELF.CurH < 1 THEN SELF.CurH = SELF.BaseH .
  SELF.Base()                                                ! geometry keeps the base grid


MyWeatherClass.Say PROCEDURE(LONG pX,LONG pY,STRING pText)
  CODE
  SETFONT(0,Wx:Face,SELF.FSize,SELF.FColor,CHOOSE(SELF.FBold = 1,FONT:bold,FONT:regular),CHARSET:ANSI)
  SHOW(INT(pX * SELF.CurW / SELF.BaseW),INT(pY * SELF.CurH / SELF.BaseH),CLIP(pText))
  SELF.Base()


!  How wide that string comes out, in BASE units. One character is four units
!  of its own font by definition, which is exact enough to centre with.
MyWeatherClass.Wide PROCEDURE(STRING pText)
  CODE
  IF SELF.CurW < 1 THEN RETURN LEN(CLIP(pText)) * Wx:CharW .
  RETURN INT(LEN(CLIP(pText)) * Wx:CharW * SELF.BaseW / SELF.CurW)


!  One reading in the strip under the sky: a small grey label with the value
!  under it, both centred in a cell the caller sized.
MyWeatherClass.Cell PROCEDURE(LONG pX,LONG pY,LONG pW,STRING pLabel,STRING pValue)
  CODE
  SELF.Ink(7,Wx:Muted,0)
  SELF.Say(pX + INT((pW - SELF.Wide(pLabel)) / 2),pY + 8,pLabel)
  SELF.Ink(10,Wx:Ink,1)
  SELF.Say(pX + INT((pW - SELF.Wide(pValue)) / 2),pY + 19,pValue)


!  The whole card, top to bottom. Everything is drawn into the IMAGE that
!  Draw() made the target, so it all belongs to the control and survives a
!  repaint without any work from the window.
MyWeatherClass.Paint PROCEDURE()
y      LONG,AUTO
h      LONG,AUTO
i      LONG,AUTO
n      LONG,AUTO
x      LONG,AUTO
w      LONG,AUTO
cw     LONG,AUTO
c      LONG,AUTO
hh     LONG,AUTO
mm     LONG,AUTO
wh     LONG,AUTO
wl     LONG,AUTO
t      CSTRING(129)
s      CSTRING(17)
hi     CSTRING(17)
lo     CSTRING(17)
lab    CSTRING(17),DIM(6)
val    CSTRING(17),DIM(6)
  CODE
  h = SELF.CardH()

! ---- the sky --------------------------------------------------------------
!  A gradient is a stack of one-unit boxes. BOX outlines in the CURRENT pen,
!  so the pen is set for every one of them - inherit it and each band picks up
!  an edge in whatever colour ran before.
  LOOP y = 0 TO Wx:HeadH - 1
    c = SELF.Sky(y)
    SETPENCOLOR(c)
    BOX(0,y,Wx:CardW,1,c)
  END
  SETPENCOLOR(Wx:Paper)
  BOX(0,Wx:HeadH,Wx:CardW,h - Wx:HeadH,Wx:Paper)

! ---- nothing to show ------------------------------------------------------
  IF ~SELF.Ok
    SELF.Glyph(16,20,56,3,SELF.IsDay,SELF.Sky(48))
    SELF.Ink(13,Wx:OnSky,1)
    SELF.Say(88,30,SELF.Txt(WTx:NoWeather))
    SELF.Ink(9,Wx:OnSkyMuted,0)
    SELF.Say(88,52,SELF.Err)
    SELF.Ink(8,Wx:Muted,0)
    SELF.Say(16,h - 14,SELF.Txt(WTx:Source))
    RETURN
  END

! ---- the sky band: where, how warm, and what it is doing ------------------
  SELF.Glyph(14,16,64,SELF.WCode,SELF.IsDay,SELF.Sky(48))

  SELF.Ink(11,Wx:OnSky,1)
  SELF.Say(92,12,SELF.Place)

!  CLOCK() counts hundredths of a second from midnight, starting at 1. The
!  hours and minutes are picked out by hand rather than with a @T picture, so
!  the card always reads HH:MM whatever the picture set does.
  t = ''
  IF LEN(CLIP(SELF.Taken))
    t = CLIP(SELF.Txt(WTx:AsOf)) & ' ' & CLIP(SELF.Taken)
  ELSIF SELF.AsOfTime
    hh = INT((SELF.AsOfTime - 1) / 360000)
    mm = INT(((SELF.AsOfTime - 1) % 360000) / 6000)
    t  = CLIP(SELF.Txt(WTx:AsOf)) & ' ' & FORMAT(hh,@n02) & ':' & FORMAT(mm,@n02)
  END
  IF SELF.Stale
    t = CLIP(t) & ' - ' & CLIP(SELF.Txt(WTx:LastKnown))
  ELSIF LEN(CLIP(SELF.Zone))
    t = CLIP(t) & ' - ' & CLIP(SELF.Zone)
  END
  SELF.Ink(8,Wx:OnSkyMuted,0)
  SELF.Say(92,28,t)

  SELF.Ink(26,Wx:OnSky,1)
  t = SELF.TempText(SELF.Temp)
  w = SELF.Wide(t)                                          ! measured in base units, so the
  SELF.Say(90,42,t)                                         ! C / F can sit beside it
  SELF.Ink(12,Wx:OnSkyMuted,0)
  SELF.Say(86 + w,54,SELF.UnitTemp())

  SELF.Ink(10,Wx:OnSky,0)
  SELF.Say(92,74,SELF.Describe(SELF.WCode))

! ---- the readings strip ---------------------------------------------------
  y = Wx:HeadH
  n = 0
  IF SELF.ShowFeels
    n = n + 1 ; lab[n] = SELF.Txt(WTx:Feels)
                val[n] = CLIP(SELF.TempText(SELF.Feels))
  END
  IF SELF.ShowHumidity
    w = SELF.Humidity ; s = w                               ! plain conversion, no grouping comma
    n = n + 1 ; lab[n] = SELF.Txt(WTx:Humidity)
                val[n] = CLIP(s) & '%'
  END
  IF SELF.ShowWind
    w = SELF.Wind ; s = w                                   ! assignment to a LONG rounds
    n = n + 1 ; lab[n] = SELF.Txt(WTx:Wind)
                val[n] = CLIP(s) & ' ' & CLIP(SELF.UnitWind()) & |
                         ' ' & CLIP(SELF.Compass(SELF.WindDir))
  END
  IF SELF.ShowPrecip
    n = n + 1 ; lab[n] = SELF.Txt(WTx:Rain)
                val[n] = CLIP(LEFT(FORMAT(SELF.Precip,@n7.1))) & ' ' & CLIP(SELF.UnitRain())
  END
  IF SELF.ShowSun AND LEN(CLIP(SELF.Sunrise)) AND n < 6
    n = n + 1 ; lab[n] = SELF.Txt(WTx:Sunrise)
                val[n] = CLIP(SELF.Sunrise)
  END
  IF SELF.ShowSun AND LEN(CLIP(SELF.Sunset)) AND n < 6
    n = n + 1 ; lab[n] = SELF.Txt(WTx:Sunset)
                val[n] = CLIP(SELF.Sunset)
  END
  IF n
    SETPENCOLOR(Wx:Panel)
    BOX(0,y,Wx:CardW,Wx:StatH,Wx:Panel)
    cw = INT(Wx:CardW / n)
    LOOP i = 1 TO n
      x = (i - 1) * cw
      IF i > 1
        SETPENCOLOR(Wx:Rule)
        LINE(x,y + 9,0,Wx:StatH - 18)
      END
      SELF.Cell(x,y,cw,lab[i],val[i])
    END
    SETPENCOLOR(Wx:Rule)
    LINE(0,y + Wx:StatH - 1,Wx:CardW,0)
    y = y + Wx:StatH
  END

! ---- the days ahead -------------------------------------------------------
  IF SELF.Days > 0 AND SELF.NDays > 0
    SELF.Ink(8,Wx:Muted,1)
    SELF.Say(16,y + 8,UPPER(SELF.Txt(WTx:Forecast)))
    n  = SELF.NDays
    cw = INT((Wx:CardW - 24) / n)
    LOOP i = 1 TO n
      x = 12 + (i - 1) * cw
      t = SELF.DayName(SELF.DDate[i])
      SELF.Ink(9,Wx:Ink,1)
      SELF.Say(x + INT((cw - SELF.Wide(t)) / 2),y + 24,t)
      SELF.Glyph(x + INT((cw - 26) / 2),y + 36,26,SELF.DCode[i],1,Wx:Paper)
!  The high and the low read as one line - measured together and centred as a
!  pair, so a '-5' day lines up with a '105' day.
      hi = CLIP(SELF.TempText(SELF.DHi[i]))
      lo = CLIP(SELF.TempText(SELF.DLo[i]))
      SELF.Ink(9,Wx:Warm,1)
      wh = SELF.Wide(hi)
      wl = SELF.Wide(lo)
      w  = x + INT((cw - (wh + 6 + wl)) / 2)
      SELF.Say(w,y + 68,hi)
      SELF.Ink(9,Wx:Cool,0)
      SELF.Say(w + wh + 6,y + 68,lo)
    END
    y = y + Wx:CastH
  END

! ---- the attribution ------------------------------------------------------
  SETPENCOLOR(Wx:Rule)
  LINE(0,y,Wx:CardW,0)
  SELF.Ink(8,Wx:Muted,0)
  SELF.Say(16,y + 6,SELF.Txt(WTx:Source))



!  The weather itself, drawn. pSize is the side of the square it fills, pBack
!  is the colour behind it - the moon needs that to bite its crescent out.
!
!  The WMO codes group into eight pictures:
!     0        the sun, or the moon
!     1, 2     the sun or moon with a cloud across it
!     3        cloud
!     45, 48   fog
!     51-57    cloud with a light drizzle
!     61-67    cloud with rain
!     71-77    cloud with snow
!     80-86    a shower - the same, drawn heavier
!     95-99    cloud with a lightning bolt
MyWeatherClass.Glyph PROCEDURE(LONG pX,LONG pY,LONG pSize,LONG pCode,BYTE pDay,LONG pBack)
s     LONG,AUTO
r     LONG,AUTO
ox    LONG,AUTO
oy    LONG,AUTO
i     LONG,AUTO
a     REAL,AUTO
x1    LONG,AUTO
y1    LONG,AUTO
x2    LONG,AUTO
y2    LONG,AUTO
orb   BYTE(0)                                               ! draw the sun or the moon
sky   BYTE(0)                                               ! ... on its own, no cloud
cld   BYTE(0)
bolt  BYTE(0)
fog   BYTE(0)
drops LONG(0)
snow  BYTE(0)
poly  SIGNED,DIM(12)
  CODE
  s = pSize
  CASE pCode
  OF 0
    orb = 1 ; sky = 1
  OF 1 OROF 2
    orb = 1 ; cld = 1
  OF 3
    cld = 1
  OF 45 OROF 48
    cld = 1 ; fog = 1
  OF 51 OROF 53 OROF 55 OROF 56 OROF 57
    cld = 1 ; drops = 2
  OF 61 OROF 63 OROF 65 OROF 66 OROF 67
    cld = 1 ; drops = 3
  OF 80 OROF 81 OROF 82
    cld = 1 ; drops = 3 ; orb = 1                           ! a shower: sun behind the cloud
  OF 71 OROF 73 OROF 75 OROF 77
    cld = 1 ; drops = 3 ; snow = 1
  OF 85 OROF 86
    cld = 1 ; drops = 3 ; snow = 1 ; orb = 1
  OF 95 OROF 96 OROF 99
    cld = 1 ; bolt = 1
  ELSE
    cld = 1
  END

! ---- the sun, or the moon -------------------------------------------------
  IF orb
    IF sky
      r  = INT(s * 0.24)
      ox = pX + INT(s / 2)
      oy = pY + INT(s / 2)
    ELSE
      r  = INT(s * 0.17)                                    ! peeping out from behind the cloud
      ox = pX + INT(s * 0.34)
      oy = pY + INT(s * 0.28)
    END
    IF pDay
      SETPENCOLOR(Wx:Sun)
      ELLIPSE(ox - r,oy - r,2 * r,2 * r,Wx:Sun)
      IF sky                                                ! rays, only when nothing covers them
        SETPENWIDTH(2)
        SETPENCOLOR(Wx:Sun)
        LOOP i = 0 TO 7
          a  = i * 3.14159265 / 4
          x1 = ox + INT(r * 1.35 * COS(a))
          y1 = oy - INT(r * 1.35 * SIN(a))
          x2 = ox + INT(r * 1.85 * COS(a))
          y2 = oy - INT(r * 1.85 * SIN(a))
          LINE(x1,y1,x2 - x1,y2 - y1)
        END
        SETPENWIDTH(1)
      END
    ELSE
!  A crescent is a full disc with a second disc of the background punched out
!  of it, offset up and to the right.
      SETPENCOLOR(Wx:Moon)
      ELLIPSE(ox - r,oy - r,2 * r,2 * r,Wx:Moon)
      SETPENCOLOR(pBack)
      ELLIPSE(ox - r + INT(r * 0.55),oy - r - INT(r * 0.30),2 * r,2 * r,pBack)
    END
  END

! ---- the cloud ------------------------------------------------------------
  IF cld
    SELF.Cloud(pX + INT(s * 0.06),pY + INT(s * 0.26),INT(s * 0.88), |
               CHOOSE(drops > 0 OR bolt = 1,Wx:CloudDark,Wx:Cloud))
  END

! ---- what is falling out of it --------------------------------------------
  IF drops
    SELF.Drops(pX + INT(s * 0.20),pY + INT(s * 0.76),s,drops,snow)
  END
  IF bolt
    poly[1]  = pX + INT(s * 0.52) ; poly[2]  = pY + INT(s * 0.66)
    poly[3]  = pX + INT(s * 0.36) ; poly[4]  = pY + INT(s * 0.96)
    poly[5]  = pX + INT(s * 0.49) ; poly[6]  = pY + INT(s * 0.94)
    poly[7]  = pX + INT(s * 0.38) ; poly[8]  = pY + INT(s * 1.22)
    poly[9]  = pX + INT(s * 0.66) ; poly[10] = pY + INT(s * 0.86)
    poly[11] = pX + INT(s * 0.51) ; poly[12] = pY + INT(s * 0.88)
    SETPENCOLOR(Wx:Bolt)
    POLYGON(poly,Wx:Bolt)
  END
  IF fog
    SETPENWIDTH(2)
    SETPENCOLOR(Wx:CloudDark)
    LOOP i = 0 TO 2
      LINE(pX + INT(s * 0.14) + i * 3,pY + INT(s * 0.80) + i * 7,INT(s * 0.66) - i * 6,0)
    END
    SETPENWIDTH(1)
  END


!  Three puffs over a flat base - a cloud that fills a box pSize wide and
!  about two thirds of that tall, with its top-left at pX,pY.
MyWeatherClass.Cloud PROCEDURE(LONG pX,LONG pY,LONG pSize,LONG pColor)
s  LONG,AUTO
  CODE
  s = pSize
  SETPENCOLOR(pColor)
  ELLIPSE(pX,               pY + INT(s * 0.22),INT(s * 0.44),INT(s * 0.44),pColor)
  ELLIPSE(pX + INT(s*0.24), pY,                INT(s * 0.52),INT(s * 0.52),pColor)
  ELLIPSE(pX + INT(s*0.56), pY + INT(s * 0.20),INT(s * 0.44),INT(s * 0.44),pColor)
  BOX(pX + INT(s * 0.06),pY + INT(s * 0.40),INT(s * 0.88),INT(s * 0.26),pColor)


!  Rain slants; snow does not. pCount drops, spread across the width, hanging
!  under the cloud the caller has just drawn.
MyWeatherClass.Drops PROCEDURE(LONG pX,LONG pY,LONG pSize,LONG pCount,BYTE pSnow)
i    LONG,AUTO
x    LONG,AUTO
gap  LONG,AUTO
ln   LONG,AUTO                                              ! not "len" - LEN is a function
r    LONG,AUTO
  CODE
  gap = INT(pSize * 0.18)
  ln  = INT(pSize * 0.16)
  IF ln < 3 THEN ln = 3 .
  LOOP i = 0 TO pCount - 1
    x = pX + i * gap
    IF pSnow
      r = INT(ln / 2)
      IF r < 2 THEN r = 2 .
      SETPENCOLOR(Wx:Snow)
      ELLIPSE(x - r,pY - r,2 * r,2 * r,Wx:Snow)
    ELSE
      SETPENWIDTH(2)
      SETPENCOLOR(Wx:Water)
      LINE(x,pY,-INT(ln / 3),ln)
      SETPENWIDTH(1)
    END
  END
