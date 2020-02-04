#include-once

Func _objCreate($bCaseSensitiveKeys = False)
	Local $oObj = ObjCreate("Scripting.Dictionary")
	$oObj.CompareMode = ($bCaseSensitiveKeys ? 0 : 1)
	Return $oObj
EndFunc

Func _objSet($oObj, $sKey, $vValue, $bOverwrite = True)
	If Not IsObj($oObj) Then Return SetError(1, 0, False)
	$sKey = String($sKey)
	If $oObj.Exists($sKey) And Not $bOverwrite Then Return SetError(2, 0, False)
	$oObj.Item($sKey) = $vValue
	Return True
EndFunc

Func _objGet($oObj, $sKey, $vDefaultValue = "")
	If Not IsObj($oObj) Then Return SetError(1, 0, Null)
	$sKey = String($sKey)
	If Not $oObj.Exists($sKey) Then Return SetError(2, 0, $vDefaultValue)
	Return $oObj.Item($sKey)
EndFunc

Func _objDel($oObj, $sKey)
	$sKey = String($sKey)
	If Not IsObj($oObj) Or Not $oObj.Exists($sKey) Then Return SetError(1, 0, False)
	$oObj.Remove($sKey)
	Return True
EndFunc

Func _objEmpty($oObj)
	If Not IsObj($oObj) Then Return SetError(1, 0, False)
	$oObj.RemoveAll()
EndFunc

Func _objExists($oObj, $sKey)
	If Not IsObj($oObj) Then Return SetError(1, 0, False)
	Return $oObj.Exists(String($sKey))
EndFunc

Func _objCount($oObj)
	If Not IsObj($oObj) Then Return SetError(1, 0, -1)
	Return $oObj.Count
EndFunc

Func _objKeys($oObj)
	If Not IsObj($oObj) Then Return SetError(1, 0, Null)
	Return $oObj.Keys()
EndFunc

Func _objCopy($oDst, $oSrc, $bOverwrite = False)
	If Not IsObj($oDst) Or Not IsObj($oSrc) Then Return SetError(1, 0, False)
	For $sKey In $oSrc.Keys()
		If Not $oDst.Exists(String($sKey)) Or $bOverwrite Then $oDst.Item(String($sKey)) = $oSrc.Item(String($sKey))
	Next
	Return True
EndFunc

Func _objSubset($oObj, $aKeys, $vDefaultValue = "")
	If Not IsObj($oObj) Then Return SetError(1, 0, Null)

	Local $oRet = ObjCreate("Scripting.Dictionary")
	$oRet.CompareMode = $oObj.CompareMode

	For $i = ($aKeys[0] = UBound($aKeys) - 1 ? 1 : 0) To UBound($aKeys) - 1
		$aKeys[$i] = String($aKeys[$i])
		$oRet.Item($aKeys[$i]) = $oObj.Exists($aKeys[$i]) ? $oObj.Item($aKeys[$i]) : $vDefaultValue
	Next
	Return $oRet
EndFunc
