#include-once
; #INDEX# =======================================================================================================================
; Title .........: GUI Utility UDF
; AutoIt Version : 1.0
; Description ...: Functions to simply create GUIs directly from KODA file or with a simple JSON definition, and handle them
;                  as advanced input boxes.
; Author(s) .....: matwachich
; Links .........: https://www.autoitscript.com/forum/topic/201594-guiutils-simply-create-guis-from-koda-input-dialogs-from-json-and-handle-them-like-inputbox-with-one-function/
; =================================================================================================

#cs
Bugs:
- quand on créé un dialog à partir d'un KXF, si le premier contrôle est à x=0,y=0, alors la taille de la fenêtre est mal calculée
#ce

#include <Date.au3>
#include <Math.au3>
#include <Array.au3>
#include <GuiTab.au3>
#include <String.au3>
#include <WinAPI.au3>
#include <GuiEdit.au3>
#include <GuiListBox.au3>
#include <GuiComboBox.au3>
#include <GUIConstants.au3>
#include <GuiIPAddress.au3>
#include <GuiStatusBar.au3>
#include <EditConstants.au3>
#include <ColorConstants.au3>
#include <GUIConstantsEx.au3>
#include <ButtonConstants.au3>
#include <StaticConstants.au3>
#include <ListBoxConstants.au3>
#include <WindowsConstants.au3>
#include <DateTimeConstants.au3>
#include <GuiDateTimePicker.au3>
#include <ListViewConstants.au3>

#include "Json.au3"
#include "Object.au3"
#include "StringSize.au3"

;~ #include <WinAPIDiag.au3>
;~ #include <WMDebug.au3>
;~ #include <_Dbug.au3>

; #VARIABLES# ===================================================================================================================
Global $__gGuiUtils_inputDialog_oCurrentForm = Null
Global $__gGuiUtils_fnCustomInputReader = Null, $__gGuiUtils_fnCustomInputWriter = Null
Global $__gGuiUtils_oForms = _objCreate() ; object that will hold pairs of hwnd:oFormObject
; =================================================================================================

; #CONSTANTS# ===================================================================================================================
; Default JSON form configuration
Global Const $__gGuiUtils_jsonParser_oDefaultConfig = Json_Decode("{" & _
	'title:"InputBox" ' & _
	'labelsMaxWidth:' & (@DesktopWidth / 5) & ' ' & _
	'inputsWidth:' & (@DesktopWidth / 5) & ' ' & _
	'maxHeight:' & (@DesktopHeight * 2 / 3) & ' ' & _
	'margin:8 ' & _
	'inputLabelVerticalPadding:3 ' & _
	'submitBtn:{text:"OK" width:100 height:25} ' & _
	'cancelBtn:{text:"Cancel" width:80 height:25}' & _
"}")
; =================================================================================================

; #CURRENT# =====================================================================================================================
; > Region - KODA file parsing
; _GUIUtils_CreateFromKODA
;
; > Region - JSON definition parsing (advanced InputBox)
; _GUIUtils_CreateFromJSON
;
; > Region - InputBox behaviour
; _GUIUtils_InputDialog
;
; > Region - MultiGUIRegisterMsg
; _GUIUtils_RegisterMsg
;
; > Region - Controls Subclassing
; _GUIUtils_SubclassSet
;
; > Region - FormObject Accessing
; _GUIUtils_Destroy
; _GUIUtils_ListForms
; _GUIUtils_SetAccels
; _GUIUtils_HWnd
; _GUIUtils_FormName
; _GUIUtils_CtrlSet
; _GUIUtils_CtrlID
; _GUIUtils_CtrlNameByID
; _GUIUtils_HCtrl
; _GUIUtils_CtrlNameByHandle
; _GUIUtils_CtrlList
; _GUIUtils_CtrlChildren
; _GUIUtils_UserDataSet
; _GUIUtils_UserDataGet
; _GUIUtils_UserDataExists
; _GUIUtils_UserDataDel
; _GUIUtils_UserDataEmpty
; _GUIUtils_SetInputs
; _GUIUtils_GetInputs
; _GUIUtils_SetButtons
; _GUIUtils_ReadInputs
; _GUIUtils_WriteInputs
; _GUIUtils_SetCustomInputsReader
; _GUIUtils_SetCustomInputsWriter
;
; > Region - Misc
; _GUIUtils_GetFont
; =================================================================================================

; #INTERNAL_USE_ONLY# ===========================================================================================================
; __guiUtils_registerMsgDispatcher
; __guiUtils_getFormHandleOrObject
; __guiUtils_getSupportedInputsList
; __guiUtils_identifyControl
; __guiUtils_kodaParser_createGUI
; __guiUtils_kodaParser_createControls
; __guiUtils_kodaParser_sortObjects
; __guiUtils_kodaParser_calculateGUIsize
; __guiUtils_kodaParser_readObjectProperties
; __guiUtils_kodaParser_readProperty
; __guiUtils_kodaParser_processFont
; __guiUtils_kodaParser_identifiers_fontStyle
; __guiUtils_kodaParser_identifiers_docking
; __guiUtils_kodaParser_identifiers_cursor
; __guiUtils_kodaParser_identifiers_colors
; __guiUtils_jsonParser_stringSize
; __guiUtils_jsonParser_getFont
; __guiUtils_jsonParser_controlSetFontAndColors
; __guiUtils_jsonParser_getArray
; __guiUtils_inputDialog_subClassProc
; __guiUtils_inputDialog_controlGet
; __guiUtils_inputDialog_controlSet
; =================================================================================================

