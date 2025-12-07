-- SmartCast.lua
local addonName, addonTable = ...

-- Addon namespace
SmartCast = SmartCast or {}
SmartCast.buttons = SmartCast.buttons or {}

-- Saved variables
SmartCast_Saved = SmartCast_Saved or {}
local DB = SmartCast_Saved

-- Constants
local DEFAULT_BUTTON_SCALE = 1.0
local DEFAULT_LOCKED = false
local RANGE_CHECK_INTERVAL = 0.1
local BUTTON_SIZE = 36
local BUTTON_PADDING = 2

-------------------------------------------------
-- Utility Functions
-------------------------------------------------

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

function SmartCast.SelectBestRankSpellID(spellName)
    local ranks = GetSpellRanks(spellName)
    if #ranks == 0 then return nil end
    
    -- Always use efficient strategy (mana-based rank selection)
    local currentMana = UnitPower("player", Enum.PowerType.Mana)
    if not currentMana or currentMana == 0 then 
        return ranks[1].spellID -- Fallback to lowest rank if no mana info
    end
    
    local coeff = DB.manaCoeff or 0.76
    local maxAllowedCost = currentMana * coeff
    
    -- Debug output (remove after testing)
    if DB.debugMode then
        print(string.format("[SmartCast Debug] %s: Current Mana=%d, Coeff=%.2f, MaxCost=%.1f", 
            spellName, currentMana, coeff, maxAllowedCost))
    end
    
    -- Find the highest rank that costs <= maxAllowedCost AND we have enough mana for
    for i = #ranks, 1, -1 do
        local spellID = ranks[i].spellID
        local costInfo = GetSpellPowerCost(spellID)
        local manaCost = costInfo and costInfo[1] and costInfo[1].cost or 0
        
        if DB.debugMode then
            print(string.format("  Rank %d: Cost=%d, MaxAllowed=%.1f, Fits=%s", 
                i, manaCost, maxAllowedCost, tostring(manaCost <= maxAllowedCost)))
        end
        
        -- Check if this rank fits within our coefficient limit
        if manaCost <= maxAllowedCost then
            -- Also verify we actually have enough mana to cast it
            local usable, notEnoughMana = IsUsableSpell(spellID)
            if usable and not notEnoughMana then
                if DB.debugMode then
                    print(string.format("  -> Selected Rank %d (Cost=%d)", i, manaCost))
                end
                return spellID
            end
        end
    end
    
    -- If no rank fits the coefficient, use the lowest rank we can afford
    for i = 1, #ranks do
        local spellID = ranks[i].spellID
        local usable, notEnoughMana = IsUsableSpell(spellID)
        if usable and not notEnoughMana then
            if DB.debugMode then
                print(string.format("  -> Fallback to Rank %d", i))
            end
            return spellID
        end
    end
    
    -- Ultimate fallback: lowest rank
    if DB.debugMode then
        print("  -> Ultimate fallback to Rank 1")
    end
    return ranks[1].spellID
end

-------------------------------------------------
-- Button Management
-------------------------------------------------

local function GetButtonName(spellName)
    return "SmartCast_" .. spellName:gsub("%s+", "")
end

local function GetNextButtonPosition()
    local usedPositions = {}
    
    for spell, btn in pairs(SmartCast.buttons) do
        if btn:IsShown() then
            local _, _, _, x, y = btn:GetPoint()
            if x and y then
                table.insert(usedPositions, { x = x, y = y })
            end
        end
    end
    
    if #usedPositions == 0 then
        return "CENTER", UIParent, "CENTER", 0, 0
    end
    
    table.sort(usedPositions, function(a, b) return a.y < b.y end)
    local lowestY = usedPositions[1].y
    
    return "CENTER", UIParent, "CENTER", 0, lowestY - 40
end

