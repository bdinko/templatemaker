!ABCIncludeFile(MYWEATHER)
! ============================================================================
!  MyWeatherClass - the weather, on a card your application can show at
!  start-up.
!
!    * Current temperature, what it feels like, humidity, wind and rain
!    * A five-day forecast strip (up to seven days)
!    * Sunrise and sunset
!    * The sky, the sun, the moon, the clouds, the rain, the snow and the
!      lightning are all DRAWN - native Clarion graphics, no image files,
!      nothing to ship and nothing to install
!    * English or Spanish
!    * Closes itself after n seconds, or waits for the user
!
!  WHERE THE WEATHER COMES FROM
!  ----------------------------
!  api.open-meteo.com - a free public forecast service that needs NO API key
!  and NO registration. Three requests at most, all HTTPS:
!
!    1. the place        ipwho.is           (only when locating by IP)
!       or               geocoding-api.open-meteo.com  (only for a city name)
!    2. the weather      api.open-meteo.com
!
!  The download itself is curl.exe, which ships with Windows 10 and 11 in
!  %SystemRoot%\System32. curl is launched HIDDEN (no console flashing past)
!  and SYNCHRONOUSLY, so the answer is on disk before it is read - the same
!  proven launcher myQR uses.
!
!  *** PRIVACY / INTERNET ***
!  This class talks to THIRD-PARTY servers. Locating by IP sends your public
!  IP address to ipwho.is; a city name goes to Open-Meteo's geocoder; the
!  coordinates go to Open-Meteo. An internet connection is required for a
!  fresh reading - but not to start the program: a failed fetch falls back on
!  the last reading kept in the INI, and can be told to show nothing at all.
!
!  USAGE (the weatherWidget template does all of this for you)
!    INCLUDE('MyWeatherClass.INC'),ONCE
!    Weather  MyWeatherClass
!
!      Weather.Locate = Wx:ByCity                 ! or Wx:ByIP / Wx:ByLatLon
!      Weather.City   = 'Monterrey'
!      Weather.Ask()                              ! fetch (or use the cache)
!                                                 ! and show the card
!  FILES: MyWeatherClass.inc + MyWeatherClass.clw on the redirection path,
!         ANSI, CRLF.
! ============================================================================

! ---- how the place is worked out ------------------------------------------
Wx:ByIP            EQUATE(0)                    ! ask ipwho.is who we are
Wx:ByCity          EQUATE(1)                    ! geocode a name you typed
Wx:ByLatLon        EQUATE(2)                    ! coordinates you already have

! ---- what the numbers are measured in -------------------------------------
Wx:Metric          EQUATE(0)                    ! C, km/h, mm
Wx:Imperial        EQUATE(1)                    ! F, mph, in

! ---- languages ------------------------------------------------------------
Wx:English         EQUATE(1)
Wx:Spanish         EQUATE(2)

! ---- what to do when there is no answer -----------------------------------
Wx:FailSilent      EQUATE(0)                    ! show nothing, say nothing
Wx:FailCached      EQUATE(1)                    ! show the last reading kept
Wx:FailShow        EQUATE(2)                    ! show the card, with the fault

! ---- every word the card shows --------------------------------------------
WTx:Weather        EQUATE(1)
WTx:Feels          EQUATE(2)
WTx:Humidity       EQUATE(3)
WTx:Wind           EQUATE(4)
WTx:Rain           EQUATE(5)
WTx:Sunrise        EQUATE(6)
WTx:Sunset         EQUATE(7)
WTx:Refresh        EQUATE(8)
WTx:Close          EQUATE(9)
WTx:Closing        EQUATE(10)                   ! "closes in 8 s"
WTx:AsOf           EQUATE(11)                   ! "as of 09:45"
WTx:Forecast       EQUATE(12)
WTx:NoWeather      EQUATE(13)                   ! the headline when it failed
WTx:LastKnown      EQUATE(14)                   ! "last known reading"
WTx:Source         EQUATE(15)                   ! the attribution line
WTx:Today          EQUATE(16)
WTx:NoCurl         EQUATE(17)
WTx:NoPlace        EQUATE(18)
WTx:Offline        EQUATE(19)

