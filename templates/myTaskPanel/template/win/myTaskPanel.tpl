#TEMPLATE(myTaskPanel,'myTaskPanel - task panels, Clarion or DirectX - v1.0'),FAMILY('ABC')
#!-----------------------------------------------------------------------------
#!  myTaskPanel  -  task panels for Clarion windows and MDI frames.
#!
#!  The column of collapsible groups down the side of a window - Catalogs,
#!  Reports, Exports, Help - each a card of clickable items, with submenus
#!  (and submenus of submenus) opened in place or as pop-up menus. Docked on
#!  the left or the right, or floating; the user can drag it between the
#!  three, resize it, and hide it.
#!
#!  THE TEMPLATES
#!    myTaskPanelGlobal (APPLICATION) - the engine, the look, the language.
#!                     Add once.
#!    myTaskPanel       (EXTENSION)   - a task panel on this window or frame.
#!                     Groups and items, presets that fill in a whole group
#!                     at a time (then delete or change what you do not
#!                     want), and a copy of the window's own menu.
#!
#!  TWO ENGINES, chosen on the global extension:
#!    Clarion  - all Clarion source, painting with the Windows API (GDI).
#!    DirectX  - Direct2D + DirectWrite (antialiased, ClearType). mtpd2d.c is
#!               compiled into the program by Clarion's own C compiler; the
#!               global extension adds the _MTP_D2D_ define that switches it
#!               on. Nothing to ship either way.
#!
#!  REQUIRED FILES (in the zip), on the redirection path:
#!      MyTaskPanel.inc   MyTaskPanel.clw   mtpd2d.c
#!-----------------------------------------------------------------------------
#!
#!=============================================================================
#!  shared groups
#!=============================================================================
#!  The tag a generated item carries: the developer's, or g<group>i<item>.
#GROUP(%mtpTagOf)
#IF(%mtpItemTag <> '')
  #RETURN(%mtpItemTag)
#ENDIF
#RETURN('g' & INSTANCE(%mtpGroups) & 'i' & INSTANCE(%mtpItems))
#!
#!  The procedure that opens a form to insert, on its own thread: an MDI form
#!  cannot open on the frame's thread, and GlobalRequest is THREADed, so the
#!  request has to be set on the new thread - by this little procedure.
#GROUP(%mtpInsName)
#RETURN(%mtpObject & 'Insert' & INSTANCE(%mtpGroups) & '_' & INSTANCE(%mtpItems))
#GROUP(%mtpBtnInsName)
#RETURN(%mtpObject & 'Insert' & INSTANCE(%mtpGroups) & '_' & INSTANCE(%mtpItems) & '_' & INSTANCE(%mtpBtns))
#!
#!  The tag a hover button carries: the developer's, or the item's + b<n>.
#GROUP(%mtpBtnTagOf)
#IF(%mtpBtnTag <> '')
  #RETURN(%mtpBtnTag)
#ENDIF
#RETURN(%mtpTagOf() & 'b' & INSTANCE(%mtpBtns))
#!
#!  A menu caption without its & accelerators and quotes.
#GROUP(%mtpClean,%pIn),AUTO
#DECLARE(%mtpCIn)
#DECLARE(%mtpCOut)
#DECLARE(%mtpCi)
#DECLARE(%mtpCc)
#SET(%mtpCIn,%pIn)
#IF(SUB(%mtpCIn,1,1) = '''')
  #SET(%mtpCIn,SUB(%mtpCIn,2,LEN(%mtpCIn) - 2))
#ENDIF
#SET(%mtpCOut,'')
#SET(%mtpCi,1)
#LOOP,WHILE(%mtpCi <= LEN(%mtpCIn))
  #SET(%mtpCc,SUB(%mtpCIn,%mtpCi,1))
  #IF(%mtpCc = '&')
    #IF(SUB(%mtpCIn,%mtpCi + 1,1) = '&')
      #SET(%mtpCOut,%mtpCOut & '&')
      #SET(%mtpCi,%mtpCi + 1)
    #ENDIF
  #ELSIF(%mtpCc = '''' AND SUB(%mtpCIn,%mtpCi + 1,1) = '''')
    #SET(%mtpCOut,%mtpCOut & '''')
    #SET(%mtpCi,%mtpCi + 1)
  #ELSE
    #SET(%mtpCOut,%mtpCOut & %mtpCc)
  #ENDIF
  #SET(%mtpCi,%mtpCi + 1)
#ENDLOOP
#RETURN(%mtpCOut)
#!
#!-----------------------------------------------------------------------------
#!  Putting rows into the Groups / Items lists (presets and the menu import).
#!  Anything not set reads as "off" to the generator.
#!-----------------------------------------------------------------------------
#GROUP(%mtpPutGroup,%pText,%pGlyph,%pSpecial),AUTO
  #ADD(%mtpGroups,ITEMS(%mtpGroups) + 1)
  #SET(%mtpGroupText,%pText)
  #SET(%mtpGroupGlyph,%pGlyph)
  #SET(%mtpGroupOpen,1)
  #SET(%mtpGroupSpecial,%pSpecial)
  #SET(%mtpGroupHidden,0)
#!
#GROUP(%mtpPutItem,%pText,%pLevel,%pGlyph,%pAction),AUTO
  #ADD(%mtpItems,ITEMS(%mtpItems) + 1)
  #SET(%mtpItemKind,'Item')
  #SET(%mtpItemText,%pText)
  #SET(%mtpItemLevel,%pLevel)
  #SET(%mtpItemGlyph,%pGlyph)
  #SET(%mtpItemAction,%pAction)
  #SET(%mtpItemStack,25000)
  #SET(%mtpItemOpen,0)
#!
#!  English / Spanish pair, picked by the global language. (Tested inline:
#!  a group "function" returns the string '0', which #IF reads as true.)
#GROUP(%mtpPI,%pEn,%pEs,%pLevel,%pGlyph,%pAction),AUTO
  #DECLARE(%mtpT)
  #SET(%mtpT,%pEn)
  #IF(VAREXISTS(%mtpgLanguage))
    #IF(%mtpgLanguage = 'Spanish')
      #SET(%mtpT,%pEs)
    #ENDIF
  #ENDIF
  #INSERT(%mtpPutItem,%mtpT,%pLevel,%pGlyph,%pAction)
#!
#GROUP(%mtpPG,%pEn,%pEs,%pGlyph,%pSpecial),AUTO
  #DECLARE(%mtpT)
  #SET(%mtpT,%pEn)
  #IF(VAREXISTS(%mtpgLanguage))
    #IF(%mtpgLanguage = 'Spanish')
      #SET(%mtpT,%pEs)
    #ENDIF
  #ENDIF
  #INSERT(%mtpPutGroup,%mtpT,%pGlyph,%pSpecial)
#!
#GROUP(%mtpPutSep,%pLevel),AUTO
  #INSERT(%mtpPutItem,'',%pLevel,'none','Embed code only')
  #SET(%mtpItemKind,'Separator')
#!
#!-----------------------------------------------------------------------------
#!  The presets. Each one adds a NEW group, already filled in. Rename,
#!  reorder or delete anything; fill in the procedures and the embeds.
#!-----------------------------------------------------------------------------
#GROUP(%mtpAddPreset),AUTO
#DECLARE(%mtpPx)
#DECLARE(%mtpPn)
#CASE(%mtpPreset)
#OF('Catalogs')
  #INSERT(%mtpPG,'Catalogs','Cat<225>logos','table',1)
  #INSERT(%mtpPI,'Customers','Clientes',0,'user','Start a procedure')
  #INSERT(%mtpPI,'Suppliers','Proveedores',0,'truck','Start a procedure')
  #INSERT(%mtpPI,'Products','Productos',0,'box','Start a procedure')
  #INSERT(%mtpPI,'Categories','Categor<237>as',0,'table','Start a procedure')
  #INSERT(%mtpPI,'Employees','Empleados',0,'users','Start a procedure')
  #INSERT(%mtpPI,'Geography','Geograf<237>a',0,'globe','Embed code only')
  #INSERT(%mtpPI,'Countries','Pa<237>ses',1,'none','Start a procedure')
  #INSERT(%mtpPI,'States','Estados',1,'none','Start a procedure')
  #INSERT(%mtpPI,'Cities','Ciudades',1,'none','Start a procedure')
