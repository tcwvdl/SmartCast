-- SmartCastMinimap.lua

SmartCast = SmartCast or {}
SmartCast.Minimap = {}

SmartCast_Saved = SmartCast_Saved or {}

-------------------------------------------------
-- Minimap Button Creation
-------------------------------------------------

local minimapButton = CreateFrame("Button", "SmartCastMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:RegisterForDrag("LeftButton")
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("CENTER", 0, 1)
icon:SetTexture("Interface\\Icons\\Spell_Nature_MagicImmunity")
minimapButton.icon = icon

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetPoint("TOPLEFT", 0, 0)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
minimapButton.overlay = overlay

-------------------------------------------------
-- Position Functions
-------------------------------------------------

local function UpdateMinimapPosition()
    local angle = math.rad(SmartCast_Saved.minimapPos or 225)
    local x = math.cos(angle) * 80
    local y = math.sin(angle) * 80
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

local function UpdateMinimapAngle()
    local mx, my = Minimap:GetCenter()
    local px, py = GetCursorPosition()
    local scale = Minimap:GetEffectiveScale()
    px, py = px / scale, py / scale
    
    local angle = math.deg(math.atan2(py - my, px - mx))
    SmartCast_Saved.minimapPos = angle
    UpdateMinimapPosition()
end

-------------------------------------------------
-- Button Scripts
-------------------------------------------------

minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        Settings.OpenToCategory("SmartCast_Options")
    end
end)

minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", UpdateMinimapAngle)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("SmartCast", 1, 1, 1)
    GameTooltip:AddLine("Click: Open Settings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Drag: Move Button", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-------------------------------------------------
-- Public API
-------------------------------------------------

function SmartCast.Minimap.Show()
    SmartCast_Saved.minimapHidden = false
    minimapButton:Show()
    UpdateMinimapPosition()
end

function SmartCast.Minimap.Hide()
    SmartCast_Saved.minimapHidden = true
    minimapButton:Hide()
end

function SmartCast.Minimap.Toggle()
    if minimapButton:IsShown() then
        SmartCast.Minimap.Hide()
    else
        SmartCast.Minimap.Show()
    end
end

-------------------------------------------------
-- Initialization
-------------------------------------------------

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
    if not SmartCast_Saved.minimapPos then
        SmartCast_Saved.minimapPos = 225
    end
    
    if SmartCast_Saved.minimapHidden then
        minimapButton:Hide()
    else
        minimapButton:Show()
        UpdateMinimapPosition()
    end
end)