# =================================================================================================
#Region - KODA file parsing
# =================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CreateFromKODA
; Description ...: Parse a KODA Form file (.kxf) and builds a GUI
; Syntax ........: _GUIUtils_CreateFromKODA($sFileOrXML[, $hParent = Null[, $iWidth = -1[, $iHeight = -1]]])
; Parameters ....: $sFileOrXML          - KODA file path or content.
;                  $hParent             - [optional] parent GUI handle. Default is Null.
;                  $iWidth              - [optional] override automatic GUI size calculation. Default is -1 for no override.
;                  $iHeight             - [optional] override automatic GUI size calculation. Default is -1 for no override.
; Return values .: Object (scripting.dictionary) representing the GUI
; Author ........: matwachich
; Remarks .......: You can access to GUI hwnd and control IDs and handles by their names (using helper functions).
;                  GUI size is calculated to fit GUI content. It is not the size defined in KODA (I'm working to fix this).
;                  Unsupported things (todo):
;                  - Controls: Graphic, Updown, Avi, Tray Menu, COM Object, Status Bar, Tool Bar, Image List
;                  - Hotkeys (accelerator)
; Related .......: _GUIUtils_SetAccels, _GUIUtils_HWnd, _GUIUtils_CtrlID, _GUIUtils_HCtrl
; =================================================================================================
Func _GUIUtils_CreateFromKODA($sFileOrXML, $hParent = Null, $iWidth = -1, $iHeight = -1)
	; returned object that will contain control IDs
	Local $oForm = _objCreate()

	; XML DOM object
	Local $oXML = ObjCreate("Microsoft.XMLDOM")
	$oXML.Async = False

	; load XML
	If FileExists($sFileOrXML) Then
		Local $hF = FileOpen($sFileOrXML, 512)
		$sFileOrXML = FileRead($hF)
		FileClose($hF)
	EndIf
	If Not $oXML.LoadXML($sFileOrXML) Then Return SetError(1, 0, Null)

	; create GUI
	__guiUtils_kodaParser_createGUI($oForm, $oXML, $iWidth, $iHeight, __guiUtils_getFormHandleOrObject($hParent, True))
	If @error Then Return SetError(1 + @error, 0, Null)

	; get parsed gui properties
	Local $oGuiProps = _objGet($oForm, "##guiProperties")

	; create controls
	Local $oControls = $oXML.selectNodes("/object/components/object")
	__guiUtils_kodaParser_createControls($oForm, $oControls, 0, 0, Null, True)

	; set size if not manualy provided
	If $iWidth <= 0 Or $iHeight <= 0 Then
		; calculate GUI size from calculated client area size
		Local $tRect = _WinAPI_CreateRect(0, 0, _objGet($oForm, "##minX") + _objGet($oForm, "##maxX"), _objGet($oForm, "##minY") + _objGet($oForm, "##maxY"))
		_WinAPI_AdjustWindowRectEx($tRect, $oGuiProps.Item("Style"), $oGuiProps.Item("ExStyle"), _objGet($oGuiProps, "Menu", "") <> "")
		$iWidth = Abs($tRect.Left) + Abs($tRect.Right)
		$iHeight = Abs($tRect.Top) + Abs($tRect.Bottom)

		; set center position if needed
		If _objGet($oGuiProps, "Left", -1) = -1 Then _objSet($oGuiProps, "Left", (@DesktopWidth / 2) - ($iWidth / 2))
		If _objGet($oGuiProps, "Top", -1) = -1 Then _objSet($oGuiProps, "Top", (@DesktopHeight / 2) - ($iHeight / 2))

		; resize
		_WinAPI_MoveWindow($oForm.Item("hwnd"), _
			_objGet($oGuiProps, "Left", -1), _objGet($oGuiProps, "Top", -1), _
			$iWidth, $iHeight _
		)
	EndIf

	; set visible
	If _objGet($oGuiProps, "Visible", False) Then GUISetState(@SW_SHOW, _objGet($oForm, "hwnd"))

	; clean and return
	For $sKey In $oForm.Keys()
		If StringLeft($sKey, 2) = "##" Then _objDel($oForm, $sKey)
	Next

	; store oForm object and return if
	_objSet($__gGuiUtils_oForms, _GUIUtils_HWnd($oForm), $oForm, True)
	Return $oForm
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================

# =================================================================================================
#Region - JSON definition parsing (advanced InputBox)
# =================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CreateFromJSON
; Description ...: Creates an InputBox GUI from JSON definition
; Syntax ........: _GUIUtils_CreateFromJSON($vJson[, $hParent = Null])
; Parameters ....: $vJson               - JSON definition.
;                  $hParent             - [optional] parent GUI handle. Default is Null.
; Return values .: Object (scripting.dictionary) representing the GUI
; Author ........: matwachich
; Remarks .......: See JSON_Form_Definition.txt and examples.
; =================================================================================================
Func _GUIUtils_CreateFromJSON($vJson, $hParent = Null)
	; parse form definition
	Local $oJSON
	If Not IsObj($vJson) Then
		$oJSON = Json_Decode($vJson)
		If Not IsObj($oJSON) Then Return SetError(1, 0, Null)
	Else
		$oJSON = $vJSON
	EndIf

	; ensure $hParent is a HWND
	$hParent = __guiUtils_getFormHandleOrObject($hParent, True)

	; set defaults
	_objCopy($oJSON, $__gGuiUtils_jsonParser_oDefaultConfig)

	; ---------------------------------------------------------------
	; prepare GUI building
	Local $aJSONControls = _objGet($oJSON, "controls")
	If Not IsArray($aJSONControls) Then Return SetError(1, 0, Null)

	; get default GUI font (defaults to parent's font if not provided ; if no parent, $aGUIFont will be Null)
	Local $aGUIFont = __guiUtils_jsonParser_getFont($oJSON, _GUIUtils_GetFont($hParent))

	; calculate labels Width (for all labels) and Heights (for each one)
	Local $iLabelsWidth = 0
	For $i = 0 To UBound($aJSONControls) - 1
		; no control type is an error
		If Not _objExists($aJSONControls[$i], "type") Then Return SetError(1, 0, Null)

		; force id for all controls ...
		If Not _objGet($aJSONControls[$i], "id") Then _
			_objSet($aJSONControls[$i], "id", StringFormat(_objGet($aJSONControls[$i], "type") & "_%02d", $i), True)

		Switch _objGet($aJSONControls[$i], "type")
			Case "separator", "label" ; ignored
			Case "check", "checkbox", "radio", "radiobox"
				; ... and label for all but separator and label
				If Not _objGet($aJSONControls[$i], "label") Then _
					_objSet($aJSONControls[$i], "label", _StringTitleCase(_objGet($aJSONControls[$i], "id")), True)
			Case Else
				; ... and label for all but separator and label
				If Not _objGet($aJSONControls[$i], "label") Then _
					_objSet($aJSONControls[$i], "label", _StringTitleCase(_objGet($aJSONControls[$i], "id")), True)

				; calculate dimensions of control label
				$aSize = __guiUtils_jsonParser_stringSize( _
					_objGet($aJSONControls[$i], "label"), _
					__guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), _
					_objGet($oJSON, "labelsMaxWidth") _
				)

				If $aSize[2] > $iLabelsWidth Then $iLabelsWidth = $aSize[2]

				; update control definition
				_objSet($aJSONControls[$i], "label", $aSize[0]) ; update label string update with @CRLF (to fit in calculated rectangle)
;~ 				_objSet($aJSONControls[$i], "labelWidth", $aSize[2]) ; store calculated label rectangle (useless: all labels will have $iLabelsWidth width)
				_objSet($aJSONControls[$i], "labelHeight", $aSize[3]) ; store calculated label rectangle
		EndSwitch
	Next

	; when labels max width is calculated, re-iterate over controls to resize labels
	For $i = 0 To UBound($aJSONControls) - 1
		If _objGet($aJSONControls[$i], "type") = "label" Then
			$aSize = __guiUtils_jsonParser_stringSize( _
				_objGet($aJSONControls[$i], "text"), _
				__guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), _
				$iLabelsWidth + _objGet($oJSON, "margin") + _objGet($oJSON, "inputsWidth") _
			)
			_objSet($aJSONControls[$i], "text", $aSize[0])
			_objSet($aJSONControls[$i], "width", $aSize[2])
			_objSet($aJSONControls[$i], "height", $aSize[3])
		EndIf
	Next

	; ---------------------------------------------------------------
	; build GUI
	Local $oForm = _objCreate()

	; unset WS_VISIBLE if set (will be reset in the end, after controls creation)
	$iStyle = _objGet($oJSON, "style", $GUI_SS_DEFAULT_GUI)
	If $iStyle <> -1 And BitAND($iStyle, $WS_VISIBLE) Then $iStyle -= $WS_VISIBLE

	Local $hGUI = GUICreate(_objGet($oJSON, "title"), 500, 500, -1, -1, $iStyle, _objGet($oJSON, "exStyle", -1), $hParent)

	_objSet($oForm, "hwnd", $hGUI)
	_objSet($oForm, "formName", _objGet($oJSON, "title"))

	; set GUI's font and colors
	If UBound($aGUIFont) = 4 Then
		GUISetFont($aGUIFont[0], $aGUIFont[1], $aGUIFont[2], $aGUIFont[3], $hGUI)
	Else
		; here it means that we dont have a default font because no Parent GUI has been passed.
		; we need a default font, especially for the header (for the +2 and Bold)
		$aGUIFont = _GUIUtils_GetFont($hGUI)
	EndIf

	$iColor = _objGet($oJSON, "bkColor", Null)
	If $iColor <> Null Then GUISetBkColor($iColor, $hGUI)

	$iColor = _objGet($oJSON, "defColor", Null)
	If $iColor <> Null Then GUICtrlSetDefColor($iColor, $hGUI)

	$iColor = _objGet($oJSON, "defBkColor", Null)
	If $iColor <> Null Then GUICtrlSetDefBkColor($iColor, $hGUI)

	; ---------------------------------------------------------------
	; build controls
	Local $oControls = _objCreate(), $oOptions = _objCreate(), $iCtrlID, $iLabelID
	_objSet($oForm, "controls", $oControls)
	_objSet($oForm, "options", $oOptions)

	Local $aInputs[0]

	Local $iMargin = _objGet($oJSON, "margin", 8)
	Local $iNextX = $iMargin, $iNextY = $iMargin

	Local $iMaxX = 0, $iMaxY = 0 ; will be used to calculate GUI size

	For $i = 0 To UBound($aJSONControls) - 1
		Switch _objGet($aJSONControls[$i], "type")
			Case "separator"
				; create separator
				$iCtrlID = GUICtrlCreateLabel("", _
					$iNextX, $iNextY, _
					$iLabelsWidth + $iMargin + _objGet($oJSON, "inputsWidth"), 1, _
					$SS_BLACKRECT _
				)
				_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

				; advance
				$iNextY += 1 + $iMargin

			Case "label"
				; create label
				$iCtrlID = GUICtrlCreateLabel( _
					_objGet($aJSONControls[$i], "text"), _
					$iNextX, $iNextY, _
					$iLabelsWidth + $iMargin + _objGet($oJSON, "inputsWidth"), _objGet($aJSONControls[$i], "height"), _
					_objGet($aJSONControls[$i], "style", -1), _objGet($aJSONControls[$i], "exStyle", -1) _
				)
				_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

				; advance
				$iNextY += _objGet($aJSONControls[$i], "height") + $iMargin

			Case "check", "checkbox", "radio", "radiobox"
				; calculate input height
				$aSize = __guiUtils_jsonParser_stringSize( _
					_objGet($aJSONControls[$i], "label"), _
					__guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), _
					_objGet($oJSON, "inputsWidth") _
				)

				; add multiline style if text is too long
				If StringInStr($aSize[0], @CRLF) And Not BitAND(_objGet($aJSONControls[$i], "style", 0), $BS_MULTILINE) Then
					_objSet($aJSONControls[$i], "style", BitOR(_objGet($aJSONControls[$i], "style", 0), $BS_MULTILINE))
				EndIf

				; create control (special check/radio placement)
				If StringInStr(_objGet($aJSONControls[$i], "type"), "check") Then
					; if previous control is not a checkbox, start a new group (because if previous control is a list, arrow keys will move between controls. don't know if it's a feature or a bug of WinAPI, but it seems bizarre to me)
					If $i > 0 And Not StringInStr(_objGet($aJSONControls[$i - 1], "type"), "check") Then
						_objSet($aJSONControls[$i], "style", BitOR(_objGet($aJSONControls[$i], "style", 0), $WS_GROUP))
					EndIf

					; create checkbox
					$iCtrlID = GUICtrlCreateCheckbox($aSize[0], _
						$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
						_objGet($oJSON, "inputsWidth"), $aSize[3], _
						_objGet($aJSONControls[$i], "style", -1), _objGet($aJSONControls[$i], "exStyle", -1) _
					)

					; advance
					$iNextY += $aSize[3]
					If $i >= UBound($aJSONControls) - 1 Or Not StringInStr(_objGet($aJSONControls[$i + 1], "type"), "check") Or _objGet($aJSONControls[$i], "space", False) Then $iNextY += $iMargin
				Else
					; if property group = true, add $WS_GROUP style
					; also, if previous control is not a radiobox, add $WS_GROUP style
					If (_objGet($aJSONControls[$i], "group", False) And Not BitAND(_objGet($aJSONControls[$i], "style", 0), $WS_GROUP)) Or ($i > 0 And Not StringInStr(_objGet($aJSONControls[$i - 1], "type"), "radio")) Then
						_objSet($aJSONControls[$i], "style", BitOR(_objGet($aJSONControls[$i], "style", 0), $WS_GROUP))
					EndIf

					; create radiobox
					$iCtrlID = GUICtrlCreateRadio($aSize[0], _
						$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
						_objGet($oJSON, "inputsWidth"), $aSize[3], _
						_objGet($aJSONControls[$i], "style", 0), _objGet($aJSONControls[$i], "exStyle", -1) _
					)

					; advance
					$iNextY += $aSize[3]
					If $i >= UBound($aJSONControls) - 1 Or Not StringInStr(_objGet($aJSONControls[$i + 1], "type"), "radio") Or _objGet($aJSONControls[$i], "space", False) Then $iNextY += $iMargin
				EndIf
				_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

				; set checked
				If _objGet($aJSONControls[$i], "value", False) Then
					GUICtrlSetState($iCtrlID, $GUI_CHECKED)
				EndIf

				; add to inputs list
				_ArrayAdd($aInputs, _objGet($aJSONControls[$i], "id"))

			Case Else ; means all controls that have a separate label
				; create label
				$iLabelID = GUICtrlCreateLabel( _
					_objGet($aJSONControls[$i], "label"), _
					$iNextX, $iNextY + _objGet($oJSON, "inputLabelVerticalPadding"), _
					$iLabelsWidth, _objGet($aJSONControls[$i], "labelHeight"), _
					_objGet($aJSONControls[$i], "labelStyle", $SS_RIGHT), _objGet($aJSONControls[$i], "labelExStyle", -1) _
				)
				_objSet($oControls, _objGet($aJSONControls[$i], "id") & "_label", $iLabelID)

				; set label font and colors
				__guiUtils_jsonParser_controlSetFontAndColors( _
					$iLabelID, _
					__guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont, "labelFont"), _
					_objGet($aJSONControls[$i], "labelColor", Null), _
					_objGet($aJSONControls[$i], "labelBkColor", Null) _
				)

				; create control
				Switch _objGet($aJSONControls[$i], "type")
					Case "input", "password"
						; calculate input height
						$iInputHeight = __guiUtils_jsonParser_stringSize("A", __guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), 0)
						$iInputHeight = $iInputHeight[3] + 4

						; check if password
						$iStyle = _objGet($aJSONControls[$i], "style", $GUI_SS_DEFAULT_INPUT)
						If _objGet($aJSONControls[$i], "type") = "password" And Not BitAND($iStyle, $ES_PASSWORD) Then $iStyle += $ES_PASSWORD

						; create control
						$iCtrlID = GUICtrlCreateInput( _
							_objGet($aJSONControls[$i], "value", ""), _
							$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
							_objGet($oJSON, "inputsWidth"), $iInputHeight, _
							$iStyle, _objGet($aJSONControls[$i], "exStyle", -1) _
						)
						_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

						; placeholder
						$sPlaceholder = _objGet($aJSONControls[$i], "placeholder")
						If $sPlaceholder Then _GUICtrlEdit_SetCueBanner(GUICtrlGetHandle(-1), $sPlaceholder, True)

					Case "edit", "text"
						; calculate input height
						$iInputHeight = __guiUtils_jsonParser_stringSize( _
							StringStripWS(_StringRepeat("Line" & @CRLF, _objGet($aJSONControls[$i], "lines", 3)), 3), _
							__guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), _
							0 _
						)
						$iInputHeight = $iInputHeight[3] + _objGet($aJSONControls[$i], "lines", 3) + (BitAND(_objGet($aJSONControls[$i], "style", $GUI_SS_DEFAULT_EDIT), $WS_HSCROLL) ? _WinAPI_GetSystemMetrics($SM_CYHSCROLL) : 0)

						; create edit
						$iCtrlID = GUICtrlCreateEdit( _
							_objGet($aJSONControls[$i], "value", ""), _
							$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
							_objGet($oJSON, "inputsWidth"), $iInputHeight, _
							_objGet($aJSONControls[$i], "style", BitOR($ES_WANTRETURN, $WS_VSCROLL, $ES_AUTOVSCROLL)), _
							_objGet($aJSONControls[$i], "exStyle", -1) _
						)
						_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

					Case "combo", "combobox"
						; calculate input height
						$iInputHeight = __guiUtils_jsonParser_stringSize("A", __guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), 0)
						$iInputHeight = $iInputHeight[3] + 4

						; set control style
						$iStyle = _objGet($aJSONControls[$i], "style", $GUI_SS_DEFAULT_COMBO)
						If _objExists($aJSONControls[$i], "editable") Then
							If _objGet($aJSONControls[$i], "editable") Then
								If Not BitAND($iStyle, $CBS_DROPDOWN) Then $iStyle += $CBS_DROPDOWN
							Else
								Switch BitAND($iStyle, $CBS_DROPDOWNLIST) ; because $CBS_DROPDOWNLIST (3) = $CBS_DROPDOWN (2) + $CBS_SIMPLE (1)
									Case $CBS_DROPDOWN
										$iStyle += $CBS_SIMPLE
									Case 0
										$iStyle += $CBS_DROPDOWNLIST
								EndSwitch
							EndIf
						EndIf

						; create control
						$iCtrlID = GUICtrlCreateCombo("", _
							$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
							_objGet($oJSON, "inputsWidth"), $iInputHeight, _
							$iStyle, _objGet($aJSONControls[$i], "exStyle", -1) _
						)
						_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

						; placeholder
						$sPlaceholder = _objGet($aJSONControls[$i], "placeholder")
						If $sPlaceholder Then _GUICtrlEdit_SetCueBanner(GUICtrlGetHandle(-1), $sPlaceholder, True)

						; fill options
						$vOptions = __guiUtils_jsonParser_getArray($aJSONControls[$i], "options", Null)
						If UBound($vOptions) > 0 Then GUICtrlSetData(-1, "|" & _ArrayToString($vOptions, Opt("GUIDataSeparatorChar")))

						; set initial selection
						$vValue = _objGet($aJSONControls[$i], "value", Null)
						If $vValue <> Null Then
							If IsInt($vValue) Then
								_GUICtrlComboBox_SetCurSel(GUICtrlGetHandle(-1), Int($vValue))
							Else
								$vValue = _GUICtrlComboBox_FindStringExact(GUICtrlGetHandle(-1), String($vValue))
								If $vValue >= 0 Then
									_GUICtrlComboBox_SetCurSel(GUICtrlGetHandle(-1), Int($vValue))
								Else
									_GUICtrlComboBox_SetEditText(GUICtrlGetHandle(-1), String($vValue))
								EndIf
							EndIf
						EndIf

						; set extendedUI
						_GUICtrlComboBox_SetExtendedUI(GUICtrlGetHandle(-1), _objGet($aJSONControls[$i], "extendedUI", True))

					Case "list", "listbox"
						; get lines count
						$vOptions = __guiUtils_jsonParser_getArray($aJSONControls[$i], "options", Null)

						$iLines = _objGet($aJSONControls[$i], "lines", UBound($vOptions))
						If $iLines <= 0 Then $iLines = 3
						If _objGet($aJSONControls[$i], "maxLines", 0) > 0 And $iLines > _objGet($aJSONControls[$i], "maxLines") Then $iLines = _objGet($aJSONControls[$i], "maxLines")

						; set control style
						$iStyle = _objGet($aJSONControls[$i], "style", BitOR($WS_BORDER,$WS_VSCROLL,$LBS_MULTIPLESEL,$LBS_NOINTEGRALHEIGHT))
						If _objExists($aJSONControls[$i], "multisel") Then
							If _objGet($aJSONControls[$i], "multisel") Then
								If Not BitAND($iStyle, $LBS_MULTIPLESEL) Then $iStyle += $LBS_MULTIPLESEL
							Else
								If BitAND($iStyle, $LBS_MULTIPLESEL) Then $iStyle -= $LBS_MULTIPLESEL
							EndIf
						EndIf

						; calculate input height
						$iInputHeight = __guiUtils_jsonParser_stringSize(StringStripWS(_StringRepeat("Line" & @CRLF, $iLines), 3), __guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), 0)
						$iInputHeight = $iInputHeight[3] + $iLines + (BitAND($iStyle, $WS_HSCROLL) ? _WinAPI_GetSystemMetrics($SM_CYHSCROLL) : 0)

						; create control
						$iCtrlID = GUICtrlCreateList("", _
							$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
							_objGet($oJSON, "inputsWidth"), $iInputHeight, _
							$iStyle, _objGet($aJSONControls[$i], "exStyle", -1) _
						)
						_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

						; fill options