! ---- the card, in dialog units --------------------------------------------
Wx:CardW           EQUATE(352)                  ! the drawn canvas
Wx:HeadH           EQUATE(96)                   ! the sky band at the top
Wx:StatH           EQUATE(40)                   ! the four readings under it
Wx:CastH           EQUATE(88)                   ! the forecast strip
Wx:MaxDays         EQUATE(7)                    ! Open-Meteo gives us up to 7
Wx:CharW           EQUATE(4)                    ! one character, by definition
Wx:CharH           EQUATE(8)
Wx:BaseFont        EQUATE(9)                    ! the card's grid is this font's units
Wx:Face            EQUATE('Segoe UI')

! ---- the palette (Clarion colours are 0BBGGRRh) ----------------------------
Wx:DaySky1         EQUATE(0603A1FH)             ! RGB( 31, 58, 96) navy, top
Wx:DaySky2         EQUATE(0B87A4AH)             ! RGB( 74,122,184) noon blue
Wx:NightSky1       EQUATE(02C1810H)             ! RGB( 16, 24, 44)
Wx:NightSky2       EQUATE(06B4A32H)             ! RGB( 50, 74,107)
Wx:Paper           EQUATE(0FBF9F8H)             ! RGB(248,249,251) the card
Wx:Panel           EQUATE(0F2EDE9H)             ! RGB(233,237,242) stat strip
Wx:Rule            EQUATE(0DCD6D0H)             ! RGB(208,214,220)
Wx:Ink             EQUATE(037291FH)             ! RGB( 31, 41, 55) headings
Wx:Muted           EQUATE(080726BH)             ! RGB(107,114,128) labels
Wx:OnSky           EQUATE(0FFFFFFH)             ! white, on the sky band
Wx:OnSkyMuted      EQUATE(0D8C8B4H)             ! RGB(180,200,216)
Wx:Sun             EQUATE(03CB5F5H)             ! RGB(245,181, 60) amber
Wx:Moon            EQUATE(0DCE6F0H)             ! RGB(240,230,220) bone
Wx:Cloud           EQUATE(0F5F0ECH)             ! RGB(236,240,245) white cloud
Wx:CloudDark       EQUATE(0C4B4A8H)             ! RGB(168,180,196) grey cloud
Wx:Water           EQUATE(0FAA560H)             ! RGB( 96,165,250) rain blue
Wx:Snow            EQUATE(0FFFAF0H)             ! RGB(240,250,255)
Wx:Bolt            EQUATE(030C0F0H)             ! RGB(240,192, 48) lightning
Wx:Warm            EQUATE(04A5AE0H)             ! RGB(224, 90, 74) the high
Wx:Cool            EQUATE(0D08A4AH)             ! RGB( 74,138,208) the low
Wx:Bad             EQUATE(03C3CC0H)             ! RGB(192, 60, 60) the fault

MyWeatherClass       CLASS,TYPE,MODULE('MyWeatherClass.CLW'),LINK('MyWeatherClass.CLW',_myWeatherLinkMode_),DLL(_myWeatherDllMode_)

! ---- what the caller sets: the place --------------------------------------
Locate               BYTE(0)                    ! Wx:ByIP / Wx:ByCity / Wx:ByLatLon
City                 CSTRING(65)                ! 'Monterrey' or 'Monterrey, MX'
Lat                  REAL                       ! used when Locate = Wx:ByLatLon
Lon                  REAL