#OF('Operations')
  #INSERT(%mtpPG,'Operations','Operaciones','cart',0)
  #INSERT(%mtpPI,'New invoice','Nueva factura',0,'plus','Start a procedure')
  #INSERT(%mtpPI,'Invoices','Facturas',0,'money','Start a procedure')
  #INSERT(%mtpPI,'Orders','Pedidos',0,'cart','Start a procedure')
  #INSERT(%mtpPI,'Payments','Pagos',0,'money','Start a procedure')
  #INSERT(%mtpPI,'Purchases','Compras',0,'truck','Start a procedure')
  #INSERT(%mtpPI,'Inventory movements','Movimientos de inventario',0,'box','Start a procedure')
#OF('Reports')
  #INSERT(%mtpPG,'Reports','Informes','report',0)
  #INSERT(%mtpPI,'Sales by month','Ventas por mes',0,'chart','Start a procedure')
  #INSERT(%mtpPI,'Customer list','Lista de clientes',0,'doc','Start a procedure')
  #INSERT(%mtpPI,'Inventory','Inventario',0,'doc','Start a procedure')
  #INSERT(%mtpPI,'Financial','Financieros',0,'money','Embed code only')
  #INSERT(%mtpPI,'Balance sheet','Balance general',1,'none','Start a procedure')
  #INSERT(%mtpPI,'Income statement','Estado de resultados',1,'none','Start a procedure')
  #INSERT(%mtpPI,'Cash flow','Flujo de efectivo',1,'none','Start a procedure')
#OF('Exports')
  #INSERT(%mtpPG,'Exports','Exportar','export',0)
  #INSERT(%mtpPI,'Excel (.xlsx)','Excel (.xlsx)',0,'excel','Embed code only')
  #INSERT(%mtpPI,'CSV','CSV',0,'csv','Embed code only')
  #INSERT(%mtpPI,'PDF','PDF',0,'pdf','Embed code only')
  #INSERT(%mtpPI,'HTML','HTML',0,'html','Embed code only')
  #INSERT(%mtpPutSep,0)
  #INSERT(%mtpPI,'XML','XML',0,'xml','Embed code only')
  #INSERT(%mtpPI,'JSON','JSON',0,'json','Embed code only')
  #INSERT(%mtpPI,'Text','Texto',0,'txt','Embed code only')
#OF('Tools and utilities')
  #INSERT(%mtpPG,'Tools','Herramientas','tools',0)
  #INSERT(%mtpPI,'Back up the data','Respaldar los datos',0,'backup','Embed code only')
  #INSERT(%mtpPI,'Restore a backup','Restaurar un respaldo',0,'restore','Embed code only')
  #INSERT(%mtpPI,'Import data','Importar datos',0,'import','Embed code only')
  #INSERT(%mtpPI,'Rebuild indexes','Reconstruir <237>ndices',0,'refresh','Embed code only')
  #INSERT(%mtpPutSep,0)
  #INSERT(%mtpPI,'Options','Opciones',0,'gear','Start a procedure')
#OF('Window')
  #INSERT(%mtpPG,'Window','Ventana','window',0)
  #INSERT(%mtpPI,'Tile side by side','Mosaico vertical',0,'tile','Window command')
  #SET(%mtpItemWinCmd,'Tile vertically')
  #INSERT(%mtpPI,'Tile stacked','Mosaico horizontal',0,'tile','Window command')
  #SET(%mtpItemWinCmd,'Tile horizontally')
  #INSERT(%mtpPI,'Cascade','Cascada',0,'cascade','Window command')
  #SET(%mtpItemWinCmd,'Cascade')
  #INSERT(%mtpPI,'Arrange icons','Organizar iconos',0,'window','Window command')
  #SET(%mtpItemWinCmd,'Arrange icons')
#OF('Help')
  #INSERT(%mtpPG,'Help','Ayuda','help',0)
  #INSERT(%mtpPI,'Contents','Contenido',0,'book','Embed code only')
  #INSERT(%mtpPI,'Search the help','Buscar en la ayuda',0,'search','Embed code only')
  #INSERT(%mtpPI,'What''s new','Novedades',0,'star','Open a URL or file')
  #SET(%mtpItemUrl,'https://www.example.com/whatsnew')
  #INSERT(%mtpPI,'Check for updates','Buscar actualizaciones',0,'refresh','Open a URL or file')
  #SET(%mtpItemUrl,'https://www.example.com/download')
  #INSERT(%mtpPutSep,0)
  #INSERT(%mtpPI,'Website','Sitio web',0,'globe','Open a URL or file')
  #SET(%mtpItemUrl,'https://www.example.com')
  #INSERT(%mtpPI,'Email support','Escribir a soporte',0,'mail','Open a URL or file')
  #SET(%mtpItemUrl,'mailto:support@example.com')
  #INSERT(%mtpPI,'About...','Acerca de...',0,'info','Start a procedure')
#OF('Quick links')
  #INSERT(%mtpPG,'Quick links','Accesos r<225>pidos','link',0)
  #INSERT(%mtpPI,'Home page','P<225>gina principal',0,'home','Open a URL or file')
  #SET(%mtpItemUrl,'https://www.example.com')
  #INSERT(%mtpPI,'Documentation','Documentaci<243>n',0,'book','Open a URL or file')
  #SET(%mtpItemUrl,'https://www.example.com/docs')
  #INSERT(%mtpPI,'Calendar','Calendario',0,'calendar','Embed code only')
#OF('Settings and security')
  #INSERT(%mtpPG,'Settings','Configuraci<243>n','gear',0)
  #INSERT(%mtpPI,'Options','Opciones',0,'gear','Start a procedure')
  #INSERT(%mtpPI,'Users','Usuarios',0,'users','Start a procedure')
  #INSERT(%mtpPI,'Change password','Cambiar la contrase<241>a',0,'key','Start a procedure')
  #INSERT(%mtpPI,'Lock','Bloquear',0,'lock','Embed code only')
  #INSERT(%mtpPutSep,0)
  #INSERT(%mtpPI,'Log out','Cerrar sesi<243>n',0,'exit','Close the window')
#OF('Catalogs from this application''s browses')
  #INSERT(%mtpAddFromProcedures,'Browse')
#OF('Reports from this application''s reports')
  #INSERT(%mtpAddFromProcedures,'Report')
#OF('This window''s menu, as editable groups')
  #INSERT(%mtpImportMenu)
#ENDCASE
#!
#!  A group with one item per procedure of a kind. The names are collected
#!  first and the rows added afterwards, so the walk over %Procedure never
#!  overlaps the edits to this procedure's own lists.
#GROUP(%mtpAddFromProcedures,%pKind),AUTO
#DECLARE(%mtpProcList),MULTI
#DECLARE(%mtpProcText,%mtpProcList)
#DECLARE(%mtpOne)
#DECLARE(%mtpHit)
#FOR(%Procedure)
  #SET(%mtpHit,0)
  #IF(%pKind = 'Browse')
    #IF(UPPER(SUB(%Procedure,1,6)) = 'BROWSE')
      #SET(%mtpHit,1)
    #ENDIF
    #IF(INSTRING('BROWSE',UPPER(%ProcedureDescription),1,1))
      #SET(%mtpHit,1)
    #ENDIF
  #ELSE
    #IF(INSTRING('REPORT',UPPER(%ProcedureTemplate),1,1))
      #SET(%mtpHit,1)
    #ENDIF
    #IF(UPPER(SUB(%Procedure,1,5)) = 'PRINT')
      #SET(%mtpHit,1)
    #ENDIF
    #IF(UPPER(SUB(%Procedure,1,6)) = 'REPORT')
      #SET(%mtpHit,1)
    #ENDIF
    #IF(INSTRING('REPORT',UPPER(%ProcedureDescription),1,1))
      #SET(%mtpHit,1)
    #ENDIF
  #ENDIF
  #IF(%mtpHit)
    #ADD(%mtpProcList,%Procedure)
    #IF(%ProcedureDescription <> '')
      #SET(%mtpProcText,%ProcedureDescription)
    #ELSE
      #SET(%mtpProcText,%Procedure)
    #ENDIF
  #ENDIF
