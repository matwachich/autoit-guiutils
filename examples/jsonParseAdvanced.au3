#NoTrayIcon
#include "..\guiUtils.au3"

#cs
Advanced JSON GUI definition: InputBox controls showcase
#ce

; dialog definition
$sJSON = '{title:"Login dialog" maxHeight:'& (@DesktopHeight / 3) &' font:"10,400,0,Consolas" header:{text:"InputBox controls Showcase" font:"12,600,0,Consolas"} controls: ['

; simple inputs
$sJSON &= '{type:input id:inputID label:"Simple input"}'
$sJSON &= '{type:password id:passwordID label:"Password input"}'

; edits
$sJSON &= '{type:edit id:edit01 label:"Long text" value:"Long text\r\n.\r\n(default: 3 lines height)"}'
$sJSON &= '{type:edit id:edit02 label:"Longer text" lines:5 value:"Hello, world!\r\nThis is a long text\r\n.\r\n.\r\n(5 lines height)"}'

; combo boxes
$sJSON &= '{type:combo id:combo01 label:"Combo box" editable:true options:["Combo value 1", "Combo value 2"]}'
$sJSON &= '{type:combo id:combo02 label:"Combo box" editable:false options:["Combo value 1", "Combo value 2"]}'

; check boxes
$sJSON &= '{type:check id:check01 label:"Checkbox 01" value:true}'
$sJSON &= '{type:check id:check02 label:"Checkbox 02"}'
$sJSON &= '{type:check id:check03 label:"Checkbox 03" space:true}'

; radio boxes (2 groups)"
$sJSON &= '{type:radio id:radio01_01 label:"Radiobox 01" value:true}'
$sJSON &= '{type:radio id:radio01_02 label:"Radiobox 02"}'
$sJSON &= '{type:radio id:radio01_03 label:"Radiobox 03" space:true}'

$sJSON &= '{type:radio id:radio02_01 label:"Radiobox 04" group:true}'
$sJSON &= '{type:radio id:radio02_02 label:"Radiobox 05" value:true}'
$sJSON &= '{type:radio id:radio02_03 label:"Radiobox 06"}'

; date time picker
$sJSON &= '{type:date id:dateID label:"Date" value:"2006/05/04"}'
$sJSON &= '{type:time id:timeID label:"Time" value:"14:35:15"}'

; list boxes
$sJSON &= '{type:list id:list01 label:"List box (multi-sel)" multisel:true options:"Value 01|Value 02|Value 03" value:"Value 02"}'
$sJSON &= '{type:list id:list02 label:"List box (single-sel)" multisel:false options:"Single 01|Single 02|Single 03" value:"Single 03"}'

$sJSON &= ']}'

; create and show
$oForm = _GUIUtils_CreateFromJSON($sJSON)
GUISetState(@SW_SHOW, _GUIUtils_HWnd($oForm))

While 1
	Switch GUIGetMsg()
		Case $GUI_EVENT_CLOSE, _GUIUtils_CtrlID($oForm, "cancelBtn")
			MsgBox(16, "Example", "Dialog canceled", 0, _GUIUtils_HWnd($oForm))
			Exit
		Case _GUIUtils_CtrlID($oForm, "submitBtn")
			; in place of manually reading all input controls, you can simply use this function (it is used internally by _GUIUtils_InputDialog)
			$oRead = _GUIUtils_ReadInputs($oForm)

;~ 			you can iterate over read values like this
;~ 			For $sName In _objKeys($oRead)
;~ 				$sName is control name
;~ 				_objGet($oRead, $sName) is control data
;~ 			Next

			MsgBox(64, "Example", Json_Encode($oRead, $JSON_PRETTY_PRINT), 0, _GUIUtils_HWnd($oForm))
			Exit
	EndSwitch
WEnd
