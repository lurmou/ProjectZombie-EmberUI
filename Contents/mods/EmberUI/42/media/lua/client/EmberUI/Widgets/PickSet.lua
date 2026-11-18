--[[
    PickSet.lua - EmberRoutes UI Core
    Reusable multi-selection, focus, range-click (Shift), toggle-click (Ctrl),
    and double-click state container (adapted from LFS Core PickSet<T>).
    Zero engine/UI dependencies; operates purely on stable item keys/ids.
]]

local Clock = require "EmberUI/Core/Clock"

local PickSet = {}
PickSet.__index = PickSet

local DOUBLE_CLICK_MS = 380

---@return table
function PickSet.new()
    return setmetatable({
        picked = {},
        order = {},
        focus = nil,
        lastClicked = nil,
        lastClickedAt = -1
    }, PickSet)
end

function PickSet:count()
    return #self.order
end

function PickSet:any()
    return #self.order > 0
end

function PickSet:contains(id)
    return id ~= nil and self.picked[id] == true
end

function PickSet:getFocus()
    return self.focus
end

function PickSet:setFocus(id)
    self.focus = id
end

function PickSet:clear()
    self.picked = {}
    self.order = {}
    self.focus = nil
end

function PickSet:add(id)
    if id == nil or self.picked[id] then return false end
    self.picked[id] = true
    self.order[#self.order + 1] = id
    if self.focus == nil then self.focus = id end
    return true
end

function PickSet:remove(id)
    if id == nil or not self.picked[id] then return false end
    self.picked[id] = nil
    for i = #self.order, 1, -1 do
        if self.order[i] == id then
            table.remove(self.order, i)
            break
        end
    end
    if self.focus == id then
        self.focus = self.order[#self.order]
    end
    return true
end

function PickSet:toggle(id)
    if self:contains(id) then
        self:remove(id)
        return false
    else
        self:add(id)
        self.focus = id
        return true
    end
end

---Handles a list/table click with optional Ctrl/Shift semantics.
---Returns `true` if this click qualifies as a double-click on the same item.
---@param id any
---@param opts table? { ctrl = boolean?, shift = boolean?, orderedIds = any[]?, nowMs = number? }
---@return boolean doubleClicked
function PickSet:click(id, opts)
    opts = opts or {}
    local now = opts.nowMs or (Clock and Clock.nowMs and Clock.nowMs()) or 0
    local isDouble = (self.lastClicked == id) and (self.lastClickedAt >= 0) and ((now - self.lastClickedAt) <= DOUBLE_CLICK_MS)
    self.lastClicked = id
    self.lastClickedAt = now

    if id == nil then return false end

    if opts.shift and opts.orderedIds and self.focus ~= nil then
        local a, b = nil, nil
        for i = 1, #opts.orderedIds do
            local cur = opts.orderedIds[i]
            if cur == self.focus then a = i end
            if cur == id then b = i end
        end
        if a and b then
            if not opts.ctrl then
                self:clear()
            end
            local step = a <= b and 1 or -1
            for i = a, b, step do
                self:add(opts.orderedIds[i])
            end
            self.focus = id
            return isDouble
        end
    end

    if opts.ctrl then
        self:toggle(id)
    else
        self:clear()
        self:add(id)
        self.focus = id
    end

    return isDouble
end

---Returns ordered array of currently picked IDs (or `[focus]` if empty and `fallbackToFocus` is true).
---@param fallbackToFocus boolean?
---@return any[]
function PickSet:targets(fallbackToFocus)
    local out = {}
    for i = 1, #self.order do
        out[i] = self.order[i]
    end
    if #out == 0 and fallbackToFocus and self.focus ~= nil then
        out[1] = self.focus
    end
    return out
end

function PickSet:allPicked(candidates)
    if not candidates or #candidates == 0 then return false end
    for i = 1, #candidates do
        if not self.picked[candidates[i]] then return false end
    end
    return true
end

function PickSet:countIn(candidates)
    if not candidates then return 0 end
    local n = 0
    for i = 1, #candidates do
        if self.picked[candidates[i]] then n = n + 1 end
    end
    return n
end

---Removes picked IDs that no longer exist in `validSet` (map id -> true).
---@param validSet table
function PickSet:prune(validSet)
    validSet = validSet or {}
    for i = #self.order, 1, -1 do
        local id = self.order[i]
        if not validSet[id] then
            self.picked[id] = nil
            table.remove(self.order, i)
        end
    end
    if self.focus ~= nil and not validSet[self.focus] then
        self.focus = self.order[#self.order]
    end
end

return PickSet