#ENDFOR
#IF(%pKind = 'Browse')
  #INSERT(%mtpPG,'Catalogs','Cat<225>logos','table',1)
#ELSE
  #INSERT(%mtpPG,'Reports','Informes','report',0)
#ENDIF
#FOR(%mtpProcList)
  #SET(%mtpOne,%mtpProcList)
  #INSERT(%mtpPutItem,%mtpProcText,0,'auto','Start a procedure')
  #SET(%mtpItemProc,%mtpOne)
#ENDFOR
#!
#!  The window's MENUBAR, copied into editable groups now (at design time).
#!  Each top MENU becomes a group; nested MENUs become items with children;
#!  every ITEM "presses" the original, so the menu's own action and embeds
#!  keep working. Prefer the run-time copy (Menu tab) if the menu changes.
#GROUP(%mtpImportMenu),AUTO
#DECLARE(%mtpBase)
#DECLARE(%mtpLvl)
#DECLARE(%mtpTxt)
#DECLARE(%mtpStmt)
#DECLARE(%mtpOpen)
#SET(%mtpBase,-1)
#SET(%mtpOpen,0)
#FOR(%Control),WHERE(%ControlType = 'MENU' OR %ControlType = 'ITEM')
  #SET(%mtpStmt,%ControlStatement)
  #IF(%mtpBase = -1 AND %ControlType = 'MENU')
    #SET(%mtpBase,%ControlIndent)
  #ENDIF
  #IF(%mtpBase = -1)
    #CYCLE
  #ENDIF
  #IF(%ControlType = 'MENU' AND %ControlIndent <= %mtpBase)
    #SET(%mtpTxt,%mtpClean(EXTRACT(%mtpStmt,'MENU',1)))
    #INSERT(%mtpPutGroup,%mtpTxt,'auto',0)
    #SET(%mtpOpen,1)
    #CYCLE
  #ENDIF
  #IF(%mtpOpen = 0)
    #CYCLE
  #ENDIF
  #SET(%mtpLvl,%ControlIndent - %mtpBase - 1)
  #IF(%mtpLvl < 0)
    #SET(%mtpLvl,0)
  #ENDIF
  #IF(%ControlType = 'MENU')
    #SET(%mtpTxt,%mtpClean(EXTRACT(%mtpStmt,'MENU',1)))
    #INSERT(%mtpPutItem,%mtpTxt,%mtpLvl,'auto','Embed code only')
  #ELSIF(INSTRING('SEPARATOR',UPPER(%mtpStmt),1,1) OR EXTRACT(%mtpStmt,'ITEM',1) = '')
    #INSERT(%mtpPutSep,%mtpLvl)
  #ELSE
    #SET(%mtpTxt,%mtpClean(EXTRACT(%mtpStmt,'ITEM',1)))
    #INSERT(%mtpPutItem,%mtpTxt,%mtpLvl,'auto','Press a control or menu item')
    #SET(%mtpItemControl,%Control)
  #ENDIF
#ENDFOR
#!
#!#############################################################################
#!  GLOBAL EXTENSION
#!#############################################################################
#EXTENSION(myTaskPanelGlobal,'myTaskPanel - Global settings (add once per application)'),APPLICATION
#SHEET
  #TAB('&General')
    #DISPLAY('myTaskPanel 1.0 - add the myTaskPanel extension to the frame')
    #DISPLAY('or to any window to put a task panel on it.')
    #PROMPT('&Disable this template',CHECK),%mtpgDisable,DEFAULT(0),AT(10)
    #BOXED('Engine')
      #PROMPT('&Draw the panels with:',DROP('Clarion (full source, GDI)|DirectX (Direct2D and DirectWrite)')),%mtpgEngine,DEFAULT('Clarion (full source, GDI)')
      #DISPLAY('DirectX compiles mtpd2d.c into the program (no DLL) and')
      #DISPLAY('falls back to the Clarion engine if Direct2D will not start.')
      #ENABLE(SUB(%mtpgEngine,1,7) = 'DirectX')
        #PROMPT('DirectX &effects: shadows, glass, fading hover',CHECK),%mtpgEffects,DEFAULT(1),AT(10)
        #ENABLE(%mtpgEffects)
          #PROMPT('Floating panel &opacity when idle (%):',SPIN(@n3,30,100,1)),%mtpgFloatOpacity,DEFAULT(88)
        #ENDENABLE
      #ENDENABLE
      #PROMPT('Show which engine is &painting (a badge, for testing)',CHECK),%mtpgShowEngine,DEFAULT(0),AT(10)
    #ENDBOXED
  #ENDTAB
  #TAB('&Look')
    #BOXED('Colours')
      #PROMPT('&Theme:',DROP('Slate|Navy|Graphite (dark)|Teal|Light|Forest|High contrast|Low contrast|Ocean|Crimson|Amber|Copper|Sky|Mint|Steel|Sand|Midnight (dark)|Olive')),%mtpgTheme,DEFAULT('Slate')
      #PROMPT('Use my own &accent colour',CHECK),%mtpgUseAccent,DEFAULT(0)
      #ENABLE(%mtpgUseAccent)
        #PROMPT('Accent &colour:',COLOR),%mtpgAccent,DEFAULT(0C47015H)
      #ENDENABLE
    #ENDBOXED
    #BOXED('Text and size')
      #PROMPT('&Font:',@s40),%mtpgFont,DEFAULT('Segoe UI')
      #PROMPT('Font &size:',SPIN(@n2,7,16,1)),%mtpgFontSize,DEFAULT(9)
      #PROMPT('&Item height (pixels):',SPIN(@n2,16,48,1)),%mtpgItemH,DEFAULT(24)
      #PROMPT('&Header height (pixels):',SPIN(@n2,20,60,1)),%mtpgHeadH,DEFAULT(30)
      #PROMPT('Corner &radius (pixels):',SPIN(@n2,0,16,1)),%mtpgRadius,DEFAULT(6)
      #PROMPT('A&nimate groups opening and closing',CHECK),%mtpgAnimate,DEFAULT(1)
    #ENDBOXED
  #ENDTAB
  #TAB('&Behaviour')
    #BOXED('Language')
      #PROMPT('&Language:',DROP('English|Spanish')),%mtpgLanguage,DEFAULT('English')
      #DISPLAY('The panel''s own menu, and the captions presets fill in.')
    #ENDBOXED
    #BOXED('Remember the layout')
      #PROMPT('&Remember where each panel was and which groups were open',CHECK),%mtpgRemember,DEFAULT(1)
      #ENABLE(%mtpgRemember)
        #PROMPT('&INI file:',@s200),%mtpgIniFile,DEFAULT('TaskPanel.ini')
        #DISPLAY('One section per procedure.')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Multi-DLL')
    #BOXED('Where MyTaskPanelClass lives')
      #DISPLAY('Out of the box this follows the application''s External')
      #DISPLAY('setting: the app that owns the data compiles the class in')
      #DISPLAY('and exports it; the others import it. Add this extension')
      #DISPLAY('to every app in the suite, with the same engine.')
    #ENDBOXED
    #BOXED('Override - place the class by hand')
      #INSERT(%AbcLibraryPrompts(ABC))
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#AT(%AfterGlobalIncludes),WHERE(%mtpgDisable = 0)
INCLUDE('MyTaskPanel.INC'),ONCE
#ENDAT
#!
#AT(%CustomGlobalDeclarations),WHERE(%mtpgDisable = 0 AND SUB(%mtpgEngine,1,7) = 'DirectX')
  #PDEFINE('_MTP_D2D_',1)
