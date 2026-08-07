  MEMBER('airwin.clw')

  PRAGMA('define(init_priority=>3)')

  MAP
    MODULE('airwin_BC0.CLW')
airwin_BC0:DctInit             PROCEDURE()
airwin_BC0:DctKill             PROCEDURE()
airwin_BC0:FilesInit           PROCEDURE()
    END
  END

DctInit PROCEDURE()
  CODE
  airwin_BC0:DctInit
  airwin_BC0:FilesInit


DctKill PROCEDURE()
  CODE
  airwin_BC0:DctKill

