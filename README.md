# WowheadCopy

A World of Warcraft addon with an optional AutoHotkey v2 companion for opening Wowhead Forever links.

## What it searches

- **Inventory, character equipment, or Inspect equipment open:** hovered item (`item=ID`)
- **Profession window open:** hovered reagent/product (`item=ID`), otherwise selected recipe (`spell=ID`)
- **Otherwise, NPC targeted:** targeted NPC (`npc=ID`)
- **Quest Log or quest dialogue visible:** hovered or selected quest (`quest=ID`)

Does not generate links in combat. NPC identifiers may be protected in dungeons.

## Install and configure

1. Copy the `WowheadCopy` folder into your WoW `Interface/AddOns/` directory.
2. Type `/reload`, then `/whcopy settings` to assign the **in-game** keybind.
3. Install [AutoHotkey v2](https://www.autohotkey.com/) on Windows.
4. Double-click **`WowheadClipboard.ahk`** in the addon folder, set the **same** WoW keybind in its settings window, and click **Save**.
5. Optionally create a Windows desktop shortcut to `WowheadClipboard.ahk` for convenient manual launching.

Profession recipe lookup uses the selected recipe spell ID, not necessarily the item it creates. The character or Inspect pane must be on its equipment tab, and you must hover an equipped item. Inspect uses the item displayed in the tooltip, not the inspected player's character ID.

The AHK script must be started separately; WoW cannot launch it. Use its tray icon to reopen settings or exit. Keybinds are saved to `WowheadClipboard.ini` beside the script (ignored by Git).

## How it works

When you press the shared keybind, the addon briefly opens chat with a Wowhead URL highlighted. AHK waits **60 ms**, sends `Ctrl+C`, and opens the link in your browser. Lua clears and closes the temporary chat input after **150 ms**. The chat text is highlighted again on the next frame to account for Blizzard's delayed chat initialization. Failed lookups clear any previous addon-generated URL and open an empty chat input for the same interval, absorbing Ctrl+C without triggering the character pane. Quest IDs are read only while a quest window is actually visible; closing the Quest Log no longer reuses its previously selected quest.

## Safeguards

- **One trigger, one URL:** AHK accepts only the first clipboard change within **200 ms** of the shared keybind, and requires WoW to remain active.
- **Strict URLs:** Only `https://wowhead.com/forever/{item|npc|quest|spell}=ID` links are accepted (optional `www`).
- **250 ms throttle:** Repeated WoW keypresses do not initiate repeated copies in rapid succession.
- **Emergency exit:** Press **Ctrl+Shift+F12** anywhere to close the AHK companion immediately; change this shortcut in the AHK settings GUI.
- **Automatic emergency exit:** AHK shuts down on **3 clipboard changes in any rolling 1-second interval** while WoW is running. It also shuts down on **3 captured WoW-keybind presses in 1 second**, including key repeats suppressed by the normal throttle. Restart the `.ahk` file manually afterward.

**Limitations:** AHK cannot inspect Lua chat edit-box focus or know whether the addon produced a URL. In combat or after a failed lookup, the addon uses a temporary empty chat input to absorb Ctrl+C. If the addon fails to run at all (for example, an unbound shortcut or Lua error), AHK cannot guarantee it will avoid WoW's `C` action. Short timing intervals are best-effort and may need adjustment for lag or other addons. Unmodified keys (such as `F8`) are recommended initially. The addon does not overwrite an existing chat message.
