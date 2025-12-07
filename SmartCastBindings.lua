-- SmartCastBindings.lua

local addonName, addonTable = ...

SmartCast = SmartCast or {}
SmartCast.Bindings = {}

-------------------------------------------------
-- Configuration
-------------------------------------------------

local MAX_BINDING_SLOTS = 20

-------------------------------------------------
-- Internal State
-------------------------------------------------

local availableSlots = {}
local spellToSlot = {}
local slotToSpell = {}
local bindingFrame = CreateFrame("Frame", "SmartCastBindingFrame", UIParent)

-------------------------------------------------
-- Initialization
-------------------------------------------------

function SmartCast.Bindings.Initialize()
    for i = 1, MAX_BINDING_SLOTS do
        table.insert(availableSlots, i)
    end
end

-------------------------------------------------
-- Slot Allocation
-------------------------------------------------

function SmartCast.Bindings.AllocateSlot(spellName)
    if spellToSlot[spellName] then
        return spellToSlot[spellName]
    end
    
    if #availableSlots == 0 then
        print("SmartCast: No available binding slots! Maximum " .. MAX_BINDING_SLOTS .. " spells supported.")
        return nil
    end
    
    local slot = table.remove(availableSlots, 1)
    spellToSlot[spellName] = slot
    slotToSpell[slot] = spellName
    
    return slot
end

function SmartCast.Bindings.ReleaseSlot(spellName)
    local slot = spellToSlot[spellName]
    if not slot then return false end
    
    local bindingName = "SMARTCAST_SLOT" .. slot
    local key = GetBindingKey(bindingName)
    if key then
        SetBinding(key, nil)
    end
    
    table.insert(availableSlots, slot)
    table.sort(availableSlots)
    
    spellToSlot[spellName] = nil
    slotToSpell[slot] = nil
    
    return true
end

-------------------------------------------------
-- Queries
-------------------------------------------------

function SmartCast.Bindings.GetSlotForSpell(spellName)
    return spellToSlot[spellName]
end

function SmartCast.Bindings.GetSpellForSlot(slot)
    return slotToSpell[slot]
end

function SmartCast.Bindings.GetBindingName(spellName)
    local slot = spellToSlot[spellName]
    return slot and ("SMARTCAST_SLOT" .. slot) or nil
end

function SmartCast.Bindings.GetBoundKey(spellName)
    local bindingName = SmartCast.Bindings.GetBindingName(spellName)
    return bindingName and GetBindingKey(bindingName) or nil
end

-------------------------------------------------
-- Binding Management
-------------------------------------------------

function SmartCast.Bindings.UpdateBindingTexts()
    for slot = 1, MAX_BINDING_SLOTS do
        local bindingName = "SMARTCAST_SLOT" .. slot
        local spellName = slotToSpell[slot]
        _G["BINDING_NAME_" .. bindingName] = spellName or nil
    end
end

function SmartCast.Bindings.UpdateOverrideBindings()
    ClearOverrideBindings(bindingFrame)
    
    for spellName, slot in pairs(spellToSlot) do
        local bindingName = "SMARTCAST_SLOT" .. slot
        local key1, key2 = GetBindingKey(bindingName)
        local buttonName = "SmartCast_" .. spellName:gsub("%s+", "")
        
        if key1 then
            SetOverrideBindingClick(bindingFrame, false, key1, buttonName)
        end
        if key2 then
            SetOverrideBindingClick(bindingFrame, false, key2, buttonName)
        end
    end
end

-------------------------------------------------
-- Batch Operations
-------------------------------------------------

function SmartCast.Bindings.RestoreFromSavedData(savedSpells)
    for spellName, config in pairs(savedSpells) do
        if type(config) == "table" and config.enabled then
            SmartCast.Bindings.AllocateSlot(spellName)
        end
    end
    SmartCast.Bindings.UpdateBindingTexts()
    SmartCast.Bindings.UpdateOverrideBindings()
end

function SmartCast.Bindings.GetAllocatedSpells()
    local spells = {}
    for spellName, _ in pairs(spellToSlot) do
        table.insert(spells, spellName)
    end
    table.sort(spells)
    return spells
end

function SmartCast.Bindings.GetAvailableSlotCount()
    return #availableSlots
end

function SmartCast.Bindings.PrintStatus()
    print("SmartCast Binding Status:")
    print("  Available slots: " .. #availableSlots .. "/" .. MAX_BINDING_SLOTS)
    print("  Allocated spells:")
    for spellName, slot in pairs(spellToSlot) do
        local key = SmartCast.Bindings.GetBoundKey(spellName) or "none"
        print("    [" .. slot .. "] " .. spellName .. " -> " .. key)
    end
end