#ENDAT
#!
#AT(%BeforeGenerateApplication),WHERE(%mtpgDisable = 0)
  #CALL(%AddCategory(ABC),'MYTASKPANEL')
  #CALL(%SetCategoryLocationFromPrompts(ABC),'MYTASKPANEL','MyTaskPanel','')
#ENDAT
#!
#!#############################################################################
#!  PROCEDURE EXTENSION - a task panel on this window
#!#############################################################################
#EXTENSION(myTaskPanel,'myTaskPanel - a task panel on this window or frame'),PROCEDURE,WINDOW
#SHEET,HSCROLL
  #TAB('&General')
    #PROMPT('&Disable',CHECK),%mtpDisable,DEFAULT(0),AT(10)
    #PROMPT('&Object name:',@s40),%mtpObject,DEFAULT('TaskPanel'),REQ
    #PROMPT('&Title:',@s80),%mtpTitle,DEFAULT('Tasks')
    #BOXED('Where it goes')
      #PROMPT('&Starts:',DROP('Docked on the left|Docked on the right|Floating')),%mtpDock,DEFAULT('Docked on the left')
      #PROMPT('&Width (pixels):',SPIN(@n3,120,600,10)),%mtpWidth,DEFAULT(230)
      #PROMPT('Starts &hidden',CHECK),%mtpHidden,DEFAULT(0)
      #PROMPT('&Grow the window by the panel''s width (not on a frame)',CHECK),%mtpGrow,DEFAULT(1)
    #ENDBOXED
    #PROMPT('A &search box under the title',CHECK),%mtpSearch,DEFAULT(1),AT(10)
  #ENDTAB
  #TAB('&User')
    #BOXED('What the user may do')
      #PROMPT('&Float it (drag the title away)',CHECK),%mtpAllowFloat,DEFAULT(1)
      #PROMPT('Doc&k it on either side',CHECK),%mtpAllowDock,DEFAULT(1)
      #PROMPT('&Close it (the X)',CHECK),%mtpAllowClose,DEFAULT(1)
      #PROMPT('&Resize it (drag the inner edge)',CHECK),%mtpAllowResize,DEFAULT(1)
      #PROMPT('Show / hide it with &key:',@s20),%mtpToggleKey,DEFAULT('')
      #DISPLAY('A Clarion key code such as F12Key. Blank: none.')
      #PROMPT('Move the &keyboard into it with:',@s20),%mtpFocusKey,DEFAULT('F6Key')
      #DISPLAY('Then arrows, Enter, typing searches, Esc goes back.')
    #ENDBOXED
  #ENDTAB
  #TAB('G&roups')
    #DISPLAY('Level 0 items sit in the group; level 1 is the submenu of the')
    #DISPLAY('item above, and so on. Presets fill in a whole group.')
    #BUTTON('&Groups'),MULTI(%mtpGroups,%mtpGroupText & '   (' & ITEMS(%mtpItems) & ' items)'),INLINE
      #PROMPT('&Caption:',@s60),%mtpGroupText,REQ
      #PROMPT('&Icon:',DROP('none|auto|folder|table|user|users|box|doc|report|chart|export|import|excel|csv|pdf|html|xml|json|txt|print|mail|help|info|book|globe|gear|tools|backup|restore|key|lock|exit|home|star|window|tile|cascade|calendar|money|cart|truck|search|plus|link|menu|bell|phone')),%mtpGroupGlyph,DEFAULT('none')
      #PROMPT('Icon &file (instead):',OPENDIALOG('Pick an icon','Icons|*.ico')),%mtpGroupIcon,DEFAULT('')
      #PROMPT('Starts &open',CHECK),%mtpGroupOpen,DEFAULT(1)
      #PROMPT('&Accent header (stands out)',CHECK),%mtpGroupSpecial,DEFAULT(0)
      #PROMPT('Starts &hidden',CHECK),%mtpGroupHidden,DEFAULT(0)
      #PROMPT('Show only &when:',@s200),%mtpGroupShowIf,DEFAULT('')
      #BUTTON('&Items in this group'),MULTI(%mtpItems,SUB('. . . . . . . . . . . . ',1,%mtpItemLevel * 2) & CHOOSE(%mtpItemKind = 'Separator','------------',%mtpItemText) & CHOOSE(%mtpItemKind = 'Label','   (label)','')),INLINE
        #SHEET
          #TAB('&Item')
            #PROMPT('&Kind:',DROP('Item|Separator|Label|Info|Progress|Chart')),%mtpItemKind,DEFAULT('Item')
            #PROMPT('&Text:',@s80),%mtpItemText
            #ENABLE(%mtpItemKind = 'Info' OR %mtpItemKind = 'Progress' OR %mtpItemKind = 'Chart')
              #PROMPT('&Value (expression):',@s200),%mtpItemValue,DEFAULT('')
              #DISPLAY('Info: text. Progress: 0-100. Chart: ''12,15,9''.')
            #ENDENABLE
            #ENABLE(%mtpItemKind = 'Chart')
              #PROMPT('C&hart:',DROP('Bars|Line')),%mtpItemChart,DEFAULT('Bars')
            #ENDENABLE
            #PROMPT('&Level:',SPIN(@n1,0,6,1)),%mtpItemLevel,DEFAULT(0)
            #DISPLAY('0 = in the group, 1 = in the submenu of the item above')
            #PROMPT('&Icon:',DROP('none|auto|folder|table|user|users|box|doc|report|chart|export|import|excel|csv|pdf|html|xml|json|txt|print|mail|help|info|book|globe|gear|tools|backup|restore|key|lock|exit|home|star|window|tile|cascade|calendar|money|cart|truck|search|plus|link|menu|bell|phone')),%mtpItemGlyph,DEFAULT('none')
            #PROMPT('Icon &file (instead):',OPENDIALOG('Pick an icon','Icons|*.ico')),%mtpItemIcon,DEFAULT('')
            #PROMPT('&Shortcut text (shown on the right):',@s30),%mtpItemShortcut,DEFAULT('')
            #PROMPT('T&ag (blank = automatic):',@s40),%mtpItemTag,DEFAULT('')
          #ENDTAB
          #TAB('&Action')
            #PROMPT('When &clicked:',DROP('Start a procedure|Call a procedure|Insert a record (a form)|Press a control or menu item|Post an event|Open a URL or file|Run a program|Window command|Close the window|Embed code only')),%mtpItemAction,DEFAULT('Embed code only')
            #ENABLE(%mtpItemAction = 'Start a procedure' OR %mtpItemAction = 'Call a procedure' OR %mtpItemAction = 'Insert a record (a form)')
              #PROMPT('&Procedure:',PROCEDURE),%mtpItemProc
            #ENDENABLE
            #ENABLE(%mtpItemAction = 'Start a procedure' OR %mtpItemAction = 'Insert a record (a form)')
              #PROMPT('&Stack size:',SPIN(@n6,5000,500000,5000)),%mtpItemStack,DEFAULT(25000)
            #ENDENABLE
            #ENABLE(%mtpItemAction = 'Call a procedure')
              #PROMPT('Pa&rameters:',@s128),%mtpItemParms,DEFAULT('')
            #ENDENABLE
            #ENABLE(%mtpItemAction = 'Press a control or menu item')
              #PROMPT('C&ontrol:',CONTROL),%mtpItemControl
              #DISPLAY('Posts EVENT:Accepted to it, so its own code runs.')
            #ENDENABLE
            #ENABLE(%mtpItemAction = 'Post an event')
              #PROMPT('&Event:',@s40),%mtpItemEvent,DEFAULT('EVENT:User')
            #ENDENABLE
            #ENABLE(%mtpItemAction = 'Open a URL or file' OR %mtpItemAction = 'Run a program')
              #PROMPT('&URL, file or program:',@s255),%mtpItemUrl,DEFAULT('')
            #ENDENABLE
            #ENABLE(%mtpItemAction = 'Window command')
              #PROMPT('&Window command:',DROP('Tile vertically|Tile horizontally|Cascade|Arrange icons')),%mtpItemWinCmd,DEFAULT('Tile vertically')
            #ENDENABLE
            #DISPLAY('')
            #DISPLAY('Every item also gets its own embed point, after the action.')
          #ENDTAB
          #TAB('&State')
            #PROMPT('Its submenu starts &open',CHECK),%mtpItemOpen,DEFAULT(0)
            #PROMPT('Starts &disabled',CHECK),%mtpItemDisabled,DEFAULT(0)
            #PROMPT('Starts &hidden',CHECK),%mtpItemHidden,DEFAULT(0)
            #PROMPT('&Bold',CHECK),%mtpItemBold,DEFAULT(0)
            #BOXED('Conditions (Clarion expressions; blank = always)')
              #PROMPT('Show only &when:',@s200),%mtpItemShowIf,DEFAULT('')
              #PROMPT('&Enable only when:',@s200),%mtpItemEnableIf,DEFAULT('')
              #DISPLAY('Checked when the window opens, and again each time')
              #DISPLAY('the mouse enters the panel or the panel takes the keyboard.')
            #ENDBOXED
          #ENDTAB
          #TAB('E&xtras')
            #PROMPT('&Tooltip (a description):',@s255),%mtpItemTip,DEFAULT('')
            #DISPLAY('Shown in a card beside the panel after a pause.')
            #PROMPT('Accept &files dropped on it',CHECK),%mtpItemDrop,DEFAULT(0)
            #DISPLAY('Its own embed point gets DropFiles / DropCount.')
            #BUTTON('&Hover buttons'),MULTI(%mtpBtns,%mtpBtnGlyph & '   ' & %mtpBtnTip),INLINE
              #PROMPT('&Icon:',DROP('plus|print|mail|export|import|excel|pdf|search|gear|tools|doc|report|chart|link|star|bell|phone|lock|key|refresh|calendar|user|users|box|cart|truck|money|globe|help|info')),%mtpBtnGlyph,DEFAULT('plus')
              #PROMPT('Ti&p:',@s80),%mtpBtnTip,DEFAULT('')
              #PROMPT('T&ag (blank = automatic):',@s40),%mtpBtnTag,DEFAULT('')
              #PROMPT('When &clicked:',DROP('Insert a record (a form)|Start a procedure|Call a procedure|Post an event|Embed code only')),%mtpBtnAction,DEFAULT('Embed code only')
              #DISPLAY('Insert a record: the update form opens to add one,')
              #DISPLAY('on its own thread (so an MDI form works too).')
              #ENABLE(%mtpBtnAction = 'Start a procedure' OR %mtpBtnAction = 'Call a procedure' OR %mtpBtnAction = 'Insert a record (a form)')
                #PROMPT('P&rocedure:',PROCEDURE),%mtpBtnProc
              #ENDENABLE
              #ENABLE(%mtpBtnAction = 'Post an event')
                #PROMPT('&Event:',@s40),%mtpBtnEvent,DEFAULT('EVENT:User')
              #ENDENABLE
            #ENDBUTTON
          #ENDTAB
        #ENDSHEET
      #ENDBUTTON
    #ENDBUTTON
  #ENDTAB
  #TAB('&Presets')
    #BOXED('Add a ready-made group')
      #DISPLAY('A NEW group appears on the Groups tab, filled in. Rename,')
      #DISPLAY('reorder or delete anything; point items at your procedures.')
      #PROMPT('&Preset:',DROP('Catalogs|Operations|Reports|Exports|Tools and utilities|Window|Help|Quick links|Settings and security|Catalogs from this application''s browses|Reports from this application''s reports|This window''s menu, as editable groups')),%mtpPreset,DEFAULT('Catalogs')
      #BUTTON('&Add this group'),WHENACCEPTED(%mtpAddPreset()),AT(,,120)
      #ENDBUTTON
    #ENDBOXED
  #ENDTAB
  #TAB('&Menu')
    #BOXED('Copy this window''s menu when it opens')
      #PROMPT('&Copy the menu into the panel at run time',CHECK),%mtpMirror,DEFAULT(0)
      #ENABLE(%mtpMirror)
        #PROMPT('&Arrange it as:',DROP('One group per menu|One group called Menu')),%mtpMirrorMode,DEFAULT('One group per menu')
        #PROMPT('&Put it:',DROP('After my groups|Before my groups')),%mtpMirrorWhere,DEFAULT('After my groups')
        #PROMPT('&Skip menus named:',@s200),%mtpMirrorSkip,DEFAULT('Window')
        #DISPLAY('Separate names with a bar: Window|Help')
        #PROMPT('&Take the real menu off the window',CHECK),%mtpMirrorHide,DEFAULT(0)
        #DISPLAY('Copied rows press the original menu items.')
      #ENDENABLE
    #ENDBOXED
  #ENDTAB
  #TAB('&Options')
    #BOXED('Behaviour')
      #PROMPT('&Submenus:',DROP('Open in place|Pop-up menu')),%mtpSubStyle,DEFAULT('Open in place')
      #PROMPT('Only one group open at a time (&accordion)',CHECK),%mtpAccordion,DEFAULT(0)
      #PROMPT('Show &shortcut text',CHECK),%mtpShortcuts,DEFAULT(1)
      #PROMPT('&Favourites (right-click an item to add it)',CHECK),%mtpFavorites,DEFAULT(1)
      #PROMPT('&Recent items kept (0 = none):',SPIN(@n2,0,20,1)),%mtpRecent,DEFAULT(5)
      #PROMPT('&Most used kept (0 = none):',SPIN(@n2,0,20,1)),%mtpMost,DEFAULT(5)
      #PROMPT('Description &cards (item tooltips)',CHECK),%mtpTips,DEFAULT(1)
      #PROMPT('Start collapsed to &icons (the rail)',CHECK),%mtpRail,DEFAULT(0)
      #PROMPT('Auto-&hide: tuck it into the edge',CHECK),%mtpAutoHide,DEFAULT(0)
    #ENDBOXED
    #BOXED('Look')
      #PROMPT('&Theme:',DROP('Global setting|Slate|Navy|Graphite (dark)|Teal|Light|Forest|High contrast|Low contrast|Ocean|Crimson|Amber|Copper|Sky|Mint|Steel|Sand|Midnight (dark)|Olive')),%mtpTheme,DEFAULT('Global setting')
    #ENDBOXED
  #ENDTAB
