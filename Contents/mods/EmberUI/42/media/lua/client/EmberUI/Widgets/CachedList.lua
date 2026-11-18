local Tooltip = require "EmberUI/Core/TooltipManager"
require "ISUI/ISScrollingListBox"
require "ISUI/ISScrollBar"
local Text = require "EmberUI/Core/Text"
local Theme = require "EmberUI/Core/Theme"
local Chrome = require "EmberUI/Core/Chrome"
local FocusManager = require "EmberUI/Core/FocusManager"
local EmptyState = require "EmberUI/Widgets/EmptyState"

local Cached = {}
local WELL_TRANSPARENT = { r = 0, g = 0, b = 0, a = 0 }
local globalProfiler = nil

---@param hook table? Optional { begin = fun(key):any, finish = fun(key, token) }
function Cached.setProfiler(hook)
    assert(hook == nil or (type(hook) == "table" and type(hook.begin) == "function" and type(hook.finish) == "function"), "CACHED_LIST_PROFILER_INVALID")
    globalProfiler = hook
end

function Cached.draw(list, y, entry)
    if list.emberStyle then return list.emberStyle.draw(list, y, entry) end
    local h = entry.height or list.itemheight
    local visible = y + list:getYScroll()
    if visible + h < 0 or visible >= list.height then return y + h end
    if list.selected == entry.index then
        Chrome.roundedFill(list, 0, y, list.width, h, Theme.selected)
    end
    for index, line in ipairs(entry.item.lines) do
        Theme.text(list, line, list.emberPad, y + list.emberPad / 2 + (index - 1) * list.emberFontHeight, Theme.textColor, UIFont.Small)
    end
    return y + h
end

function Cached.styleWell(list, bg, border)
    if not list then return list end
    list.backgroundColor = WELL_TRANSPARENT
    list.borderColor = border or Theme.border
    list.drawBorder = false
    if bg then list._emberWellBg = bg end
    if border then list._emberWellBorder = border end
    if not list._emberWellStyled then
        list._emberWellStyled = true
        local origPrerender = list.prerender
        list.prerender = function(self)
            local sy = self.getYScroll and self:getYScroll() or 0
            self.backgroundColor = WELL_TRANSPARENT
            Chrome.roundedRect(self, 0, -sy, self.width, self.height, self._emberWellBg or Theme.well or Theme.panel, self._emberWellBorder or Theme.border)
            if origPrerender then origPrerender(self) end
        end
    end
    return list
end

