BINDING_HEADER_WOWHEADCOPY = "WowheadCopy"
BINDING_NAME_WOWHEADCOPY_HOVER = "Generate Wowhead Forever URL"

local ACTION = "WOWHEADCOPY_HOVER"
local URL_PREFIX = "https://www.wowhead.com/forever/"

-- 1. TEMPORARY CHAT LINK
local pendingChat, pendingURL, transferToken = nil, nil, 0
local function CloseTransfer()
    if pendingChat and ChatEdit_GetActiveWindow() == pendingChat
        and pendingChat:GetText() == pendingURL then
        pendingChat:SetText("")
        ChatEdit_DeactivateChat(pendingChat)
    end
    pendingChat, pendingURL = nil, nil
end

-- 2. KEYBIND SETTINGS
local settings = CreateFrame("Frame", "WowheadCopySettings", UIParent, "BasicFrameTemplateWithInset")
settings:SetSize(440, 224)
settings:SetPoint("CENTER", 0, 30)
settings:SetFrameStrata("DIALOG")
settings.TitleText:SetText("WowheadCopy - Keybind")
settings:SetMovable(true)
settings:EnableMouse(true)
settings:RegisterForDrag("LeftButton")
settings:SetScript("OnDragStart", settings.StartMoving)
settings:SetScript("OnDragStop", settings.StopMovingOrSizing)
settings:Hide()

local instructions = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
instructions:SetPoint("TOP", 0, -48)
instructions:SetText("Assign the key that generates the context-sensitive URL.")

local boundLabel = settings:CreateFontString(nil, "OVERLAY", "GameFontNormal")
boundLabel:SetPoint("TOP", 0, -80)

local bindButton = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
bindButton:SetSize(154, 25)
bindButton:SetPoint("TOP", -86, -109)
bindButton:SetText("Set Keybind")

local clearButton = CreateFrame("Button", nil, settings, "UIPanelButtonTemplate")
clearButton:SetSize(154, 25)
clearButton:SetPoint("TOP", 86, -109)
clearButton:SetText("Clear Keybind")

local status = settings:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", 0, -154)
status:SetWidth(402)
status:SetJustifyH("CENTER")
status:SetText("Press Set Keybind, then press a key combination.")

local note = settings:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
note:SetPoint("BOTTOM", 0, 19)
note:SetText("An occupied shortcut will replace its previous WoW binding.")