#ENDSHEET
#!
#ATSTART
  #DECLARE(%mtpOn)
  #SET(%mtpOn,0)
  #DECLARE(%mtpAnyDrop)
  #SET(%mtpAnyDrop,0)
  #DECLARE(%mtpAnyInsert)
  #SET(%mtpAnyInsert,0)
  #FOR(%mtpGroups)
    #FOR(%mtpItems),WHERE(%mtpItemKind = 'Item')
      #IF(%mtpItemAction = 'Insert a record (a form)' AND %mtpItemProc <> '')
        #SET(%mtpAnyInsert,1)
      #ENDIF
      #FOR(%mtpBtns),WHERE(%mtpBtnAction = 'Insert a record (a form)' AND %mtpBtnProc <> '')
        #SET(%mtpAnyInsert,1)
      #ENDFOR
    #ENDFOR
  #ENDFOR
  #FOR(%mtpGroups)
    #FOR(%mtpItems),WHERE(%mtpItemKind = 'Item' AND %mtpItemDrop)
      #SET(%mtpAnyDrop,1)
    #ENDFOR
  #ENDFOR
  #IF(%mtpDisable = 0)
    #SET(%mtpOn,1)
    #IF(VAREXISTS(%mtpgDisable))
      #IF(%mtpgDisable)
        #SET(%mtpOn,0)
      #ENDIF
    #ENDIF
  #ENDIF
  #DECLARE(%mtpEngineEq)
  #SET(%mtpEngineEq,'MTP:Clarion')
  #IF(VAREXISTS(%mtpgEngine))
    #IF(SUB(%mtpgEngine,1,7) = 'DirectX')
      #SET(%mtpEngineEq,'MTP:DirectX')
    #ENDIF
  #ENDIF
  #DECLARE(%mtpThemeName)
  #SET(%mtpThemeName,%mtpTheme)
  #IF(%mtpThemeName = 'Global setting' OR %mtpThemeName = '')
    #SET(%mtpThemeName,'Slate')
    #IF(VAREXISTS(%mtpgTheme))
      #SET(%mtpThemeName,%mtpgTheme)
    #ENDIF
  #ENDIF
  #DECLARE(%mtpThemeEq)
  #CASE(%mtpThemeName)
  #OF('Navy')
    #SET(%mtpThemeEq,'MTP:Navy')
  #OF('Graphite (dark)')
    #SET(%mtpThemeEq,'MTP:Graphite')
  #OF('Teal')
    #SET(%mtpThemeEq,'MTP:Teal')
  #OF('Light')
    #SET(%mtpThemeEq,'MTP:Light')
  #OF('Forest')
    #SET(%mtpThemeEq,'MTP:Forest')
  #OF('High contrast')
    #SET(%mtpThemeEq,'MTP:HighContrast')
  #OF('Low contrast')
    #SET(%mtpThemeEq,'MTP:LowContrast')
  #OF('Ocean')
    #SET(%mtpThemeEq,'MTP:Ocean')
  #OF('Crimson')
    #SET(%mtpThemeEq,'MTP:Crimson')
  #OF('Amber')
    #SET(%mtpThemeEq,'MTP:Amber')
  #OF('Copper')
    #SET(%mtpThemeEq,'MTP:Copper')
  #OF('Sky')
    #SET(%mtpThemeEq,'MTP:Sky')
  #OF('Mint')
    #SET(%mtpThemeEq,'MTP:Mint')
  #OF('Steel')
    #SET(%mtpThemeEq,'MTP:Steel')
  #OF('Sand')
    #SET(%mtpThemeEq,'MTP:Sand')
  #OF('Midnight (dark)')
    #SET(%mtpThemeEq,'MTP:Midnight')
  #OF('Olive')
    #SET(%mtpThemeEq,'MTP:Olive')
  #ELSE
    #SET(%mtpThemeEq,'MTP:Slate')
  #ENDCASE
  #DECLARE(%mtpParent)
  #DECLARE(%mtpLv)
  #DECLARE(%mtpMaxLv)
  #DECLARE(%mtpTagQ)
  #DECLARE(%mtpGlyphQ)
