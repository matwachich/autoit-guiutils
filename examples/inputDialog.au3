#NoTrayIcon
#include <EditConstants.au3>

#include "..\guiUtils.au3"

; with _GUIUtils_InputDialog, you can use a formObject as an InputBox

; first create our form object (a simple form)
$g_oForm = _GUIUtils_CreateFromJSON('{title:"Advanced InputBox" submitBtn:"Validate" cancelBtn:{text:"Cancel" tip:"Press this button to cancel entry"} header:{text:"Enter your informations" font:"12,600,0,Consolas" tip:"This is the header"} focus:"lastName" controls:[' & _
	'{type:input id:firstName label:"First Name" placeholder:"First name goes here"}' & _
	'{type:input id:lastName label:"Last Name" placeholder:"Last name goes here"}' & _
	'{type:date id:dob label:"Date of Birth" tip:"Date de naissance"}' & _
	'{type:input id:age label:"Age" style:' & BitOR($GUI_SS_DEFAULT_INPUT,$ES_READONLY) & ' tip:"Enter DOB to calculate Age" tipTitle:"Calculated field" tipIcon:1}' & _
	'{type:combo id:sex label:"Sexe" editable:false options:["Male", "Female"]}' & _
	'{type:list id:multiList multisel:true label:"Multi-Selection" options:["Option 01", "Option 02", "Option 03"]}' & _
	'{type:list id:singleList multisel:false label:"Single-Selection" options:"Option 04|Option 05|Option 06"}' & _
	'{type:check id:like label:"Yes, I like AutoIt" value:true}' & _
']}')

; simple inputbox using the previously created
$g_oData = _GUIUtils_InputDialog($g_oForm, Null, Null, _onChange)
If IsObj($g_oData) Then
	MsgBox(64, "InputBox 01", Json_Encode($g_oData, $JSON_PRETTY_PRINT))
Else
	MsgBox(16, "InputBox 01", "Canceled")
EndIf

; you can re-use the GUI more times
; here we set initial GUI data to the data entered in the first example
$g_oData = _GUIUtils_InputDialog($g_oForm, $g_oData, Null, _onChange)
If IsObj($g_oData) Then
	MsgBox(64, "InputBox 02", Json_Encode($g_oData, $JSON_PRETTY_PRINT))
Else
	MsgBox(16, "InputBox 02", "Canceled")
EndIf

; onChange callback: calculate age
Func _onChange($oForm, $vData, $vUserData)
	If $vData = "dob" Then
		Local $tDOB = _GUICtrlDTP_GetSystemTimeEx(_GUIUtils_HCtrl($oForm, "dob"))
		GUICtrlSetData(_GUIUtils_CtrlID($oForm, "age"), _DateDiff("y", _Date_Time_SystemTimeToDateTimeStr($tDOB, 1), _NowCalc()) & " year(s) old")
	EndIf
EndFunc