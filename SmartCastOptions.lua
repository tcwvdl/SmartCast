-- SmartCastOptions.lua
local options = CreateFrame("Frame", "SmartCastOptions")
options.name = "SmartCast"

local title = options:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("SmartCast Options")

-- Utility: collect all non-passive spells with multiple ranks
local function GetMultiRankSpells()
    local spells = {}
    local i = 1
    while true do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not name then break end
        local _, spellID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
        if spellID and not IsPassiveSpell(i, BOOKTYPE_SPELL) then
            spells[name] = (spells[name] or 0) + 1
        end
        i = i + 1
    end
    local list = {}
    for spellName, count in pairs(spells) do
        if count > 1 then
            table.insert(list, spellName)
        end
    end
    table.sort(list)
    return list
end

options:SetScript("OnShow", function(self)
    if self.init then return end
    self.init = true

    local DB = SmartCast_Saved
    local checkboxes = {}

    local function BuildSpellCheckboxes()
        -- Hide old checkboxes only (not the refresh button)
        for _, cb in ipairs(checkboxes) do cb:Hide() end
        wipe(checkboxes)

        local spells = GetMultiRankSpells()
        local y = -60
        for _, spell in ipairs(spells) do
            local cb = CreateFrame("CheckButton", nil, self, "InterfaceOptionsCheckButtonTemplate")
            cb:SetPoint("TOPLEFT", 16, y)
            cb.Text:SetText(spell)
            cb:SetChecked(DB[spell] and DB[spell].enabled or false)
            cb:SetScript("OnClick", function(btn)
                SmartCast.SetEnabled(spell, btn:GetChecked())
            end)
            table.insert(checkboxes, cb)
            y = y - 32
        end
    end

    -- Build initial list
    BuildSpellCheckboxes()

    -- Persistent refresh button anchored at bottom
    local refreshBtn = CreateFrame("Button", nil, self, "UIPanelButtonTemplate")
    refreshBtn:SetSize(140, 24)
    refreshBtn:SetPoint("BOTTOMLEFT", 16, 16) -- fixed bottom position
    refreshBtn:SetText("Refresh Spells")
    refreshBtn:SetScript("OnClick", function()
        BuildSpellCheckboxes()
    end)
end)

-- Register options category
local cat = Settings.RegisterCanvasLayoutCategory(options, options.name)
cat.ID = options.name
Settings.RegisterAddOnCategory(cat)

