#Requires AutoHotkey v2.0
#SingleInstance Force
Persistent

configPath := A_ScriptDir "\WowheadClipboard.ini"
activeKey := IniRead(configPath, "Settings", "Hotkey", "F8")
exitKey := IniRead(configPath, "Settings", "ExitHotkey", "^+F12")
startupShortcut := A_Startup "\WowheadClipboard.lnk"
startAtLogin := FileExist(startupShortcut) != ""
skipPrompt := IniRead(configPath, "Settings", "SkipSettingsPrompt", "0") = "1"
isStartupLaunch := A_Args.Length && A_Args[1] = "--autostart"
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
settingsGui.Add("Text", "xm y+14", "WoW keybind: (must match in-game addon)")
keyField := settingsGui.Add("Hotkey", "xm w185", activeKey)
settingsGui.Add("Text", "xm y+12", "Emergency exit (works anywhere):")
exitField := settingsGui.Add("Hotkey", "xm w185", exitKey)
startupField := settingsGui.Add("CheckBox", "xm y+16 w345", "Start when I sign in to Windows")
startupField.Value := startAtLogin
skipField := settingsGui.Add("CheckBox", "xm y+8 w345", "Don't show settings on manual launch")
skipField.Value := skipPrompt
settingsGui.Add("Button", "xm y+16 w95 Default", "Save").OnEvent("Click", SaveSettings)
settingsGui.Add("Button", "x+10 w95", "Hide").OnEvent("Click", (*) => settingsGui.Hide())
settingsGui.Add("Text", "xm y+16 w340", "Stops after 3 clipboard changes or 3 WoW keypresses within 1 second.")
settingsGui.OnEvent("Close", (*) => settingsGui.Hide())
settingsGui.OnEvent("Escape", (*) => settingsGui.Hide())

HotIf(IsWoWActive)
Hotkey("~" activeKey, CopyFromWoW, "On")
HotIf()
Hotkey(exitKey, EmergencyExit, "On")
OnClipboardChange(OpenWowhead)
A_TrayMenu.Add("Change Keybinds / Settings", ShowSettings)
A_TrayMenu.Default := "Change Keybinds / Settings"
if !isStartupLaunch && !skipPrompt
    settingsGui.Show()

ShowSettings(*) {
    global settingsGui, keyField, exitField, startupField, skipField
    global activeKey, exitKey, skipPrompt, startupShortcut
    keyField.Value := activeKey
    exitField.Value := exitKey
    startupField.Value := FileExist(startupShortcut) != ""
    skipField.Value := skipPrompt
    settingsGui.Show()
}

SetStartup(enabled) {
    global startupShortcut
    if enabled
        FileCreateShortcut(A_AhkPath, startupShortcut, A_ScriptDir,
            '"' A_ScriptFullPath '" --autostart', "Start WowheadClipboard at Windows sign-in")
    else if FileExist(startupShortcut)
        FileDelete(startupShortcut)
}

SaveSettings(*) {
    global activeKey, exitKey, keyField, exitField, configPath, settingsGui
    global startupField, skipField, startAtLogin, skipPrompt
    newKey := keyField.Value
    newExit := exitField.Value
    newStartup := startupField.Value = 1
    newSkip := skipField.Value = 1
    if !newKey || !newExit || RegExMatch(newKey, "^[\^!+]+$") || RegExMatch(newExit, "^[\^!+]+$") {
        MsgBox("Choose two complete key combinations.", "WowheadClipboard")
        return
    }
    if (newKey = newExit) {
        MsgBox("The WoW and emergency-exit keybinds must be different.", "WowheadClipboard")
        return
    }
    if (newKey = activeKey) && (newExit = exitKey)
        && (newStartup = startAtLogin) && (newSkip = skipPrompt) {
        settingsGui.Hide()
        return
    }
    newCopyRegistered := false
    newExitRegistered := false
    startupChanged := false
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
        if (newStartup != startAtLogin) {
            SetStartup(newStartup)
            startupChanged := true
        }
        IniWrite(newKey, configPath, "Settings", "Hotkey")
        IniWrite(newExit, configPath, "Settings", "ExitHotkey")
        IniWrite(newSkip ? "1" : "0", configPath, "Settings", "SkipSettingsPrompt")
    } catch as err {
        HotIf()
        if newCopyRegistered {
            HotIf(IsWoWActive)
            Hotkey("~" newKey, "Off")
            HotIf()
        }
        if newExitRegistered
            Hotkey(newExit, "Off")
        if startupChanged {
            try SetStartup(startAtLogin)
        }
        MsgBox("Could not save settings:`n" err.Message, "WowheadClipboard")
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
    startAtLogin := newStartup
    skipPrompt := newSkip
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