#!  Procedures named in the PROCEDURE prompts join the call tree (and the
#!  module's MAP) by themselves - nothing to add here.
#ENDAT
#!
#AT(%AfterGlobalIncludes),WHERE(%mtpDisable = 0)
INCLUDE('MyTaskPanel.INC'),ONCE
#ENDAT
#!
#AT(%DataSection),WHERE(%mtpOn AND %mtpAnyInsert)
  MAP                                                   ! myTaskPanel: the Insert a record actions
  #FOR(%mtpGroups)
    #FOR(%mtpItems),WHERE(%mtpItemKind = 'Item')
      #IF(%mtpItemAction = 'Insert a record (a form)' AND %mtpItemProc <> '')
%(%mtpInsName()) PROCEDURE
      #ENDIF
      #FOR(%mtpBtns),WHERE(%mtpBtnAction = 'Insert a record (a form)' AND %mtpBtnProc <> '')
%(%mtpBtnInsName()) PROCEDURE
      #ENDFOR
    #ENDFOR
  #ENDFOR
  END
#ENDAT
#!
#AT(%LocalProcedures),WHERE(%mtpOn AND %mtpAnyInsert)
  #FOR(%mtpGroups)
    #FOR(%mtpItems),WHERE(%mtpItemKind = 'Item')
      #IF(%mtpItemAction = 'Insert a record (a form)' AND %mtpItemProc <> '')
!-----------------------------------------------------------------------------
!  myTaskPanel: %mtpItemText - %mtpItemProc opens to insert a record, on
!  this new thread (an MDI form cannot open on the frame's thread, and
!  GlobalRequest belongs to the thread that sets it).
!-----------------------------------------------------------------------------
%(%mtpInsName()) PROCEDURE
  CODE
  GlobalRequest = InsertRecord
  %mtpItemProc()
      #ENDIF
      #FOR(%mtpBtns),WHERE(%mtpBtnAction = 'Insert a record (a form)' AND %mtpBtnProc <> '')
!-----------------------------------------------------------------------------
!  myTaskPanel: %mtpItemText, %mtpBtnGlyph button - %mtpBtnProc opens to insert
!  a record, on this new thread (see above).
!-----------------------------------------------------------------------------
%(%mtpBtnInsName()) PROCEDURE
  CODE
  GlobalRequest = InsertRecord
  %mtpBtnProc()
      #ENDFOR
    #ENDFOR
  #ENDFOR
#ENDAT
#!
#AT(%DataSection),WHERE(%mtpOn)
%mtpObject           MyTaskPanelClass                   ! myTaskPanel
%mtpObject:G         LONG                               ! myTaskPanel: the group being built
%mtpObject:L         LONG,DIM(8)                        ! myTaskPanel: the last item at each level
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'TakeEvent','(),BYTE'),PRIORITY(2000),WHERE(%mtpOn)
  CASE EVENT()
  OF EVENT:OpenWindow
    DO mtpBuild:%mtpObject                                ! myTaskPanel: build and show the panel
  OF MTP:Check                                            ! myTaskPanel: mouse in / keyboard in
    DO mtpCheck:%mtpObject
  OF MTP:Event                                            ! myTaskPanel: an item was clicked
    LOOP WHILE %mtpObject.NextClick()
      #EMBED(%mtpBeforeClick,'myTaskPanel - any item clicked, before its action')
      CASE %mtpObject.ClickTag
  #FOR(%mtpGroups)
    #FOR(%mtpItems),WHERE((%mtpItemKind = 'Item' OR ((%mtpItemKind = 'Info' OR %mtpItemKind = 'Progress' OR %mtpItemKind = 'Chart') AND %mtpItemAction <> 'Embed code only')) AND %mtpItemAction <> 'Press a control or menu item')
      OF '%(QUOTE(%mtpTagOf()))'                          ! %mtpGroupText / %mtpItemText
      #CASE(%mtpItemAction)
      #OF('Start a procedure')
        #IF(%mtpItemProc <> '')
        START(%mtpItemProc, %mtpItemStack)
        #ENDIF
      #OF('Insert a record (a form)')
        #IF(%mtpItemProc <> '')
        START(%(%mtpInsName()), %mtpItemStack)               ! %mtpItemProc, to insert
        #ENDIF
      #OF('Call a procedure')
        #IF(%mtpItemProc <> '')
        %mtpItemProc(%mtpItemParms)
        #ENDIF
      #OF('Post an event')
        #IF(%mtpItemEvent <> '')
        POST(%mtpItemEvent)
        #ENDIF
      #OF('Open a URL or file')
        #IF(%mtpItemUrl <> '')
        %mtpObject.OpenUrl('%(QUOTE(%mtpItemUrl))')
        #ENDIF
      #OF('Run a program')
        #IF(%mtpItemUrl <> '')
        RUN('%(QUOTE(%mtpItemUrl))')
        #ENDIF
      #OF('Window command')
        #CASE(%mtpItemWinCmd)
        #OF('Tile horizontally')
        %mtpObject.MdiCommand(MTP:TileH)
        #OF('Cascade')
        %mtpObject.MdiCommand(MTP:Cascade)
        #OF('Arrange icons')
        %mtpObject.MdiCommand(MTP:Arrange)
        #ELSE
        %mtpObject.MdiCommand(MTP:TileV)
        #ENDCASE
      #OF('Close the window')
        POST(EVENT:CloseWindow)
      #ENDCASE
        #EMBED(%mtpItemClicked,'myTaskPanel - item clicked'),%mtpGroups,%mtpItems,TREE('myTaskPanel|' & %mtpGroupText & '|' & %mtpItemText)
    #ENDFOR
  #ENDFOR
  #FOR(%mtpGroups)
    #FOR(%mtpItems),WHERE(%mtpItemKind = 'Item')
      #FOR(%mtpBtns)
      OF '%(QUOTE(%mtpBtnTagOf()))'                       ! %mtpItemText: %mtpBtnGlyph button
      #CASE(%mtpBtnAction)
      #OF('Insert a record (a form)')
        #IF(%mtpBtnProc <> '')
        START(%(%mtpBtnInsName()), 25000)                    ! %mtpBtnProc, to insert
        #ENDIF
      #OF('Start a procedure')
        #IF(%mtpBtnProc <> '')
        START(%mtpBtnProc, 25000)
        #ENDIF
      #OF('Call a procedure')
        #IF(%mtpBtnProc <> '')
        %mtpBtnProc()
        #ENDIF
      #OF('Post an event')
        #IF(%mtpBtnEvent <> '')
        POST(%mtpBtnEvent)
        #ENDIF
      #ENDCASE
        #EMBED(%mtpBtnClicked,'myTaskPanel - hover button clicked'),%mtpGroups,%mtpItems,%mtpBtns,TREE('myTaskPanel|' & %mtpGroupText & '|' & %mtpItemText & '|button ' & INSTANCE(%mtpBtns))
      #ENDFOR
    #ENDFOR
  #ENDFOR
      ELSE
        #EMBED(%mtpOtherClick,'myTaskPanel - an item added in code was clicked')
      END
    END
  OF MTP:Drop                                             ! myTaskPanel: files dropped on an item
    LOOP WHILE %mtpObject.NextDrop()
      #EMBED(%mtpBeforeDrop,'myTaskPanel - files dropped (DropTag, DropFiles, DropCount, DropFile(n))')
  #IF(%mtpAnyDrop)
      CASE %mtpObject.DropTag
    #FOR(%mtpGroups)
      #FOR(%mtpItems),WHERE(%mtpItemKind = 'Item' AND %mtpItemDrop)
      OF '%(QUOTE(%mtpTagOf()))'                          ! %mtpGroupText / %mtpItemText
        #EMBED(%mtpItemDropped,'myTaskPanel - files dropped on the item'),%mtpGroups,%mtpItems,TREE('myTaskPanel|' & %mtpGroupText & '|' & %mtpItemText & '|files dropped')
      #ENDFOR
    #ENDFOR
      END
  #ENDIF
    END
  #IF(%mtpToggleKey <> '' OR %mtpFocusKey <> '')
  OF EVENT:AlertKey
    #IF(%mtpToggleKey <> '')
    IF KEYCODE() = %mtpToggleKey THEN %mtpObject.TogglePanel().
    #ENDIF
    #IF(%mtpFocusKey <> '')
    IF KEYCODE() = %mtpFocusKey                           ! myTaskPanel: the keyboard into the panel
      IF ~%mtpObject.IsVisible() THEN %mtpObject.ShowPanel().
      %mtpObject.Focus()
    END
    #ENDIF
  #ENDIF
  END
