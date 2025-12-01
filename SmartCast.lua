-- SmartCast.lua
local addonName, addonTable = ...
SmartCast = SmartCast or {}
SmartCast_Saved = SmartCast_Saved or {}

local DB = SmartCast_Saved

-- Collect all non-passive spells that have multiple ranks
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

local function buttonNameFor(spell) return "SmartCast_" .. spell:gsub(" ", "_") end

-- Collect all ranks for a spell
local function GetSpellRanks(spellName)
    local ranks = {}
    local i = 1
    while true do
        local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
        if not name then break end
        if name == spellName then
            local _, spellID = GetSpellBookItemInfo(i, BOOKTYPE_SPELL)
            if spellID then
                table.insert(ranks, { index = i, spellID = spellID })
            end
        end
        i = i + 1
    end
    table.sort(ranks, function(a, b) return a.index < b.index end)
    return ranks
end

-- Pick highest usable rank
local function SelectBestRankSpellID(spellName)
    local ranks = GetSpellRanks(spellName)
    if #ranks == 0 then return nil end
    for i = #ranks, 1, -1 do
        local usable, notEnoughMana = IsUsableSpell(ranks[i].spellID)
        if usable and not notEnoughMana then
            return ranks[i].spellID
        end
    end
    return nil
end

function SmartCast.CreateButton(spell)
    local name = buttonNameFor(spell)
    local btn = _G[name]
    if btn then return btn end

    btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
    btn:SetSize(36, 36)
    btn:SetFrameStrata("MEDIUM")
    btn:SetAttribute("type", "spell")
    btn:SetAttribute("spell", spell)

    -- Icon
    local icon = btn:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture(GetSpellTexture(spell))

    -- Rank overlay text
    local rankText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rankText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.rankText = rankText

    -- Tooltip + overlay updater
    local function UpdateButtonState(self, spell)
        local bestSpellID = SelectBestRankSpellID(spell)
        if bestSpellID then
            self:SetAttribute("spell", bestSpellID)
            self:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:SetSpellByID(bestSpellID)
                GameTooltip:Show()
            end)
            local subtext = GetSpellSubtext(bestSpellID)
            local rankNum = subtext and subtext:match("%d+")
            self.rankText:SetText(rankNum or "")
        else
            self:SetAttribute("spell", spell)
            self:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(spell .. " (no usable rank)")
                GameTooltip:Show()
            end)
            self.rankText:SetText("")
        end
    end

    btn:SetScript("PreClick", function(self) UpdateButtonState(self, spell) end)

    local manaWatcher = CreateFrame("Frame", nil, btn)
    manaWatcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    manaWatcher:SetScript("OnEvent", function() UpdateButtonState(btn, spell) end)

    btn:SetScript("OnLeave", function(self) GameTooltip:Hide() end)

    -- Drag persistence
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self) self:StartMoving() end)
    btn:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        DB[spell] = DB[spell] or {}
        DB[spell].pos = { point = p, relPoint = rp, xOfs = x, yOfs = y }
    end)

    -- Restore state
    local cfg = DB[spell]
    if cfg and cfg.enabled then
        btn:ClearAllPoints()
        if cfg.pos then
            btn:SetPoint(cfg.pos.point, UIParent, cfg.pos.relPoint, cfg.pos.xOfs, cfg.pos.yOfs)
        else
            btn:SetPoint("CENTER")
        end
        btn:Show()
    else
        DB[spell] = DB[spell] or {}
        if DB[spell].enabled == nil then
            DB[spell].enabled = true
            btn:SetPoint("CENTER")
            btn:Show()
        else
            btn:Hide()
        end
    end

    UpdateButtonState(btn, spell)
    return btn
end

function SmartCast.SetEnabled(spell, enabled)
    DB[spell] = DB[spell] or {}
    DB[spell].enabled = enabled
    local btn = SmartCast.CreateButton(spell)
    if enabled then
        DB[spell].pos = nil -- reset to default
        btn:ClearAllPoints()
        btn:SetPoint("CENTER")
        btn:Show()
    else
        btn:Hide()
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        SmartCast_Saved = SmartCast_Saved or {}
        DB = SmartCast_Saved
    elseif event == "PLAYER_LOGIN" then
        local spells = GetMultiRankSpells()
        for _, spell in ipairs(spells) do
            SmartCast.CreateButton(spell)
        end
    end
end)