! ---- what the caller sets: the card ---------------------------------------
Units                BYTE(0)                    ! Wx:Metric / Wx:Imperial
Language             BYTE(1)                    ! Wx:English / Wx:Spanish
Days                 BYTE(5)                    ! forecast days shown, 0..7
Title                CSTRING(65)                ! blank = the localised name
AutoClose            LONG(0)                    ! seconds, 0 = wait for the user
ShowFeels            BYTE(1)
ShowHumidity         BYTE(1)
ShowWind             BYTE(1)
ShowPrecip           BYTE(1)
ShowSun              BYTE(1)

! ---- what the caller sets: the network ------------------------------------
Timeout              LONG(6)                    ! seconds any one download may take
CacheMinutes         LONG(30)                   ! reuse a reading younger than this
OnFail               BYTE(1)                    ! Wx:FailSilent / Cached / Show

! ---- what the caller sets: remembering ------------------------------------
Persist              BYTE(1)                    ! keep the last reading in the INI
IniFile              CSTRING(261)               ! blank = <exename>.INI
Profile              CSTRING(65)                ! blank = one shared entry

! ---- what you get back ----------------------------------------------------
Ok                   BYTE                       ! 1 = there is a reading to show
Stale                BYTE                       ! 1 = it came from the INI, not the net
Err                  CSTRING(129)               ! why not, in the chosen language
Place                CSTRING(97)                ! 'Monterrey, Mexico'
Zone                 CSTRING(65)                ! 'America/Monterrey'
Temp                 REAL                       ! now
Feels                REAL
Humidity             LONG                       ! per cent
Precip               REAL                       ! mm or in
Wind                 REAL                       ! km/h or mph
WindDir              LONG                       ! degrees the wind comes FROM
WCode                LONG                       ! WMO weather code - see Describe
IsDay                BYTE                       ! 1 = the sun is up there now
AsOfDate             LONG                       ! when this machine fetched it
AsOfTime             LONG
Taken                CSTRING(9)                 ! 'HH:MM' the reading itself is for,
                                                !   in the PLACE's time zone
Sunrise              CSTRING(9)                 ! 'HH:MM', local to the place
Sunset               CSTRING(9)
NDays                BYTE                       ! forecast days actually parsed
DDate                LONG,DIM(Wx:MaxDays)
DCode                LONG,DIM(Wx:MaxDays)
DHi                  REAL,DIM(Wx:MaxDays)
DLo                  REAL,DIM(Wx:MaxDays)

! ---- internals ------------------------------------------------------------
Canvas               SIGNED                     ! the IMAGE being drawn into
Closed               BYTE                       ! the card was closed by hand
Json                 CSTRING(24577)             ! the last response read
!  A dialog unit is a fraction of the CURRENT font's character cell, so the
!  drawing grid moves every time SETFONT changes size. These four hold the
!  canvas measured both ways - in the base font, and in the font the next
!  string will be drawn in - which is what Say() converts between.
BaseW                LONG                       ! the canvas in base-font units
BaseH                LONG
CurW                 LONG                       ! the canvas in the pending font
CurH                 LONG
FSize                LONG                       ! the pending font
FColor               LONG
FBold                BYTE

! ############################################################################
!  The three you actually call
! ############################################################################
!  Ask()     - the whole job: a reading (fresh, cached or none) and the card.
!              Returns 1 if a card was shown.
!  Fetch()   - just get a reading. Uses the cache when it is young enough.
!  Refresh() - get a reading, ignoring the cache. This one always hits the net.
Ask                  PROCEDURE(),BYTE,PROC
Fetch                PROCEDURE(),BYTE,PROC
Refresh              PROCEDURE(),BYTE,PROC

! ---- drawing --------------------------------------------------------------
Draw                 PROCEDURE(WINDOW pWin,SIGNED pImage)
CardH                PROCEDURE(),LONG           ! how tall the card comes out