#ENDAT
#!
#AT(%WindowManagerMethodCodeSection,'Kill','(),BYTE'),PRIORITY(4400),WHERE(%mtpOn)
  %mtpObject.Kill()                                       ! myTaskPanel: saves the layout, gives the room back
#ENDAT
#!
#AT(%ProcedureRoutines),WHERE(%mtpOn)
!-----------------------------------------------------------------------------
!  myTaskPanel - builds the panel. Runs once, on EVENT:OpenWindow.
!-----------------------------------------------------------------------------
mtpBuild:%mtpObject ROUTINE
  %mtpObject.Init(%Window, %mtpEngineEq)
  %mtpObject.ShowSearch = %mtpSearch
  %mtpObject.SetTheme(%mtpThemeEq)
  #IF(VAREXISTS(%mtpgUseAccent))
    #IF(%mtpgUseAccent)
  %mtpObject.SetAccent(%mtpgAccent)
    #ENDIF
  %mtpObject.FontName = '%(QUOTE(%mtpgFont))'
  %mtpObject.FontSize = %mtpgFontSize
  %mtpObject.ItemHeight = %mtpgItemH
  %mtpObject.HeaderHeight = %mtpgHeadH
  %mtpObject.Radius = %mtpgRadius
  %mtpObject.Animate = %mtpgAnimate
  %mtpObject.Effects = %mtpgEffects
  %mtpObject.FloatOpacity = %mtpgFloatOpacity
  %mtpObject.ShowEngine = %mtpgShowEngine
    #IF(%mtpgLanguage = 'Spanish')
  %mtpObject.SetLanguage('ES')
    #ENDIF
    #IF(%mtpgRemember)
  %mtpObject.IniFile = '%(QUOTE(%mtpgIniFile))'
  %mtpObject.IniSection = 'TaskPanel.%Procedure'
    #ENDIF
  #ENDIF
  %mtpObject.Title = '%(QUOTE(%mtpTitle))'
  #CASE(%mtpDock)
  #OF('Docked on the right')
  %mtpObject.DockSide = MTP:Right
  #OF('Floating')
  %mtpObject.DockSide = MTP:Float
  #ELSE
  %mtpObject.DockSide = MTP:Left
  #ENDCASE
  %mtpObject.PanelWidth = %mtpWidth
  %mtpObject.AllowFloat = %mtpAllowFloat
  %mtpObject.AllowDock = %mtpAllowDock
  %mtpObject.AllowClose = %mtpAllowClose
  %mtpObject.AllowResize = %mtpAllowResize
  %mtpObject.GrowHost = %mtpGrow
  %mtpObject.Accordion = %mtpAccordion
  %mtpObject.ShowShortcuts = %mtpShortcuts
  %mtpObject.Favorites = %mtpFavorites
  %mtpObject.RecentMax = %mtpRecent
  %mtpObject.MostMax = %mtpMost
  %mtpObject.ShowTips = %mtpTips
  %mtpObject.Rail = %mtpRail
  %mtpObject.AutoHide = %mtpAutoHide
  #IF(%mtpSubStyle = 'Pop-up menu')
  %mtpObject.SubStyle = MTP:Flyout
  #ENDIF
  #EMBED(%mtpBeforeBuild,'myTaskPanel - before the groups are added')
  #IF(%mtpMirror AND %mtpMirrorWhere = 'Before my groups')
  %mtpObject.MirrorMenu(%mtpMirrorHide, '%(QUOTE(%mtpMirrorSkip))', %(CHOOSE(%mtpMirrorMode = 'One group called Menu',1,0)))
  #ENDIF
  #FOR(%mtpGroups)
    #IF(%mtpGroupGlyph = 'auto')
      #SET(%mtpGlyphQ,%mtpObject & '.GuessGlyph(''' & QUOTE(%mtpGroupText) & ''')')
    #ELSIF(%mtpGroupGlyph = 'none' OR %mtpGroupGlyph = '')
      #SET(%mtpGlyphQ,'''''')
    #ELSE
      #SET(%mtpGlyphQ,'''' & %mtpGroupGlyph & '''')
    #ENDIF
  %mtpObject:G = %mtpObject.AddGroup('%(QUOTE(%mtpGroupText))', %mtpGlyphQ, %mtpGroupOpen, %mtpGroupSpecial)
    #IF(%mtpGroupIcon <> '')
  %mtpObject.SetIcon(%mtpObject:G, '%(QUOTE(%mtpGroupIcon))')
    #ENDIF
    #IF(%mtpGroupHidden)
  %mtpObject.SetHidden(%mtpObject:G, 1)
    #ENDIF
    #SET(%mtpMaxLv,0)
    #FOR(%mtpItems)
      #SET(%mtpLv,%mtpItemLevel)
      #IF(%mtpLv > %mtpMaxLv)
        #SET(%mtpLv,%mtpMaxLv)
      #ENDIF
      #IF(%mtpLv = 0)
        #SET(%mtpParent,%mtpObject & ':G')
      #ELSE
        #SET(%mtpParent,%mtpObject & ':L[' & %mtpLv & ']')
      #ENDIF
      #CASE(%mtpItemKind)
      #OF('Separator')
  %mtpObject.AddSeparator(%mtpParent)
      #OF('Label')
  %mtpObject.AddLabel(%mtpParent, '%(QUOTE(%mtpItemText))')
      #OF('Info')
  %mtpObject:L[%(%mtpLv + 1)] = %mtpObject.AddInfo(%mtpParent, '%(QUOTE(%mtpItemText))', '', '%(QUOTE(%mtpTagOf()))')
        #IF(%mtpItemAction <> 'Embed code only')
  %mtpObject.SetClickable(%mtpObject:L[%(%mtpLv + 1)])
        #ENDIF
      #OF('Progress')
  %mtpObject:L[%(%mtpLv + 1)] = %mtpObject.AddProgress(%mtpParent, '%(QUOTE(%mtpItemText))', 0, '%(QUOTE(%mtpTagOf()))')
        #IF(%mtpItemAction <> 'Embed code only')
  %mtpObject.SetClickable(%mtpObject:L[%(%mtpLv + 1)])
        #ENDIF
      #OF('Chart')
  %mtpObject:L[%(%mtpLv + 1)] = %mtpObject.AddChart(%mtpParent, '%(QUOTE(%mtpItemText))', '', %(CHOOSE(%mtpItemChart = 'Line', 'MTP:Line', 'MTP:Bars')), '%(QUOTE(%mtpTagOf()))')
        #IF(%mtpItemAction <> 'Embed code only')
  %mtpObject.SetClickable(%mtpObject:L[%(%mtpLv + 1)])
        #ENDIF
      #ELSE
        #SET(%mtpTagQ,QUOTE(%mtpTagOf()))
        #IF(%mtpItemGlyph = 'auto')
          #SET(%mtpGlyphQ,%mtpObject & '.GuessGlyph(''' & QUOTE(%mtpItemText) & ''')')
        #ELSIF(%mtpItemGlyph = 'none' OR %mtpItemGlyph = '')
          #SET(%mtpGlyphQ,'''''')
        #ELSE
          #SET(%mtpGlyphQ,'''' & %mtpItemGlyph & '''')
        #ENDIF
        #IF(%mtpItemAction = 'Press a control or menu item' AND %mtpItemControl <> '')
  %mtpObject:L[%(%mtpLv + 1)] = %mtpObject.AddItem(%mtpParent, '%(QUOTE(%mtpItemText))', %mtpGlyphQ, '%mtpTagQ', %mtpItemControl)
        #ELSE
  %mtpObject:L[%(%mtpLv + 1)] = %mtpObject.AddItem(%mtpParent, '%(QUOTE(%mtpItemText))', %mtpGlyphQ, '%mtpTagQ')
        #ENDIF
        #IF(%mtpItemIcon <> '')
  %mtpObject.SetIcon(%mtpObject:L[%(%mtpLv + 1)], '%(QUOTE(%mtpItemIcon))')
        #ENDIF
        #IF(%mtpItemShortcut <> '')
  %mtpObject.SetShortcut(%mtpObject:L[%(%mtpLv + 1)], '%(QUOTE(%mtpItemShortcut))')
        #ENDIF
        #IF(%mtpItemDisabled)
  %mtpObject.SetEnabled(%mtpObject:L[%(%mtpLv + 1)], 0)
        #ENDIF
        #IF(%mtpItemHidden)
  %mtpObject.SetHidden(%mtpObject:L[%(%mtpLv + 1)], 1)
        #ENDIF
        #IF(%mtpItemBold)
  %mtpObject.SetBold(%mtpObject:L[%(%mtpLv + 1)], 1)
        #ENDIF
        #IF(%mtpItemOpen)
  %mtpObject.Expand(%mtpObject:L[%(%mtpLv + 1)], 1)
        #ENDIF
        #IF(%mtpItemTip <> '')
  %mtpObject.SetTip(%mtpObject:L[%(%mtpLv + 1)], '%(QUOTE(%mtpItemTip))')
        #ENDIF
        #IF(%mtpItemDrop)
  %mtpObject.SetDropTarget(%mtpObject:L[%(%mtpLv + 1)])
        #ENDIF
        #FOR(%mtpBtns)
  %mtpObject.AddAction(%mtpObject:L[%(%mtpLv + 1)], '%mtpBtnGlyph', '%(QUOTE(%mtpBtnTagOf()))', '%(QUOTE(%mtpBtnTip))')
        #ENDFOR
        #SET(%mtpMaxLv,%mtpLv + 1)
        #IF(%mtpMaxLv > 7)
          #SET(%mtpMaxLv,7)
        #ENDIF
      #ENDCASE
    #ENDFOR
  #ENDFOR
  #IF(%mtpMirror AND %mtpMirrorWhere <> 'Before my groups')
  %mtpObject.MirrorMenu(%mtpMirrorHide, '%(QUOTE(%mtpMirrorSkip))', %(CHOOSE(%mtpMirrorMode = 'One group called Menu',1,0)))
  #ENDIF
  #EMBED(%mtpAfterBuild,'myTaskPanel - after the groups are added, before it shows')
  %mtpObject.LoadState()
  DO mtpCheck:%mtpObject
  #IF(%mtpToggleKey <> '')
  ALERT(%mtpToggleKey)
  #ENDIF
  #IF(%mtpFocusKey <> '')
  ALERT(%mtpFocusKey)
  #ENDIF
  #IF(%mtpHidden = 0)
  %mtpObject.ShowPanel()
  #ENDIF