;~ 						$vOptions = __guiUtils_jsonParser_getArray($aJSONControls[$i], "options", Null) ; get $vOptions before calculating control height
						If UBound($vOptions) > 0 Then GUICtrlSetData(-1, _ArrayToString($vOptions, Opt("GUIDataSeparatorChar")))

						; set initial selection
						$aValues = __guiUtils_jsonParser_getArray($aJSONControls[$i], "value", Null)
						If UBound($aValues) > 0 Then
							If BitAND($iStyle, $LBS_MULTIPLESEL) Then
								; multiselect listbox: select all elements
								For $j = 0 To UBound($aValues) - 1
									If Not IsInt($aValues[$j]) Then $aValues[$j] = _GUICtrlListBox_FindString(GUICtrlGetHandle(-1), String($aValues[$j]), True)
									If $aValues[$j] >= 0 Then _GUICtrlListBox_SetSel(GUICtrlGetHandle(-1), $aValues[$j], True)
								Next
							Else
								; singleselect listbox: select only one element
								If Not IsInt($aValues[0]) Then $aValues[0] = _GUICtrlListBox_FindString(GUICtrlGetHandle(-1), String($aValues[0]), True)
								If $aValues[0] >= 0 Then _GUICtrlListBox_SetCurSel(GUICtrlGetHandle(-1), $aValues[0])
							EndIf
						EndIf

					Case "date", "datepick", "datepicker"
						; calculate input height
						$iInputHeight = __guiUtils_jsonParser_stringSize("A", __guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), 0)
						$iInputHeight = $iInputHeight[3] + 4

						; set style
						$iStyle = _objGet($aJSONControls[$i], "style", $DTS_SHORTDATEFORMAT)
						If _objGet($aJSONControls[$i], "nullable", False) And Not BitAND($iStyle, $DTS_SHOWNONE) Then
							$iStyle = BitOR($iStyle, $DTS_SHOWNONE)
						EndIf

						; create control
						$iCtrlID = GUICtrlCreateDate( _
							_objGet($aJSONControls[$i], "value"), _
							$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
							_objGet($oJSON, "inputsWidth"), $iInputHeight, _
							$iStyle, _objGet($aJSONControls[$i], "exStyle", -1) _
						)
						_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

						; store options
						If _objExists($aJSONControls[$i], "format") Then
							_objSet($oOptions, _objGet($aJSONControls[$i], "id") & "_format", _objGet($aJSONControls[$i], "format"))
						EndIf

					Case "time", "timepick", "timepicker"
						; calculate input height
						$iInputHeight = __guiUtils_jsonParser_stringSize("A", __guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), 0)
						$iInputHeight = $iInputHeight[3] + 4

						; set style
						$iStyle = _objGet($aJSONControls[$i], "style", $DTS_TIMEFORMAT)
						If _objGet($aJSONControls[$i], "nullable", False) And Not BitAND($iStyle, $DTS_SHOWNONE) Then
							$iStyle = BitOR($iStyle, $DTS_SHOWNONE)
						EndIf

						; create control
						$iCtrlID = GUICtrlCreateDate( _
							_objGet($aJSONControls[$i], "value"), _
							$iNextX + $iLabelsWidth + $iMargin, $iNextY, _
							_objGet($oJSON, "inputsWidth"), $iInputHeight, _
							$iStyle, _objGet($aJSONControls[$i], "exStyle", -1) _
						)
						_objSet($oControls, _objGet($aJSONControls[$i], "id"), $iCtrlID)

						; store options
						If _objExists($aJSONControls[$i], "format") Then
							_objSet($oOptions, _objGet($aJSONControls[$i], "id") & "_format", _objGet($aJSONControls[$i], "format"))
						EndIf
				EndSwitch

				; add to inputs list
				_ArrayAdd($aInputs, _objGet($aJSONControls[$i], "id"))

				; advance
				$iNextY += _Max(_objGet($aJSONControls[$i], "labelHeight"), $iInputHeight) + $iMargin
		EndSwitch

		; set tooltip
		__guiUtils_jsonParser_controlSetTip($iCtrlID, $aJSONControls[$i])

		; set control font and colors
		__guiUtils_jsonParser_controlSetFontAndColors( _
			$iCtrlID, _
			__guiUtils_jsonParser_getFont($aJSONControls[$i], $aGUIFont), _
			_objGet($aJSONControls[$i], "color", Null), _objGet($aJSONControls[$i], "bkColor", Null) _
		)

		; check if new column is needed
		If _objGet($aJSONControls[$i], "new_col", False) Or (_objGet($aJSONControls[$i], "type") <> "separator" And $iNextY >= _objGet($oJSON, "maxHeight")) Then
			$iNextY = $iMargin
			$iNextX = $iNextX + $iMargin + $iLabelsWidth + $iMargin + _objGet($oJSON, "inputsWidth") + $iMargin
		EndIf

		; calculate GUI size
		If $iCtrlID > 0 Then
			$aPos = ControlGetPos($hGUI, "", $iCtrlID)
			$iMaxX = _Max($aPos[0] + $aPos[2], $iMaxX)
			$iMaxY = _Max($aPos[1] + $aPos[3], $iMaxY)
			$iCtrlID = 0
		EndIf
		If $iLabelID > 0 Then
			$aPos = ControlGetPos($hGUI, "", $iLabelID)
			$iMaxX = _Max($aPos[0] + $aPos[2], $iMaxX)
			$iMaxY = _Max($aPos[1] + $aPos[3], $iMaxY)
			$iLabelID = 0
		EndIf
	Next

	_objSet($oForm, "inputs", $aInputs)

	; ---------------------------------------------------------------

	; bottom separator
	_objSet( _
		$oControls, "footerSeparator", _
		GUICtrlCreateLabel("", $iMargin, $iMaxY + $iMargin, $iMaxX - $iMargin, 1, $SS_BLACKRECT) _
	)
	$iMaxY += $iMargin + 1

	; submit button (mandatory)
	$oSubmitBtn = _objGet($oJSON, "submitBtn", "OK")
	If $oSubmitBtn And Not IsObj($oSubmitBtn) Then
		$oSubmitBtn = _objCreate()
		_objSet($oSubmitBtn, "text", _objGet($oJSON, "submitBtn"))
	EndIf

	_objSet($oControls, "submitBtn", _
		GUICtrlCreateButton( _
			_objGet($oSubmitBtn, "text", "OK"), _
			$iMaxX - _objGet($oSubmitBtn, "width", 100), $iMaxY + $iMargin, _
			_objGet($oSubmitBtn, "width", 100), _objGet($oSubmitBtn, "height", 25), _
			_objGet($oSubmitBtn, "style", $BS_DEFPUSHBUTTON), _objGet($oSubmitBtn, "exStyle", -1) _
		) _
	)
	__guiUtils_jsonParser_controlSetTip(-1, $oSubmitBtn)

	_objSet($oForm, "submitBtn", "submitBtn")

	$iButtonsWidth = _objGet($oSubmitBtn, "width", 100)

	; cancel button (optional)
	$oCancelBtn = _objGet($oJSON, "cancelBtn", Null)
	If $oCancelBtn Or IsObj($oCancelBtn) Then
		If Not IsObj($oCancelBtn) Then
			$oCancelBtn = _objCreate()
			_objSet($oCancelBtn, "text", _objGet($oJSON, "cancelBtn"))
		EndIf

		_objSet($oControls, "cancelBtn", _
			GUICtrlCreateButton( _
				_objGet($oCancelBtn, "text", "Cancel"), _
				$iMaxX - _objGet($oSubmitBtn, "width", 100) - $iMargin - _objGet($oCancelBtn, "width", 80), $iMaxY + $iMargin, _
				_objGet($oCancelBtn, "width", 80), _objGet($oCancelBtn, "height", 25), _
				_objGet($oCancelBtn, "style", -1), _objGet($oCancelBtn, "exStyle", -1) _
			) _
		)
		__guiUtils_jsonParser_controlSetTip(-1, $oCancelBtn)

		_objSet($oForm, "cancelBtn", "cancelBtn")

		$iButtonsWidth += _objGet($oCancelBtn, "width", 80) + $iMargin
	EndIf

	$iMaxY += _objGet($oSubmitBtn, "height", 25) + $iMargin

	; header
	$oHeader = _objGet($oJSON, "header", Null)
	If $oHeader And Not IsObj($oHeader) Then
		$oHeader = _objCreate()
		_objSet($oHeader, "text", _objGet($oJSON, "header"))
	EndIf

	If _objGet($oHeader, "text", "") Then
		$aHeaderFont = $aGUIFont
		If IsArray($aHeaderFont) Then
			$aHeaderFont[0] += 2
			$aHeaderFont[1] = 800
		EndIf
		$aHeaderFont = __guiUtils_jsonParser_getFont($oHeader, $aHeaderFont)

		$aSize = __guiUtils_jsonParser_stringSize(_objGet($oHeader, "text"), $aHeaderFont, $iMaxX)

		$iHeaderLabel = GUICtrlCreateLabel($aSize[0], _
			$iMargin, $iMargin, $iMaxX, $aSize[3], _
			_objGet($oHeader, "style", $SS_CENTER), _objGet($oHeader, "exStyle", -1) _
		)
		__guiUtils_jsonParser_controlSetTip(-1, $oHeader)

		$iHeaderSeparator = GUICtrlCreateLabel("", $iMargin, $iMargin + $aSize[3] + $iMargin, $iMaxX - $iMargin, 1, $SS_BLACKRECT)


		__guiUtils_jsonParser_controlSetFontAndColors($iHeaderLabel, $aHeaderFont, _objGet($oHeader, "color", Null), _objGet($oHeader, "bkColor", Null))

		; move all controls to make place for the header and its separator
		For $sKey In _objKeys($oControls)
			$aPos = ControlGetPos($hGUI, "", _objGet($oControls, $sKey))
			GUICtrlSetPos(_objGet($oControls, $sKey), $aPos[0], $aPos[1] + $aSize[3] + $iMargin + 1 + $iMargin)
		Next
		$iMaxY += $aSize[3] + $iMargin + 1 + $iMargin

		; add header controls to form (AFTER moving other controls)
		_objSet($oControls, "headerLabel", $iHeaderLabel)
		_objSet($oControls, "headerSeparator", $iHeaderSeparator)
	EndIf

	; ---------------------------------------------------------------
	; resize GUI
	Local $tRect = _WinAPI_CreateRect(0, 0, $iMaxX + $iMargin, $iMaxY + $iMargin)
	_WinAPI_AdjustWindowRectEx($tRect, _objGet($oJSON, "style", $GUI_SS_DEFAULT_GUI), _objGet($oJSON, "exStyle", 0))
	$tRect.Right = Abs($tRect.Left) + Abs($tRect.Right)
	$tRect.Bottom = Abs($tRect.Top) + Abs($tRect.Bottom)

	WinMove($hGUI, "", (@DesktopWidth / 2) - ($tRect.Right / 2), (@DesktopHeight / 2) - ($tRect.Bottom / 2), $tRect.Right, $tRect.Bottom)

	; ---------------------------------------------------------------
	; show GUI if WS_VISIBLE is set
	If BitAND(_objGet($oJSON, "style", 0), $WS_VISIBLE) Then GUISetState(@SW_SHOW, $hGUI)

	; store/set initial focused control name
	; used by _GUIUtils_InputDialog
	If _objExists($oJSON, "focus") Then
		ControlFocus($hGUI, "", _objGet($oControls, _objGet($oJSON, "focus")))
		_objSet($oForm, "initialFocus", _objGet($oJSON, "focus"))
	EndIf

	; store oForm object and return
	_objSet($__gGuiUtils_oForms, _GUIUtils_HWnd($oForm), $oForm, True)
	Return $oForm
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================

# =================================================================================================
#Region - InputBox behaviour
# =================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_InputDialog
; Description ...: Takes a KODA/JSON created GUI, defined by it's representing object $oForm, and displays it as a modal input
;                  dialog box.
; Syntax ........: _GUIUtils_InputDialog($oForm[, $oInitialData = Null[, $fnOnSubmit = Null[, $fnOnInit = Null[,
;                  $fnOnChange = Null[, $vUserData = Null]]]]])
; Parameters ....: $oForm               - GUI object.
;                  $oInitialData        - [optional] initial inputs data ({inputName: inputData, ...}). Default is Null.
;                  $fnOnSubmit          - [optional] function called when user press dialog's OK button. Default is Null.
;                  $fnOnInit            - [optional] function called just before showing the input, when initial data is filled.
;                                                    Default is Null.
;                  $fnOnChange          - [optional] function called when the data of some input is changed. Default is Null.
;                  $vUserData           - [optional] user data that is passed to callback functions. Default is Null.
; Return values .: Object containing inputs data ({inputName: inputData, ...})
;                  Or Null and @error = 1 if dialog canceled
; Author ........: matwachich
; Remarks .......:
;                  - About inputs:
;                    -------------
;                    by default, all supported inputs will be writen/read by the function. Supported inputs are:
;                    input, edit, combobox, listbox, checkbox, radio, dateTimePicker.
;                    Or, if you want to write/read only a subset of input controls, you can specify them by using
;                    _GUIUtils_SetInputs($oForm, inputControlNames)
;
;                  - About validation and cancelling buttons:
;                    ----------------------------------------
;                    by default, if the GUI contains a DEFPUSHBUTTON it will be used as validation button.
;                    If it doesn't contain any DEFBUSHBUTTON, you MUST define the validation button you want to use by calling
;                    _GUIUtils_SetButtons().
;                    You can also use _GUIUtils_SetButtons() to define a cancel button control, but it is not mandatory.
;
;                  - About initial dialog data:
;                    --------------------------
;                    You can set initial data for input controls by passing $oInitialData an object: {controlName: data...}.
;                    See _GUIUtils_WriteItems remarks about data format of each control type.
;                  - You can also set the initially focused input control by specifying "controlName:focus" = True in the
;                    initial data object.
;
;                  - About callback functions:
;                    -------------------------
;                    This function accepts 3 callback functions, none of them is mendatory.
;                    All of them takes 3 parameters: $oForm, $vData, $vUserData. $oForm and $vUserData dont need further
;                    explanations. $vData is different for each callback.
;                      - $fnOnSubmit:
;                        if set, this callback is called when Validation Button is pressed.
;                        $vData is an object containing all inputs values ({inputName: inputData, ...}).
;                        you can check the data for validity and completeness in this function, then return:
;                        (> 0) to validate them (the dialog will be closed and the data returned)
;                        (< 0) to close dialog, but returning Null and @error = 1
;                        (= 0) to do nothing (keep dialog open)
;                      - $fnOnInit:
;                        if set, this callback is called after $oInitialData is filled into the dialog inputs, and just before
;                        the dialog is shown.
;                        $vData is an object containing all inputs values ({inputName: inputData, ...}).
;                      - $fnOnChange:
;                        if set, called every time the content/data of an input control gets changed.
;                        $vData is the inputName of the modified control
; =================================================================================================
Func _GUIUtils_InputDialog($oForm, $oInitialData = Null, $fnOnSubmit = Null, $fnOnInit = Null, $fnOnChange = Null, $vUserData = Null)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, Null)

	; get input control names as an array
	Local $aInputCtrlNames = _objGet($oForm, "inputs", Null)
	If $aInputCtrlNames = Null Then
		$aInputCtrlNames = __guiUtils_getSupportedInputsList($oForm)
		; store for further use
		_objSet($oForm, "inputs", $aInputCtrlNames)
	Else
		If Not IsArray($aInputCtrlNames) Then
			; convert string to array, and store it in this form (optimisation)
			$aInputCtrlNames = StringSplit($aInputCtrlNames, " ,-|" & Opt("GUIDataSeparatorChar"))
			_ArrayDelete($aInputCtrlNames, 0)
		EndIf
	EndIf

	If UBound($aInputCtrlNames) <= 0 Then Return SetError(1, 0, Null) ; impossible to make an InputDialog without input controls

	; check submitBtn
	Local $sSubmitBtnName = _objGet($oForm, "submitBtn", Null)
	If $sSubmitBtnName = Null Then
		; search for any DEFPUSHBUTTON and set it as submitBtn
		Local $aCtrlList = _objKeys(_GUIUtils_CtrlList($oForm)), $iStyle
		For $i = 0 To UBound($aCtrlList) - 1
			$iStyle = _WinAPI_GetWindowLong(_GUIUtils_HCtrl($oForm, $aCtrlList[$i]), $GWL_STYLE)
			If _WinAPI_GetClassName(_GUIUtils_HCtrl($oForm, $aCtrlList[$i])) = "Button" And Not BitAND($iStyle, $BS_CHECKBOX) And BitAND($iStyle, $BS_DEFPUSHBUTTON) Then ; must be a button, must not be a check/radio, and must have DEFPUSHBUTTON style
				$sSubmitBtnName = $aCtrlList[$i]
				ExitLoop
			EndIf
		Next
		; or return ERROR (cannot handle an input dialog box without submitBtn)
		If Not $sSubmitBtnName Then Return SetError(1, 0, Null)
	EndIf

	; get cancelBtnID
	Local $iCancelBtnID = $GUI_EVENT_CLOSE
	If _objExists($oForm, "cancelBtn") Then
		$iCancelBtnID = _GUIUtils_CtrlID($oForm, _objGet($oForm, "cancelBtn"))
	EndIf

	; set subclass (to catch modifications and send them to caller)
	Local $pfnSubclassProc = DllCallbackRegister("__guiUtils_inputDialog_subClassProc", "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
	_WinAPI_SetWindowSubclass(_GUIUtils_HWnd($oForm), DllCallbackGetPtr($pfnSubclassProc), 1000)

	; create a dummy control that will be used to notify about controls content/data change
	Local $hPreviousGUI = GUISwitch(_GUIUtils_HWnd($oForm))
	If Not _objExists($oForm, "###___onChangeDummy") Then _objSet($oForm, "###___onChangeDummy", GUICtrlCreateDummy())

	; set controls initial data if provided (don't use _GUIUtils_WriteInputs because it doesn't support focus control)
	Local $sInitialFocus = ""
	If IsObj($oInitialData) Then
		For $i = 0 To UBound($aInputCtrlNames) - 1
			__guiUtils_inputDialog_controlSet( _
				$oForm, $aInputCtrlNames[$i], _
				_objGet($oInitialData, $aInputCtrlNames[$i], Null), _
				_objGet($oInitialData, $aInputCtrlNames[$i] & ":options", Null) _
			)
			If _objGet($oInitialData, $aInputCtrlNames[$i] & ":focus", False) Then $sInitialFocus = $aInputCtrlNames[$i]
		Next
	EndIf

	; always save initially focused control, and restore it after
	Local $focusCtrl = ControlGetFocus(_GUIUtils_HWnd($oForm))

	; then, set focus
	If $sInitialFocus Then
		; either to the control provided in $oInitialData
		ControlFocus(_GUIUtils_HWnd($oForm), "", _GUIUtils_CtrlID($oForm, $sInitialFocus))
	Else
		; or to the focused control when the Form was created, or lastly, to the first input control
		ControlFocus(_GUIUtils_HWnd($oForm), "", _GUIUtils_CtrlID($oForm, _objGet($oForm, "initialFocus", $aInputCtrlNames[0])))
	EndIf

	; call onInit
	If IsFunc($fnOnInit) Then
		$fnOnInit($oForm, _GUIUtils_ReadInputs($oForm), $vUserData)
	EndIf

	; show and activate window
	$__gGuiUtils_inputDialog_oCurrentForm = $oForm
	GUISetState(@SW_SHOW, _GUIUtils_HWnd($oForm))
	WinActivate(_GUIUtils_HWnd($oForm))

	; set close on Escape
	$iOldCloseOnEscValue = Opt("GUICloseOnEsc", 1)

	; enter main loop
	Local $aMsg, $oRead = _objCreate(), $iError = 0
	While 1
		$aMsg = GUIGetMsg(1)
		If $aMsg[1] = _GUIUtils_HWnd($oForm) Then
			Switch $aMsg[0]
				Case $GUI_EVENT_CLOSE, $iCancelBtnID
					; dialog canceled
					$oRead = Null
					$iError = 1
					ExitLoop
				Case _GUIUtils_CtrlID($oForm, $sSubmitBtnName)
					; read values
					_objEmpty($oRead)
					For $i = 0 To UBound($aInputCtrlNames) - 1
						_objSet($oRead, $aInputCtrlNames[$i], __guiUtils_inputDialog_controlGet($oForm, $aInputCtrlNames[$i]))
					Next

					; call validation function if needed, or exitloop directly
					If Not IsFunc($fnOnSubmit) Then
						ExitLoop
					Else
						Local $iRet = $fnOnSubmit($oForm, $oRead, $vUserData)
						Select
							Case $iRet > 0 ; return success
								ExitLoop
							Case $iRet < 0 ; return error
								$oRead = Null
								$iError = 1
								ExitLoop
							; else (0), just continu looping (do nothing)
						EndSelect
					EndIf
				Case _objGet($oForm, "###___onChangeDummy")
					$sCtrlName = GUICtrlRead(_objGet($oForm, "###___onChangeDummy"))
					If IsFunc($fnOnChange) Then
						_objSet($oForm, "__lockOnChange", True)
						$fnOnChange($oForm, $sCtrlName, $vUserData)
						_objDel($oForm, "__lockOnChange")
					EndIf
;~ 				Case 0 ; no event => ignore
;~ 				Case Else
;~ 					ConsoleWrite("onEvent:  " & $aMsg[0] & " (" & _GUIUtils_CtrlNameByID($oForm, $aMsg[0]) & ")" & @CRLF)
;~ 					If IsFunc($fnOnEvent) Then $fnOnEvent($oForm, $aMsg[0], $vUserData)
			EndSwitch
		EndIf
	WEnd

	; cleanup
	_WinAPI_RemoveWindowSubclass(_GUIUtils_HWnd($oForm), DllCallbackGetPtr($pfnSubclassProc), 1000)
	DllCallbackFree($pfnSubclassProc)

	; keep OnChangeDummy for further use
;~ 	GUICtrlDelete(_objGet($oForm, "###___onChangeDummy"))
;~ 	_objDel($oForm, "###___onChangeDummy")

	; restore initialy focused control
	If $focusCtrl <> Null Then ControlFocus(_GUIUtils_HWnd($oForm), "", $focusCtrl)

	; restore close on Escape value
	Opt("GUICloseOnEsc", $iOldCloseOnEscValue)

	; hide GUI
	GUISetState(@SW_HIDE, _GUIUtils_HWnd($oForm))
	$__gGuiUtils_inputDialog_oCurrentForm = Null

	; switch to previous GUI
	GUISwitch($hPreviousGUI)

	; reset input values
	For $i = 0 To UBound($aInputCtrlNames) - 1
		__guiUtils_inputDialog_controlSet($oForm, $aInputCtrlNames[$i], Null, Null)
	Next

	Return SetError($iError, 0, $oRead)
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================

# =================================================================================================
#Region - MultiGUIRegisterMsg
# =================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_RegisterMsg
; Description ...: Register message(s) with a single Form.
; Syntax ........: _GUIUtils_RegisterMsg($oForm[, $iMsg = Null[, $vFunc = Null]])
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKoda or _GUIUtils_CreateFromJSON).
;                  $iMsg                - [optional] Message(s) to register. If Null, all GUI's message handlers are unregistered.
;                  $vFunc               - [optional] The handler (function) to associate with the message(s). If Null, any
;                                         registered message handler is removed.
; Return values .: True
; Author ........: matwachich
; Remarks .......: This function is for when you need to have different message handlers for different forms.
; =================================================================================================
Func _GUIUtils_RegisterMsg($oForm, $iMsg = Null, $vFunc = Null)
	; retreive form object
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)

	; if $iMsg is a string, register many messages
	If IsString($iMsg) Then
		$iMsg = StringSplit($iMsg, " ,;:.-")
		For $i = 1 To $iMsg[0]
			_GUIUtils_RegisterMsg($oForm, Int($iMsg[$i]), $vFunc)
		Next
		Return True
	EndIf

	; create an object inside form object that contains: iMsg => funcName pairs
	Local $oRegMsgs = _objGet($oForm, "registerMsg", Null)
	If Not IsObj($oRegMsgs) Then
		$oRegMsgs = _objCreate()
		_objSet($oForm, "registerMsg", $oRegMsgs)
	EndIf

	; create a static object that contains registration count for each message
	; incremented on registration, decremented on deregistration
	; message is unregistred when it reaches 0
	Static $oMsgsRegCount = _objCreate()

	;
	Select
		; register one message
		Case $iMsg <> Null And $vFunc <> Null
			; store message handler with form object
			_objSet($oRegMsgs, $iMsg, IsFunc($vFunc) ? FuncName($vFunc) : String($vFunc))

			; register message and increment message registration count
			Local $iRegCount = _objGet($oMsgsRegCount, $iMsg, 0)
			If $iRegCount <= 0 Then GUIRegisterMsg(Int($iMsg), __guiUtils_registerMsgDispatcher)
			_objSet($oMsgsRegCount, $iMsg, $iRegCount + 1)
			Return True
		; ---
		; unregister one message
		Case $iMsg <> Null
			If _objExists($oRegMsgs, $iMsg) Then
				; remove message handler
				_objDel($oRegMsgs, $iMsg)

				; decrement message's registration count
				Local $iRegCount = _objGet($oMsgsRegCount, $iMsg, 0)
				$iRegCount -= 1
				If $iRegCount <= 0 Then
					GUIRegisterMsg($iMsg, "")
					_objDel($oMsgsRegCount, $iMsg)
				Else
					_objSet($oMsgsRegCount, $iMsg, $iRegCount)
				EndIf
			EndIf
			Return True
		; ---
		; unregister all messages for one GUI
		Case Else
			Local $iRegCount
			For $iMsg In _objKeys($oRegMsgs)
				; decrement messages registration count
				$iRegCount = _objGet($oMsgsRegCount, $iMsg, 0)
				$iRegCount -= 1
				If $iRegCount <= 0 Then
					GUIRegisterMsg($iMsg, "")
					_objDel($oMsgsRegCount, $iMsg)
				Else
					_objSet($oMsgsRegCount, $iMsg, $iRegCount)
				EndIf
			Next

			; remove all message handlers
			_objEmpty($oRegMsgs)
			Return True
	EndSelect
