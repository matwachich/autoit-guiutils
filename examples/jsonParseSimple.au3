#NoTrayIcon
#include <EditConstants.au3>

#include "..\guiUtils.au3"

#cs
Simple JSON GUI definition: Login Dialog
#ce

; dialog definition
$sJSON = '{title:"Login dialog" font:"10,400,0,Consolas" header:{text:"Login to you account" font:"12,800,0,Consolas"} controls:[' & _
	'{type:input id:username label:"User Name" placeholder:"Enter your user name"}' & _
	'{type:password id:password label:"Password" placeholder:"Enter you password"}' & _
	'{type:checkbox id:remember label:"Remember me"}' & _
']}'

; create and show
$oForm = _GUIUtils_CreateFromJSON($sJSON)
GUISetState(@SW_SHOW, _GUIUtils_HWnd($oForm))

; simple loop
While 1
	Switch GUIGetMsg()
		Case $GUI_EVENT_CLOSE, _GUIUtils_CtrlID($oForm, "cancelBtn")
			MsgBox(16, "Example", "Dialog canceled", 0, _GUIUtils_HWnd($oForm))
			Exit
		Case _GUIUtils_CtrlID($oForm, "submitBtn")
			; manually get inputs data
			MsgBox(64, "Example", _
				"Username: " & GUICtrlRead(_GUIUtils_CtrlID($oForm, "username")) & @CRLF & _
				"Password: " & GUICtrlRead(_GUIUtils_CtrlID($oForm, "password")) & @CRLF & _
				"Remember: " & (GUICtrlRead(_GUIUtils_CtrlID($oForm, "remember")) = $GUI_CHECKED), _
				0, _GUIUtils_HWnd($oForm) _
			)
			Exit
	EndSwitch
WEnd
