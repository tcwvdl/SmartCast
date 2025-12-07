-- SmartCastCommands.lua

SLASH_SMARTCAST1 = "/smartcast"
SLASH_SMARTCAST2 = "/sc"

local function ShowHelp()
    print("|cff00ff00SmartCast Commands:|r")
    print("  /smartcast |cffffffffor|r /sc - Show this help")
    print("  /smartcast |cffff00ffconfig|r - Open settings")
    print("  /smartcast |cffff00fflock|r - Toggle lock buttons")
    print("  /smartcast |cffff00ffreset|r - Reset all button positions")
    print("  /smartcast |cffff00ffminimap|r - Toggle minimap button")
    print("  /smartcast |cffff00ffscale <0.5-2.0>|r - Set button scale")
    print("  /smartcast |cffff00ffdebug|r - Toggle debug mode")
end

local commands = {
    [""] = ShowHelp,
    ["help"] = ShowHelp,
    
    ["config"] = function()
        Settings.OpenToCategory("SmartCast_Options")
    end,
    
    ["options"] = function()
        Settings.OpenToCategory("SmartCast_Options")
    end,
    
    ["settings"] = function()
        Settings.OpenToCategory("SmartCast_Options")
    end,
    
    ["lock"] = function()
        SmartCast.SetButtonsLocked(not SmartCast.AreButtonsLocked())
        if SmartCast.AreButtonsLocked() then
            print("SmartCast: Buttons |cffff0000locked|r")
        else
            print("SmartCast: Buttons |cff00ff00unlocked|r")
        end
    end,
    
    ["reset"] = function()
        SmartCast.ResetAllPositions()
    end,
    
    ["minimap"] = function()
        SmartCast.Minimap.Toggle()
        if SmartCast_Saved.minimapHidden then
            print("SmartCast: Minimap button hidden")
        else
            print("SmartCast: Minimap button shown")
        end
    end,
    
    ["debug"] = function()
        SmartCast_Saved.debugMode = not SmartCast_Saved.debugMode
        if SmartCast_Saved.debugMode then
            print("SmartCast: |cff00ff00Debug mode enabled|r")
        else
            print("SmartCast: |cffff0000Debug mode disabled|r")
        end
    end,
}

SlashCmdList["SMARTCAST"] = function(msg)
    msg = string.lower(msg or "")
    
    -- Check for scale command
    if string.match(msg, "^scale%s+") then
        local scale = tonumber(string.match(msg, "^scale%s+([%d%.]+)"))
        if scale and scale >= 0.5 and scale <= 2.0 then
            SmartCast.SetButtonScale(scale)
            print(string.format("SmartCast: Button scale set to %.1f", scale))
        else
            print("SmartCast: Invalid scale. Use a value between 0.5 and 2.0")
        end
        return
    end
    
    -- Check for registered commands
    local cmd = commands[msg]
    if cmd then
        cmd()
    else
        print("SmartCast: Unknown command. Type |cffff00ff/smartcast help|r for help")
    end
end