EndFunc

Func __guiUtils_registerMsgDispatcher($hWnd, $iMsg, $wParam, $lParam)
	Local $oForm = _objGet($__gGuiUtils_oForms, $hWnd, Null)
	If IsObj($oForm) Then
		Local $oRegMsgs = _objGet($oForm, "registerMsg", Null)
		If IsObj($oRegMsgs) Then
			$sFunc = _objGet($oRegMsgs, $iMsg, "")
			If $sFunc Then Return SetError(0, 1, Call($sFunc, $hWnd, $iMsg, $wParam, $lParam))
		EndIf
	EndIf
	Return SetError(0, 0, $GUI_RUNDEFMSG)
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================

# =================================================================================================
#Region - Controls Subclassing
# =================================================================================================

; TODO: document
; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_SubclassSet
; Description ...:
; Syntax ........: _GUIUtils_SubclassSet($oForm, $sCtrlName, $iSubclassID[, $fnSubclassProc = Null])
; Parameters ....: $oForm               - an object.
;                  $sCtrlName           - a string value.
;                  $iSubclassID         - an integer value.
;                  $fnSubclassProc      - [optional] a floating point value. Default is Null.
; Return values .: None
; Author ........: matwachich at gmail dot com
; Modified ......:
; Remarks .......:
; Related .......:
; Link ..........:
; Example .......: No
; =================================================================================================
Func _GUIUtils_SubclassSet($oForm, $sCtrlName, $iSubclassID, $fnSubclassProc = Null)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	Local $oSubclasses = _objGet($oForm, "subclasses", Null)
	If Not _objIsObject($oSubclasses) Then
		$oSubclasses = _objCreate()
		_objSet($oForm, "subclasses", $oSubclasses)
	EndIf

	Local $oCtrlSubclasses = _objGet($oSubclasses, $sCtrlName, Null)
	If Not _objIsObject($oCtrlSubclasses) Then
		$oCtrlSubclasses = _objCreate()
		_objSet($oSubclasses, $sCtrlName, $oCtrlSubclasses)
	EndIf

	Local $sCallback = _objGet($oCtrlSubclasses, $iSubclassID, "") ; subclassID = funcName:callbackHandle
	If $sCallback Then
		Local $hCallback = Int(StringTrimLeft($sCallback, StringInStr($sCallback, ":")))
		$sCallback = StringLeft($sCallback, StringInStr($sCallback, ":") - 1)

		If FuncName($fnSubclassProc) <> $sCallback Then
			_WinAPI_RemoveWindowSubclass(_GUIUtils_HCtrl($oForm, $sCtrlName), DllCallbackGetPtr($hCallback), $iSubclassID)
			DllCallbackFree($hCallback)
			_objDel($oCtrlSubclasses, $iSubclassID)
		Else
			Return ; nothing to do (same function)
		EndIf
	EndIf

	If IsFunc($fnSubclassProc) Then
		$hCallback = DllCallbackRegister($fnSubclassProc, "lresult", "hwnd;uint;wparam;lparam;uint_ptr;dword_ptr")
		_objSet($oCtrlSubclasses, $iSubclassID, FuncName($fnSubclassProc) & ":" & $hCallback)
		_WinAPI_SetWindowSubclass(_GUIUtils_HCtrl($oForm, $sCtrlName), DllCallbackGetPtr($hCallback), $iSubclassID)
	EndIf
	Return True
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================

# =================================================================================================
#Region - FormObject handling
# =================================================================================================

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_Destroy
; Description ...: Destroy a GUI created with _GUIUtils_CreateFromKoda or _GUIUtils_CreateFromJSON
; Syntax ........: _GUIUtils_Destroy($oForm)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKoda or _GUIUtils_CreateFromJSON).
; Return values .: Boolean
; Author ........: matwachich
; Remarks .......: You MUST use this function to destroy a form created with this UDF.
; =================================================================================================
Func _GUIUtils_Destroy($oForm)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	; unregister messages
	_GUIUtils_RegisterMsg($oForm)

	; remove Form from global store
	_objDel($__gGuiUtils_oForms, _GUIUtils_HWnd($oForm))

	; delete GUI
	GUIDelete(_GUIUtils_HWnd($oForm))
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_ListForms
; Description ...: Returns the global Scripting.Dictionary containing HWnd:oFormObject pairs.
; Syntax ........: _GUIUtils_ListForms()
; Parameters ....: None
; Return values .: Object { HWnd (as string): formObject, ... }
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_ListForms()
	Return $__gGuiUtils_oForms
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_SetAccels
; Description ...: Set accelerators.
; Syntax ........: _GUIUtils_SetAccels($oForm, $vAccels)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA).
;                  $vAccels             - Either an array (similar format as GUISetAccelerators), or a boolean (see remarks).
; Return values .: Success: 1 - Failure: 0
; Author ........: matwachich
; Remarks .......: $vAccels array format: $array[][] = [["hotkey", "controlName"], ...]
;                  When first setting accelerators array, it is saved in $oForm objet.
;                  Later on, you can just set $vAccels to True or False to activate or deactivate accelerators.
; =================================================================================================
Func _GUIUtils_SetAccels($oForm, $vAccels)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	If IsArray($vAccels) Then
		For $i = 0 To UBound($vAccels) - 1
			$vAccels[$i][1] = _GUIUtils_CtrlID($oForm, $vAccels[$i][1])
		Next
		_objSet($oForm, "accelerators", $vAccels)
		Return GUISetAccelerators($vAccels, _GUIUtils_HWnd($oForm))
	Else
		If $vAccels Then
			Return GUISetAccelerators(_objGet($oForm, "accelerators", False), _GUIUtils_HWnd($oForm))
		Else
			Return GUISetAccelerators(False, _GUIUtils_HWnd($oForm))
		EndIf
	EndIf
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_HWnd
; Description ...: Get GUI's HWnd.
; Syntax ........: _GUIUtils_HWnd($oForm)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA).
; Return values .: HWnd
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_HWnd($oForm)
	If IsHWnd($oForm) Then Return $oForm

	Return Hwnd(_objGet($oForm, "hwnd", Null))
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_FormObject
; Description ...: Get formObject from a GUI handle.
; Syntax ........: _GUIUtils_FormObject($oForm)
; Parameters ....: $oForm               - GUI handle.
; Return values .: Form Object
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_FormObject($oForm)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	Return $oForm
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_FormName
; Description ...: Get Form name (as defined in KODA, or winTitle for JSON dialogs).
; Syntax ........: _GUIUtils_FormName($oForm)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA).
; Return values .: Form name
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_FormName($oForm)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, "")

	Return _objGet($oForm, "formName", "")
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CtrlSet
; Description ...: Store or replace a user created control in the $oForm object.
; Syntax ........: _GUIUtils_CtrlSet($oForm, $sCtrlName, $iCtrlID_or_hCtrl[, $bOverwrite = True[, $bDeleteIfExists = True]])
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sCtrlName           - control name.
;                  $iCtrlID_or_hCtrl    - controlID (standard controls) or controlHandle (UDF controls) of the control to store.
;                  $bOverwrite          - [optional] if False and the $sCtrlName already exists, nothing is modified.
;                                         Default is True.
;                  $bDeleteIfExists     - [optional] if True and $sCtrlName already exists, it is destroyed using GUICtrlDelete
;                                         (for standard control) and _WinAPI_DestroyWindow (for UDF control).
;                                         Default is True.
; Return values .: Boolean
; Author ........: matwachich
; Remarks .......: This function is usefull to add custom (UDF for example) controls to a $oForm.
;                  Dont worry about passing a CtrlID or HCtrl, both are handled correctly, and you will be able to normaly use
;                  _GUIUtils_CtrlID and _GUIUtils_HCtrl.
; =================================================================================================
Func _GUIUtils_CtrlSet($oForm, $sCtrlName, $iCtrlID_or_hCtrl, $bOverwrite = True, $bDeleteIfExists = True)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	Local $oControls = _objGet($oForm, "controls", Null)
	Local $bExists = _objExists($oControls, $sCtrlName)

	If Not $bOverwrite And $bExists Then Return False

	If $bDeleteIfExists And $bExists Then
		GUICtrlDelete(_GUIUtils_CtrlID($oForm, $sCtrlName))
		_WinAPI_DestroyWindow(_GUIUtils_HCtrl($oForm, $sCtrlName))
		_objDel($oControls, $sCtrlName)
	EndIf

	If IsPtr($iCtrlID_or_hCtrl) Or IsHWnd($iCtrlID_or_hCtrl) Then $iCtrlID_or_hCtrl = _WinAPI_GetDlgCtrlID($iCtrlID_or_hCtrl)
	_objSet($oControls, $sCtrlName, $iCtrlID_or_hCtrl)
	Return True
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CtrlID
; Description ...: Get control ID by name.
; Syntax ........: _GUIUtils_CtrlID($oForm, $sCtrlName)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sCtrlName           - control name.
; Return values .: ControlID, or -1 if not found or error
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_CtrlID($oForm, $sCtrlName)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, -1)

	Local $iCtrlID = Int(_objGet(_objGet($oForm, "controls", Null), $sCtrlName, -1))
	If $iCtrlID == -1 Then ConsoleWrite("!!! Accessing invalid Ctrl: " & $sCtrlName & @CRLF)
	Return $iCtrlID
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CtrlNameByID
; Description ...: Find control name by ID.
; Syntax ........: _GUIUtils_CtrlNameByID($oForm, $iCtrlID)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $iCtrlID             - control ID.
; Return values .: Control name or empty string if not found or error
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_CtrlNameByID($oForm, $iCtrlID)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, "")

	Local $oControls = _objGet($oForm, "controls", Null)
	If Not IsObj($oControls) Then Return SetError(1, 0, "")

	For $sKey In $oControls.Keys()
		If $oControls.Item($sKey) = $iCtrlID Then Return $sKey
	Next
	Return ""
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_HCtrl
; Description ...: Get control handle by name.
; Syntax ........: _GUIUtils_HCtrl($oForm, $sCtrlName)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sCtrlName           - control name.
; Return values .: Control handle or 0 if not found or error
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_HCtrl($oForm, $sCtrlName)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, 0)

	Local $iCtrlID = _GUIUtils_CtrlID($oForm, $sCtrlName)
	If $iCtrlID = -1 Then Return Null

	Local $hCtrl = GUICtrlGetHandle($iCtrlID)
	If Not $hCtrl Then $hCtrl = _WinAPI_GetDlgItem(_GUIUtils_HWnd($oForm), $iCtrlID) ; this is to support custom UDF created controls
	Return $hCtrl
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CtrlNameByHandle
; Description ...: Find control name by handle.
; Syntax ........: _GUIUtils_CtrlNameByHandle($oForm, $hCtrl)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $hCtrl               - control handle.
; Return values .: Control name or empty string if not found or error
; Author ........: matwahich
; =================================================================================================
Func _GUIUtils_CtrlNameByHandle($oForm, $hCtrl)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, "")

	Local $oControls = _objGet($oForm, "controls", Null)
	If Not IsObj($oControls) Then Return SetError(1, 0, "")

	For $sKey In $oControls.Keys()
		If GUICtrlGetHandle($oControls.Item($sKey)) = $hCtrl Then Return $sKey
	Next
	Return ""
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CtrlList
; Description ...: Get an array of control names.
; Syntax ........: _GUIUtils_CtrlList($oForm)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
; Return values .: Object {controlName: controlID, ...}
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_CtrlList($oForm)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, Null)

	Return _objGet($oForm, "controls", Null)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CtrlChildren