local capturing = false
local function UpdateBindingLabel()
    local keys = {GetBindingKey(ACTION)}
    boundLabel:SetText("Current keybind: " .. (#keys > 0 and table.concat(keys, ", ") or "Not set"))
end

local function StopCapture()
    capturing = false
    settings:EnableKeyboard(false)
    bindButton:SetText("Set Keybind")
    UpdateBindingLabel()
end

bindButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        status:SetText("Keybindings cannot be changed during combat.")
        return
    end
    if capturing then
        StopCapture()
        status:SetText("Keybind selection cancelled.")
        return
    end
    capturing = true
    bindButton:SetText("Cancel")
    status:SetText("Press a key combination now (Esc to cancel).")
    settings:SetPropagateKeyboardInput(false)
    settings:EnableKeyboard(true)
end)

settings:SetScript("OnKeyDown", function(self, key)
    if not capturing then return end
    if key == "ESCAPE" then
        StopCapture()
        status:SetText("Keybind selection cancelled.")
        return
    end
    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
        or key == "LALT" or key == "RALT" or key == "LMETA" or key == "RMETA"
        or key == "UNKNOWN" then return end
    local binding = (IsControlKeyDown() and "CTRL-" or "")
        .. (IsAltKeyDown() and "ALT-" or "")
        .. (IsShiftKeyDown() and "SHIFT-" or "") .. key
    local previous = GetBindingAction(binding)
    local oldKeys = {GetBindingKey(ACTION)}
    if SetBinding(binding, ACTION) then
        for _, oldKey in ipairs(oldKeys) do
            if oldKey ~= binding then SetBinding(oldKey) end
        end
        SaveBindings(GetCurrentBindingSet())
        status:SetText("Saved " .. binding .. (previous and previous ~= "" and previous ~= ACTION and " (replaced previous binding)." or "."))
    else
        status:SetText("Could not assign " .. binding .. ".")
    end
    StopCapture()
end)

clearButton:SetScript("OnClick", function()
    if InCombatLockdown() then
        status:SetText("Keybindings cannot be changed during combat.")
        return
    end
    if capturing then StopCapture() end
    for _, key in ipairs({GetBindingKey(ACTION)}) do SetBinding(key) end
    SaveBindings(GetCurrentBindingSet())
    UpdateBindingLabel()
    status:SetText("Keybind cleared.")
end)

settings:SetScript("OnShow", UpdateBindingLabel)
settings:SetScript("OnHide", function()
    if capturing then StopCapture() end
end)

local combatWatcher = CreateFrame("Frame")
combatWatcher:RegisterEvent("PLAYER_REGEN_DISABLED")
combatWatcher:SetScript("OnEvent", function()
    CloseTransfer()
    settings:Hide()
end)

-- 3. CONTEXT DETECTION (INVENTORY > NPC TARGET > QUEST)
local function BagsOpen()
    if IsBagOpen then
        for bag = 0, NUM_BAG_SLOTS or 4 do
            if IsBagOpen(bag) then return true end
        end
    end
    return ContainerFrameCombinedBags and ContainerFrameCombinedBags:IsShown()
end

local function HoveredItemID()
    if not GameTooltip:IsShown() then return end
    local _, link = GameTooltip:GetItem()
    return link and link:match("item:(%d+)")
end

local function TargetNPCID()
    local guid = UnitGUID("target")
    if issecretvalue and issecretvalue(guid) then return nil, true end
    if not guid then return end
    local unitType, npcID = guid:match("^(%a+)%-[^-]+%-[^-]+%-[^-]+%-[^-]+%-(%d+)")
    if unitType == "Creature" or unitType == "Vehicle" then return npcID end
end

local tooltipType, tooltipID
if TooltipDataProcessor and TooltipDataProcessor.AllTypes and TooltipDataProcessor.AddTooltipPostCall then
    TooltipDataProcessor.AddTooltipPostCall(TooltipDataProcessor.AllTypes, function(tooltip, data)
        if tooltip == GameTooltip then
            tooltipType, tooltipID = data.type, data.id
        end
    end)
    GameTooltip:HookScript("OnHide", function()
        tooltipType, tooltipID = nil, nil
    end)
end

local function HoveredQuestID()
    local focus = GetMouseFoci and GetMouseFoci() or {GetMouseFocus and GetMouseFocus()}
    for _, region in ipairs(focus) do
        local node = region
        for i = 1, 6 do
            if not node then break end
            if type(node.questID) == "number" and node.questID > 0 then
                return node.questID
            end
            if type(node.questLogIndex) == "number" and C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
                local id = C_QuestLog.GetQuestIDForLogIndex(node.questLogIndex)
                if id and id > 0 then return id end
            end
            node = node.GetParent and node:GetParent()
        end
    end
    if GameTooltip:IsShown() and Enum and Enum.TooltipDataType
        and tooltipType == Enum.TooltipDataType.Quest and tooltipID and tooltipID > 0 then
        return tooltipID
    end
end

local function SelectedQuestID()
    if QuestFrame and QuestFrame:IsShown() and GetQuestID then
        local id = GetQuestID()
        if id and id > 0 then return id end
    end
    local questLogVisible = (QuestLogFrame and QuestLogFrame:IsShown())
        or (QuestMapFrame and QuestMapFrame:IsShown())
    if not questLogVisible then return end
    if C_QuestLog and C_QuestLog.GetSelectedQuest then
        local id = C_QuestLog.GetSelectedQuest()
        if id and id > 0 then return id end
    end
    if GetQuestLogSelection then
        local index = GetQuestLogSelection()
        if index and index > 0 then
            if C_QuestLog and C_QuestLog.GetQuestIDForLogIndex then
                local id = C_QuestLog.GetQuestIDForLogIndex(index)
                if id and id > 0 then return id end
            elseif GetQuestLogTitle then
                local _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(index)
                if not isHeader and id and id > 0 then return id end
            end
        end
    end
end

function WowheadCopy_HoveredItem()
    if InCombatLockdown() then
        print("WowheadCopy: Unavailable during combat.")
        return
    end
    local kind, id
    if BagsOpen() then
        kind, id = "item", HoveredItemID()
        if not id then
            print("WowheadCopy: Inventory is open. Hover over an item and try again.")
            return
        end
    elseif UnitExists("target") then
        local protected
        id, protected = TargetNPCID()
        kind = "npc"
        if not id then
            print(protected and "WowheadCopy: Target GUID is protected; try again after the encounter."
                or "WowheadCopy: Your target is not an NPC with an available NPC ID.")
            return
        end
    else
        kind, id = "quest", HoveredQuestID()
        id = id or SelectedQuestID()
        if not id then
            print("WowheadCopy: Hover over or select a quest in the Quest Log (or open a quest at an NPC).")
            return
        end
    end

    -- Use chat only as a brief, selectable clipboard transfer field.
    if ChatEdit_GetActiveWindow() then
        print("WowheadCopy: Finish your current chat message before generating a link.")
        return
    end
    local url = URL_PREFIX .. kind .. "=" .. id
    ChatFrame_OpenChat(url)
    local editBox = ChatEdit_GetActiveWindow()
    if not editBox then
        print("WowheadCopy: Could not open the chat input.")
        return
    end
    editBox:SetText(url)
    editBox:HighlightText()
    pendingChat, pendingURL = editBox, url
    transferToken = transferToken + 1
    local token = transferToken
    C_Timer.After(0.1, function()
        if transferToken == token then CloseTransfer() end
    end)
end

SLASH_WOWHEADCOPY1 = "/whcopy"
SlashCmdList.WOWHEADCOPY = function(msg)
    if InCombatLockdown() then
        print("WowheadCopy: Unavailable during combat.")
        return
    end
    local command = msg and msg:lower():match("^%s*(%S+)")
    if command == "settings" or command == "config" or command == "bind" then
        settings:Show()
    else
        -- Allow a typed /whcopy command to finish closing its chat input.
        C_Timer.After(0, WowheadCopy_HoveredItem)
    end
end
