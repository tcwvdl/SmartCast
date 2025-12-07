-- SmartCastOptions.lua

SmartCast_Saved = SmartCast_Saved or {}

-------------------------------------------------
-- Helper Functions
-------------------------------------------------

local function Round2(x)
    if not x or x ~= x then return 0 end
    x = math.max(0, math.min(1, x))
    return math.floor(x * 100 + 0.5) / 100
end

local function FormatCoeff(val)
    return string.format("%.2f", val or 0)
end

local function GetMultiRankSpells()
    local spellRankCounts = {}
    local i = 1
    
    -- Scan entire spellbook
    while true do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not name then break end
        spellRankCounts[name] = (spellRankCounts[name] or 0) + 1
        i = i + 1
    end
    
    -- Categorize spells with multiple ranks
    local categorized = {
        Healing = {},
        Damage = {},
        Totems = {},
        Utility = {}
    }
    
    for spell, count in pairs(spellRankCounts) do
        if count > 1 then
            -- Simple categorization based on spell name
            if spell:match("Heal") or spell:match("Mend") or spell:match("Renewal") then
                table.insert(categorized.Healing, spell)
            elseif spell:match("Totem") then
                table.insert(categorized.Totems, spell)
            elseif spell:match("Bolt") or spell:match("Shock") or spell:match("Nova") or spell:match("Blast") or spell:match("Strike") then
                table.insert(categorized.Damage, spell)
            else
                table.insert(categorized.Utility, spell)
            end
        end
    end
    
    for _, list in pairs(categorized) do
        table.sort(list)
    end
    
    return categorized
end

-------------------------------------------------
-- Main Options Panel
-------------------------------------------------

local mainOptions = CreateFrame("Frame", "SmartCastMainOptions")
mainOptions.name = "Options"
mainOptions.parent = "SmartCast"

local title = mainOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("SmartCast Options")

-------------------------------------------------
-- Mana Coefficient Section
-------------------------------------------------

local strategyLabel = mainOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
strategyLabel:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -20)
strategyLabel:SetText("Mana-Efficient Rank Selection")

local strategyDesc = mainOptions:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
strategyDesc:SetPoint("TOPLEFT", strategyLabel, "BOTTOMLEFT", 0, -5)
strategyDesc:SetText("SmartCast automatically selects the highest spell rank within your mana budget.")
strategyDesc:SetTextColor(0.8, 0.8, 0.8)

local sliderTitle = mainOptions:CreateFontString(nil, "ARTWORK", "GameFontNormal")
sliderTitle:SetPoint("TOPLEFT", strategyDesc, "BOTTOMLEFT", 0, -15)
sliderTitle:SetText("Mana Coefficient (max % of current mana to spend per cast)")

local slider = CreateFrame("Slider", "SmartCastManaCoeffSlider", mainOptions, "OptionsSliderTemplate")
slider:SetPoint("TOPLEFT", sliderTitle, "BOTTOMLEFT", 0, -10)
slider:SetMinMaxValues(0, 1)
slider:SetValueStep(0.01)
slider:SetObeyStepOnDrag(true)
slider:SetWidth(200)

_G[slider:GetName() .. "Low"]:SetText("0.00")
_G[slider:GetName() .. "High"]:SetText("1.00")
_G[slider:GetName() .. "Text"]:SetText("")

local editBox = CreateFrame("EditBox", "SmartCastManaCoeffBox", mainOptions, "InputBoxTemplate")
editBox:SetSize(50, 20)
editBox:SetPoint("LEFT", slider, "RIGHT", 10, 0)
editBox:SetAutoFocus(false)
editBox:SetNumeric(false)

local isUpdating = false

local function SetCoefficient(value)
    local rounded = Round2(value)
    SmartCast_Saved.manaCoeff = rounded
    
    isUpdating = true
    slider:SetValue(rounded)
    editBox:SetText(FormatCoeff(rounded))
    isUpdating = false
    
    -- Debug output
    if SmartCast_Saved.debugMode then
        print(string.format("[SmartCast] Coefficient set to: %.2f", rounded))
    end
    
    -- Refresh all buttons to use new coefficient
    SmartCast.RefreshAllButtons()
end

slider:SetScript("OnValueChanged", function(self, value)
    if isUpdating then return end
    SetCoefficient(value)
end)