; Description ...: Get $sCtrlName children (if any).
; Syntax ........: _GUIUtils_CtrlChildren($oForm, $sCtrlName)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA).
;                  $sCtrlName           - control name (group, controlGroup, tab or tabSheet).
; Return values .: Object {controlName: controlID, ...}
; Author ........: matwachich
; Remarks .......: Only forms created by _GUIUtils_CreateFromKODA will have children controls set for some kind of controls.
;                  These kind of controls (who have children) are: group, controlGroup, tab, and tabSheet
; =================================================================================================
Func _GUIUtils_CtrlChildren($oForm, $sCtrlName)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, Null)

	Local $oChildrenLists = _objGet($oForm, "childrenLists", Null)
	If Not IsObj($oChildrenLists) Then Return SetError(1, 0, Null)

	Local $aChildrenNames = _objGet($oForm, $sCtrlName, Null)
	If Not IsArray($aChildrenNames) Then Return Null

	Local $oRet = _objCreate()
	For $i = 0 To UBound($aChildrenNames) - 1
		_objSet($oRet, $aChildrenNames[$i], _GUIUtils_CtrlID($oForm, $aChildrenNames[$i]))
	Next
	Return $oRet
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_UserDataSet
; Description ...: Associate $vValue named $sItemName to $oForm.
; Syntax ........: _GUIUtils_UserDataSet($oForm, $sItemName, $vValue[, $bOverwrite = True])
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sItemName           - value name.
;                  $vValue              - the value to associate.
;                  $bOverwrite          - [optional] overwrite existing value. Default is True.
; Return values .: None
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_UserDataSet($oForm, $sItemName, $vValue, $bOverwrite = True)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	Local $oUserData = _objGet($oForm, "userData", Null)
	If Not IsObj($oUserData) Then
		$oUserData = _objCreate()
		_objSet($oForm, "userData", $oUserData)
	EndIf

	Return _objSet($oUserData, $sItemName, $vValue, $bOverwrite)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_UserDataGet
; Description ...: The the associated value named $sItemName of $oForm.
; Syntax ........: _GUIUtils_UserDataGet($oForm, $sItemName[, $vDefaultValue = Null])
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sItemName           - value name.
;                  $vDefaultValue       - [optional] the value to return if $sItemName doesn't exists. Default is Null.
; Return values .: The value $sItemName or $vDefaultValue
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_UserDataGet($oForm, $sItemName, $vDefaultValue = Null)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, $vDefaultValue)

	Local $oUserData = _objGet($oForm, "userData", Null)
	If Not IsObj($oUserData) Then Return $vDefaultValue

	Return _objGet($oUserData, $sItemName, $vDefaultValue)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_UserDataExists
; Description ...: Check if $sItemName exists (is associated to $oForm).
; Syntax ........: _GUIUtils_UserDataExists($oForm, $sItemName)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sItemName           - value name.
; Return values .: True/False
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_UserDataExists($oForm, $sItemName)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	Return _objExists(_objGet($oForm, "userData", Null), $sItemName)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_UserDataDel
; Description ...: Delete the associated value $sItemName from $oForm.
; Syntax ........: _GUIUtils_UserDataDel($oForm, $sItemName)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sItemName           - value name.
; Return values .: None
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_UserDataDel($oForm, $sItemName)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	Return _objDel(_objGet($oForm, "userData", Null), $sItemName)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_UserDataEmpty
; Description ...: Delete all associated values from $oForm.
; Syntax ........: _GUIUtils_UserDataEmpty($oForm)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
; Return values .: None
; Author ........: matwachich
; =================================================================================================
Func _GUIUtils_UserDataEmpty($oForm)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	Return _objEmpty(_objGet($oForm, "userData", Null))
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_SetInputs
; Description ...: Define the controls that are used as inputs for $oForm.
; Syntax ........: _GUIUtils_SetInputs($oForm, $vInputs)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $vInputs             - Array (0- or 1-based) of control names, or string with control names separated by
;                                         " ", ",", "-", "|" or Opt("GUIDataSeparatorChar").
; Return values .: None
; Author ........: matwachich
; Remarks .......: By default, all named Inputs, Edits, Combo, List, Checkbox, Radiobox and DateTimePicker will be considered as
;                  input controls.
; =================================================================================================
Func _GUIUtils_SetInputs($oForm, $vInputs)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	If Not IsArray($vInputs) Then $vInputs = StringSplit($vInputs, " ,-|" & Opt("GUIDataSeparatorChar"))
	If UBound($vInputs) > 0 And $vInputs[0] = UBound($vInputs) - 1 Then _ArrayDelete($vInputs, 0)

	Return _objSet($oForm, "inputs", $vInputs)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_GetInputs
; Description ...: Get control names that are used as inputs.
; Syntax ........: _GUIUtils_GetInputs($oForm)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
; Return values .: 0-based array of input control names
; Author ........: matwachich
; Remarks .......: If an input list was previously set by _GUIUtils_SetInputs, then this list is returned.
;                  If not, all supported input names are returned.
; =================================================================================================
Func _GUIUtils_GetInputs($oForm)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, Null)

	Local $aInputs = _objGet($oForm, "inputs", Null)
	If IsArray($aInputs) Then Return $aInputs

	$aInputs = __guiUtils_getSupportedInputsList($oForm)
	If UBound($aInputs) <= 0 Then Return Null ; no any supported input control in $oForm

	_objSet($oForm, "inputs", $aInputs)
	Return $aInputs
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_SetButtons
; Description ...: Define button controls that will be used by _GUIUtils_InputDialog.
; Syntax ........: _GUIUtils_SetButtons($oForm[, $sBtnSubmit = Default[, $sBtnCancel = Default]])
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sBtnSubmit          - submit button control name.
;                  $sBtnCancel          - [optional] cancel button control name.
; Return values .: None
; Author ........: matwachich
; Remarks .......: See remarks in _GUIUtils_InputDialog for default behaviour if buttons are not set.
; =================================================================================================
Func _GUIUtils_SetButtons($oForm, $sBtnSubmit, $sBtnCancel = Default)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	_objSet($oForm, "submitBtn", $sBtnSubmit)
	If $sBtnCancel <> Default Then _objSet($oForm, "cancelBtn", $sBtnCancel)
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_ReadInputs
; Description ...: Read the data of all input controls of a form.
; Syntax ........: _GUIUtils_ReadInputs($oForm)
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $sCtrlName           - [optional] control name to read. Default read all input controls and return object
; Return values .: Object {controlName: controlData, ...} OR single control data (string, boolean or array)
; Author ........: matwachich
; Remarks .......: Input controls are: Inputs, Edits, Combo, List, Checkbox, Radiobox and DateTimePicker.
;                  See _GUIUtils_WriteInputs for data format
; =================================================================================================
Func _GUIUtils_ReadInputs($oForm, $sCtrlName = "")
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, Null)

	If $sCtrlName Then
		Return __guiUtils_inputDialog_controlGet($oForm, $sCtrlName)
	Else
		Local $oRet = _objCreate(), $aInputs = _GUIUtils_GetInputs($oForm)
		For $i = 0 To UBound($aInputs) - 1
			_objSet($oRet, $aInputs[$i], __guiUtils_inputDialog_controlGet($oForm, $aInputs[$i]))
		Next
		Return $oRet
	EndIf
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_WriteInputs
; Description ...: Set $oForm input(s) data.
; Syntax ........: _GUIUtils_WriteInputs($oForm[, $vCtrlNameOrDataObj = Null[, $vData = Null[, $vOptions = Null]]])
; Parameters ....: $oForm               - GUI object (as returned by _GUIUtils_CreateFromKODA or _GUIUtils_CreateFromJSON).
;                  $vCtrlNameOrDataObj  - [optional] input control name OR data object ({controlName: data, ...}).
;                                         Default is Null => reset all controls.
;                  $vData               - [optional] only if $vCtrlNameOrDataObj is a controlName string.
;                                         Default is Null => reset control data.
;                  $vOptions            - [optional] only if $vCtrlNameOrDataObj is a combo/listbox controlName string.
;                                         Default is Null => do not modifiy options.
; Return values .: None
; Author ........: matwachich
; Remarks .......:
;                  Inputs data format:
;                  -------------------
;                  - Input, Edit: "text"
;                  - Check, Radiobox: boolean
;                  - Date, Time: date or time in _NowCalc format (YYYY/MM/DD or HH[:MM[:SS]])
;                                you can set Null for NODATE ($DTS_SHOWNONE)
;                  - Combobox:
;                      - Editable ($CBS_DROPDOWN): string = selected item OR edit text content ; int = selected item ID (0-based)
;                      - Non editable ($CBS_DROPDOWNLIST): string = selected item ; int = selected item ID (0-based)
;                      you can set controlName:options to set Combobox items (0-based array or string with
;                      Opt("GUIDataSeparatorChar") separated items)
;                  - Listbox:
;                      - Singlesel: string = selected item ; int = selected item ID (0-based) ; 1 element array ([0] = string/int)
;                      - Multisel: string =
;                      you can set controlName:options to set Listbox items (0-based array or string with
;                      Opt("GUIDataSeparatorChar") separated items)
;
;                  Control Focus:
;                  --------------
;                  You can set controlName:focus in order to set input focus to controlName
; =================================================================================================
Func _GUIUtils_WriteInputs($oForm, $vCtrlNameOrDataObj = Null, $vData = Null, $vOptions = Null)
	If IsHWnd($oForm) Then $oForm = _objGet($__gGuiUtils_oForms, $oForm, Null)
	If Not IsObj($oForm) Then Return SetError(1, 0, False)

	If $vCtrlNameOrDataObj = Null Then
		; reset all inputs
		For $sInput In _GUIUtils_GetInputs($oForm)
			__guiUtils_inputDialog_controlSet($oForm, $sInput)
		Next
		Return
	EndIf

	If IsString($vCtrlNameOrDataObj) And $vCtrlNameOrDataObj Then
		__guiUtils_inputDialog_controlSet($oForm, $vCtrlNameOrDataObj, $vData, $vOptions)
	ElseIf IsObj($vCtrlNameOrDataObj) Then
		For $sKey In _GUIUtils_CtrlList($oForm)
			If _objExists($vCtrlNameOrDataObj, $sKey) Then
				__guiUtils_inputDialog_controlSet($oForm, $sKey, _
					_objGet($vCtrlNameOrDataObj, $sKey, Null), _
					_objGet($vCtrlNameOrDataObj, $sKey & ":options", Null) _
				)
				If _objGet($vCtrlNameOrDataObj, $sKey & ":focus", False) Then ControlFocus(_GUIUtils_HWnd($oForm), "", _GUIUtils_CtrlID($oForm, $sKey))
			EndIf
		Next

;~ 		For $sKey In _objKeys($vCtrlNameOrDataObj)
;~ 			If Not StringInStr($sKey, ":") Then
;~ 				__guiUtils_inputDialog_controlSet($oForm, $sKey, _
;~ 					_objGet($vCtrlNameOrDataObj, $sKey, Null), _
;~ 					_objGet($vCtrlNameOrDataObj, $sKey & ":options", Null) _
;~ 				)
;~ 				If _objGet($vCtrlNameOrDataObj, $sKey & ":focus", False) Then ControlFocus(_GUIUtils_HWnd($oForm), "", _GUIUtils_CtrlID($oForm, $sKey))
;~ 			EndIf
;~ 		Next
	EndIf
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_SetCustomInputsReader
; Description ...: Set a function that will be called when attemptin to read from a non standard input.
; Syntax ........: _GUIUtils_SetCustomInputsReader([$fnReader = Null])
; Parameters ....: $fnReader            - Reader function (see remarks). Default is Null (no custom reader).
; Return values .: Old reader function.
; Author ........: matwachich at gmail dot com
; Remarks .......: Reader prototype: $fnReader($oForm, $sCtrlName, $sCtrlClass)
; Related .......: _GUIUtils_ReadInputs
; ===============================================================================================================================
Func _GUIUtils_SetCustomInputsReader($fnReader = Null)
	Local $oldFunc = $__gGuiUtils_fnCustomInputReader
	$__gGuiUtils_fnCustomInputReader = $fnReader
	Return $oldFunc
EndFunc

; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_SetCustomInputsWriter
; Description ...: Set a function that will be called when attempting to write to a non standard input.
; Syntax ........: _GUIUtils_SetCustomInputsWriter([$fnWriter = Null])
; Parameters ....: $fnWriter            - Writer function (see remarks). Default is Null (no custom writer).
; Return values .: Old writer function.
; Author ........: matwachich at gmail dot com
; Remarks .......: Writer prototype: $fnWriter($oForm, $sCtrlName, $sCtrlClass, $vData, $vOptions)
; Related .......: _GUIUtils_WriteInputs
; ===============================================================================================================================
Func _GUIUtils_SetCustomInputsWriter($fnWriter = Null)
	Local $oldFunc = $__gGuiUtils_fnCustomInputWriter
	$__gGuiUtils_fnCustomInputWriter = $fnWriter
	Return $oldFunc
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================

# =================================================================================================
#Region - Misc
# =================================================================================================