function Cached.create(owner, bounds, select, style)
    local list = ISScrollingListBox:new(bounds.x, bounds.y, bounds.width, bounds.height)
    list:initialise()
    Tooltip.register(list, { method = "updateTooltip", owner = owner })
    list.font = UIFont.Small
    list.emberPad = (owner and owner.pad) or 6
    list.emberFontHeight = (owner and owner.fontHeight) or 14
    list.emberStyle = style

    if list.vscroll then Theme.scrollbar(list.vscroll) end
    if list.hscroll then Theme.scrollbar(list.hscroll) end

    local function clampScroll(self)
        local total = (self.getScrollHeight and self:getScrollHeight()) or (self.items and #self.items * (self.itemheight or 0)) or 0
        local height = self.height or 0
        local maxScroll = math.max(0, total - height)
        if maxScroll <= 0 then
            if self.getYScroll and self:getYScroll() ~= 0 and self.setYScroll then self:setYScroll(0) end
            self.smoothScrollTargetY = nil
            self.smoothScrollY = nil
            return 0
        end
        local cur = self.getYScroll and self:getYScroll() or 0
        local clamped = math.max(-maxScroll, math.min(0, cur))
        if cur ~= clamped and self.setYScroll then self:setYScroll(clamped) end
        if self.smoothScrollTargetY then
            self.smoothScrollTargetY = math.max(-maxScroll, math.min(0, self.smoothScrollTargetY))
        end
        if self.smoothScrollY then
            self.smoothScrollY = math.max(-maxScroll, math.min(0, self.smoothScrollY))
        end
        return maxScroll
    end

    local nativeWheel = list.onMouseWheel
    list.onMouseWheel = function(self, del)
        local maxScroll = math.max(0, self:getScrollHeight() - self.height)
        if maxScroll <= 0 then
            self:setYScroll(0)
            self.smoothScrollTargetY = nil
            self.smoothScrollY = nil
            return true
        end
        local res = nativeWheel(self, del)
        clampScroll(self)
        return res
    end

    local nativeSmooth = list.updateSmoothScrolling
    list.updateSmoothScrolling = function(self)
        local maxScroll = clampScroll(self)
        if maxScroll <= 0 then return end
        nativeSmooth(self)
        clampScroll(self)
    end

    local nativePre = list.prerender
    list.prerender = function(self)
        local vs = self.vscroll
        if vs then
            if not vs._emberScrollSkinned then Theme.scrollbar(vs) end
            local vw = vs.width or 6
            if vw > 8 then vw = 7 if vs.setWidth then vs:setWidth(vw) end end
            local targetX = math.max(0, (self.width or 0) - vw)
            local curX = vs.getX and vs:getX() or vs.x
            local curH = vs.getHeight and vs:getHeight() or vs.height
            if curX ~= targetX and vs.setX then vs:setX(targetX) end
            if curH ~= self.height and vs.setHeight then vs:setHeight(self.height) end
        end
        if self.hscroll and not self.hscroll._emberScrollSkinned then Theme.scrollbar(self.hscroll) end
        clampScroll(self)
        local prof = self.emberProfiler or globalProfiler
        if prof then
            local key = self.emberMetric or "ui.list"
            local token = prof.begin(key)
            nativePre(self)
            prof.finish(key, token)
        else
            nativePre(self)
        end
        clampScroll(self)
    end

    if style then
        local native = list.render
        list.render = function(self)
            if native then native(self) end
            if #self.items == 0 then
                if self.emberEmptyState then
                    if not self._cachedEmptyBounds then
                        self._cachedEmptyBounds = { x = 0, y = 0, width = self.width, height = self.height }
                    else
                        self._cachedEmptyBounds.width = self.width
                        self._cachedEmptyBounds.height = self.height
                    end
                    EmptyState.draw(self, self._cachedEmptyBounds, self.emberEmptyState)
                elseif self.emberEmptyLines and #self.emberEmptyLines > 0 then
                    if not self._cachedEmptyBounds then
                        self._cachedEmptyBounds = { x = 0, y = 0, width = self.width, height = self.height }
                    else
                        self._cachedEmptyBounds.width = self.width
                        self._cachedEmptyBounds.height = self.height
                    end
                    if not self._cachedEmptyOpts then
                        self._cachedEmptyOpts = { icon = "box", iconSize = 32 }
                    end
                    self._cachedEmptyOpts.title = self.emberEmptyLines[1] or ""
                    self._cachedEmptyOpts.hint = self.emberEmptyLines[2] or ""
                    EmptyState.draw(self, self._cachedEmptyBounds, self._cachedEmptyOpts)
                end
            end
        end
    end

    local origMouseDown = list.onMouseDown
    list.onMouseDown = function(self, x, y)
        if #self.items == 0 and self._cachedEmptyBounds and self.emberEmptyState and self.emberEmptyState.onAction then
            if EmptyState.hitTest(self._cachedEmptyBounds, x, y) then
                self.emberEmptyState.onAction(self)
                return true
            end
        end
        return origMouseDown and origMouseDown(self, x, y) or true
    end

    list.itemheight = list.emberFontHeight + list.emberPad
    list.doDrawItem = Cached.draw

    if select then
        local clicked = function(target, row)
            if target and target.focusList then target:focusList(list) end
            if row ~= nil then
                local val = (type(row) == 'table' and row.value ~= nil) and row.value or row
                select(target, val)
            end
        end
        list:setOnMouseDownFunction(owner, clicked)
        list:setOverrideAButtonFunction(owner, clicked)
    end

    list:setWantKeyEvents(true)
    local function move(direction)
        list.selected = math.max(1, math.min(#list.items, (list.selected or 1) + direction))
        if list.ensureVisible then list:ensureVisible(list.selected) end
        if select and list.items[list.selected] then
            local it = list.items[list.selected].item
            local val = (type(it) == 'table' and it.value ~= nil) and it.value or it
            select(owner, val)
        end
    end

    list.onKeyPress = function(_, key)
        if owner and owner.isListFocused and not owner:isListFocused(list) then return end
        if key == Keyboard.KEY_UP then
            move(-1)
        elseif key == Keyboard.KEY_DOWN then
            move(1)
        elseif key == Keyboard.KEY_ESCAPE then
            if owner and type(owner.close) == "function" then
                owner:close()
                FocusManager.eatKey(key)
            end
        elseif owner and owner.onListKey then
            owner:onListKey(key, list)
        end
    end

    list.isKeyConsumed = function(_, key)
        if owner and owner.isListFocused and not owner:isListFocused(list) then return false end
        if key == Keyboard.KEY_UP or key == Keyboard.KEY_DOWN then return true end
        if key == Keyboard.KEY_ESCAPE and owner and type(owner.close) == "function" then return true end
        return (owner and owner.onListKey and (key == Keyboard.KEY_LEFT or key == Keyboard.KEY_RIGHT
            or key == Keyboard.KEY_TAB or key == Keyboard.KEY_RETURN)) == true
    end

    list.onJoypadDirUp = function() move(-1) end
    list.onJoypadDirDown = function() move(1) end
    list.onJoypadDown = function(_, button)
        if button == Joypad.BButton then
            if owner and type(owner.close) == "function" then owner:close() end
        elseif button == Joypad.AButton and owner and owner.onListActivate then
            owner:onListActivate(list)
        elseif owner and owner.onListJoypad then
            owner:onListJoypad(button)
        end
    end
    if owner and owner.onListFocus then
        list.onJoypadDirLeft = function() owner:onListFocus(list, -1) end
        list.onJoypadDirRight = function() owner:onListFocus(list, 1) end
    end
    return list
end

function Cached.fill(list, rows, caption)
    Tooltip.clear(list)
    list:clear()
    for _, value in ipairs(rows) do
        local label = caption(value)
        local lines = Text.wrap(label, list.width - list.emberPad * 3 - 16, UIFont.Small)
        if #lines > 3 then lines = { lines[1], lines[2], lines[3] .. "..." } end
        list.itemheight = list.emberPad + list.emberFontHeight * math.max(1, #lines)
        list:addItem(label, { value = value, lines = lines }, label)
    end
    list.selected = #rows > 0 and 1 or 0
end

-- Reuse native entries by stable key with scratch map pooling (0 temporary tables on count-only updates).
function Cached.reconcile(list, rows, caption, key, preserveAnchor, cacheRevision)
    local revisionChanged = cacheRevision ~= list.emberPreparedRevision
    local old = list.items
    local selected = old[list.selected or 0]
    local selectedKey = selected and key(selected.item.value)
    local oldTop = 0
    for i, entry in ipairs(old) do
        if i == (list.selected or 0) then break end
        oldTop = oldTop + entry.height
    end

    local entries = list._reconcileMap
    if not entries then
        entries = {}
        list._reconcileMap = entries
    else
        for k in pairs(entries) do entries[k] = nil end
    end
    for _, entry in ipairs(old) do
        entries[key(entry.item.value)] = entry
    end

    local updated = list._reconcileScratch
    if not updated then
        updated = {}
        list._reconcileScratch = updated
    else
        for i = #updated, 1, -1 do updated[i] = nil end
    end

    local total, selectedIndex, newTop = 0, nil, 0
    local structural = #old ~= #rows
    local heightChanged = false
    for i, value in ipairs(rows) do
        local id = key(value)
        local entry = entries[id]
        local label
        if revisionChanged or not entry or entry.item.value ~= value then
            label = caption(value)
        end
        if revisionChanged or not entry or (label and entry.text ~= label) then
            local visual
            if list.emberStyle then
                visual = list.emberStyle.prepare(list, value, label)
            else
                local lines = Text.wrap(label, list.width - list.emberPad * 3 - 16, UIFont.Small)
                if #lines > 3 then lines = { lines[1], lines[2], lines[3] .. "..." } end
                visual = { lines = lines, height = list.emberPad + list.emberFontHeight * math.max(1, #lines) }
            end
            local itemTip = (visual and visual.tooltip) or (not list.emberStyle and label or nil)
            if not entry then
                list.itemheight = visual.height
                entry = list:addItem(label, { value = value, lines = visual.lines, visual = visual }, itemTip)
            else
                heightChanged = heightChanged or entry.height ~= visual.height
                entry.text = label
                entry.tooltip = itemTip
                entry.item.lines = visual.lines
                entry.item.visual = visual
                entry.height = visual.height
            end
            if list.mouseoverselected == i and list.tooltipUI then
                list.tooltipUI.description = itemTip
            end
        end
        entry.item.value = value
        if old[i] ~= entry then structural = true end
        entry.itemindex = i
        entry.index = i
        updated[i] = entry
        if id == selectedKey then
            selectedIndex = i
            newTop = total
        end
        total = total + entry.height
    end
    for k in pairs(entries) do entries[k] = nil end

    if structural then
        Tooltip.clear(list)
        -- Swap array buffers between list.items and scratch so next reconcile reuses old array
        list._reconcileScratch = old
        for i = #old, 1, -1 do old[i] = nil end
        list.items = updated
        list.count = #updated
        list.itemheightoverride = {}
    else
        for i = #updated, 1, -1 do updated[i] = nil end
    end

    list.selected = selectedIndex or (#rows > 0 and math.max(1, math.min(list.selected or 1, #rows)) or 0)
    if structural or heightChanged then
        local scroll = list:getYScroll()
        if preserveAnchor and selectedIndex then scroll = scroll + oldTop - newTop end
        list:setScrollHeight(total)
        local clamped = math.max(math.min(0, scroll), math.min(0, list.height - total))
        list:setYScroll(clamped)
        if list.smoothScrollY then list.smoothScrollY = clamped end
        if list.smoothScrollTargetY then list.smoothScrollTargetY = clamped end
    end
    list.emberPreparedRevision = cacheRevision
    local current = list.items[list.selected]
    return current and current.item.value or false
end

return Cached
