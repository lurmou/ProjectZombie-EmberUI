-- Declarative layout DSL facade producing side-effect-free layout descriptors.
local UI = {}
local Clock = require 'EmberUI/Core/Clock'

local function copyShallow(t)
    if not t then return {} end
    local out = {}
    for k, v in pairs(t) do out[k] = v end
    return out
end

local function flattenChildren(...)
    local out = {}
    local function append(list)
        for i = 1, #list do
            local child = list[i]
            if child ~= nil and child ~= false then
                if type(child) == "table" and child[1] ~= nil and not child.isLayoutSpec and not child.isLayoutItemSpec then
                    append(child)
                else
                    out[#out + 1] = child
                end
            end
        end
    end
    append({ ... })
    return out
end

local function normalize(props, children)
    if type(props) == "table" and props[1] ~= nil and children == nil then
        return {}, props
    end
    return props or {}, children or {}
end

---Creates a horizontal row layout descriptor.
---@param props table? Styling properties (padding, gap, align, justify)
---@param children table? Array of child specifications
---@return table Layout descriptor
function UI.Row(props, children)
    local p, c = normalize(props, children)
    return {
        isLayoutSpec = true,
        type = "row",
        props = p,
        children = c
    }
end

---Creates a vertical column layout descriptor.
---@param props table? Styling properties (padding, gap, align, justify)
---@param children table? Array of child specifications
---@return table Layout descriptor
function UI.Column(props, children)
    local p, c = normalize(props, children)
    return {
        isLayoutSpec = true,
        type = "column",
        props = p,
        children = c
    }
end

---Wraps a child (native widget or nested container) with parent layout properties.
---@param child any Native widget, rect leaf, or nested UI.Row/Column
---@param props table? Layout properties (key, grow, basis, margin, bind, when, pad, font, autoText)
---@return table Layout item descriptor
function UI.Item(child, props)
    assert(child ~= nil, "UI_ITEM_CHILD_NIL")
    local p
    if type(child) == "table" and child.isLayoutItemSpec then
        p = copyShallow(child.props)
        if props then
            for k, v in pairs(props) do p[k] = v end
        end
        child = child.child
    else
        p = copyShallow(props)
    end
    if p.height ~= nil and p.basis == nil then
        p.basis = p.height
        p.height = nil
    elseif p.width ~= nil and p.basis == nil then
        p.basis = p.width
        p.width = nil
    end
    return {
        isLayoutItemSpec = true,
        child = child,
        props = p
    }
end

---Creates a pure geometric elastic spacer without native widget.
---@param grow number? Elastic weight, default 1
---@return table Spacer descriptor
function UI.Spacer(grow)
    local g = grow == nil and 1 or grow
    assert(type(g) == "number" and g >= 0 and g == g and g < math.huge, "INVALID_SPACER_GROW")
    return {
        isSpacer = true,
        grow = g
    }
end

---Creates a standard form configuration row descriptor (Label + Control + Action).
---Produces a pure UI.Item descriptor wrapping a UI.Row, ready for direct inclusion in UI.Column.
---@param label any Label widget, text element, or layout descriptor
---@param control any Input widget (e.g. StepperInput, ISTextEntryBox, Dropdown)
---@param action any? Optional button or action widget (e.g. Save, Reset)
---@param opts table? Optional styling/proportions ({ gap, labelWidth, actionWidth, height, align, margin, key, bind, grow, padding, when })
---@return table Layout item descriptor
function UI.FormRow(label, control, action, opts)
    assert(label ~= nil, "FORM_ROW_LABEL_NIL")
    assert(control ~= nil, "FORM_ROW_CONTROL_NIL")
    opts = opts or {}
    local gap = opts.gap or 8
    local labelW = opts.labelWidth or 120
    local actionW = opts.actionWidth or 64
    local align = opts.align or "center"

    local labelWidget = label
    if type(label) == "string" then
        labelWidget = UI.Label(label, { w = labelW, h = opts.height or 24, muted = opts.labelMuted })
    end

    local children = {
        UI.Item(labelWidget, { basis = labelW, grow = 0 }),
        UI.Item(control, { grow = 1 })
    }
    if action ~= nil then
        children[#children + 1] = UI.Item(action, { basis = actionW, grow = 0 })
    end

    local rowProps = { gap = gap, align = align }
    if opts.padding then rowProps.padding = opts.padding end

    local rowSpec = UI.Row(rowProps, children)
    return UI.Item(rowSpec, {
        key = opts.key,
        grow = opts.grow or 0,
        basis = opts.height or 24,
        margin = opts.margin,
        bind = opts.bind,
        when = opts.when
    })
end

---Creates a 2D grid layout descriptor composed of rows within a column.
---@param props table? Styling properties (columns, colGap, rowGap, gap, rowHeight, align, grow, height, width, margin, key, bind, when)
---@param ... any Child specifications or array of specifications
---@return table Layout item descriptor
function UI.Grid(props, ...)
    props = props or {}
    local cols = props.columns or 2
    assert(type(cols) == "number" and cols > 0 and math.floor(cols) == cols, "INVALID_GRID_COLUMNS")
    local colGap = props.colGap or props.gap or 0
    local rowGap = props.rowGap or props.gap or 0
    local rowH = props.rowHeight
    local children = flattenChildren(...)

    local rows = {}
    local currentRow = {}
    for i = 1, #children do
        local child = children[i]
        if not child.isLayoutItemSpec and not child.isSpacer then
            child = UI.Item(child, { grow = 1 })
        elseif not child.props or (child.props.grow == nil and child.props.basis == nil) then
            local cp = copyShallow(child.props or {})
            cp.grow = 1
            child = copyShallow(child)
            child.props = cp
        end
        currentRow[#currentRow + 1] = child
        if #currentRow == cols or i == #children then
            if #currentRow < cols then
                for _ = #currentRow + 1, cols do
                    currentRow[#currentRow + 1] = UI.Spacer(1)
                end
            end
            local rowProps = {
                gap = colGap,
                align = props.align or "stretch"
            }
            local rowItemProps = {
                grow = (rowH and 0 or 1),
                basis = rowH or 0
            }
            rows[#rows + 1] = UI.Item(UI.Row(rowProps, currentRow), rowItemProps)
            currentRow = {}
        end
    end

    local colProps = {
        gap = rowGap,
        align = props.align or "stretch"
    }
    if props.padding then colProps.padding = props.padding end

    local colSpec = UI.Column(colProps, rows)
    return UI.Item(colSpec, {
        key = props.key,
        grow = props.grow,
        basis = props.height,
        margin = props.margin,
        bind = props.bind,
        when = props.when
    })
end

---Creates a conditional item descriptor.
---When the condition is met, the item is displayed; otherwise it collapses to 0 geometry without re-slicing.
---@param predicate function|boolean Function taking state context or boolean
---@param item any Main child specification to display when true
---@param fallback any? Optional fallback child specification to display when false
---@return table|table[] Layout item descriptor (or array if fallback provided)
function UI.Show(predicate, item, fallback)
    assert(type(predicate) == "function" or type(predicate) == "boolean", "INVALID_SHOW_PREDICATE")
    assert(item ~= nil, "SHOW_ITEM_NIL")

    local function wrap(target, cond, initVis)
        if target.isLayoutItemSpec then
            local cloned = copyShallow(target)
            local p = copyShallow(target.props or {})
            p.when = cond
            if initVis ~= nil then p.visible = initVis end
            cloned.props = p
            return cloned
        elseif target.isLayoutSpec then
            return UI.Item(target, { when = cond, visible = initVis })
        else
            return UI.Item(target, { when = cond, visible = initVis, grow = 1 })
        end
    end

    local initTrue = type(predicate) == "boolean" and predicate or nil
    local trueItem = wrap(item, predicate, initTrue)

    if fallback ~= nil then
        local fallbackCond = false
        if type(predicate) == "function" then
            fallbackCond = function(ctx) return not predicate(ctx) end
        else
            fallbackCond = not predicate
        end
        local initFalse = type(predicate) == "boolean" and (not predicate) or false
        local falseItem = wrap(fallback, fallbackCond, initFalse)
        return { trueItem, falseItem }
    end

    return trueItem
end

---Creates a structured card container layout descriptor.
---Encapsulates optional header row (title + action) and content body,
---binding its outer geometry to props.bind for zero-GC card background rendering.
---@param props table? Styling and binding properties (title, action, headerHeight, headerGap, bodyGap, padding, headerPadding, bodyPadding, margin, grow, basis, height, bind, key, when)
---@param ... any Child specifications or array of specifications
---@return table Layout item descriptor
function UI.Card(props, ...)
    props = props or {}
    local children = flattenChildren(...)

    local cardItems = {}

    -- 1. Optional Header Row
    if props.title ~= nil or props.action ~= nil then
        local headerChildren = {}
        if props.title ~= nil then
            local titleWidget = props.title
            if type(titleWidget) == "string" then
                titleWidget = {
                    text = titleWidget,
                    title = titleWidget,
                    x = 0, y = 0, width = 0, height = 0,
                    visible = true
                }
            end
            headerChildren[#headerChildren + 1] = UI.Item(titleWidget, {
                basis = props.titleWidth or "auto",
                grow = props.titleGrow or 0,
                autoText = type(props.title) == "string" and props.title or nil
            })
        end

        headerChildren[#headerChildren + 1] = UI.Spacer(1)

        if props.action ~= nil then
            headerChildren[#headerChildren + 1] = UI.Item(props.action, {
                basis = props.actionWidth or "auto",
                grow = 0
            })
        end

        local headerRow = UI.Row({
            gap = props.headerGap or 8,
            align = "center",
            padding = props.headerPadding
        }, headerChildren)

        cardItems[#cardItems + 1] = UI.Item(headerRow, {
            basis = props.headerHeight or 28,
            grow = 0,
            margin = props.headerMargin
        })
    end

    -- 2. Body Column
    local bodyCol = UI.Column({
        gap = props.bodyGap or 8,
        padding = props.bodyPadding,
        align = props.align or "stretch"
    }, children)

    cardItems[#cardItems + 1] = UI.Item(bodyCol, {
        grow = props.bodyGrow == nil and 1 or props.bodyGrow
    })

    -- 3. Outer Card Container
    local cardCol = UI.Column({
        gap = 0,
        padding = props.padding,
        align = "stretch"
    }, cardItems)

    return UI.Item(cardCol, {
        key = props.key,
        grow = props.grow or 0,
        basis = props.basis or props.height,
        margin = props.margin,
        bind = props.bind,
        when = props.when
    })
end

local debouncerMeta = {
    trigger = function(self, ...)
        if not self.scope or not self.scope:isCurrent() then
            self:cancel()
            return
        end
        local n = select("#", ...)
        self.nArgs = n
        for i = 1, n do self.args[i] = select(i, ...) end
        for i = n + 1, #self.args do self.args[i] = nil end
        local now = Clock.nowMs()
        self.targetTime = now + self.delayMs
        self.pending = true
    end,
    tick = function(self, now)
        if not self.pending then return false end
        if not self.scope or not self.scope:isCurrent() then
            self:cancel()
            return false
        end
        now = now or (Clock.nowMs())
        if now >= self.targetTime then
            self:flush()
            return true
        end
        return false
    end,
    flush = function(self)
        if not self.pending then return end
        self.pending = false
        if self.scope and self.scope:isCurrent() then
            local fn = self.fn
            local a = self.args
            local n = self.nArgs
            if n == 0 then fn()
            elseif n == 1 then fn(a[1])
            elseif n == 2 then fn(a[1], a[2])
            elseif n == 3 then fn(a[1], a[2], a[3])
            elseif n == 4 then fn(a[1], a[2], a[3], a[4])
            else fn(unpack(a, 1, n)) end
        end
    end,
    cancel = function(self)
        self.pending = false
        self.nArgs = 0
        for i = 1, #self.args do self.args[i] = nil end
    end
}
debouncerMeta.__index = debouncerMeta
debouncerMeta.__call = function(t, ...)
    t:trigger(...)
end

---Creates a zero-GC lifecycle-bound debounced function.
---Execution is tied to scope:isCurrent() and automatically cancelled when the page unmounts.
---If host is provided, the host's update loop will tick the debouncer automatically.
---@param scope table Page or component lifecycle scope with :isCurrent()
---@param fn function Callback to execute after debounce delay
---@param delayMs number? Milliseconds delay (default 150)
---@param host table? LayoutHost instance to register tick listener with
---@return table Debouncer callable table
function UI.debounce(scope, fn, delayMs, host)
    assert(scope and type(scope.isCurrent) == "function", "INVALID_DEBOUNCE_SCOPE")
    assert(type(fn) == "function", "INVALID_DEBOUNCE_FN")
    delayMs = delayMs or 150
    assert(type(delayMs) == "number" and delayMs >= 0, "INVALID_DEBOUNCE_DELAY")

    local inst = setmetatable({
        scope = scope,
        fn = fn,
        delayMs = delayMs,
        host = host,
        targetTime = -1,
        pending = false,
        args = {},
        nArgs = 0
    }, debouncerMeta)

    if host and type(host.registerDebouncer) == "function" then
        host:registerDebouncer(inst)
    end
    return inst
end

local LAYOUT_KEYS = {
    grow = true, basis = true, crossBasis = true, alignSelf = true,
    margin = true, key = true, bind = true, when = true,
}

local function finishWidget(widget, opts, defaultOwner)
    widget.anchorRight = false
    widget.anchorBottom = false
    if opts then
        if opts.tooltip then
            widget.tooltip = opts.tooltip
            local Tooltip = require("EmberUI/Core/TooltipManager")
            Tooltip.register(widget, { method = opts.tooltipMethod or "prerender", owner = opts.owner or defaultOwner })
        end
        if opts.focusGroup ~= nil then
            local FocusManager = require("EmberUI/Core/FocusManager")
            FocusManager.register(opts.focusGroup, widget)
        end
        if opts.assign and opts.assign[1] and opts.assign[2] then
            opts.assign[1][opts.assign[2]] = widget
        end
        local layoutProps
        for k, v in pairs(opts) do
            if LAYOUT_KEYS[k] then
                layoutProps = layoutProps or {}
                layoutProps[k] = v
            end
        end
        if layoutProps then
            return UI.Item(widget, layoutProps)
        end
    end
    return widget
end

---Creates a pure rect leaf `{ x=0, y=0, width=0, height=0 }` for custom prerender regions.
---@param opts table? Optional layout props and `assign = { table, key }`
function UI.Rect(opts)
    local rect = { x = 0, y = 0, width = 0, height = 0, visible = false }
    if opts then
        if opts.assign and opts.assign[1] and opts.assign[2] then
            opts.assign[1][opts.assign[2]] = rect
        end
        local layoutProps
        for k, v in pairs(opts) do
            if LAYOUT_KEYS[k] then
                layoutProps = layoutProps or {}
                layoutProps[k] = v
            end
        end
        if layoutProps then
            return UI.Item(rect, layoutProps)
        end
    end
    return rect
end

---Creates a themed ISButton with detached anchors and optional LayoutHost item wrapper.
function UI.Button(title, target, fn, opts)
    opts = opts or {}
    require("ISUI/ISButton")
    local btn = ISButton:new(0, 0, opts.w or 100, opts.h or 24, title, target, fn)
    btn:initialise()
    if opts.theme ~= false then
        local Theme = require("EmberUI/Core/Theme")
        Theme.button(btn, opts.primary == true or opts.accent == true, opts.active == true or opts.solid == true)
    end
    return finishWidget(btn, opts, target)
end

---Creates a Dropdown with detached anchors, optional initial options and LayoutHost item wrapper.
function UI.Dropdown(target, onChange, opts)
    opts = opts or {}
    local Dropdown = require("EmberUI/Widgets/Dropdown")
    local dd = Dropdown:new(0, 0, opts.w or 100, opts.h or 24, target, onChange)
    dd:initialise()
    if opts.options then
        dd:setOptions(opts.options, opts.selected)
    end
    return finishWidget(dd, opts, target)
end

---Creates a SearchInput with detached anchors and optional LayoutHost item wrapper.
function UI.SearchInput(placeholder, target, onChange, opts)
    opts = opts or {}
    local SearchInput = require("EmberUI/Widgets/SearchInput")
    local box = SearchInput:new(0, 0, opts.w or 100, opts.h or 24, placeholder or "", target, onChange)
    if opts.text and opts.text ~= "" then
        box:setText(opts.text)
    end
    return finishWidget(box, opts, target)
end

---Creates a StepperInput with detached anchors and optional LayoutHost item wrapper.
function UI.Stepper(initialValue, min, max, steps, onChange, opts)
    opts = opts or {}
    local StepperInput = require("EmberUI/Widgets/StepperInput")
    local w = opts.w
    if not w then
        local tm = getTextManager and getTextManager()
        local fh = (tm and tm.getFontHeight and tm:getFontHeight(UIFont.Small)) or 14
        local pad = math.ceil(fh * 0.4)
        local btnW = math.max(24, math.floor(fh * 2.2))
        local gap = math.max(2, math.floor(pad / 3))
        w = btnW * 4 + gap * 4 + math.max(40, math.floor(fh * 2.5))
    end
    local stepper = StepperInput:new(0, 0, w, opts.h or 24, initialValue, min, max, steps, onChange)
    stepper.anchorRight = false
    stepper.anchorBottom = false
    if opts.entryTooltip and stepper.entry then
        stepper.entry.tooltip = opts.entryTooltip
        local Tooltip = require("EmberUI/Core/TooltipManager")
        Tooltip.register(stepper.entry, { method = "prerender", owner = opts.owner })
    end
    return finishWidget(stepper, opts, opts.owner)
end

---Creates a lightweight self-rendering text label with Zero-GC cached wrapping and alignment.
---@param labelText string?
---@param opts table? { w, h, font, color, muted, align, wrap, maxLines, assign, ... }
function UI.Label(labelText, opts)
    opts = opts or {}
    require("ISUI/ISPanel")
    local Theme = require("EmberUI/Core/Theme")
    local UICache = require("EmberUI/Core/UICache")
    local Text = require("EmberUI/Core/Text")
    local font = opts.font or UIFont.Small
    local tm = getTextManager and getTextManager()
    local fh = (tm and tm.getFontHeight and tm:getFontHeight(font)) or 14
    local initialText = tostring(labelText or "")
    local measuredW = opts.w or opts.width or math.max(16, UICache.measure(font, initialText))
    local lbl = ISPanel:new(0, 0, measuredW, opts.h or opts.height or math.max(18, fh + 4))
    lbl.background = false
    lbl.text = initialText
    lbl.font = font
    lbl.fontHeight = fh
    lbl.color = opts.color
    lbl.muted = opts.muted == true
    lbl.align = opts.align or "left"
    lbl.wrap = opts.wrap == true
    lbl.truncate = opts.truncate ~= false
    lbl.maxLines = opts.maxLines or 2
    lbl._cachedTextW = UICache.measure(font, initialText)
    lbl._wrappedWidth = -1
    lbl._lines = nil

    function lbl:setText(nextText)
        local s = tostring(nextText or "")
        if self.text == s then return end
        self.text = s
        self._cachedTextW = UICache.measure(self.font, s)
        self._wrappedWidth = -1
        self._lines = nil
    end

    function lbl:setColor(col)
        self.color = col
    end

    lbl:initialise()
    lbl.prerender = function(self)
        local col = self.color or (self.muted and Theme.muted or Theme.textColor)
        if self.wrap and self.width > 0 then
            if self._wrappedWidth ~= self.width or not self._lines then
                self._wrappedWidth = self.width
                self._lines = Text.wrapLimited(self.text, self.width, self.font, self.maxLines)
            end
            local totalH = #self._lines * self.fontHeight
            local startY = math.max(0, math.floor((self.height - totalH) / 2))
            for i = 1, #self._lines do
                Theme.text(self, self._lines[i], 0, startY + (i - 1) * self.fontHeight, col, self.font)
            end
        elseif self.text ~= "" then
            local drawStr = self.text
            local drawW = self._cachedTextW
            if self.truncate and self.width > 0 and drawW > self.width then
                drawStr = Text.truncate(drawStr, self.width, self.font)
                drawW = UICache.measure(self.font, drawStr)
            end
            local tx = 0
            if self.align == "center" then
                tx = math.max(0, math.floor((self.width - drawW) / 2))
            elseif self.align == "right" then
                tx = math.max(0, self.width - drawW)
            end
            local ty = math.floor((self.height - self.fontHeight) / 2)
            Theme.text(self, drawStr, tx, ty, col, self.font)
        end
    end
    return finishWidget(lbl, opts, opts.owner)
end

---Creates a themed rounded ISTextEntryBox with detached anchors and optional LayoutHost wrapper.
---@param value string?
---@param target any?
---@param onChange function?
---@param opts table? { w, h, placeholder, masked, onlyNumbers, maxLength, editable, ... }
function UI.TextInput(value, target, onChange, opts)
    opts = opts or {}
    require("ISUI/ISTextEntryBox")
    local Theme = require("EmberUI/Core/Theme")
    local entry = ISTextEntryBox:new(value or "", 0, 0, opts.w or opts.width or 140, opts.h or opts.height or 24)
    entry:initialise()
    entry:instantiate()
    if opts.placeholder and entry.setPlaceholderText then entry:setPlaceholderText(opts.placeholder) end
    if opts.masked and entry.setMasked then entry:setMasked(true) end
    if opts.onlyNumbers and entry.setOnlyNumbers then entry:setOnlyNumbers(true) end
    if type(opts.maxLength) == "number" and entry.setMaxTextLength then entry:setMaxTextLength(opts.maxLength) end
    if opts.editable == false and entry.setEditable then entry:setEditable(false) end
    if onChange then
        entry.target = target
        entry.onTextChangeFunction = onChange
    end
    Theme.input(entry, opts.focusGroup)
    return finishWidget(entry, opts, target)
end

---Creates a rounded themed ISTickBox with detached anchors and option population.
---@param options table[]? Array of strings or { label, data, selected, disabled }
---@param target any?
---@param onChange function?
---@param opts table?
function UI.TickBox(options, target, onChange, opts)
    opts = opts or {}
    require("ISUI/ISTickBox")
    local Theme = require("EmberUI/Core/Theme")
    local tb = ISTickBox:new(0, 0, opts.w or opts.width or 160, opts.h or opts.height or 24, "", target, onChange)
    tb:initialise()
    Theme.tickBox(tb)
    for i, opt in ipairs(options or {}) do
        if type(opt) == "table" then
            local idx = tb:addOption(opt.label or tostring(opt.data or i), opt.data)
            if opt.selected ~= nil and tb.setSelected then tb:setSelected(idx, opt.selected == true) end
            if opt.disabled and tb.disableOption then tb:disableOption(opt.label or tostring(opt.data or i), true) end
        else
            tb:addOption(tostring(opt))
        end
    end
    if opts.selected ~= nil and type(opts.selected) == "boolean" and #(options or {}) > 0 and tb.setSelected then
        tb:setSelected(1, opts.selected)
    end
    return finishWidget(tb, opts, target)
end

---Creates an animated ToggleSwitch with detached anchors and optional LayoutHost wrapper.
---@param checked boolean?
---@param target any?
---@param onChange function?
---@param opts table? { w, h, label, enable, trackWidth, ... }
function UI.Switch(checked, target, onChange, opts)
    opts = opts or {}
    local ToggleSwitch = require("EmberUI/Widgets/ToggleSwitch")
    local sw = ToggleSwitch:new(0, 0, opts.w or opts.width, opts.h or opts.height, checked, target, onChange, opts)
    return finishWidget(sw, opts, target)
end

---Creates a FilterChips horizontal capsule bar with detached anchors.
---@param options table[]?
---@param selectedId any?
---@param onSelect function?
---@param opts table? { w, h, variant, gap, ... }
function UI.FilterChips(options, selectedId, onSelect, opts)
    opts = opts or {}
    local FilterChips = require("EmberUI/Widgets/FilterChips")
    local fc = FilterChips:new(0, 0, opts.w or opts.width or 240, opts.h or opts.height or 26, onSelect)
    if opts.variant then fc.variant = opts.variant end
    if opts.gap then fc.gap = opts.gap end
    if options then fc:setOptions(options, selectedId) end
    return finishWidget(fc, opts, opts.owner)
end

---Creates a TabBar navigation strip with detached anchors and optional panel binding.
---@param tabs table[]?
---@param selectedId any?
---@param onSelect function?
---@param opts table? { w, h, variant, panels, stretch, gap, ... }
function UI.TabBar(tabs, selectedId, onSelect, opts)
    opts = opts or {}
    local TabBar = require("EmberUI/Widgets/TabBar")
    local bar = TabBar:new(0, 0, opts.w or opts.width or 260, opts.h or opts.height or 30, tabs, selectedId, onSelect, opts)
    return finishWidget(bar, opts, opts.target or opts.owner)
end

---Creates a CardPanel (optionally collapsible and hosting nested LayoutHost contentSpec).
---@param opts table? { w, h, title, badge, collapsible, collapsed, contentSpec, hostProps, scope, ... }
---@param childrenSpec table? Optional UI.Column/UI.Row descriptor used as contentSpec
function UI.CardPanel(opts, childrenSpec)
    opts = opts or {}
    local CardPanel = require("EmberUI/Widgets/CardPanel")
    local cardOpts = copyShallow(opts)
    if childrenSpec and not cardOpts.contentSpec then
        cardOpts.contentSpec = childrenSpec
    end
    local card = CardPanel:new(0, 0, cardOpts.w or cardOpts.width or 240, cardOpts.h or cardOpts.height or 120, cardOpts)
    return finishWidget(card, opts, opts.owner)
end

---Creates a themed CachedList with rounded Chrome well and slim capsule scrollbar.
---@param opts table? { w, h, owner, onSelect, style, itemheight, well, bg, border, emptyState, ... }
function UI.List(opts)
    opts = opts or {}
    local Cached = require("EmberUI/Widgets/CachedList")
    local Theme = require("EmberUI/Core/Theme")
    local listOwner = opts.owner or { fontHeight = 16, pad = 6 }
    local list = Cached.create(listOwner, { x = 0, y = 0, width = opts.w or opts.width or 200, height = opts.h or opts.height or 160 }, opts.onSelect, opts.style)
    if opts.itemheight then list.itemheight = opts.itemheight end
    if opts.emptyState then list.emberEmptyState = opts.emptyState end
    Theme.list(list)
    if opts.well ~= false then
        Cached.styleWell(list, opts.bg, opts.border)
    end
    return finishWidget(list, opts, opts.owner)
end

---Creates a Zero-GC StatMeter progress/health/load bar widget.
---@param fraction number?
---@param opts table?
function UI.StatMeter(fraction, opts)
    opts = opts or {}
    local StatMeter = require("EmberUI/Widgets/StatMeter")
    local meterOpts = copyShallow(opts)
    meterOpts.fraction = fraction or opts.fraction or 0
    local meter = StatMeter:new(0, 0, opts.w or opts.width or 160, opts.h or opts.height or 16, meterOpts)
    return finishWidget(meter, opts, opts.owner)
end

---Creates a Zero-GC self-rendering SemanticBadge panel.
---@param statusOrLabel string
---@param opts table? { w, h, customLabel, assign, ... }
function UI.Badge(statusOrLabel, opts)
    opts = opts or {}
    require("ISUI/ISPanel")
    local SemanticBadge = require("EmberUI/Widgets/SemanticBadge")
    local UICache = require("EmberUI/Core/UICache")
    local desc = SemanticBadge.resolve(statusOrLabel, opts.customLabel)
    local autoW = math.max(56, UICache.measure(UIFont.Small, desc.displayText or "") + 28)
    local badge = ISPanel:new(0, 0, opts.w or opts.width or autoW, opts.h or opts.height or 22)
    badge.background = false
    badge._key = statusOrLabel
    badge._opts = { label = opts.customLabel }
    function badge:setBadge(statusKey, customLabel)
        self._key = statusKey
        self._opts.label = customLabel
    end
    badge:initialise()
    badge.prerender = function(self)
        SemanticBadge.draw(self, 0, 0, self.width, self.height, self._key, self._opts)
    end
    return finishWidget(badge, opts, opts.owner)
end

---Creates a Zero-GC self-rendering InlineAlert banner panel.
---@param message string?
---@param kind "info"|"success"|"warning"|"danger"?
---@param opts table? { w, h, title, icon, assign, ... }
function UI.Alert(message, kind, opts)
    opts = opts or {}
    require("ISUI/ISPanel")
    local InlineAlert = require("EmberUI/Widgets/InlineAlert")
    local alert = ISPanel:new(0, 0, opts.w or opts.width or 260, opts.h or opts.height or 44)
    alert.background = false
    alert._opts = {
        type = kind or "info",
        message = message or "",
        title = opts.title,
        icon = opts.icon,
    }
    function alert:setAlert(msg, nextKind, title)
        self._opts.message = msg or ""
        if nextKind ~= nil then self._opts.type = nextKind end
        if title ~= nil then self._opts.title = title end
        self._opts.lines = nil
    end
    alert:initialise()
    alert.prerender = function(self)
        InlineAlert.draw(self, 0, 0, self.width, self.height, self._opts)
    end
    return finishWidget(alert, opts, opts.owner)
end

---Subscribes a State store to an owner's PageLifecycle (auto-gated by activationScope and auto-disposed).
---@param owner table Page or WindowHost with PageLifecycle scopes
---@param store table State store supporting :subscribe(fn) and .value
---@param callback fun(snapshot:table, changed:table?)
---@return function unsubscribe
function UI.bindStore(owner, store, callback)
    assert(owner and store and type(store.subscribe) == "function", "INVALID_BIND_STORE_ARGS")
    assert(type(callback) == "function", "INVALID_BIND_STORE_CALLBACK")
    local PageLifecycle = require("EmberUI/Core/PageLifecycle")
    local unsub = store:subscribe(function(snapshot, changed)
        if owner.disposed then return end
        if owner.activationScope and not owner.activationScope:isCurrent() then return end
        callback(snapshot, changed)
    end)
    if owner.activationScope and owner.activationScope:isCurrent() then
        owner.activationScope:own(unsub, function(fn) fn() end)
        callback(store.value, nil)
    else
        local lifetime = PageLifecycle.createLifetimeScope(owner)
        lifetime:defer(unsub)
    end
    return unsub
end

UI.validate = require("EmberUI/Widgets/FormValidator").validate
UI.createFilter = require("EmberUI/Widgets/ListFilter").new
UI.ScrollContainer = require("EmberUI/Widgets/ScrollContainer")
UI.ScrollView = require("EmberUI/Widgets/ScrollView")

function UI.showModal(opts)
    return require("EmberUI/Widgets/ModalDialog").show(opts)
end

setmetatable(UI, {
    __index = function(t, k)
        if k == "Modal" then
            local M = require("EmberUI/Widgets/ModalDialog")
            rawset(t, "Modal", M)
            return M
        elseif k == "WindowHost" then
            local W = require("EmberUI/Widgets/WindowHost")
            rawset(t, "WindowHost", W)
            return W
        end
    end
})


---Wraps an arbitrary vanilla or third-party ISUIElement for LayoutHost placement without rewriting it.
---@param element ISUIElement
---@param opts table? { w, h, detachAnchors, tooltip, ... }
function UI.Native(element, opts)
    assert(element ~= nil, "UI_NATIVE_ELEMENT_REQUIRED")
    opts = opts or {}
    if opts.w and element.setWidth then element:setWidth(opts.w) end
    if opts.h and element.setHeight then element:setHeight(opts.h) end
    if opts.detachAnchors == false then
        if opts.assign and opts.assign[1] and opts.assign[2] then
            opts.assign[1][opts.assign[2]] = element
        end
        local layoutProps
        for k, v in pairs(opts) do
            if LAYOUT_KEYS[k] then
                layoutProps = layoutProps or {}
                layoutProps[k] = v
            end
        end
        return layoutProps and UI.Item(element, layoutProps) or element
    end
    return finishWidget(element, opts, opts.owner)
end

---Creates an interactive draggable SplitView container.
---Automatically hosts UI.Row/UI.Column descriptors inside a LayoutHost pane when passed directly.
---@param firstPane any? ISUIElement or UI.Row/UI.Column descriptor
---@param secondPane any? ISUIElement or UI.Row/UI.Column descriptor
---@param opts table? { w, h, orientation, ratio, defaultRatio, minFirst, minSecond, handleSize, onRatioChange, ... }
function UI.SplitView(firstPane, secondPane, opts)
    opts = opts or {}
    local function resolvePane(pane)
        if not pane then return nil end
        if type(pane) == "table" and pane.isLayoutItemSpec then
            pane = pane.child
        end
        if type(pane) == "table" and pane.isLayoutSpec then
            local LayoutHost = require("EmberUI/Core/LayoutHost")
            local host = LayoutHost:new(0, 0, 200, 200, { direction = pane.type or "column" })
            host:initialise()
            host:instantiate()
            local handles, err = host:build(pane, opts.initialContext)
            assert(handles, err or "SPLITVIEW_PANE_BUILD_FAILED")
            return host
        end
        return pane
    end
    local SplitView = require("EmberUI/Widgets/SplitView")
    local splitOpts = copyShallow(opts)
    local p1 = resolvePane(firstPane or splitOpts.first)
    local p2 = resolvePane(secondPane or splitOpts.second)
    if p1 then splitOpts.first = p1 end
    if p2 then splitOpts.second = p2 end
    local sv = SplitView:new(0, 0, opts.w or opts.width or 480, opts.h or opts.height or 320, splitOpts)
    return finishWidget(sv, opts, opts.owner)
end

---Creates a BulkBar paired with PickSet.
---@param pickSet table
---@param opts table? { w, h, allIds, actions, onSelectAll, onClear, autoHide, ... }
function UI.BulkBar(pickSet, opts)
    opts = opts or {}
    local BulkBar = require("EmberUI/Widgets/BulkBar")
    local barOpts = copyShallow(opts)
    barOpts.pickSet = pickSet
    local bar = BulkBar:new(0, 0, opts.w or opts.width or 360, opts.h or opts.height or 34, barOpts)
    return finishWidget(bar, opts, opts.owner)
end

---Creates a declarative validated Field combining label + control + FormValidator feedback.
---@param opts table { label, type, value, rules, control, labelWidth, w, h, onChange, ... }
function UI.Field(opts)
    opts = opts or {}
    local Field = require("EmberUI/Widgets/Field")
    local f = Field:new(0, 0, opts.w or opts.width or 280, opts.h or opts.height, opts)
    return finishWidget(f, opts, opts.owner)
end

return UI