editBox:SetScript("OnEnterPressed", function(self)
    local text = self:GetText():gsub(",", ".")
    local value = tonumber(text)
    if value then
        SetCoefficient(value)
    else
        self:SetText(FormatCoeff(slider:GetValue()))
    end
    self:ClearFocus()
end)

editBox:SetScript("OnEditFocusLost", function(self)
    self:SetText(FormatCoeff(slider:GetValue()))
end)

editBox:SetScript("OnEscapePressed", function(self)
    self:SetText(FormatCoeff(slider:GetValue()))
    self:ClearFocus()
end)

slider:EnableMouseWheel(true)
slider:SetScript("OnMouseWheel", function(self, delta)
    local step = self:GetValueStep() or 0.01
    local newValue = self:GetValue() + (delta > 0 and step or -step)
    SetCoefficient(newValue)
end)

-------------------------------------------------
-- Button Controls
-------------------------------------------------

local controlsHeader = mainOptions:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
controlsHeader:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -40)
controlsHeader:SetText("Button Settings")

local controlsFrame = CreateFrame("Frame", nil, mainOptions)
controlsFrame:SetPoint("TOPLEFT", controlsHeader, "BOTTOMLEFT", 0, -10)
controlsFrame:SetSize(400, 120)

-- Scale Slider
local scaleLabel = controlsFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
scaleLabel:SetPoint("TOPLEFT", 0, 0)
scaleLabel:SetText("Button Scale")

local scaleSlider = CreateFrame("Slider", "SmartCastScaleSlider", controlsFrame, "OptionsSliderTemplate")
scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 0, -10)
scaleSlider:SetMinMaxValues(0.5, 2.0)
scaleSlider:SetValueStep(0.1)
scaleSlider:SetObeyStepOnDrag(true)
scaleSlider:SetWidth(150)

_G[scaleSlider:GetName() .. "Low"]:SetText("50%")
_G[scaleSlider:GetName() .. "High"]:SetText("200%")
_G[scaleSlider:GetName() .. "Text"]:SetText("")

local scaleValue = controlsFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
scaleValue:SetPoint("LEFT", scaleSlider, "RIGHT", 10, 0)

scaleSlider:SetScript("OnValueChanged", function(self, value)
    SmartCast.SetButtonScale(value)
    scaleValue:SetText(string.format("%.0f%%", value * 100))
end)

-- Lock Checkbox
local lockCheckbox = CreateFrame("CheckButton", nil, controlsFrame, "InterfaceOptionsCheckButtonTemplate")
lockCheckbox:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", 0, -25)
lockCheckbox.Text:SetText("Lock Button Positions")
lockCheckbox:SetScript("OnClick", function(self)
    SmartCast.SetButtonsLocked(self:GetChecked())
end)

-- Auto-enable New Ranks
local autoEnableCheckbox = CreateFrame("CheckButton", nil, controlsFrame, "InterfaceOptionsCheckButtonTemplate")
autoEnableCheckbox:SetPoint("TOPLEFT", lockCheckbox, "BOTTOMLEFT", 0, -5)
autoEnableCheckbox.Text:SetText("Auto-enable New Ranks")
autoEnableCheckbox:SetScript("OnClick", function(self)
    SmartCast_Saved.autoEnableNewRanks = self:GetChecked()
end)

-- Reset Positions
local resetBtn = CreateFrame("Button", nil, controlsFrame, "UIPanelButtonTemplate")
resetBtn:SetSize(140, 24)
resetBtn:SetPoint("TOPLEFT", autoEnableCheckbox, "BOTTOMLEFT", 0, -10)
resetBtn:SetText("Reset Positions")
resetBtn:SetScript("OnClick", function()
    SmartCast.ResetAllPositions()
end)

-------------------------------------------------
-- Spells Panel
-------------------------------------------------

local spellsPanel = CreateFrame("Frame", "SmartCastSpellsPanel")
spellsPanel.name = "Spells"
spellsPanel.parent = "SmartCast"

local spellsTitle = spellsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
spellsTitle:SetPoint("TOPLEFT", 16, -16)
spellsTitle:SetText("Smart Spells")

local spellsDescription = spellsPanel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
spellsDescription:SetPoint("TOPLEFT", spellsTitle, "BOTTOMLEFT", 0, -5)
spellsDescription:SetText("Enable smart rank selection for multi-rank spells.")
spellsDescription:SetTextColor(0.8, 0.8, 0.8)