local function CreateButtonVisuals(btn)
    -- Background
    local bg = btn:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.5)
    btn.bg = bg
    
    -- Icon
    local icon = btn:CreateTexture(nil, "BORDER")
    icon:SetPoint("TOPLEFT", BUTTON_PADDING, -BUTTON_PADDING)
    icon:SetPoint("BOTTOMRIGHT", -BUTTON_PADDING, BUTTON_PADDING)
    btn.icon = icon
    
    -- Border (for unlock mode)
    local border = btn:CreateTexture(nil, "ARTWORK")
    border:SetAllPoints()
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:Hide()
    btn.border = border
    
    -- Cooldown frame
    local cooldown = CreateFrame("Cooldown", nil, btn, "CooldownFrameTemplate")
    cooldown:SetPoint("TOPLEFT", BUTTON_PADDING, -BUTTON_PADDING)
    cooldown:SetPoint("BOTTOMRIGHT", -BUTTON_PADDING, BUTTON_PADDING)
    cooldown:SetDrawEdge(true)
    cooldown:SetSwipeColor(0, 0, 0, 0.8)
    btn.cooldown = cooldown
    
    -- Charge count text
    local chargeText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    chargeText:SetPoint("BOTTOM", btn, "BOTTOM", 0, 2)
    btn.chargeText = chargeText
    
    -- Rank text (will turn red when out of range)
    local rankText = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    rankText:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -2, 2)
    btn.rankText = rankText
    
    -- Hotkey text
    local hotkeyText = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
    hotkeyText:SetPoint("TOPLEFT", btn, "TOPLEFT", 4, -4)
    btn.hotkeyText = hotkeyText
end

local function SetupButtonTooltip(btn, spell)
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local current = self:GetAttribute("spell")
        if type(current) == "number" then
            GameTooltip:SetSpellByID(current)
            
            local ranks = GetSpellRanks(spell)
            if #ranks > 1 then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Available Ranks:", 1, 1, 1)
                
                for i, rank in ipairs(ranks) do
                    local costInfo = GetSpellPowerCost(rank.spellID)
                    local manaCost = costInfo and costInfo[1] and costInfo[1].cost or 0
                    local color = (rank.spellID == current) and "|cff00ff00" or "|cffaaaaaa"
                    local marker = (rank.spellID == current) and " (Selected)" or ""
                    GameTooltip:AddLine(string.format("%sRank %d: %d mana%s|r", color, i, manaCost, marker), 0.8, 0.8, 0.8)
                end
            end
        elseif type(current) == "string" then
            GameTooltip:AddLine(current)
        end
        GameTooltip:Show()
    end)
    
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

local function SetupButtonDragging(btn, spell)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForDrag("LeftButton")
    
    btn:SetScript("OnDragStart", function(self)
        if not DB.buttonsLocked then
            self:StartMoving()
        end
    end)
    
    btn:SetScript("OnDragStop", function(self)
        if not DB.buttonsLocked then
            self:StopMovingOrSizing()
            local p, _, rp, x, y = self:GetPoint()
            DB[spell] = DB[spell] or {}
            DB[spell].pos = { point = p, relPoint = rp, xOfs = x, yOfs = y }
        end
    end)
end

local function SetupButtonClicks(btn, spell)
    btn:RegisterForClicks("LeftButtonUp")
    
    btn:SetScript("PostClick", function(self, button)
        -- Update cooldown immediately after casting
        self:UpdateCooldown()
    end)
end

local function UpdateButtonState(btn, spell)
    local ranks = GetSpellRanks(spell)
    local bestSpellID = SmartCast.SelectBestRankSpellID(spell)
    
    if bestSpellID then
        btn:SetAttribute("spell", bestSpellID)
        local subtext = GetSpellSubtext(bestSpellID)
        local rankNum = subtext and subtext:match("%d+")
        btn.rankText:SetText(rankNum or "")
        
        -- Update all visual states
        btn:UpdateCooldown(bestSpellID)
        btn:UpdateUsability(bestSpellID)
        btn:UpdateRange(bestSpellID)
        btn:UpdateCharges(bestSpellID)
    else
        btn:SetAttribute("spell", spell)
        btn.rankText:SetText("")
        btn.rankText:SetTextColor(1, 1, 1) -- Reset to white
    end