Func _GUIUtils_GetFont($oForm, $bAsString = False)
	$oForm = __guiUtils_getFormHandleOrObject($oForm, True)
	If Not IsHWnd($oForm) Then Return SetError(1, 0, "")

	Local $hPreviousGUI = GUISwitch($oForm)
	Local $iLabel = GUICtrlCreateLabel("ABC", -100, -100)
	Local $hFont = _SendMessage(GUICtrlGetHandle($iLabel), $WM_GETFONT)
	Local $tLOGFONT = DllStructCreate($tagLOGFONT)
	_WinAPI_GetObject($hFont, DllStructGetSize($tLOGFONT), DllStructGetPtr($tLOGFONT))
	GUICtrlDelete($iLabel)
	GUISwitch($hPreviousGUI)

	; nHeight = -MulDiv(PointSize, GetDeviceCaps(hDC, LOGPIXELSY), 72);
	; nHeight = -1 * ((PointSize * LOGPIXELSY) / 72)
	; PointSize = nHeight * 72 / LOGPIXELSY

	Local $hDC = _WinAPI_GetDC($oForm)
	Local $aRet[] = [ _
		Round(-1 * $tLOGFONT.Height * 72 / _WinAPI_GetDeviceCaps($hDC, 90)), _ ; LOGPIXELSY = 90
		$tLOGFONT.Weight, _
		0, _
		$tLOGFONT.FaceName _
	]
	_WinAPI_ReleaseDC($oForm, $hDC)

	If $tLOGFONT.Italic Then $aRet[2] += 2
	If $tLOGFONT.Underline Then $aRet[2] += 4
	If $tLOGFONT.StrikeOut Then $aRet[2] += 8

	Return $bAsString ? _ArrayToString($aRet, ",") : $aRet
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================

# =================================================================================================
#Region - Internal functions
# =================================================================================================

#... STOP DBUG

Func __guiUtils_getFormHandleOrObject($vForm, $bAsHWnd = False)
	Select
		Case IsHWnd($vForm)
			If $bAsHWnd Then
				Return $vForm
			Else
				Return _objGet($__gGuiUtils_oForms, $vForm, $vForm)
			EndIf
		Case IsObj($vForm)
			If $bAsHWnd Then
				Return _GUIUtils_HWnd($vForm)
			Else
				Return $vForm
			EndIf
		Case Else
			Return $vForm
	EndSelect
EndFunc

; returns all *named* and *supported* controls in $oForm
Func __guiUtils_getSupportedInputsList($oForm)
	; list of supported controls
	Static Local $aSupportedControls[] = ["Checkbox", "Combobox", "Date", "Edit", "Input", "Listbox", "Radio", "Time"] ; MUST BE SORTED for binary search

	; get a list of all named controls
	Local $aCtrls = _objKeys(_GUIUtils_CtrlList($oForm))

	; loop through controls, and check if they are supported
	For $i = UBound($aCtrls) - 1 To 0 Step -1
		If _ArrayBinarySearch($aSupportedControls, __guiUtils_identifyControl(_GUIUtils_HCtrl($oForm, $aCtrls[$i]))) = -1 Then
			_ArrayDelete($aCtrls, $i)
		EndIf
	Next

	Return $aCtrls
EndFunc

