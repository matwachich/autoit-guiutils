#NoTrayIcon
#include <GuiListView.au3>

#include "..\guiUtils.au3"

;~ #include <_Dbug.au3>

Opt("GUICloseOnEsc", 0)

; create main application GUI
Global $oMainGUI = _GUIUtils_CreateFromKODA("exampleAppMainGUI.kxf")
GUISetState()

ConsoleWrite("+> Main GUI formObject : " & Json_Encode($oMainGUI, $JSON_PRETTY_PRINT) & @CRLF)

; set some accelerators
Global $aAccels[][] = [["^n", "btnNew"], ["{enter}", "btnEdit"], ["{del}", "btnDelete"]]
_GUIUtils_SetAccels($oMainGUI, $aAccels)

; create new/edit dialog
Global $oEditGUI = _GUIUtils_CreateFromJSON('{title:"New entry" controls:[' & _
	'{type:input id:firstName label:"First Name"}' & _
	'{type:input id:lastName label:"Last Name"}' & _
	'{type:date id:dob label:"Date of birth"}' & _
	'{type:radio id:sexMale label:"Male"}' & _
	'{type:radio id:sexFemale label:"Female"}' & _
	'{type:list id:attribs label:"Attributes" multisel:true options:"Attribute 01|Attribute 02|Attribute 03"}' & _
']}', _GUIUtils_HWnd($oMainGUI))

ConsoleWrite("+> Edit GUI formObject : " & Json_Encode($oEditGUI, $JSON_PRETTY_PRINT) & @CRLF)

; main loop
While 1
	Switch GUIGetMsg()
		Case $GUI_EVENT_CLOSE
			Exit
		Case _GUIUtils_CtrlID($oMainGUI, "btnNew")
			$oEntryData = _GUIUtils_InputDialog($oEditGUI)
			If IsObj($oEntryData) Then
				MsgBox(64, "Example", "Creating new Entry:" & @CRLF & Json_Encode($oEntryData, $JSON_PRETTY_PRINT))
				_LV_NewItem($oEntryData)
				_LV_ResizeCols()
			EndIf
		Case _GUIUtils_CtrlID($oMainGUI, "btnEdit")
			$aSel = _GUICtrlListView_GetSelectedIndices(_GUIUtils_HCtrl($oMainGUI, "ListView"), True)
			If $aSel[0] > 0 Then
				$oEntryData = _GUIUtils_InputDialog($oEditGUI, _LV_ReadItem($aSel[1]))
				If IsObj($oEntryData) Then
					MsgBox(64, "Example", "Edit selected Entry:" & @CRLF & Json_Encode($oEntryData, $JSON_PRETTY_PRINT))
					_LV_WriteItem($aSel[1], $oEntryData)
					_LV_ResizeCols()
				EndIf
			EndIf
		Case _GUIUtils_CtrlID($oMainGUI, "btnDelete")
			_GUICtrlListView_DeleteItemsSelected(_GUIUtils_HCtrl($oMainGUI, "ListView"))
	EndSwitch
WEnd

Func _LV_NewItem($oData)
	Local $iItem = _GUICtrlListView_AddItem(_GUIUtils_HCtrl($oMainGUI, "ListView"), _objGet($oData, "firstName"))
	_GUICtrlListView_AddSubItem(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, _objGet($oData, "lastName"), 1)
	_GUICtrlListView_AddSubItem(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, _objGet($oData, "dob"), 2)
	If _objGet($oData, "sexMale") Then
		_GUICtrlListView_AddSubItem(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, "M", 3)
	ElseIf _objGet($oData, "sexFemale") Then
		_GUICtrlListView_AddSubItem(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, "F", 3)
	EndIf
	Local $aAttribs = _objGet($oData, "attribs")
	_GUICtrlListView_AddSubItem(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, _ArrayToString($aAttribs, ", "), 4)
	Return $iItem
EndFunc

Func _LV_WriteItem($iItem, $oData)
	_GUICtrlListView_SetItemText(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, _objGet($oData, "firstName"), 0)
	_GUICtrlListView_SetItemText(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, _objGet($oData, "lastName"), 1)
	_GUICtrlListView_SetItemText(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, _objGet($oData, "dob"), 2)
	If _objGet($oData, "sexMale") Then
		_GUICtrlListView_SetItemText(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, "M", 3)
	ElseIf _objGet($oData, "sexFemale") Then
		_GUICtrlListView_SetItemText(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, "F", 3)
	EndIf
	Local $aAttribs = _objGet($oData, "attribs")
	_GUICtrlListView_SetItemText(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem, _ArrayToString($aAttribs, ", "), 4)
EndFunc

Func _LV_ReadItem($iItem)
	Local $oData = _objCreate()
	Local $aRead = _GUICtrlListView_GetItemTextArray(_GUIUtils_HCtrl($oMainGUI, "ListView"), $iItem)
	_objSet($oData, "firstName", $aRead[1])
	_objSet($oData, "lastName", $aRead[2])
	_objSet($oData, "dob", $aRead[3])
	_objSet($oData, "sexMale", $aRead[4] = "M" ? True : False)
	_objSet($oData, "sexFemale", $aRead[4] = "F" ? True : False)
	Local $aAttribs = StringSplit($aRead[5], ", ", 1)
	_ArrayDelete($aAttribs, 0)
	_objSet($oData, "attribs", $aAttribs)
	Return $oData
EndFunc

Func _LV_ResizeCols()
	For $i = 0 To _GUICtrlListView_GetColumnCount(_GUIUtils_HCtrl($oMainGUI, "ListView")) - 1
		_GUICtrlListView_SetColumnWidth(_GUIUtils_HCtrl($oMainGUI, "ListView"), $i, $LVSCW_AUTOSIZE)
	Next
EndFunc