end

local function UpdateCooldown(btn, spellID)
    if not spellID then
        spellID = btn:GetAttribute("spell")
        if type(spellID) ~= "number" then return end
    end
    
    local start, duration = GetSpellCooldown(spellID)
    if start and duration and duration > 0 then
        btn.cooldown:SetCooldown(start, duration)
    else
        btn.cooldown:Clear()
    end
end

local function UpdateUsability(btn, spellID)
    if not spellID then
        spellID = btn:GetAttribute("spell")
        if type(spellID) ~= "number" then return end
    end
    
    local isUsable, notEnoughMana = IsUsableSpell(spellID)
    
    if notEnoughMana then
        btn.icon:SetVertexColor(0.5, 0.5, 1.0)
        btn.icon:SetDesaturated(false)
    elseif not isUsable then
        btn.icon:SetVertexColor(1.0, 1.0, 1.0)
        btn.icon:SetDesaturated(true)
    else
        btn.icon:SetVertexColor(1.0, 1.0, 1.0)
        btn.icon:SetDesaturated(false)
    end
end

local function UpdateRange(btn, spellID)
    if not spellID then
        spellID = btn:GetAttribute("spell")
        if type(spellID) ~= "number" then return end
    end
    
    local inRange = IsSpellInRange(spellID, "target")
    
    -- Red rank number when out of range
    if inRange == false then
        btn.rankText:SetTextColor(1.0, 0.3, 0.3)
    else
        btn.rankText:SetTextColor(1, 1, 1)
    end
end

local function UpdateCharges(btn, spellID)
    if not spellID then
        spellID = btn:GetAttribute("spell")
        if type(spellID) ~= "number" then return end
    end
    
    local charges, maxCharges = GetSpellCharges(spellID)
    
    if charges and maxCharges and maxCharges > 1 then
        btn.chargeText:SetText(charges)
        btn.chargeText:Show()
    else
        btn.chargeText:Hide()
    end
end

local function UpdateHotkeyText(btn, spell)
    local key = SmartCast.Bindings.GetBoundKey(spell)
    if key then
        btn.hotkeyText:SetText(GetBindingText(key, "KEY_", 1))
    else
        btn.hotkeyText:SetText("")
    end
end

local function SetupButtonEvents(btn, spell)
    btn:SetScript("PreClick", function(self)
        self:UpdateButtonState()
    end)
    
    local watcher = CreateFrame("Frame", nil, btn)
    watcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
    watcher:RegisterEvent("SPELLS_CHANGED")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("SPELL_UPDATE_COOLDOWN")
    watcher:RegisterEvent("SPELL_UPDATE_CHARGES")
    watcher:RegisterEvent("SPELL_UPDATE_USABLE")
    watcher:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
    watcher:RegisterUnitEvent("PLAYER_TARGET_CHANGED")
    
    watcher:SetScript("OnEvent", function(self, event)
        btn:UpdateButtonState()
        if event == "SPELL_UPDATE_COOLDOWN" or event == "UNIT_SPELLCAST_SUCCEEDED" then
            btn:UpdateCooldown()
        end
        if event == "SPELL_UPDATE_CHARGES" then
            local spellID = btn:GetAttribute("spell")
            if type(spellID) == "number" then
                btn:UpdateCharges(spellID)
            end
        end
    end)
    
    -- Range check on timer
    local rangeTimer = 0
    btn:SetScript("OnUpdate", function(self, elapsed)
        rangeTimer = rangeTimer + elapsed
        if rangeTimer >= RANGE_CHECK_INTERVAL then
            rangeTimer = 0
            local spellID = self:GetAttribute("spell")
            if type(spellID) == "number" then
                self:UpdateUsability(spellID)
                self:UpdateRange(spellID)
            end
        end
    end)
