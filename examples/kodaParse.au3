#NoTrayIcon
#include "..\guiUtils.au3"

; simply create a GUI from a KODA form
$oForm = _GUIUtils_CreateFromKODA("formsample.kxf")
GUISetState()

While 1
	$iMsg = GUIGetMsg()
	Switch $iMsg
		Case -3 ; $GUI_EVENT_CLOSE
			MsgBox(64, "Inputs Read", Json_Encode(_GUIUtils_ReadInputs($oForm), $JSON_PRETTY_PRINT), 0, _GUIUtils_HWnd($oForm))
			Exit
		Case _GUIUtils_CtrlID($oForm, "Button1"), _GUIUtils_CtrlID($oForm, "Button2"), _GUIUtils_CtrlID($oForm, "Button3"), _GUIUtils_CtrlID($oForm, "Button4"), _GUIUtils_CtrlID($oForm, "Button5")
			MsgBox(64, "Button Clicked", "`" & _GUIUtils_CtrlNameByID($oForm, $iMsg) & "` clicked!", 0, _GUIUtils_HWnd($oForm))
		Case _GUIUtils_CtrlID($oForm, "MenuItem1"), _GUIUtils_CtrlID($oForm, "MenuItem2"), _GUIUtils_CtrlID($oForm, "MenuItem3")
			MsgBox(64, "Menu Item Clicked", "`" & _GUIUtils_CtrlNameByID($oForm, $iMsg) & "` clicked!", 0, _GUIUtils_HWnd($oForm))
		Case _GUIUtils_CtrlID($oForm, "Checkbox1"), _GUIUtils_CtrlID($oForm, "Checkbox2"), _GUIUtils_CtrlID($oForm, "Checkbox3")
			MsgBox(64, "Checkbox State changed", "Checkbox `" & _GUIUtils_CtrlNameByID($oForm, $iMsg) & "` state: " & (GUICtrlRead($iMsg) = 1), 0, _GUIUtils_HWnd($oForm)) ; $GUI_CHECKED = 1
	EndSwitch
WEnd
