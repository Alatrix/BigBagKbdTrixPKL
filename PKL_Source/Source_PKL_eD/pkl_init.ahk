; eD: Added Trim() around any 'SubStr( A_LoopField, 1, pos-1 )' entries
;     (From vVv, AHK v1.1 function. Not in AHK v1.0, so make a version here.)
if ( A_AhkVersion < "1.0.90" ) {
	Trim( str )	{
		return % RegExReplace( str, "(^\s*|\s*$)")
	}
}

; eD: Set a PKL hotkey. 
;     Usage: pklSetHotkey( <HKstring>, <goto label>, <PKLinfo tag> )
pklSetHotkey( val, HKlabel, pklInfoTag, default = "" )						; eD: Set a PKL hotkey
{
	if ( val <> "" ) {
		Loop, parse, val, `,
		{
			Hotkey, %A_LoopField%, %HKlabel%
			if ( A_Index == 1 )
				setPklInfo( pklInfoTag, A_LoopField )
		}
	}
}

pkl_init( layoutFromCommandLine = "" )
{
	global gP_Pkl_Ini_File				; eD:    "pkl.ini" -	will eventually be stored in a pdic
	global gP_Lay_Ini_File				; eD:    "layout.ini" 	--"--
;	global gP_Pkl_eD__File				; eD: My "pkl.ini" 		--"--
	global gP_Lay_eD__File				; eD: My "layout.ini" 	--"--
;	global gP_Pkl_Dic_File				; eD: My "tables.ini" 	--"--
	
	if ( not FileExist( gP_Pkl_Ini_File ) ) {
		MsgBox, %gP_Pkl_Ini_File% file NOT FOUND`nSorry. The program will exit.
		ExitApp
	}
	
	compactMode := pklIniBool( "compactMode", false )
	
	it := pklIniRead( "language", "auto" )
	if ( it == "auto" )
		it := pklIniRead( SubStr( A_Language , -3 ), "", "Pkl_Dic", "LangStrFromLangID" )	; eD: Replaced getLangStrFromDigits( A_Language )
	pkl_locale_load( it, compactMode )
	
	pklSetHotkey( pklIniRead( "suspendHotkey"              ), "ToggleSuspend"       , "HK_Suspend"      )	; eD: Was LAlt & RCtrl
	pklSetHotkey( pklIniRead( "displayHelpImageHotkey"     ), "showHelpImageToggle" , "HK_ShowHelpImg"  )
	pklSetHotkey( pklIniRead( "changeLayoutHotkey"         ), "changeActiveLayout"  , "HK_ChangeLayout" )
	pklSetHotkey( pklIniRead( "exitAppHotkey"              ), "ExitPKL"             , "HK_ExitApp"      )
	pklSetHotkey( pklIniRead( "refreshHotkey","","Pkl_eD_" ), "rerunWithSameLayout" , "HK_Refresh"      )
	pklSetHotkey( pklIniRead( "changeNonASCIIMode"         ), "_SendU_Try_Dyn_Mode" , "HK_SendUMode"    )	; eD TODO: To be deprecated?
	
	setDeadKeysInCurrentLayout( pklIniRead( "systemsDeadkeys" ) )
	setPklInfo( "altGrEqualsAltCtrl", pklIniBool( "altGrEqualsAltCtrl", false ) )
	
	SendU_Clipboard_Restore_Mode( pklIniBool( "restoreClipboard", 1, "nonASCII.ini", "global" ) )
	Loop, read, nonASCII.ini
	{
		t := RegExReplace(A_LoopReadLine, "^\s+")
		if ( SubStr( t, 1, 1 ) == ";" )
			Continue
		StringSplit, a, t, =
		if ( a0 != 2 )
			Continue
		a1 := RegExReplace(a1, "^\s+")
		a2 := RegExReplace(a2, "^\s+")
		a1 := RegExReplace(a1, "\s+$")
		a2 := RegExReplace(a2, "\s+$")
		if ( a1 == "restoreClipboard" )
			Continue
		SendU_SetMode( a1, a2 )
	}
	
	activity_setTimeout( 1, pklIniRead( "suspendTimeOut", 0 ) )
	activity_setTimeout( 2, pklIniRead( "exitTimeOut"   , 0 ) )
	
	Layout := pklIniRead( "layout" )
	StringSplit, layouts, Layout, `,
	setLayInfo( "countOfLayouts", layouts0 )
	Loop, % layouts0 {
		StringSplit, parts, layouts%A_Index%, :
		A_Layout := parts1
		if ( parts0 > 1 )
			A_Name := parts2
		else
			A_Name := parts1
		setLayInfo( "layout" . A_Index . "code", A_Layout )
		setLayInfo( "layout" . A_Index . "name", A_Name )
	}
	
	if ( layoutFromCommandLine )
		Layout := layoutFromCommandLine
	else
		Layout := getLayInfo( "layout1code" )
	if ( Layout == "" ) {
		pkl_MsgBox( 1, gP_Pkl_Ini_File )	; eD
		ExitApp
	}
	setLayInfo( "active", Layout )
	
	nextLayoutIndex := 1
	Loop, % layouts0 {
		if ( Layout == getLayInfo( "layout" . A_Index . "code") ) {
			nextLayoutIndex := A_Index + 1
			break
		}
	}
	if ( nextLayoutIndex > layouts0 )
			nextLayoutIndex := 1
	setLayInfo( "nextLayout", getLayInfo( "layout" . nextLayoutIndex . "code" ) )
	
	if ( compactMode ) {
		LayoutDir := "."
	} else {
		LayoutDir := "Layouts\" . Layout
	}
	LayoutFile := LayoutDir . "\" . gP_Lay_Ini_File
	if (not FileExist(LayoutFile) ) {
		pkl_MsgBox( 2, LayoutFile )
		ExitApp
	}
	gP_Lay_Ini_File := LayoutFile							; eD: Update global as file path
	gP_Lay_eD__File := LayoutDir . "\" . gP_Lay_eD__File	; eD: Update global as file path
	setLayInfo( "layDir", LayoutDir )
	
	IniRead, ShiftStates, %LayoutFile%, global, shiftstates, 0:1
	ShiftStates = %ShiftStates%:8:9 ; SgCap, SgCap + Shift
	StringSplit, ShiftStates, ShiftStates, :
	IfInString, ShiftStates, 6
		setLayInfo( "hasAltGr", 1)
	else
		setLayInfo( "hasAltGr", 0)
	;IniRead, extendKey, %LayoutFile%, global, extend_key, %A_Space%
	extendKey := pklIniRead( "extend_key", "", LayoutFile, "global" )
	if ( extendKey <> "" ) {
		setLayInfo( "extendKey", extendKey )
	}
	
	remap := iniReadSection( LayoutFile, "layout" )
	Loop, parse, remap, `r`n
	{
		pklIniKeyVal( A_LoopField, key, parts )
		If ( key == "<NoKey>" )
			Continue
		StringSplit, parts, parts, %A_Tab%
		if ( parts0 < 2 ) {
			Hotkey, *%key%, doNothing
			Continue
		}
		StringLower, parts2, parts2
		if ( parts2 == "virtualkey" || parts2 == "vk")
			parts2 = -1
		else if ( parts2 == "modifier" )
			parts2 = -2
;		setKeyInfo( key . "v", getVKeyCodeFromName(parts1) ) 	; virtual key
		setKeyInfo( key . "v", pklIniRead( "VK_" . parts1, "00", "Pkl_Dic", "VKeyCodeFromName" ) ) ; eD: replaced getVKeyCodeFromName(parts1) )
		setKeyInfo( key . "c", parts2 ) 							; caps state
		if ( parts2 == -2 ) {
			Hotkey, *%key%, modifierDown
			Hotkey, *%key% Up, modifierUp
			if ( getLayInfo( "hasAltGr" ) && parts1 == "RAlt" )
				setKeyInfo( key . "v", "AltGr" )
			else
				setKeyInfo( key . "v", parts1 )
		} else if ( key == extendKey ) {
			Hotkey, *%key% Up, upToDownKeyPress
		} else {
			Hotkey, *%key%, keyPressed
		}
		Loop, % parts0 - 3 {
			k = ShiftStates%A_Index%
			k := %k%
			
			v := A_Index + 2
			v = parts%v%
			v := %v%	; eD: Trims v
;			v := Trim( v )
			if ( StrLen( v ) == 0 ) {
				v = -- ; Disabled
			} else if ( StrLen( v ) == 1 ) {
				v := asc( v )
			} else {
				if ( SubStr( v, 1, 1 ) == "*" ) { ; Special chars
					setKeyInfo( key . k . "s", SubStr( v, 2 ) )
					v := "*"
				} else if ( SubStr( v, 1, 1 ) == "=" ) { ; Special chars with {Blind}
					setKeyInfo( key . k . "s", SubStr( v, 2 ) )
					v := "="
				} else if ( SubStr( v, 1, 1 ) == "%" ) { ; Ligature (with unicode chars, too)
					setKeyInfo( key . k . "s", SubStr( v, 2 ) )
					v := "%"
				} else if ( v == "--" ) {
					v = -- ;) Disabled
				} else if ( SubStr( v, 1, 2 ) == "dk" ) { ; dead key
					setKeyInfo( key . k . "s", SubStr( v, 3 ) )
					v := "dk"
;					v := "-" . SubStr( v, 3 )
;					v += 0	; eD: Makes v numeric (need to avoid this!)
				} else {
					Loop, parse, v
					{
						if ( A_Index == 1 ) {
							ligature = 0
						} else if ( asc( A_LoopField ) < 128 ) {
							ligature = 1
							break
						}
					}
					if ( ligature ) { ; Ligature
						setKeyInfo( key . k . "s", v )
						v := "%"
					} else { ; One character
						v := "0x" . HexUC( v )
						v += 0
					}
				}
			}
			if ( v != "--" )
				setKeyInfo( key . k , v )
		}
	}
	
	; eD: Read/set deadkey name list
	Loop, 32											; Default dead key table
	{
		; eD: In AHK v1.1.17+, you can use Format("{:02}",num) to pad with zeros. Better in any way?
		key := "dk" . SubStr( "00" . A_Index, -1 )		; Pad with zero if index < 10
		ky2 := "dk" .                A_Index      		; e.g., "dk1" or "dk14"
		val := "deadkey" . A_Index
		setKeyInfo( key, val )							; e.g., "dk01" = "deadkey1"
		if ( ky2 != key )
			setKeyInfo( ky2, val )						; e.g., "dk1" = "deadkey1"; backwards compatible
	}
	file := pklIniRead( "dk_tables", "", "Lay_eD_", "global" )
	file := ( FileExist( file ) ) ? file : LayoutFile	; eD: If no dedicated DK file, try the layout file
	setLayInfo( "dkfile", file )						; This file should contain the actual dk tables
	file := ( pklIniRead( "dk01", -1, "Lay_eD_", "deadkeys" ) != -1 ) ? gP_Lay_eD__File : file
	remap := iniReadSection( file, "deadkeys" )
	Loop, parse, remap, `r`n
	{
		pklIniKeyVal( A_LoopField, key, val )
		if ( val )
			setKeyInfo( key, val )						; e.g., "dk01" = "dk_dotbelow"
	}
	
	; eD: Read/set deadkey image data
	dir := pklIniRead( "dk_imgDir", "", "Lay_eD_", "global" )
	dir := ( FileExist( dir ) ) ? dir : LayoutDir	; eD: If no dedicated DK image dir, try the layout dir
	setLayInfo( "dkImgDir", dir )
	setLayInfo( "dkImgSuf", pklIniRead( "dk_imgSuf", "", "Lay_eD_", "global" ) )
	
	if ( extendKey ) {
		remap := iniReadSection( gP_Pkl_Ini_File, "extend" )
		Loop, parse, remap, `r`n
		{
			pklIniKeyVal( A_LoopField, key, parts )
			setKeyInfo( key . "e", parts )
		}
		remap := iniReadSection( LayoutFile, "extend" )
		Loop, parse, remap, `r`n
		{
			pklIniKeyVal( A_LoopField, key, parts )
			setKeyInfo( key . "e", parts )
		}
	}
	
	if ( FileExist( getLayInfo("layDir") . "\on.ico") ) {
		setLayInfo( "Ico_On_File", getLayInfo( "layDir" ) . "\on.ico" )
		setLayInfo( "Ico_On_Num_", 1 )
	} else if ( A_IsCompiled ) {
		setLayInfo( "Ico_On_File", A_ScriptName )
		setLayInfo( "Ico_On_Num_", 6 )
	} else {
		setLayInfo( "Ico_On_File", "Resources\on.ico" )
		setLayInfo( "Ico_On_Num_", 1 )
	}
	if ( FileExist( getLayInfo( "layDir" ) . "\off.ico") ) {
		setLayInfo( "Ico_OffFile", getLayInfo( "layDir" ) . "\off.ico" )
		setLayInfo( "Ico_OffNum_", 1 )
	} else if ( A_IsCompiled ) {
		setLayInfo( "Ico_OffFile", A_ScriptName )
		setLayInfo( "Ico_OffNum_", 3 )
	} else {
		setLayInfo( "Ico_OffFile", "Resources\off.ico" )
		setLayInfo( "Ico_OffNum_", 1 )
	}
	pkl_set_tray_menu()
}

pkl_activate()
{
	SetTitleMatchMode 2
	DetectHiddenWindows on
	WinGet, id, list, %A_ScriptName%
	Loop, %id%
	{
		; This isn't the first instance. Send "kill yourself" message to all instances
		id := id%A_Index%
		PostMessage, 0x398, 422,,, ahk_id %id%
	}
	Sleep, 10
	pkl_show_tray_menu()
	
	if ( pklIniBool( "displayHelpImage", true ) )
		pkl_showHelpImage( 1 )

	Sleep, 200 ; I don't want to kill myself...
	OnMessage( 0x398, "MessageFromNewInstance" )
	
	activity_ping(1)
	activity_ping(2)
	SetTimer, activityTimer, 20000
	
	if ( pklIniBool( "startsInSuspendMode", false ) ) {
		Suspend
		gosub afterSuspend
	}
}

pkl_show_tray_menu()
{
	Menu, Tray, Icon, % getLayInfo( "Ico_On_File" ), % getLayInfo( "Ico_On_Num_" )
	Menu, Tray, Icon,,, 1 ; Freeze the icon
}

MessageFromNewInstance(lparam)
{
	; The second instance send this message
	if ( lparam == 422 )
		ExitApp
}

changeLayout( nextLayout )
{
	Menu, Tray, Icon,,, 1 ; Freeze the icon
	Suspend, On
	
	if ( A_IsCompiled )
		Run %A_ScriptName% /f %nextLayout%
	else
		Run %A_AhkPath% /f %A_ScriptName% %nextLayout%
}

; eD: Moved this here from ext_Uni2Hex.ahk. eD TODO: In AHK v1.1, can it be replaced?
HexUC(utf8) {   ; by Laszlo Hars: Return 4 hex Unicode digits of a UTF-8 input CHAR
   format = %A_FormatInteger%   ; save original integer format
   SetFormat Integer, Hex       ; for converting bytes to hex
   VarSetCapacity(U, 2)        ; from CoHelper.ahk
   DllCall("MultiByteToWideChar", UInt,65001, UInt,0, Str,utf8, Int,-1, UInt,&U, Int,1)
   h := 0x10000 + (*(&U+1)<<8) + *(&U)
   StringTrimLeft h, h, 3
   SetFormat Integer, %format%  ; restore original format
   Return h
}