Func __guiUtils_identifyControl($hCtrl)
	Local $sClassName = _WinAPI_GetClassName($hCtrl)
	Switch $sClassName
		Case "Edit"
			Local $iStyle = _WinAPI_GetWindowLong($hCtrl, $GWL_STYLE)
			If Not BitAND($iStyle, $ES_MULTILINE) Then $sClassName = "Input"
		Case "Button"
			Local $iStyle = _WinAPI_GetWindowLong($hCtrl, $GWL_STYLE)
			If BitAND($iStyle, $BS_CHECKBOX) Then $sClassName = "Checkbox"
			If BitAND($iStyle, 8) Then $sClassName = "Radio" ; $BS_AUTORADIOBUTTON - $BS_DEFPUSHBUTTON (je ne sait pourquoi ça marche! d'autant plus que $BS_RADIOBUTTON = 4 et pas 8)
		Case "SysDateTimePick32"
			Local $iStyle = _WinAPI_GetWindowLong($hCtrl, $GWL_STYLE)
			$sClassName = BitAND($iStyle, $DTS_TIMEFORMAT) ? "Time" : "Date"
	EndSwitch
	Return $sClassName
EndFunc

Func __guiUtils_kodaParser_createGUI($oForm, $oXML, $iWidth, $iHeight, $hParent = Null)
	Local $oObject = $oXML.selectSingleNode("/object")
	If $oObject.getAttribute("type") <> "TAForm" Then Return SetError(1, 0, Null)

	Local $oProperties = __guiUtils_kodaParser_readObjectProperties($oObject)

	Switch $oProperties.Item("Position")
		Case "poDesktopCenter"
			$oProperties.Item("Left") = -1
			$oProperties.Item("Top") = -1
		;TODO: $poFixed ???
	EndSwitch

	; temporary store GUI properties object (could be used by control creation)
	; deleted in _GUIUtils_CreateFromKODA befor returning
	_objSet($oForm, "##guiProperties", $oProperties)

	; ajust window size (tooo headache!)
;~ 	$oProperties.Item("Width") = $oProperties.Item("Width") - (_WinAPI_GetSystemMetrics($SM_CXSIZEFRAME) * 2)
;~ 	$oProperties.Item("Height") = $oProperties.Item("Height") - (_WinAPI_GetSystemMetrics($SM_CYSIZEFRAME) * 2); caption, menu, status bar?

	; remove visible flag, GUI will be displayed in _GUIUtils_CreateFromKODA (if WS_VISIBLE is set)
	If BitAND($oProperties.Item("Style"), $WS_VISIBLE) = $WS_VISIBLE Then $oProperties.Item("Style") -= $WS_VISIBLE

	; GUI creation
	Local $hGUI = GUICreate( _
		$oProperties.Item("Caption"), _
		$iWidth > 0 ? $iWidth : Default, $iHeight > 0 ? $iHeight : Default, _ ; $oProperties.Item("Width"), $oProperties.Item("Height"), _
		$oProperties.Item("Left"), $oProperties.Item("Top"), _
		$oProperties.Item("Style"), $oProperties.Item("ExStyle"), _
		$hParent _ ; Eval($oProperties.Item("ParentForm")) _ ;TODO: test
	)

	; font
	Local $aFont = __guiUtils_kodaParser_processFont($oForm, $oProperties)
	GUISetFont($aFont[0], $aFont[1], $aFont[2], $aFont[3], $hGUI)

	; color
	Local $iColor = __guiUtils_kodaParser_identifiers_colors(_objGet($oProperties, "Color", ""))
	If $iColor <> "" Then GUISetBkColor($iColor, $hGUI)

	; cursor
	GUISetCursor(__guiUtils_kodaParser_identifiers_cursor($oProperties.Item("Cursor")), 0, $hGUI)

	; store GUI handle
	_objSet($oForm, "formName", $oObject.getAttribute("name"))
	_objSet($oForm, "hwnd", $hGUI)
EndFunc

Func __guiUtils_kodaParser_createControls($oForm, $oObjects, $iXOffset = 0, $iYOffset = 0, $vUserData = Null, $bIsFirstCall = False)
	Local $iCtrlID, $oObject, $oProperties, $bIsStandardCtrl

	Local $aRetNames[0]

	; get/create container sub-objects
	Local $oControls = _objGet($oForm, "controls", Null)
	If Not IsObj($oControls) Then
		$oControls = _objCreate()
		_objSet($oForm, "controls", $oControls)
	EndIf

	Local $oChildrenLists = _objGet($oForm, "childrenLists", Null)
	If Not IsObj($oChildrenLists) Then
		$oChildrenLists = _objCreate()
		_objSet($oForm, "childrenLists", $oChildrenLists)
	EndIf

	; init variables for calculating GUI size (if not provided)
	If $bIsFirstCall Then
		_objSet($oForm, "##minX", 0)
		_objSet($oForm, "##minY", 0)
		_objSet($oForm, "##maxX", 0)
		_objSet($oForm, "##maxY", 0)
	EndIf

	; we first sort the objects/controls to create in order to respect TabOrder
	; also, this function will make sure that any PopupMenu declaration comes after it's parent control
	Local $aObjects = __guiUtils_kodaParser_sortObjects($oObjects)

	; iterate over controls
	For $iObjID = 0 To UBound($aObjects) - 1
		$oObject = $aObjects[$iObjID][0]
		$oProperties = $aObjects[$iObjID][1]
		$bIsStandardCtrl = True

		; add offset (if in groupbox or tabitem)
		If _objExists($oProperties, "Left") Then _objSet($oProperties, "Left", _objGet($oProperties, "Left") + $iXOffset)
		If _objExists($oProperties, "Top") Then _objSet($oProperties, "Top", _objGet($oProperties, "Top") + $iYOffset)

		; create control
		Switch $oObject.getAttribute("type")
			; ---
			Case "TAMenu" ; main GUI menu
				Local $oMainMenu = $oObject.selectNodes("//object[@type='TMainMenu' and @name='" & _objGet($oProperties, "WrappedName") & "']")
				__guiUtils_kodaParser_createControls($oForm, $oMainMenu, 0, 0, -1)
			; ---
			Case "TAContextMenu"
				; after sortin, we are sure that the 'Associate' control exists because menus are created the last
				$iCtrlID = GUICtrlCreateContextMenu(_GUIUtils_CtrlID($oForm, _objGet($oProperties, "Associate")))

				Local $oPopupMenu = $oObject.selectNodes("//object[@type='TPopupMenu' and @name='" & _objGet($oProperties, "WrappedName") & "']")
				__guiUtils_kodaParser_createControls($oForm, $oPopupMenu, 0, 0, $iCtrlID)
			; ---
			Case "TMainMenu"
				If Not $vUserData Then ContinueLoop

				Local $oComponents = $oObject.selectNodes("components/object")
				__guiUtils_kodaParser_createControls($oForm, $oComponents, 0, 0, -1) ; (*)

				ContinueLoop
			; ---
			Case "TPopupMenu"
				If Not $vUserData Then ContinueLoop

				Local $oComponents = $oObject.selectNodes("components/object")
				__guiUtils_kodaParser_createControls($oForm, $oComponents, 0, 0, $vUserData)

				ContinueLoop
			; ---
			Case "TAMenuItem"
				Local $oSubMenuItems = $oObject.selectNodes("components/object")
				If $oSubMenuItems.length > 0 Or $vUserData = -1 Then ; $vUserData is set to -1 when creating parent main menu item (*)
					$iCtrlID = GUICtrlCreateMenu( _
						_objGet($oProperties, "Caption", ""), _
						$vUserData _
					)
					__guiUtils_kodaParser_createControls($oForm, $oSubMenuItems, 0, 0, $iCtrlID)
				Else
					$iCtrlID = GUICtrlCreateMenuItem( _
						_objGet($oProperties, "Caption", ""), _
						$vUserData, _
						-1, _
						_objGet($oProperties, "RadioItem", False) ? 1 : 0 _
					)
				EndIf
			; ---
			Case "TALabel"
				$iCtrlID = GUICtrlCreateLabel( _
					$oProperties.Item("Caption"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAButton"
				$iCtrlID = GUICtrlCreateButton( _
					$oProperties.Item("Caption"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; do not change background color if default (to not fall in windows xp style)
				If $oProperties.Item("Color") = "clBtnFace" Then _objDel($oProperties, "Color")

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAInput"
				$iCtrlID = GUICtrlCreateInput( _
					$oProperties.Item("Text"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAEdit"
				$aLines = $oProperties.Item("Lines.Strings")
				$iCtrlID = GUICtrlCreateEdit( _
					IsArray($aLines) ? _ArrayToString($aLines, @CRLF, 1) : "", _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TACheckbox"
				$iCtrlID = GUICtrlCreateCheckbox( _
					$oProperties.Item("Caption"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TARadio"
				$iCtrlID = GUICtrlCreateRadio( _
					$oProperties.Item("Caption"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAList"
				$iCtrlID = GUICtrlCreateList("", _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				$aItems = _objGet($oProperties, "Items.Strings", Null)
				If IsArray($aItems) Then GUICtrlSetData($iCtrlID, _ArrayToString($aItems, "|", 1))

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TACombo"
				If _objGet($oProperties, "ItemIndex", -1) > 0 Then
					_objSet($oProperties, "Text", "")
				EndIf

				$iCtrlID = GUICtrlCreateCombo( _
					$oProperties.Item("Text"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				$aItems = _objGet($oProperties, "Items.Strings", Null)
				$iItemIndex = _objGet($oProperties, "ItemIndex", -1)
				If IsArray($aItems) Then GUICtrlSetData($iCtrlID, _
					_ArrayToString($aItems, "|", 1), _
					$iItemIndex > 0 ? $aItems[$iItemIndex] : "" _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAGroup"
				$iCtrlID = GUICtrlCreateGroup( _
					$oProperties.Item("Caption"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				Local $oComponents = $oObject.selectNodes("components/object")

				Local $aRet = __guiUtils_kodaParser_createControls($oForm, $oComponents, $oProperties.Item("Left"), $oProperties.Item("Top"))
				If $oObject.getAttribute("name") Then _objSet($oChildrenLists, $oObject.getAttribute("name"), $aRet)

				GUICtrlCreateGroup("", -99, -99, 1, 1)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAPic"
				$iCtrlID = GUICtrlCreatePic( _
					$oProperties.Item("PicturePath"), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAIcon" ;TODO: display bug (peut être rafraichir la fenêtre?)
				$iCtrlID = GUICtrlCreateIcon( _
					_objGet($oProperties, "CurstomPath", $oProperties.Item("PicturePath")), -1 * ($oProperties.Item("PictureIndex") + 1), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TADummy"
				$iCtrlID = GUICtrlCreateDummy()
			; ---
			Case "TAControlGroup"
				GUIStartGroup()
				Local $oComponents = $oObject.selectNodes("components/object")

				Local $aRet = __guiUtils_kodaParser_createControls($oForm, $oComponents, $oProperties.Item("Left"), $oProperties.Item("Top"))
				If $oObject.getAttribute("name") Then _objSet($oChildrenLists, $oObject.getAttribute("name"), $aRet)

				$oComponents = 0
				GUIStartGroup()

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TASlider"
				$iCtrlID = GUICtrlCreateSlider( _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				GUICtrlSetLimit($iCtrlID, _objGet($oProperties, "Max", 100), _objGet($oProperties, "Min", 0))
				GUICtrlSetData($iCtrlID, _objGet($oProperties, "Position", _objGet($oProperties, "Min", 0)))

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAProgress"
				$iCtrlID = GUICtrlCreateProgress( _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

;~ 				GUICtrlSetLimit($iCtrlID, _objGet($oProperties, "Max", 100), _objGet($oProperties, "Min", 0)) ; limits are ignored by Progress control
				GUICtrlSetData($iCtrlID, _objGet($oProperties, "Position", _objGet($oProperties, "Min", 0))) ; 0-100

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TADate"
				Local $sText = StringSplit($oProperties.Item("Date"), "/")
				$sText = UBound($sText) = 4 ? StringFormat("%04i/%02i/%02i", $sText[3], $sText[2], $sText[1]) : ""

				If BitAND($oProperties.Item("CtrlStyle"), $DTS_TIMEFORMAT) = $DTS_TIMEFORMAT Then $sText = $oProperties.Item("Time")

				$iCtrlID = GUICtrlCreateDate( _
					$sText, _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				If _objGet($oProperties, "Format") Then GUICtrlSendMsg($iCtrlID, $DTM_SETFORMATW, 0, _objGet($oProperties, "Format"))

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAMonthCal"
				Local $sText = StringSplit($oProperties.Item("Date"), "/")
				$sText = UBound($sText) = 4 ? StringFormat("%04i/%02i/%02i", $sText[3], $sText[2], $sText[1]) : ""

				Local $iCtrlID = GUICtrlCreateMonthCal( _
					$sText, _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TATreeView"
				$iCtrlID = GUICtrlCreateTreeView( _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				; treeView items are stored in an (opaque?) binary format

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TAListView"
				Local $sText = ""
				Local $aColumns = _objGet($oProperties, "Columns", Null)
				If IsArray($aColumns) Then
					For $i = 1 To $aColumns[0]
						$sText &= _objGet($aColumns[$i], "Caption", "") & "|"
					Next
					$sText = StringTrimRight($sText, 1)
				EndIf

				$iCtrlID = GUICtrlCreateListView( _
					$sText, _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				For $i = 1 To $aColumns[0]
					GUICtrlSendMsg(-1, $LVM_SETCOLUMNWIDTH, $i - 1, _objGet($aColumns[$i], "Width", 50))
				Next

				; listView items are stored in an (opaque?) binary format

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TATab"
				$iCtrlID = GUICtrlCreateTab( _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)
				Local $aRet = __guiUtils_kodaParser_createControls($oForm, $oObject.selectNodes("components/object"), $oProperties.Item("Left"), $oProperties.Item("Top"), $iCtrlID)
				If $oObject.getAttribute("name") Then _objSet($oChildrenLists, $oObject.getAttribute("name"), $aRet)

				GUICtrlSetState(_objGet($oForm, _objGet($oProperties, "ActivePage", ""), 0), $GUI_SHOW)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
			; ---
			Case "TTabSheet"
				$iCtrlID = GUICtrlCreateTabItem($oProperties.Item("Caption"))

				$aDispRect = _GUICtrlTab_GetDisplayRect(GUICtrlGetHandle($vUserData))
				Local $aRet = __guiUtils_kodaParser_createControls($oForm, $oObject.selectNodes("components/object"), $iXOffset + $aDispRect[0], $iYOffset + $aDispRect[1])
				If $oObject.getAttribute("name") Then _objSet($oChildrenLists, $oObject.getAttribute("name"), $aRet)

				GUICtrlCreateTabItem("")
			; ---------------
			; Custom controls
			; ---
;~ 			Case "TAStatusBar"
;~ 				$bIsStandardCtrl = False
			Case "TAIPAddress"
				$iCtrlID = _GUICtrlIpAddress_Create( _
					HWnd($oForm.Item("hwnd")), _
					$oProperties.Item("Left"), $oProperties.Item("Top"), $oProperties.Item("Width"), $oProperties.Item("Height"), _
					$oProperties.Item("CtrlStyle"), $oProperties.Item("CtrlExStyle") _
				)

				_GUICtrlIpAddress_Set($iCtrlID, $oProperties.Item("Text"))
				_GUICtrlIpAddress_ShowHide($iCtrlID, _objGet($oProperties, "Visible", True) ? @SW_SHOW : @SW_HIDE)

				Local $aFont = __guiUtils_kodaParser_processFont($oForm, $oProperties) ; get default GUI font
				_GUICtrlIpAddress_SetFont($iCtrlID, $aFont[3], $aFont[0], $aFont[1], BitAND($aFont[2], 2) = 2)

				; ---
				If $bIsFirstCall Then __guiUtils_kodaParser_calculateGUIsize($oForm, $oProperties)
				$bIsStandardCtrl = False
			; ---
;~ 			Case "TAToolBar"
;~ 				$bIsStandardCtrl = False
;~ 			Case "TAImageList"
;~ 				$bIsStandardCtrl = False
			Case Else
				ContinueLoop
		EndSwitch
		; ---
		; set status and style for standard controls
		If $bIsStandardCtrl Then
			; font
			Local $aFont = __guiUtils_kodaParser_processFont($oForm, $oProperties)
			GUICtrlSetFont($iCtrlID, $aFont[0], $aFont[1], $aFont[2], $aFont[3])

			; colors
			$iColor = __guiUtils_kodaParser_identifiers_colors(_objGet($oProperties, "Color", ""))
			If $iColor <> "" Then GUICtrlSetBkColor($iCtrlID, $iColor)

			$iColor = __guiUtils_kodaParser_identifiers_colors(_objGet($oProperties, "Font.Color", ""))
			If $iColor <> "" Then GUICtrlSetColor($iCtrlID, $iColor)

			; cursor
			GUICtrlSetCursor($iCtrlID, __guiUtils_kodaParser_identifiers_cursor(_objGet($oProperties, "Cursor", "")))

			; hint
			GUICtrlSetTip($iCtrlID, _objGet($oProperties, "Hint", ""))

			; visible
			If Not _objGet($oProperties, "Visible", True) Then GUICtrlSetState($iCtrlID, $GUI_HIDE)

			; enable
			If Not _objGet($oProperties, "Enabled", True) Then GUICtrlSetState($iCtrlID, $GUI_DISABLE)

			; checked
			If _objGet($oProperties, "Checked", False) Then GUICtrlSetState($iCtrlID, $GUI_CHECKED)

			; resizing
			Local $aResizing = $oProperties.Item("Resizing")
			If IsArray($aResizing) And $aResizing[0] > 0 Then
				Local $iResizing = 0
				For $i = 1 To $aResizing[0]
					$iResizing += __guiUtils_kodaParser_identifiers_docking($aResizing[$i])
				Next
				GUICtrlSetResizing($iCtrlID, $iResizing)
			EndIf
		EndIf
		; ---
		; store control in returned object (if non empty name)
		If String($oObject.getAttribute("name")) Then
			_objSet($oControls, $oObject.getAttribute("name"), $iCtrlID)
			_ArrayAdd($aRetNames, $oObject.getAttribute("name"))
		EndIf
	Next

	Return $aRetNames
EndFunc

Func __guiUtils_kodaParser_sortObjects($oObjects)
	Local $i = 0, $aObjects[$oObjects.length][3] ; $oObject, $oProperties, $iTabOrder
	For $oObject In $oObjects
		$aObjects[$i][0] = $oObject
		$aObjects[$i][1] = __guiUtils_kodaParser_readObjectProperties($oObject)

		; default to a very big taborder (so that elements such as menus and popuMenus will be the last ones)
		; add + $i to preserve original order for these controls
		$aObjects[$i][2] = _objGet($aObjects[$i][1], "TabOrder", 1000000 + $i)
		$i += 1
	Next
	_ArraySort($aObjects, 0, 0, 0, 2)
	ReDim $aObjects[UBound($aObjects)][2]
	Return $aObjects
EndFunc

Func __guiUtils_kodaParser_calculateGUIsize($oForm, $oCtrlProps)
	; get left-top margin
	If _objGet($oForm, "##minX", 0) = 0 Or ($oCtrlProps.Exists("Left") And $oCtrlProps.Item("Left") < _objGet($oForm, "##minX", 0)) Then _objSet($oForm, "##minX", $oCtrlProps.Item("Left"))
	If _objGet($oForm, "##minY", 0) = 0 Or ($oCtrlProps.Exists("Top") And $oCtrlProps.Item("Top") < _objGet($oForm, "##minY", 0)) Then _objSet($oForm, "##minY", $oCtrlProps.Item("Top"))

	; get max width-height
	If _objGet($oForm, "##maxX", 0) = 0 Or $oCtrlProps.Item("Left") + $oCtrlProps.Item("Width") > _objGet($oForm, "##maxX", 0) Then _objSet($oForm, "##maxX", $oCtrlProps.Item("Left") + $oCtrlProps.Item("Width"))
	If _objGet($oForm, "##maxY", 0) = 0 Or $oCtrlProps.Item("Top") + $oCtrlProps.Item("Height") > _objGet($oForm, "##maxY", 0) Then _objSet($oForm, "##maxY", $oCtrlProps.Item("Top") + $oCtrlProps.Item("Height"))
EndFunc

Func __guiUtils_kodaParser_readObjectProperties($oObject)
	Local $oRet = _objCreate()
	For $oProperty In $oObject.selectNodes("properties/property")
		_objSet($oRet, $oProperty.getAttribute("name"), __guiUtils_kodaParser_readProperty($oProperty))
	Next
	Return $oRet
EndFunc

Func __guiUtils_kodaParser_readProperty($oProperty)
	Switch $oProperty.getAttribute("vt")
		Case "Binary" ;TODO: test
			Local $oBins = $oProperty.selectNodes("bin")
			If $oBins.length <= 0 Then Return Binary("")

			Local $aBins[$oBins.length], $i = 0
			For $oBin In $oBins
				$aBins[$i] = Binary($oBin.text)
				$i += 1
			Next
			Return Binary("0x" & _ArrayToString($aBins, ""))
		; ---
		Case "Collection" ; collection of properties
			Local $oItems = $oProperty.selectNodes("collection/item")
			Local $aRet[1] = [0]
			If $oItems.length > 0 Then
				ReDim $aRet[$oItems.length + 1]
				$aRet[0] = $oItems.length
				$i = 1
				For $oItem In $oItems
					$aRet[$i] = _objCreate()
					For $oItemProp In $oItem.selectNodes("property")
						_objSet($aRet[$i], $oItemProp.getAttribute("name"), __guiUtils_kodaParser_readProperty($oItemProp))
					Next
					$i += 1
				Next
			EndIf
			Return $aRet
		; ---
		Case "List" ; list of strings (only?)
			Local $oItems = $oProperty.selectNodes("list/li")
			Local $aRet[1] = [0]
			If $oItems.length > 0 Then
				ReDim $aRet[$oItems.length + 1]
				$aRet[0] = $oItems.length
				$i = 1
				For $oItem In $oItems
					$aRet[$i] = __guiUtils_kodaParser_readProperty($oItem)
					$i += 1
				Next
			EndIf
			Return $aRet
		; ---
		Case "Set" ; list of Identifiers
			Local $aRet[1] = [0]
			If $oProperty.text Then
				$aRet = StringSplit($oProperty.text, ",")
				For $i = 1 To $aRet[0]
					$aRet[$i] = StringStripWS($aRet[$i], 3)
				Next
			EndIf
			Return $aRet
		; ---
		Case "False"
			Return False
		Case "True"
			Return True
		Case "Ident" ; identifier
			Return String($oProperty.text)
		Case "Int8", "Int16", "Int32"
			Return Int($oProperty.text)
		Case "Single", "Extended"
			Return Number($oProperty.text)
		Case "String", "UTF8String", "WString" ;TODO: handle unicode strings?
			Return String($oProperty.text)
		Case Else
			Return String($oProperty.text)
	EndSwitch
EndFunc

;TODO: test on non-highDPI displays
Func __guiUtils_kodaParser_processFont($oForm, $oProperties)
	Local $aRet[4] ; size, weight, attributes, name

	; GUI props are used for PixelsPerInch, and to default to GUI font if no font info are provided for the control
	Local $oGUIProps = _objGet($oForm, "##guiProperties")

	; calculate font point size (https://support.microsoft.com/en-us/help/74299/info-calculating-the-logical-height-and-point-size-of-a-font)
	$aRet[0] = Round(Abs(_objGet($oProperties, "Font.Height", _objGet($oGUIProps, "Font.Height")) * 72 / _objGet($oGUIProps, "PixelsPerInch")))

	; font attributes
	Local $aAttribs = _objGet($oProperties, "Font.Style", _objGet($oGUIProps, "Font.Style"))
	$aRet[1] = _ArraySearch($aAttribs, "fsBold", 1) > 0 ? 800 : 400

	$aRet[2] = 0
	For $i = 1 To $aAttribs[0]
		$aRet[2] += __guiUtils_kodaParser_identifiers_fontStyle($aAttribs[$i])
	Next

	; font name
	$aRet[3] = _objGet($oProperties, "Font.Name", _objGet($oGUIProps, "Font.Name"))

	Return $aRet
EndFunc

Func __guiUtils_kodaParser_identifiers_fontStyle($sIdent)
	Local $aDef[][] = [ _
		["fsItalic", 2], _
		["fsUnderline", 4], _
		["fsStrikeOut", 8] _
	]
	For $i = 0 To UBound($aDef) - 1
		If $sIdent = $aDef[$i][0] Then Return $aDef[$i][1]
	Next
	Return 0 ; normal font
EndFunc

Func __guiUtils_kodaParser_identifiers_docking($sIdent)
	Local $aDef[][] = [ _
		["DockAuto", 1], _
		["DockLeft", 2], _
		["DockRight", 4], _
		["DockHCenter", 8], _
		["DockTop", 32], _
		["DockBottom", 64], _
		["DockVCenter", 128], _
		["DockWidth", 256], _
		["DockHeight", 512] _
	]
	For $i = 0 To UBound($aDef) - 1
		If $sIdent = $aDef[$i][0] Then Return $aDef[$i][1]
	Next
	Return 0 ; no docking value
EndFunc

Func __guiUtils_kodaParser_identifiers_cursor($sIdent)
	Local $aDef[][] = [ _
		["crAppStart", 1], _
		["crArrow", 2], _
		["crCross", 3], _
		["crDefault", -1], _
		["crDrag", 2], _
		["crHandPoint", 0], _
		["crHelp", 4], _
		["crHourGlass", 15], _
		["crHSplit", 2], _
		["crBeam", 5], _
		["crMultiDrag", 2], _
		["crNo", 7], _
		["crNoDrop", 7], _
		["crSizeAll", 9], _
		["crSizeNESW", 10], _
		["crSizeNS", 11], _
		["crSizeNWSE", 12], _
		["crSizeWE", 13], _
		["crSQLWait", 2], _
		["crUpArrow", 14], _
		["crVSplit", 2] _
	]
	For $i = 0 To UBound($aDef) - 1
		If $aDef[$i][0] = $sIdent Then Return $aDef[$i][1]
	Next
	Return -1 ; $crDefault
EndFunc

Func __guiUtils_kodaParser_identifiers_colors($sIdent)
	If Not $sIdent Then Return ""

	Local $aDef[][] = [ _ ; standard colors (unused: $COLOR_MEDBLUE)
		["clDefault", $CLR_DEFAULT], _
		["clNone", $CLR_NONE], _
		["clBlack", $COLOR_BLACK], _
		["clMaroon", $COLOR_MAROON], _
		["clGreen", $COLOR_GREEN], _
		["clOlive", $COLOR_OLIVE], _
		["clNavy", $COLOR_NAVY], _
		["clPurple", $COLOR_PURPLE], _
		["clTeal", $COLOR_TEAL], _
		["clGray", $COLOR_GRAY], _
		["clSilver", $COLOR_SILVER], _
		["clRed", $COLOR_RED], _
		["clLime", $COLOR_LIME], _
		["clYellow", $COLOR_YELLOW], _
		["clBlue", $COLOR_BLUE], _
		["clFuchsia", $COLOR_FUCHSIA], _
		["clAqua", $COLOR_AQUA], _
		["clWhite", $COLOR_WHITE], _
		["clMoneyGreen", $COLOR_MONEYGREEN], _
		["clSkyBlue", $COLOR_SKYBLUE], _
		["clCream", $COLOR_CREAM], _
		["clMedGray", $COLOR_MEDGRAY] _
	]
	For $i = 0 To UBound($aDef) - 1
		If $aDef[$i][0] = $sIdent Then Return $aDef[$i][1]
	Next

	Dim $aDef[][] = [ _ ; system colors (unused: $COLOR_3DHIGHLIGHT, $COLOR_3DHILIGHT, $COLOR_3DSHADOW)
		["clActiveBorder", $COLOR_ACTIVEBORDER], _
		["clActiveCaption", $COLOR_ACTIVECAPTION], _
		["clAppWorkSpace", $COLOR_APPWORKSPACE], _
		["clBackground", $COLOR_BACKGROUND], _
		["clBtnFace", $COLOR_BTNFACE], _
		["clBtnHighlight", $COLOR_BTNHIGHLIGHT], _
		["clBtnHilight", $COLOR_BTNHILIGHT], _ ; same as $COLOR_BTNHIGHLIGHT (added)
		["clBtnShadow", $COLOR_BTNSHADOW], _
		["clBtnText", $COLOR_BTNTEXT], _
		["clCaptionText", $COLOR_CAPTIONTEXT], _
		["clDesktop", $COLOR_DESKTOP], _ ; same as $COLOR_BACKGROUND (added)
		["clGradientActiveCaption", $COLOR_GRADIENTACTIVECAPTION], _
		["clGradientInactiveCaption", $COLOR_GRADIENTINACTIVECAPTION], _
		["clGrayText", $COLOR_GRAYTEXT], _
		["clHighlight", $COLOR_HIGHLIGHT], _
		["clHighlightText", $COLOR_HIGHLIGHTTEXT], _
		["clHotLight", $COLOR_HOTLIGHT], _
		["clInactiveBorder", $COLOR_INACTIVEBORDER], _
		["clInactiveCaption", $COLOR_INACTIVECAPTION], _
		["clInactiveCaptionText", $COLOR_INACTIVECAPTIONTEXT], _
		["clInfoBk", $COLOR_INFOBK], _
		["clInfoText", $COLOR_INFOTEXT], _
		["clMenu", $COLOR_MENU], _
		["clMenuBar", $COLOR_MENUBAR], _
		["clMenuHilight", $COLOR_MENUHILIGHT], _
		["clMenuHighlight", $COLOR_MENUHILIGHT], _ ; HILIGH is the same as HIGHLIGHT (I think! :p)
		["clMenuText", $COLOR_MENUTEXT], _
		["clScrollBar", $COLOR_SCROLLBAR], _
		["cl3DFace", $COLOR_3DFACE], _ ; (added)
		["cl3DHighlight", $COLOR_3DHIGHLIGHT], _ ; (added)
		["cl3DHilight", $COLOR_3DHILIGHT], _ ; (added)
		["cl3DShadow", $COLOR_3DSHADOW], _ ; (added)
		["cl3DDkShadow", $COLOR_3DDKSHADOW], _
		["cl3DLight", $COLOR_3DLIGHT], _
		["clWindow", $COLOR_WINDOW], _
		["clWindowFrame", $COLOR_WINDOWFRAME], _
		["clWindowText", $COLOR_WINDOWTEXT] _
	]
	For $i = 0 To UBound($aDef) - 1
		If $aDef[$i][0] = $sIdent Then Return _WinAPI_GetSysColor($aDef[$i][1])
	Next
	Return ""
EndFunc

Func __guiUtils_jsonParser_stringSize($sText, $aFont = Null, $iMaxWidth = 0)
	Local $aRet
	If IsArray($aFont) And UBound($aFont) == 4 Then
		$aRet = _StringSize($sText, Number($aFont[0]), Number($aFont[1]), Number($aFont[2]), String($aFont[3]), Number($iMaxWidth))
	Else
		$aRet = _StringSize($sText, Default, Default, Default, Default, Number($iMaxWidth))
	EndIf
	Return SetError(@error, @extended, $aRet)
EndFunc

Func __guiUtils_jsonParser_getFont($oObject, $vDefaultFontValue = "", $sFontValueKey = "font")
	Local $vRead = _objGet($oObject, $sFontValueKey, $vDefaultFontValue)
	If IsArray($vRead) And UBound($vRead) = 4 Then Return $vRead
	$vRead = StringSplit($vRead, ",")
	_ArrayDelete($vRead, 0)
	If UBound($vRead) = 4 Then Return $vRead
	Return Null
EndFunc

Func __guiUtils_jsonParser_controlSetFontAndColors($iCtrlID, $vFont = Null, $iColor = Null, $iBkColor = Null)
	If Not IsArray($vFont) Then
		$vFont = StringSplit($vFont, ",")
		_ArrayDelete($vFont, 0)
	EndIf
	If UBound($vFont) = 4 Then GUICtrlSetFont($iCtrlID, $vFont[0], $vFont[1], $vFont[2], $vFont[3])
	If $iColor <> Null Then GUICtrlSetColor($iCtrlID, $iColor)
	If $iBkColor <> Null Then GUICtrlSetBkColor($iCtrlID, $iColor)
EndFunc

Func __guiUtils_jsonParser_controlSetTip($iCtrlID, $oCtrlProps, $sTipKey = "tip", $sTipTitleKey = "tipTitle", $sTipIconKey = "tipIcon", $sTipOptionsKey = "tipOptions")
	If _objExists($oCtrlProps, $sTipKey) Then
		GUICtrlSetTip($iCtrlID, _
			_objGet($oCtrlProps, $sTipKey, ""), _
			_objGet($oCtrlProps, $sTipTitleKey, Default), _
			_objGet($oCtrlProps, $sTipIconKey, Default), _
			_objGet($oCtrlProps, $sTipOptionsKey, Default) _
		)
	EndIf
EndFunc

Func __guiUtils_jsonParser_getArray($oControl, $sItem, $vNotFound = Null, $sSplit = Opt("GUIDataSeparatorChar"))
	Local $vData = _objGet($oControl, $sItem, $vNotFound)
	If $vData = $vNotFound Then Return $vNotFound

	If IsNumber($vData) Then
		Local $aRet[1] = [$vData]
		Return $aRet
	EndIf

	If Not IsArray($vData) Then
		$vData = StringSplit($vData, $sSplit)
		_ArrayDelete($vData, 0)
	EndIf
	Return $vData
EndFunc

Func __guiUtils_inputDialog_subClassProc($hWnd, $iMsg, $wParam, $lParam, $iID, $pData)
	If _objGet($__gGuiUtils_inputDialog_oCurrentForm, "__lockOnChange", False) Then Return _WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
	Switch $iMsg
		Case $WM_COMMAND
			; first: check if COMMAND is issued from an input control
			Local $iCtrlID = _WinAPI_LoWord($wParam)
			Local $aInputs = _objGet($__gGuiUtils_inputDialog_oCurrentForm, "inputs")
			For $i = 0 To UBound($aInputs) - 1
				If $iCtrlID = _GUIUtils_CtrlID($__gGuiUtils_inputDialog_oCurrentForm, $aInputs[$i]) Then
					; then: check COMMAND code
					Switch _WinAPI_HiWord($wParam)
						Case $EN_CHANGE, $LBN_SELCHANGE, $CBN_SELCHANGE, $BN_CLICKED
							GUICtrlSendToDummy(_objGet($__gGuiUtils_inputDialog_oCurrentForm, "###___onChangeDummy"), $aInputs[$i])
					EndSwitch
					ExitLoop
				EndIf
			Next
		; ---
		Case $WM_NOTIFY
			Local $tHDR = DllStructCreate($tagNMHDR, $lParam)
			Switch $tHDR.Code
				Case $DTN_DATETIMECHANGE
					Local $aInputs = _objGet($__gGuiUtils_inputDialog_oCurrentForm, "inputs")
					For $i = 0 To UBound($aInputs) - 1
						If $tHDR.IDFrom = _GUIUtils_CtrlID($__gGuiUtils_inputDialog_oCurrentForm, $aInputs[$i]) Then
							GUICtrlSendToDummy(_objGet($__gGuiUtils_inputDialog_oCurrentForm, "###___onChangeDummy"), $aInputs[$i])
							ExitLoop
						EndIf
					Next
			EndSwitch
	EndSwitch
	Return _WinAPI_DefSubclassProc($hWnd, $iMsg, $wParam, $lParam)
EndFunc

Func __guiUtils_inputDialog_controlGet($oForm, $sCtrlName)
	Local $sCtrlClass = __guiUtils_identifyControl(_GUIUtils_HCtrl($oForm, $sCtrlName))
	Switch $sCtrlClass
		Case "Static", "Input", "Edit", "Combobox"
			Return GUICtrlRead(_GUIUtils_CtrlID($oForm, $sCtrlName))

		Case "Listbox"
			If BitAND(_WinAPI_GetWindowLong(_GUIUtils_HCtrl($oForm, $sCtrlName), $GWL_STYLE), $LBS_MULTIPLESEL) Then
				Local $aRet = _GUICtrlListBox_GetSelItemsText(_GUIUtils_HCtrl($oForm, $sCtrlName))
				_ArrayDelete($aRet, 0)
				Return $aRet
			Else
				Local $aRet = _GUICtrlListBox_GetCurSel(_GUIUtils_HCtrl($oForm, $sCtrlName))
				If $aRet = -1 Then Return ""
				Return _GUICtrlListBox_GetText(_GUIUtils_HCtrl($oForm, $sCtrlName), $aRet)
			EndIf

		Case "Checkbox", "Radio"
			Return GUICtrlRead(_GUIUtils_CtrlID($oForm, $sCtrlName)) = $GUI_CHECKED

		Case "Date"
			Local $oOptions = _objGet($oForm, "options", Null)

			Local $tST = _GUICtrlDTP_GetSystemTimeEx(_GUIUtils_HCtrl($oForm, $sCtrlName))
			Return @error ? "" : _WinAPI_GetDateFormat(0, $tST, 0, _objGet($oOptions, $sCtrlName & "_format", "yyyy/MM/dd"))

		Case "Time"
			Local $oOptions = _objGet($oForm, "options", Null)

			Local $tST = _GUICtrlDTP_GetSystemTimeEx(_GUIUtils_HCtrl($oForm, $sCtrlName))
			Return @error ? "" : _WinAPI_GetTimeFormat(0, $tST, 0, _objGet($oOptions, $sCtrlName & "_format")) ;TODO: faudrait pas mettre le format ici???

		Case Else
			If IsFunc($__gGuiUtils_fnCustomInputReader) Then _
				Return $__gGuiUtils_fnCustomInputReader($oForm, $sCtrlName, $sCtrlClass)
	EndSwitch
	Return ""
EndFunc

Func __guiUtils_inputDialog_controlSet($oForm, $sCtrlName, $vData = Null, $vOptions = Null)
	Local $sCtrlClass = __guiUtils_identifyControl(_GUIUtils_HCtrl($oForm, $sCtrlName))
	Switch $sCtrlClass
		Case "Static", "Edit", "Input"
			GUICtrlSetData(_GUIUtils_CtrlID($oForm, $sCtrlName), $vData <> Null ? String($vData) : "")

		Case "Checkbox", "Radio"
			GUICtrlSetState(_GUIUtils_CtrlID($oForm, $sCtrlName), $vData ? $GUI_CHECKED : $GUI_UNCHECKED)

		Case "Combobox"
			If $vOptions <> Null Then
				If Not IsArray($vOptions) Then
					$vOptions = StringSplit($vOptions, Opt("GUIDataSeparatorChar"))
					_ArrayDelete($vOptions, 0)
				EndIf

				_GUICtrlComboBox_BeginUpdate(_GUIUtils_HCtrl($oForm, $sCtrlName))
				_GUICtrlComboBox_ResetContent(_GUIUtils_HCtrl($oForm, $sCtrlName))
				For $i = 0 To UBound($vOptions) - 1
					_GUICtrlComboBox_AddString(_GUIUtils_HCtrl($oForm, $sCtrlName), $vOptions[$i])
				Next
				_GUICtrlComboBox_EndUpdate(_GUIUtils_HCtrl($oForm, $sCtrlName))
			EndIf

			If $vData <> Null Then
				Local $iFind = _GUICtrlComboBox_FindStringExact(_GUIUtils_HCtrl($oForm, $sCtrlName), $vData)
				If $iFind >= 0 Then
					_GUICtrlComboBox_SetCurSel(_GUIUtils_HCtrl($oForm, $sCtrlName), $iFind)
				Else
					If BitAND(_WinAPI_GetWindowLong(_GUIUtils_HCtrl($oForm, $sCtrlName), $GWL_STYLE), $CBS_DROPDOWNLIST) <> $CBS_DROPDOWNLIST Then
						_GUICtrlComboBox_SetEditText(_GUIUtils_HCtrl($oForm, $sCtrlName), $vData)
					EndIf
				EndIf
			Else
				_GUICtrlComboBox_SetCurSel(_GUIUtils_HCtrl($oForm, $sCtrlName))
				_GUICtrlComboBox_SetEditText(_GUIUtils_HCtrl($oForm, $sCtrlName), "")
			EndIf

		Case "Listbox"
			If $vOptions <> Null Then
				If Not IsArray($vOptions) Then
					$vOptions = StringSplit($vOptions, Opt("GUIDataSeparatorChar"))
					_ArrayDelete($vOptions, 0)
				EndIf

				_GUICtrlListBox_BeginUpdate(_GUIUtils_HCtrl($oForm, $sCtrlName))
				_GUICtrlListBox_ResetContent(_GUIUtils_HCtrl($oForm, $sCtrlName))
				For $i = 0 To UBound($vOptions) - 1
					_GUICtrlListBox_AddString(_GUIUtils_HCtrl($oForm, $sCtrlName), $vOptions[$i])
				Next
				_GUICtrlListBox_EndUpdate(_GUIUtils_HCtrl($oForm, $sCtrlName))
			EndIf

			If $vData <> Null Then
				If BitAND(_WinAPI_GetWindowLong(_GUIUtils_HCtrl($oForm, $sCtrlName), $GWL_STYLE), $LBS_MULTIPLESEL) Then
					If Not IsArray($vData) Then
						$vData = StringSplit($vData, Opt("GUIDataSeparatorChar"))
						_ArrayDelete($vData, 0)
					EndIf

					_SendMessage(_GUIUtils_HCtrl($oForm, $sCtrlName), $LB_SETSEL, False, -1) ; deselect all
					For $i = 0 To UBound($vData) - 1
						$iFind = _GUICtrlListBox_FindString(_GUIUtils_HCtrl($oForm, $sCtrlName), $vData[$i], True)
						If $iFind >= 0 Then _SendMessage(_GUIUtils_HCtrl($oForm, $sCtrlName), $LB_SETSEL, True, $iFind)
					Next
				Else
					_GUICtrlListBox_SetCurSel(_GUIUtils_HCtrl($oForm, $sCtrlName), _GUICtrlListBox_FindString(_GUIUtils_HCtrl($oForm, $sCtrlName), $vData, True))
				EndIf
			Else
				If BitAND(_WinAPI_GetWindowLong(_GUIUtils_HCtrl($oForm, $sCtrlName), $GWL_STYLE), $LBS_MULTIPLESEL) Then
					For $i = 0 To _GUICtrlListBox_GetCount(_GUIUtils_HCtrl($oForm, $sCtrlName))
						_GUICtrlListBox_SetSel(_GUIUtils_HCtrl($oForm, $sCtrlName), $i, False)
					Next
				Else
					_GUICtrlListBox_SetCurSel(_GUIUtils_HCtrl($oForm, $sCtrlName), -1)
				EndIf
			EndIf

		Case "Date"
			Local $tST
			If $vData Then
				Local $aDate, $aTime
				_DateTimeSplit($vData, $aDate, $aTime)
				$tST = _Date_Time_EncodeSystemTime($aDate[2], $aDate[3], $aDate[1])
			Else
				$tST = _Date_Time_GetSystemTime()
			EndIf
			_GUICtrlDTP_SetSystemTimeEx(_GUIUtils_HCtrl($oForm, $sCtrlName), $tST, $vData = Null)

		Case "Time"
			Local $tST
			If $vData Then
				Local $aTime = StringSplit($vData, ":")
				While UBound($aTime) < 4
					_ArrayAdd($aTime, 0)
					$aTime[0] += 1
				WEnd
				$tST = _Date_Time_EncodeSystemTime(@MON, @MDAY, @YEAR, $aTime[1], $aTime[2], $aTime[3])
			Else
				$tST = _Date_Time_GetSystemTime()
			EndIf
			_GUICtrlDTP_SetSystemTimeEx(_GUIUtils_HCtrl($oForm, $sCtrlName), $tST, $vData = Null)

		Case Else
			If IsFunc($__gGuiUtils_fnCustomInputWriter) Then _
				$__gGuiUtils_fnCustomInputWriter($oForm, $sCtrlName, $sCtrlClass, $vData, $vOptions)
	EndSwitch
EndFunc

# =================================================================================================
#EndRegion
# =================================================================================================
