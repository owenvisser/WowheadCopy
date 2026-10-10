#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

configPath := A_ScriptDir "\WowheadClipboard.ini"
activeKey := IniRead(configPath, "Settings", "Hotkey", "F8")
exitKey := IniRead(configPath, "Settings", "ExitHotkey", "^+F12")
A_IconTip := "WowheadClipboard - WowheadCopy companion"
copyArmed := false
copyIssued := false
copyDeadline := 0
lastTrigger := -1000
clipboardEvents := []
keyEvents := []

settingsGui := Gui(, "WowheadClipboard Settings")
settingsGui.SetFont("s9", "Segoe UI")
settingsGui.Add("Text", "xm w340", "Match the WoW shortcut to your WowheadCopy keybind.")
settingsGui.Add("Text", "xm y+14", "WoW keybind:")
keyField := settingsGui.Add("Hotkey", "xm w185", activeKey)
settingsGui.Add("Text", "xm y+12", "Emergency exit (works anywhere):")
exitField := settingsGui.Add("Hotkey", "xm w185", exitKey)
settingsGui.Add("Button", "xm y+16 w95 Default", "Save").OnEvent("Click", SaveSettings)
settingsGui.Add("Button", "x+10 w95", "Hide").OnEvent("Click", (*) => settingsGui.Hide())
settingsGui.Add("Text", "xm y+16 w340", "Stops after 5 clipboard changes or 5 WoW keypresses within 1 second.")
settingsGui.OnEvent("Close", (*) => settingsGui.Hide())
settingsGui.OnEvent("Escape", (*) => settingsGui.Hide())

HotIf(IsWoWActive)
Hotkey("~" activeKey, CopyFromWoW, "On")
HotIf()
Hotkey(exitKey, EmergencyExit, "On")
OnClipboardChange(OpenWowhead)
A_TrayMenu.Add("Settings", ShowSettings)
A_TrayMenu.Default := "Settings"
settingsGui.Show()

ShowSettings(*) {
    global settingsGui, keyField, exitField, activeKey, exitKey
    keyField.Value := activeKey
    exitField.Value := exitKey
    settingsGui.Show()
}

SaveSettings(*) {
    global activeKey, exitKey, keyField, exitField, configPath, settingsGui
    newKey := keyField.Value
    newExit := exitField.Value
    if !newKey || !newExit || RegExMatch(newKey, "^[\^!+]+$") || RegExMatch(newExit, "^[\^!+]+$") {
        MsgBox("Choose two complete key combinations.", "WowheadClipboard")
        return
    }
    if (newKey = newExit) {
        MsgBox("The WoW and emergency-exit keybinds must be different.", "WowheadClipboard")
        return
    }
    if (newKey = activeKey) && (newExit = exitKey) {
        settingsGui.Hide()
        return
    }
    newCopyRegistered := false
    newExitRegistered := false
    try {
        if (newKey != activeKey) {
            HotIf(IsWoWActive)
            Hotkey("~" newKey, CopyFromWoW, "On")
            HotIf()
            newCopyRegistered := true
        }
        if (newExit != exitKey) {
            Hotkey(newExit, EmergencyExit, "On")
            newExitRegistered := true
        }
        IniWrite(newKey, configPath, "Settings", "Hotkey")
        IniWrite(newExit, configPath, "Settings", "ExitHotkey")
    } catch as err {
        HotIf()
        if newCopyRegistered {
            HotIf(IsWoWActive)
            Hotkey("~" newKey, "Off")
            HotIf()
        }
        if newExitRegistered
            Hotkey(newExit, "Off")
        MsgBox("Could not save keybinds:`n" err.Message, "WowheadClipboard")
        return
    }
    if (newKey != activeKey) {
        HotIf(IsWoWActive)
        Hotkey("~" activeKey, "Off")
        HotIf()
    }
    if (newExit != exitKey)
        Hotkey(exitKey, "Off")
    activeKey := newKey
    exitKey := newExit
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

EmergencyExit(*) {
    ExitApp()
}

CheckBurst(events) {
    now := A_TickCount
    events.Push(now)
    while events.Length && (now - events[1] < 0 || now - events[1] >= 1000)
        events.RemoveAt(1)
    if events.Length >= 3
        ExitApp()
}

CopyFromWoW(*) {
    global copyArmed, copyIssued, copyDeadline, lastTrigger, keyEvents
    CheckBurst(keyEvents)
    if copyArmed || (A_TickCount - lastTrigger < 250)
        return
    lastTrigger := A_TickCount
    copyArmed := true
    copyIssued := false
    copyDeadline := A_TickCount + 200
    SetTimer(ExpireCopy, -200)
    Sleep(60)
    if !copyArmed || !IsWoWActive() {
        copyArmed := false
        return
    }
    copyIssued := true
    Send("^c")
}

ExpireCopy() {
    global copyArmed, copyIssued
    copyArmed := false
    copyIssued := false
}

OpenWowhead(type) {
    global copyArmed, copyIssued, copyDeadline, clipboardEvents
    if IsWoWRunning()
        CheckBurst(clipboardEvents)
    else
        clipboardEvents := []
    if !copyArmed || !copyIssued
        return
    copyArmed := false  ; Consume one clipboard change per activation.
    copyIssued := false
    if (type != 1) || (A_TickCount > copyDeadline) || !IsWoWActive()
        return
    url := Trim(A_Clipboard)
    if RegExMatch(url, "i)^https://(www\.)?wowhead\.com/forever/(item|npc|quest|spell)=[0-9]+$")
        Run(url)
}
