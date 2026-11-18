--[[
    FocusManager.lua - EmberUI Core
    Unified focus ring, Tab/Shift+Tab keyboard traversal, editable-input game hotkey lock,
    B42 UITextBox2 ESC/Tab bridge, subtree unfocus cleanup, and LIFO ShortcutScope stack.
]]

local FocusManager = {}

local groups = {}
local shortcutStack = {}
local activeEditableCount = 0
local lastConsumedKey = nil

local function isWidgetAlive(widget)
    if not widget or widget.disposed then return false end
    if widget.isVisible and not widget:isVisible() then return false end
    if widget.enable == false then return false end
    return true
end

local function clearFocusFlag(widget)
    if not widget then return end
    widget.isFocused = false
    if type(widget.unfocus) == "function" then
        pcall(widget.unfocus, widget)
    end
end

local function setFocusFlag(widget)
    if not widget then return false end
    widget.isFocused = true
    if type(widget.focus) == "function" then
        pcall(widget.focus, widget)
    end
    if type(widget.onGainFocus) == "function" then
        pcall(widget.onGainFocus, widget)
    end
    return true
end

---Swallows a key inside B42 GameKeyboard.eatKey[] so key-release does not leak OnKeyPressed(key).
---@param key number
function FocusManager.eatKey(key)
    if type(key) == "number" and GameKeyboard and type(GameKeyboard.eatKeyPress) == "function" then
        GameKeyboard.eatKeyPress(key)
    end
end

---Finds the nearest ancestor registered as a FocusManager group key.
---@param widget any
---@return any?
function FocusManager.findGroupOwner(widget)
    local cur = widget
    local depth = 0
    while cur ~= nil and depth < 32 do
        if groups[cur] ~= nil then
            return cur
        end
        cur = cur.parent or cur.owner
        depth = depth + 1
    end
    return nil
end