end

function SmartCast.CreateNamedSpellButton(spell, globalName)
    local btn = _G[globalName]
    if not btn then
        btn = CreateFrame("Button", globalName, UIParent, "SecureActionButtonTemplate")
        btn:SetSize(BUTTON_SIZE, BUTTON_SIZE)
        btn:SetFrameStrata("MEDIUM")
        btn:SetAttribute("type", "spell")
        
        CreateButtonVisuals(btn)
        SetupButtonTooltip(btn, spell)
        SetupButtonDragging(btn, spell)
        SetupButtonClicks(btn, spell)
        
        -- Attach update methods
        btn.UpdateButtonState = function(self) UpdateButtonState(self, spell) end
        btn.UpdateCooldown = function(self, spellID) UpdateCooldown(self, spellID) end
        btn.UpdateUsability = function(self, spellID) UpdateUsability(self, spellID) end
        btn.UpdateRange = function(self, spellID) UpdateRange(self, spellID) end
        btn.UpdateCharges = function(self, spellID) UpdateCharges(self, spellID) end
        btn.UpdateHotkeyText = function(self) UpdateHotkeyText(self, spell) end
        
        SetupButtonEvents(btn, spell)
        
        -- Set icon
        btn.icon:SetTexture(GetSpellTexture(spell))
    end
    
    -- Position and visibility
    local cfg = DB[spell]
    if cfg and cfg.enabled then
        btn:ClearAllPoints()
        if cfg.pos then
            btn:SetPoint(cfg.pos.point, UIParent, cfg.pos.relPoint, cfg.pos.xOfs, cfg.pos.yOfs)
        else
            local p, parent, rp, x, y = GetNextButtonPosition()
            btn:SetPoint(p, parent, rp, x, y)
            DB[spell].pos = { point = p, relPoint = rp, xOfs = x, yOfs = y }
        end
        
        local scale = DB.buttonScale or DEFAULT_BUTTON_SCALE
        btn:SetScale(scale)
        btn:Show()
    else
        btn:Hide()
    end
    
    btn:UpdateButtonState()
    btn:UpdateHotkeyText()
    SmartCast.buttons[spell] = btn
    return btn
end

function SmartCast.SetEnabled(spell, enabled)
    DB[spell] = DB[spell] or {}
    DB[spell].enabled = enabled
    
    local globalName = GetButtonName(spell)
    local btn = SmartCast.buttons[spell]
    
    if enabled then
        local slot = SmartCast.Bindings.AllocateSlot(spell)
        if slot then
            SmartCast.Bindings.UpdateBindingTexts()
            SmartCast.Bindings.UpdateOverrideBindings()
            SaveBindings(GetCurrentBindingSet())
        end
        
        if not btn then
            btn = SmartCast.CreateNamedSpellButton(spell, globalName)
        else
            btn:ClearAllPoints()
            if DB[spell].pos then
                btn:SetPoint(DB[spell].pos.point, UIParent, DB[spell].pos.relPoint, 
                           DB[spell].pos.xOfs, DB[spell].pos.yOfs)
            else
                local p, parent, rp, x, y = GetNextButtonPosition()
                btn:SetPoint(p, parent, rp, x, y)
                DB[spell].pos = { point = p, relPoint = rp, xOfs = x, yOfs = y }
            end
            btn:Show()
            btn:UpdateHotkeyText()
        end
    else
        if SmartCast.Bindings.ReleaseSlot(spell) then
            SmartCast.Bindings.UpdateBindingTexts()
            SmartCast.Bindings.UpdateOverrideBindings()
            SaveBindings(GetCurrentBindingSet())
        end
        
        if btn then
            btn:Hide()
        end
    end
end