-- Scroll Frame
local scrollFrame = CreateFrame("ScrollFrame", "SmartCastSpellsScrollFrame", spellsPanel, "UIPanelScrollFrameTemplate")
scrollFrame:SetPoint("TOPLEFT", spellsDescription, "BOTTOMLEFT", 0, -10)
scrollFrame:SetPoint("BOTTOMRIGHT", spellsPanel, "BOTTOMRIGHT", -30, 10)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(1, 1)
scrollFrame:SetScrollChild(content)

local checkboxes = {}

local function BuildSpellCheckboxes()
    -- Hide existing checkboxes
    for _, cb in ipairs(checkboxes) do
        cb:Hide()
    end
    wipe(checkboxes)
    
    local categorized = GetMultiRankSpells()
    local yOffset = -10
    local categoryOrder = {"Healing", "Damage", "Totems", "Utility"}
    
    local totalSpells = 0
    for _, spells in pairs(categorized) do
        totalSpells = totalSpells + #spells
    end
    
    if totalSpells == 0 then
        -- Show a message if no multi-rank spells found
        local noSpells = CreateFrame("Frame", nil, content)
        noSpells:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
        noSpells:SetSize(400, 40)
        
        local text = noSpells:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        text:SetPoint("TOPLEFT", 0, 0)
        text:SetText("No multi-rank spells found in your spellbook.")
        text:SetTextColor(0.8, 0.8, 0.8)
        
        table.insert(checkboxes, noSpells)
        content:SetHeight(60)
        return
    end
    
    for _, category in ipairs(categoryOrder) do
        local spells = categorized[category]
        
        if #spells > 0 then
            -- Category header
            local header = CreateFrame("Frame", nil, content)
            header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, yOffset)
            header:SetSize(300, 20)
            
            local headerText = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
            headerText:SetPoint("LEFT", 0, 0)
            headerText:SetText(category)
            headerText:SetTextColor(1, 0.82, 0)
            
            table.insert(checkboxes, header)
            yOffset = yOffset - 25
            
            -- Spell checkboxes
            for _, spell in ipairs(spells) do
                local cb = CreateFrame("CheckButton", nil, content, "InterfaceOptionsCheckButtonTemplate")
                cb:SetPoint("TOPLEFT", content, "TOPLEFT", 20, yOffset)
                cb.Text:SetText(spell)
                cb:SetChecked(SmartCast_Saved[spell] and SmartCast_Saved[spell].enabled or false)
                
                cb:SetScript("OnClick", function(self)
                    SmartCast.SetEnabled(spell, self:GetChecked())
                end)
                
                table.insert(checkboxes, cb)
                yOffset = yOffset - 32
            end
            
            yOffset = yOffset - 10
        end
    end
    
    content:SetHeight(math.max(1, -yOffset + 20))
end

-------------------------------------------------
-- Panel Refresh
-------------------------------------------------

mainOptions:SetScript("OnShow", function(self)
    SetCoefficient(SmartCast_Saved.manaCoeff or 0.76)
    
    local scale = SmartCast.GetButtonScale()
    scaleSlider:SetValue(scale)
    scaleValue:SetText(string.format("%.0f%%", scale * 100))
    
    lockCheckbox:SetChecked(SmartCast.AreButtonsLocked())
    autoEnableCheckbox:SetChecked(SmartCast_Saved.autoEnableNewRanks ~= false)
end)

spellsPanel:SetScript("OnShow", function(self)
    -- Always rebuild to ensure latest spellbook data
    BuildSpellCheckboxes()
end)

-------------------------------------------------
-- Register Panels
-------------------------------------------------

local function RegisterOptions()
    -- Create a parent frame (invisible, just for hierarchy)
    local parentFrame = CreateFrame("Frame")
    parentFrame.name = "SmartCast"
    
    -- Register main Options panel under SmartCast parent
    mainOptions.name = "Options"
    mainOptions.parent = parentFrame.name
    
    -- Register Spells panel under SmartCast parent
    spellsPanel.name = "Spells"
    spellsPanel.parent = parentFrame.name
    
    -- Register in order: parent first, then children
    InterfaceOptions_AddCategory(parentFrame)
    InterfaceOptions_AddCategory(mainOptions)
    InterfaceOptions_AddCategory(spellsPanel)
end

-- Initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if arg1 == "SmartCast" then
        RegisterOptions()
        
        -- Pre-build spell list to avoid empty first open
        C_Timer.After(1, function()
            BuildSpellCheckboxes()
        end)
    end
end)