!-----------------------------------------------------------------------------
!  myTaskPanel - the Show only when / Enable only when conditions. Runs at
!  open and on MTP:Check (the mouse came into the panel, or it took the
!  keyboard), so a change in the program shows the next time it is used.
!-----------------------------------------------------------------------------
mtpCheck:%mtpObject ROUTINE
  #FOR(%mtpGroups)
    #IF(%mtpGroupShowIf <> '')
  IF %mtpGroupShowIf                                      ! group %mtpGroupText
    %mtpObject.SetHidden(%mtpObject.FindText('%(QUOTE(%mtpGroupText))', 0), 0)
  ELSE
    %mtpObject.SetHidden(%mtpObject.FindText('%(QUOTE(%mtpGroupText))', 0), 1)
  END
    #ENDIF
    #FOR(%mtpItems),WHERE(%mtpItemValue <> '')
      #CASE(%mtpItemKind)
      #OF('Info')
  %mtpObject.SetValue(%mtpObject.FindTag('%(QUOTE(%mtpTagOf()))'), %mtpItemValue)     ! %mtpItemText
      #OF('Progress')
  %mtpObject.SetProgress(%mtpObject.FindTag('%(QUOTE(%mtpTagOf()))'), %mtpItemValue)  ! %mtpItemText
      #OF('Chart')
  %mtpObject.SetSeries(%mtpObject.FindTag('%(QUOTE(%mtpTagOf()))'), %mtpItemValue)    ! %mtpItemText
      #ENDCASE
    #ENDFOR
    #FOR(%mtpItems),WHERE(%mtpItemKind = 'Item')
      #IF(%mtpItemShowIf <> '')
  IF %mtpItemShowIf                                       ! %mtpItemText
    %mtpObject.SetHidden(%mtpObject.FindTag('%(QUOTE(%mtpTagOf()))'), 0)
  ELSE
    %mtpObject.SetHidden(%mtpObject.FindTag('%(QUOTE(%mtpTagOf()))'), 1)
  END
      #ENDIF
      #IF(%mtpItemEnableIf <> '')
  IF %mtpItemEnableIf                                     ! %mtpItemText
    %mtpObject.SetEnabled(%mtpObject.FindTag('%(QUOTE(%mtpTagOf()))'), 1)
  ELSE
    %mtpObject.SetEnabled(%mtpObject.FindTag('%(QUOTE(%mtpTagOf()))'), 0)
  END
      #ENDIF
    #ENDFOR
  #ENDFOR
  #EMBED(%mtpCheck,'myTaskPanel - re-check conditions (SetHidden, SetEnabled, SetBadge)')
#ENDAT