function SmartCast.RefreshAllButtons()
    for spell, btn in pairs(SmartCast.buttons) do
        if btn.UpdateButtonState then
            btn:UpdateButtonState()
        end
    end
end

function SmartCast.RefreshAllHotkeys()
    for spell, btn in pairs(SmartCast.buttons) do
        if btn.UpdateHotkeyText then
            btn:UpdateHotkeyText()
        end
    end
end

function SmartCast.SetButtonScale(scale)
    scale = math.max(0.5, math.min(2.0, scale or 1.0))
    DB.buttonScale = scale
    
    for spell, btn in pairs(SmartCast.buttons) do
        btn:SetScale(scale)
    end
end

function SmartCast.GetButtonScale()
    return DB.buttonScale or DEFAULT_BUTTON_SCALE
end

function SmartCast.SetButtonsLocked(locked)
    DB.buttonsLocked = locked
    
    for spell, btn in pairs(SmartCast.buttons) do
        if btn:IsShown() then
            if locked then
                btn.border:Hide()
            else
                btn.border:Show()
            end
        end
    end
end

function SmartCast.AreButtonsLocked()
    return DB.buttonsLocked or DEFAULT_LOCKED
end

function SmartCast.ResetAllPositions()
    for spell, cfg in pairs(DB) do
        if type(cfg) == "table" and cfg.pos then
            cfg.pos = nil
        end
    end
    
    local yOffset = 0
    for spell, btn in pairs(SmartCast.buttons) do
        if btn:IsShown() then
            btn:ClearAllPoints()
            btn:SetPoint("CENTER", UIParent, "CENTER", 0, yOffset)
            DB[spell] = DB[spell] or {}
            DB[spell].pos = { point = "CENTER", relPoint = "CENTER", xOfs = 0, yOfs = yOffset }
            yOffset = yOffset - 40
        end
    end
    
    print("SmartCast: All button positions reset.")
end

-------------------------------------------------
-- Initialization
-------------------------------------------------

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("UPDATE_BINDINGS")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        SmartCast_Saved = SmartCast_Saved or {}
        DB = SmartCast_Saved  -- This is critical - update the reference
        if DB.manaCoeff == nil then DB.manaCoeff = 0.76 end
        if DB.buttonScale == nil then DB.buttonScale = DEFAULT_BUTTON_SCALE end
        if DB.buttonsLocked == nil then DB.buttonsLocked = DEFAULT_LOCKED end
        
        SmartCast.Bindings.Initialize()
        
    elseif event == "PLAYER_LOGIN" then
        SmartCast.Bindings.RestoreFromSavedData(DB)
        
        for spell, cfg in pairs(DB) do
            if type(cfg) == "table" and cfg.enabled then
                local globalName = GetButtonName(spell)
                SmartCast.CreateNamedSpellButton(spell, globalName)
            end
        end
        
    elseif event == "PLAYER_ENTERING_WORLD" or event == "SPELLS_CHANGED" then
        SmartCast.RefreshAllButtons()
        
        if DB.autoEnableNewRanks ~= false then
            local enabledSpells = {}
            for spell, cfg in pairs(DB) do
                if type(cfg) == "table" and cfg.enabled then
                    enabledSpells[spell] = true
                end
            end
            
            local i = 1
            local spellRankCounts = {}
            while true do
                local name = GetSpellBookItemName(i, BOOKTYPE_SPELL)
                if not name then break end
                spellRankCounts[name] = (spellRankCounts[name] or 0) + 1
                i = i + 1
            end
            
            for spell, count in pairs(spellRankCounts) do
                if count > 1 and not enabledSpells[spell] then
                    if DB[spell] and DB[spell].pos then
                        SmartCast.SetEnabled(spell, true)
                    end
                end
            end
        end
        
    elseif event == "UPDATE_BINDINGS" then
        SmartCast.Bindings.UpdateOverrideBindings()
        SmartCast.RefreshAllHotkeys()
    end
end)