! ---- words and numbers ----------------------------------------------------
Txt                  PROCEDURE(LONG pId),STRING
Describe             PROCEDURE(LONG pCode),STRING           ! WMO code -> words
DayName              PROCEDURE(LONG pDate),STRING           ! Mo Tu We / Lu Ma Mi
Compass              PROCEDURE(LONG pDeg),STRING            ! 250 -> WSW / OSO
TempText             PROCEDURE(REAL pT),STRING              ! '28<176>'
UnitTemp             PROCEDURE(),STRING                     ! 'C' / 'F'
UnitWind             PROCEDURE(),STRING                     ! 'km/h' / 'mph'
UnitRain             PROCEDURE(),STRING                     ! 'mm' / 'in'

! ---- remembering ----------------------------------------------------------
LoadCache            PROCEDURE(),BYTE,PROC
SaveCache            PROCEDURE()
ForgetCache          PROCEDURE()

! ---- internals (protected) ------------------------------------------------
Construct            PROCEDURE
FindPlace            PROCEDURE(),BYTE,PROTECTED             ! IP or city -> Lat/Lon
GetWeather           PROCEDURE(),BYTE,PROTECTED             ! coordinates -> the reading
Download             PROCEDURE(STRING pUrl),BYTE,PROTECTED  ! curl -> SELF.Json
Paint                PROCEDURE(),PROTECTED                  ! the card, into the target
Sky                  PROCEDURE(LONG pY),LONG,PROTECTED      ! the sky colour at a row
Glyph                PROCEDURE(LONG pX,LONG pY,LONG pSize,LONG pCode,BYTE pDay,LONG pBack),PROTECTED
Cloud                PROCEDURE(LONG pX,LONG pY,LONG pSize,LONG pColor),PROTECTED
Drops                PROCEDURE(LONG pX,LONG pY,LONG pSize,LONG pCount,BYTE pSnow),PROTECTED
Base                 PROCEDURE(),PROTECTED                  ! back to the base font and grid
Ink                  PROCEDURE(LONG pSize,LONG pColor,BYTE pBold),PROTECTED   ! choose the font the next Say uses
Say                  PROCEDURE(LONG pX,LONG pY,STRING pText),PROTECTED        ! draw it on the BASE grid
Wide                 PROCEDURE(STRING pText),LONG,PROTECTED ! its width, in base units
Mix                  PROCEDURE(LONG pC1,LONG pC2,LONG pPct),LONG,PROTECTED
Cell                 PROCEDURE(LONG pX,LONG pY,LONG pW,STRING pLabel,STRING pValue),PROTECTED
!  The JSON key parameter is pTag, NOT pKey: KEYCODES.CLW already defines
!  PKey (the P key, EQUATE(0050h)), Clarion labels are case-insensitive, and
!  a parameter that shadows it warns "Label duplicated, second used: PKEY" on
!  every method that has one.
Skip                 PROCEDURE(LONG pPos),LONG,PROTECTED   ! past any white space
Sect                 PROCEDURE(STRING pTag,*LONG pFrom,*LONG pTo),BYTE,PROTECTED
Num                  PROCEDURE(STRING pTag,LONG pFrom,LONG pTo),REAL,PROTECTED
Str                  PROCEDURE(STRING pTag,LONG pFrom,LONG pTo),STRING,PROTECTED
ArrNum               PROCEDURE(STRING pTag,LONG pIdx,LONG pFrom,LONG pTo),REAL,PROTECTED
ArrStr               PROCEDURE(STRING pTag,LONG pIdx,LONG pFrom,LONG pTo),STRING,PROTECTED
NumAt                PROCEDURE(LONG pPos),REAL,PROTECTED
Ansi                 PROCEDURE(STRING pUtf8),STRING,PROTECTED
IsoDate              PROCEDURE(STRING pIso),LONG,PROTECTED
IsoTime              PROCEDURE(STRING pIso),STRING,PROTECTED
UrlEnc               PROCEDURE(STRING pText),STRING,PROTECTED
IniPath              PROCEDURE(),STRING,PROTECTED
IniSection           PROCEDURE(),STRING,PROTECTED
Signature            PROCEDURE(),STRING,PROTECTED           ! which place the cache holds
                   END
