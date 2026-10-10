#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

configPath := A_ScriptDir "\WowheadClipboard.ini"
activeKey := IniRead(configPath, "Settings", "Hotkey", "F8")
A_IconTip := "WowheadClipboard - WowheadCopy companion"

settingsGui := Gui(, "WowheadClipboard Settings")
settingsGui.SetFont("s9", "Segoe UI")
settingsGui.Add("Text", "xm w330", "Match this shortcut to your WowheadCopy keybind in WoW.")
settingsGui.Add("Text", "xm y+14", "Keybind:")
keyField := settingsGui.Add("Hotkey", "xm w185", activeKey)
settingsGui.Add("Button", "xm y+16 w95 Default", "Save").OnEvent("Click", SaveKeybind)
settingsGui.Add("Button", "x+10 w95", "Hide").OnEvent("Click", (*) => settingsGui.Hide())
settingsGui.Add("Text", "xm y+16 w330", "While WoW is active: press the key, wait 35 ms, copy the selected link, and open Wowhead.")
settingsGui.OnEvent("Close", (*) => settingsGui.Hide())
settingsGui.OnEvent("Escape", (*) => settingsGui.Hide())

HotIf(IsWoWActive)
Hotkey("~" activeKey, CopyFromWoW, "On")
HotIf()
OnClipboardChange(OpenWowhead)
A_TrayMenu.Add("Settings", ShowSettings)
A_TrayMenu.Default := "Settings"
settingsGui.Show()

ShowSettings(*) {
    global settingsGui, keyField, activeKey
    keyField.Value := activeKey
    settingsGui.Show()
}

SaveKeybind(*) {
    global activeKey, keyField, configPath, settingsGui
    newKey := keyField.Value
    if !newKey || RegExMatch(newKey, "^[\^!+]+$") {
        MsgBox("Choose a complete key combination.", "WowheadClipboard")
        return
    }
    if (newKey = activeKey) {
        settingsGui.Hide()
        return
    }
    try {
        HotIf(IsWoWActive)
        Hotkey("~" newKey, CopyFromWoW, "On")
        HotIf()
    } catch as err {
        HotIf()
        MsgBox("Unable to register this keybind:`n" err.Message, "WowheadClipboard")
        return
    }
    try IniWrite(newKey, configPath, "Settings", "Hotkey")
    catch as err {
        HotIf(IsWoWActive)
        Hotkey("~" newKey, "Off")
        HotIf()
        MsgBox("Unable to save the keybind:`n" err.Message, "WowheadClipboard")
        return
    }
    HotIf(IsWoWActive)
    Hotkey("~" activeKey, "Off")
    HotIf()
    activeKey := newKey
    settingsGui.Hide()
}

IsWoWActive(*) {
    return WinActive("ahk_exe Wow.exe") || WinActive("ahk_exe WowClassic.exe")
        || WinActive("ahk_exe WowClassicT.exe") || WinActive("ahk_exe WowB.exe")
}

IsWoWRunning() {
    return ProcessExist("Wow.exe") || ProcessExist("WowClassic.exe")
        || ProcessExist("WowClassicT.exe") || ProcessExist("WowB.exe")
}

CopyFromWoW(*) {
    Sleep(35)
    if IsWoWActive()
        Send("^c")
}

OpenWowhead(type) {
    if (type != 1) || !IsWoWRunning()
        return
    url := Trim(A_Clipboard)
    if RegExMatch(url, "i)^https://(www\.)?wowhead\.com/")
        Run(url)
}
