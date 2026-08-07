  MEMBER('addrtest')
Sub PROCEDURE(LONG pFromProgram)
there LONG
  CODE
  there = ADDRESS(AirImg_WheelProc)
  0{PROP:Text} = 'AddrTest program=' & pFromProgram & ' member=' & there &  |
                 CHOOSE(pFromProgram = there,' SAME',' DIFFERENT')
