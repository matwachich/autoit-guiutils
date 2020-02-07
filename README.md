# AutoIt3 GUI Utility Functions
This UDF helps to speed up GUI applications developpement.

It provides functions for:
  - Creating GUI directly from KODA .kxf file
  - Creating Advanced InputBoxes from a simple JSON definition
  - Take a GUI created by either KODA or JSON and use it as a modal Input Dialog

# Examples
## KODA file parsing
```
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
; ===============================================================================================================================
```

You create your GUI normally in KODA

![KODA example koda](/screenshots/koda_simple_koda.png)

One simple function call

```
; #FUNCTION# ====================================================================================================================
; Name ..........: _GUIUtils_CreateFromJSON
; Description ...: Creates an InputBox GUI from JSON definition
; Syntax ........: _GUIUtils_CreateFromJSON($vJson[, $hParent = Null])
; Parameters ....: $vJson               - JSON definition.
;                  $hParent             - [optional] parent GUI handle. Default is Null.
; Return values .: Object (scripting.dictionary) representing the GUI
; Author ........: matwachich
; Remarks .......: See JSON_Form_Definition.txt and examples.
; ===============================================================================================================================
```

![KODA example code](/screenshots/koda_simple_code.png)

And here is the result

![KODA example result](/screenshots/koda_simple.png)

## JSON definition parsing (simple)
You can use a simple JSON defintion to create Input Dialog GUIs. See [JSON_Form_Definition.txt](/JSON_Form_Definition.txt).

Simple JSON definition

![JSON example code](/screenshots/json_simple_code.png)

And here is the result

![JSON example result](/screenshots/json_simple_gui.png)

## JSON definition parsing (advanced)
Here is a showcase of JSON definition.

Advanced JSON definition

![JSON example code](/screenshots/json_adv_code.png)

And here is the result

![JSON example result](/screenshots/json_adv_gui.png)