---Safely unfocuses any focused ISTextEntryBox / UITextBox2 inside a widget subtree
---so closing a window never leaves Core.currentTextEntryBox stuck in doingTextEntry=true.
---@param root any
function FocusManager.unfocusTree(root)
    if not root then return end
    local stack = { root }
    local seen = {}
    local guard = 0
    while #stack > 0 and guard < 256 do
        local node = stack[#stack]
        stack[#stack] = nil
        if type(node) == "table" and not seen[node] then
            seen[node] = true
            guard = guard + 1
            local jo = node.javaObject
            local focused = (jo and type(jo.isDoingTextEntry) == "function" and jo:isDoingTextEntry())
                or (type(node.isFocused) == "function" and node:isFocused())
                or node._focused == true
            if focused and type(node.unfocus) == "function" then
                pcall(node.unfocus, node)
            end
            if type(node.children) == "table" then
                for _, child in pairs(node.children) do
                    if type(child) == "table" and not seen[child] then
                        stack[#stack + 1] = child
                    end
                end
            end
        end
    end
end

---Hooks a B42 ISTextEntryBox so ESC unfocuses cleanly and Tab steps FocusManager focus.
---@param entry any
---@param explicitGroupKey any?
function FocusManager.bindTextEntry(entry, explicitGroupKey)
    if type(entry) ~= "table" or entry._emberFocusBound then return end
    entry._emberFocusBound = true
    if explicitGroupKey ~= nil then
        entry._emberFocusGroup = explicitGroupKey
    end
    local prevOtherKey = entry.onOtherKey
    entry.onOtherKey = function(self, key)
        if type(prevOtherKey) == "function" then
            prevOtherKey(self, key)
        end
        local escKey = (Keyboard and Keyboard.KEY_ESCAPE) or 1
        local tabKey = (Keyboard and Keyboard.KEY_TAB) or 15
        if key == escKey then
            if type(self.unfocus) == "function" then
                self:unfocus()
            end
            FocusManager.eatKey(key)
        elseif key == tabKey then
            local gKey = self._emberFocusGroup or FocusManager.findGroupOwner(self)
            if gKey then
                if type(self.unfocus) == "function" then
                    self:unfocus()
                end
                FocusManager.handleTab(gKey, tabKey)
            end
        end
    end
end

---@param groupKey any
function FocusManager.createGroup(groupKey)
    assert(groupKey ~= nil, "FOCUS_GROUP_KEY_REQUIRED")
    local g = groups[groupKey]
    if g then return g end
    g = {
        key = groupKey,
        items = {},
        activeIndex = 0,
    }
    groups[groupKey] = g
    return g
end

---@param groupKey any
---@param widget any
---@return table handle { release = function }
function FocusManager.register(groupKey, widget)
    assert(groupKey ~= nil and widget ~= nil, "FOCUS_REGISTER_ARGS_REQUIRED")
    local g = FocusManager.createGroup(groupKey)
    if type(widget) == "table" then
        widget._emberFocusGroup = groupKey
    end
    for i = 1, #g.items do
        if g.items[i] == widget then
            return { release = function() FocusManager.unregister(groupKey, widget) end }
        end
    end
    g.items[#g.items + 1] = widget
    return {
        release = function()
            FocusManager.unregister(groupKey, widget)
        end,
    }
end

---@param groupKey any
---@param widget any
function FocusManager.unregister(groupKey, widget)
    local g = groups[groupKey]
    if not g then return end
    for i = #g.items, 1, -1 do
        if g.items[i] == widget then
            if g.activeIndex == i then
                clearFocusFlag(widget)
                g.activeIndex = 0
            elseif g.activeIndex > i then
                g.activeIndex = g.activeIndex - 1
            end
            table.remove(g.items, i)
        end
    end
    if #g.items == 0 then
        groups[groupKey] = nil
    end
end

---@param groupKey any
function FocusManager.clearGroup(groupKey)
    local g = groups[groupKey]
    if not g then return end
    if g.activeIndex > 0 and g.items[g.activeIndex] then
        clearFocusFlag(g.items[g.activeIndex])
    end
    groups[groupKey] = nil
end

---@param groupKey any
---@return any?
function FocusManager.getFocused(groupKey)
    local g = groups[groupKey]
    if not g or g.activeIndex < 1 or g.activeIndex > #g.items then return nil end
    local w = g.items[g.activeIndex]
    return isWidgetAlive(w) and w or nil
end

---@param groupKey any
---@param widget any
---@return boolean
function FocusManager.focus(groupKey, widget)
    local g = groups[groupKey]
    if not g then return false end
    for i = 1, #g.items do
        if g.items[i] == widget and isWidgetAlive(widget) then
            if g.activeIndex > 0 and g.items[g.activeIndex] and g.items[g.activeIndex] ~= widget then
                clearFocusFlag(g.items[g.activeIndex])
            end
            g.activeIndex = i
            return setFocusFlag(widget)
        end
    end
    return false
end

---@param groupKey any
---@param delta number? +1 forward, -1 backward
---@return any? focusedWidget
function FocusManager.step(groupKey, delta)
    local g = groups[groupKey]
    if not g or #g.items == 0 then return nil end
    local stepDir = (delta and delta < 0) and -1 or 1
    local count = #g.items
    local start = g.activeIndex
    if start < 1 or start > count then
        start = stepDir > 0 and 0 or (count + 1)
    end
    for offset = 1, count do
        local idx = ((start - 1 + offset * stepDir) % count) + 1
        local candidate = g.items[idx]
        if isWidgetAlive(candidate) then
            if g.activeIndex > 0 and g.items[g.activeIndex] and g.items[g.activeIndex] ~= candidate then
                clearFocusFlag(g.items[g.activeIndex])
            end
            g.activeIndex = idx
            setFocusFlag(candidate)
            return candidate
        end
    end
    return nil
end

---Routes Tab / Shift+Tab inside a focus group.
---@param groupKey any
---@param key number
---@param isShift boolean?
---@return boolean consumed
function FocusManager.handleTab(groupKey, key, isShift)
    local tabKey = Keyboard and Keyboard.KEY_TAB or 15
    if key ~= tabKey then return false end
    local shift = isShift
    if shift == nil and isKeyDown and Keyboard then
        shift = (Keyboard.KEY_LSHIFT and isKeyDown(Keyboard.KEY_LSHIFT))
            or (Keyboard.KEY_RSHIFT and isKeyDown(Keyboard.KEY_RSHIFT))
            or false
    end
    return FocusManager.step(groupKey, shift and -1 or 1) ~= nil
end

----------------------------------------------------------------
-- Editable Game-Hotkey Isolation & LIFO ShortcutScope (ESC Stack)
----------------------------------------------------------------

---@return table handle { release = function }
function FocusManager.acquireTextInputLock()
    activeEditableCount = activeEditableCount + 1
    local released = false
    return {
        release = function()
            if released then return end
            released = true
            activeEditableCount = math.max(0, activeEditableCount - 1)
        end,
    }
end

---@return boolean
function FocusManager.isTextInputActive()
    return activeEditableCount > 0
end

---Push a LIFO shortcut handler scope (e.g., ChoiceMenu -> ModalDialog -> WindowHost).
---onKey(owner, key): returns true if key was consumed.
---@param owner any
---@param opts table { onEscape = fun(owner:any, key:number):boolean?, onKey = fun(owner:any, key:number):boolean? }
---@return table handle { release = function }
function FocusManager.pushShortcutScope(owner, opts)
    opts = opts or {}
    local entry = {
        owner = owner,
        onEscape = opts.onEscape,
        onKey = opts.onKey,
        released = false,
    }
    shortcutStack[#shortcutStack + 1] = entry
    return {
        release = function()
            if entry.released then return end
            entry.released = true
            for i = #shortcutStack, 1, -1 do
                if shortcutStack[i] == entry then
                    table.remove(shortcutStack, i)
                    break
                end
            end
        end,
    }
end

---Dispatch key to the topmost active ShortcutScope first.
---@param key number
---@return boolean consumed
function FocusManager.dispatchKey(key)
    local escKey = Keyboard and Keyboard.KEY_ESCAPE or 1
    for i = #shortcutStack, 1, -1 do
        local entry = shortcutStack[i]
        if entry and not entry.released then
            if key == escKey and type(entry.onEscape) == "function" then
                local handled = entry.onEscape(entry.owner, key)
                if handled ~= false then return true end
            end
            if type(entry.onKey) == "function" then
                local handled = entry.onKey(entry.owner, key)
                if handled == true then return true end
            end
            -- Topmost modal/window barrier stops ESC fallthrough
            if key == escKey then return false end
        end
    end
    return false
end

---Unified B42 UIElement:onKeyPress dispatcher for top-level windows/modals/menus.
---Records consumed key for immediate UIElement:isKeyConsumed(key) query and eats key-release.
---@param groupKey any
---@param key number
---@param fallbackEscapeFn (fun():boolean?)?
---@return boolean consumed
function FocusManager.handleWindowKeyPress(groupKey, key, fallbackEscapeFn)
    local focused = FocusManager.getFocused(groupKey)
    if focused and focused ~= groupKey and type(focused.onKeyPress) == "function" then
        local ok, used = pcall(focused.onKeyPress, focused, key)
        if ok and used == true then
            lastConsumedKey = key
            FocusManager.eatKey(key)
            return true
        end
    end
    if FocusManager.handleTab(groupKey, key) then
        lastConsumedKey = key
        FocusManager.eatKey(key)
        return true
    end
    if FocusManager.dispatchKey(key) then
        lastConsumedKey = key
        FocusManager.eatKey(key)
        return true
    end
    local escKey = Keyboard and Keyboard.KEY_ESCAPE or 1
    if key == escKey and type(fallbackEscapeFn) == "function" then
        if fallbackEscapeFn() ~= false then
            lastConsumedKey = key
            FocusManager.eatKey(key)
            return true
        end
    end
    return false
end

---Paired with handleWindowKeyPress inside B42 UIElement:isKeyConsumed(key).
---@param groupKey any
---@param key number
---@param closeOnEscape boolean?
---@return boolean
function FocusManager.isWindowKeyConsumed(groupKey, key, closeOnEscape)
    if lastConsumedKey == key then
        lastConsumedKey = nil
        return true
    end
    local escKey = Keyboard and Keyboard.KEY_ESCAPE or 1
    if key == escKey and closeOnEscape then
        return true
    end
    local tabKey = Keyboard and Keyboard.KEY_TAB or 15
    if key == tabKey then
        local g = groups[groupKey]
        if g and #g.items > 0 then return true end
    end
    return false
end

function FocusManager.resetAll()
    for _, g in pairs(groups) do
        if g.activeIndex > 0 and g.items[g.activeIndex] then
            clearFocusFlag(g.items[g.activeIndex])
        end
    end
    groups = {}
    shortcutStack = {}
    activeEditableCount = 0
    lastConsumedKey = nil
end

return FocusManager
