--[[
    SlotRegistry.lua - EmberUI Shell
    Cordis-inspired UI extension slot & capability-gated workbench registry.
    Allows modules/mods to plug tabs, toolbar actions, card blocks, or custom slots
    with automatic capability gating (requires), Failsafe error isolation, and
    deterministic release handles (no business domain names or circular imports).
]]

local Failsafe = require "EmberUI/Core/Failsafe"

local SlotRegistry = {}

local slots = {}
local entriesById = {}
local capabilities = {}

local function hasAllCapabilities(reqList)
    if not reqList or #reqList == 0 then return true end
    for i = 1, #reqList do
        if capabilities[reqList[i]] == nil then
            return false
        end
    end
    return true
end

local function compareEntries(a, b)
    local oa = a.order or 100
    local ob = b.order or 100
    if oa ~= ob then return oa < ob end
    return tostring(a.id) < tostring(b.id)
end

---@param name string
---@param value any Default true if omitted
function SlotRegistry.provideCapability(name, value)
    assert(type(name) == "string" and name ~= "", "CAPABILITY_NAME_REQUIRED")
    capabilities[name] = (value == nil) and true or value
end

---@param name string
function SlotRegistry.revokeCapability(name)
    if type(name) == "string" then
        capabilities[name] = nil
    end
end

---Clears ephemeral session capabilities without wiping static file-load slot declarations.
function SlotRegistry.clearCapabilities()
    capabilities = {}
end

---@param name string
---@return boolean
function SlotRegistry.hasCapability(name)
    return capabilities[name] ~= nil
end

---@param name string
---@return any
function SlotRegistry.getCapability(name)
    return capabilities[name]
end

---Register an extension entry into a named UI slot.
---@param def table
---@return table handle { release = function }
function SlotRegistry.register(def)
    assert(type(def) == "table" and type(def.id) == "string" and def.id ~= "", "SLOT_ID_REQUIRED")
    local slotName = def.slot or "nav.tabs"

    if entriesById[def.id] then
        SlotRegistry.unregister(def.id)
    end

    local entry = {
        id = def.id,
        slot = slotName,
        order = def.order or 100,
        title = def.title,
        titleKey = def.titleKey,
        label = def.label,
        labelKey = def.labelKey,
        tooltip = def.tooltip,
        tooltipKey = def.tooltipKey,
        icon = def.icon,
        badge = def.badge,
        requires = def.requires,
        visible = def.visible or def.when,
        mount = def.mount,
        module = def.module,
        group = def.group,
        parentTab = def.parentTab,
        meta = def.meta,
        disposed = false,
    }

    entriesById[def.id] = entry
    local bucket = slots[slotName]
    if not bucket then
        bucket = {}
        slots[slotName] = bucket
    end
    bucket[#bucket + 1] = entry
    table.sort(bucket, compareEntries)

    return {
        release = function()
            if not entry.disposed then
                SlotRegistry.unregister(def.id)
            end
        end,
    }
end

---@param id string
---@return boolean removed
function SlotRegistry.unregister(id)
    local entry = entriesById[id]
    if not entry then return false end
    entry.disposed = true
    entriesById[id] = nil
    local bucket = slots[entry.slot]
    if bucket then
        for i = #bucket, 1, -1 do
            if bucket[i] == entry then
                table.remove(bucket, i)
            end
        end
    end
    return true
end

---@param id string
---@return table?
function SlotRegistry.get(id)
    return entriesById[id]
end

function SlotRegistry.resolve(slotName, context)
    local bucket = slots[slotName]
    if not bucket then return {} end
    local out = {}
    for i = 1, #bucket do
        local e = bucket[i]
        if not e.disposed and hasAllCapabilities(e.requires) then
            local ok = true
            if type(e.visible) == "function" then
                local gOk, vis = Failsafe.guard("SlotVisible:" .. e.id, e.visible, context, capabilities)
                ok = gOk and vis == true
            elseif e.visible ~= nil then
                ok = e.visible == true
            end
            if ok then
                out[#out + 1] = e
            end
        end
    end
    return out
end

function SlotRegistry.mountSlot(slotName, container, scope, context)
    local active = SlotRegistry.resolve(slotName, context)
    local disposers = {}
    local mounted = {}

    for i = 1, #active do
        local entry = active[i]
        if type(entry.mount) == "function" then
            local ok, res = Failsafe.guard("SlotMount:" .. slotName .. ":" .. entry.id, entry.mount, context, container, capabilities)
            if ok then
                mounted[#mounted + 1] = { id = entry.id, result = res }
                if type(res) == "function" then
                    disposers[#disposers + 1] = res
                elseif type(res) == "table" and type(res.release) == "function" then
                    disposers[#disposers + 1] = function() res:release() end
                end
            end
        end
    end

    local released = false
    local function releaseAll()
        if released then return end
        released = true
        for i = #disposers, 1, -1 do
            pcall(disposers[i])
        end
    end

    if scope and type(scope.defer) == "function" then
        scope:defer(releaseAll)
    elseif scope and type(scope.own) == "function" then
        scope:own(releaseAll, function(fn) fn() end)
    end

    return {
        release = releaseAll,
        mounted = mounted,
    }
end

function SlotRegistry.clear()
    for id in pairs(entriesById) do
        entriesById[id].disposed = true
    end
    slots = {}
    entriesById = {}
    capabilities = {}
end

return SlotRegistry
