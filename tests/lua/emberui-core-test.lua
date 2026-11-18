-- Standalone EmberUI Core/Widgets/Shell Test Suite (Zero host-mod dependencies).

local checks = 0
local function check(cond, msg)
    checks = checks + 1
    assert(cond, "CHECK_FAILED [" .. checks .. "]: " .. tostring(msg))
end

-- Stub PZ Kahlua globals / ISUI base classes
Keyboard = Keyboard or { KEY_ESCAPE = 1, KEY_TAB = 15, KEY_SPACE = 57, KEY_RETURN = 28, KEY_LEFT = 203, KEY_RIGHT = 205 }
Joypad = Joypad or { AButton = 0, BButton = 1 }
UIFont = UIFont or { Small = "Small", Medium = "Medium", Large = "Large" }

local uiList = {}
UIManager = {
    getMillisSinceLastRender = function() return 16 end,
    getUI = function() return uiList end,
}

local eatenKeys = {}
GameKeyboard = {
    eatKeyPress = function(k) eatenKeys[k] = (eatenKeys[k] or 0) + 1 end,
}

local eventHandlers = {}
local function makeEvent(name)
    eventHandlers[name] = {}
    return {
        Add = function(fn) eventHandlers[name][#eventHandlers[name] + 1] = fn end,
        Remove = function(fn)
            for i = #eventHandlers[name], 1, -1 do
                if eventHandlers[name][i] == fn then table.remove(eventHandlers[name], i) end
            end
        end,
        trigger = function(...)
            for i = 1, #eventHandlers[name] do eventHandlers[name][i](...) end
        end,
    }
end
Events = {
    OnMainMenuEnter = makeEvent("OnMainMenuEnter"),
    OnResolutionChange = makeEvent("OnResolutionChange"),
}

local screenW, screenH = 1280, 720
Core = {
    currentTextEntryBox = nil,
    UnfocusActiveTextEntryBox = function()
        if Core.currentTextEntryBox then
            Core.currentTextEntryBox:setDoingTextEntry(false)
            Core.currentTextEntryBox = nil
        end
    end,
}

local tm = {
    getFontHeight = function() return 14 end,
    MeasureStringX = function(_, _, s) return #(tostring(s or "")) * 7 end,
    MeasureStringY = function() return 14 end,
}
function getTextManager() return tm end
function getCore()
    return {
        getScreenWidth = function() return screenW end,
        getScreenHeight = function() return screenH end,
    }
end
function getTextOrNull() return nil end
function getTexture() return nil end

-- Minimal ISUI widget mocks faithful to PZ B42 new/initialise/instantiate contracts
local function makeBaseClass(name)
    local cls = {}
    cls.__index = cls
    cls.Type = name
    function cls:derive(sub)
        local d = {}
        d.__index = d
        d.Type = sub
        setmetatable(d, { __index = self })
        return d
    end
    function cls:new(x, y, w, h)
        local o = setmetatable({
            x = x or 0, y = y or 0, width = w or 100, height = h or 24,
            children = {}, visible = true, javaObject = nil, enable = true,
            wantKeyEvents = false, wantMouseEvents = true,
            borderColor = { r = 1, g = 1, b = 1, a = 1 },
            backgroundColor = { r = 0, g = 0, b = 0, a = 1 },
        }, self)
        return o
    end
    function cls:initialise() end
    function cls:createChildren() end
    function cls:instantiate()
        local obj = self
        self.javaObject = {
            getParent = function() return obj.parent and obj.parent.javaObject or nil end,
            setWantKeyEvents = function(_, v) obj.wantKeyEvents = v end,
            setConsumeMouseEvents = function(_, v) obj.wantMouseEvents = v end,
            isFocused = function() return obj._focused == true end,
            isDoingTextEntry = function() return obj._doingText == true end,
        }
        if self.createChildren then self:createChildren() end
    end
    function cls:getParent() return self.parent end
    function cls:addChild(c)
        self.children[#self.children + 1] = c
        c.parent = self
        if c.javaObject == nil and c.instantiate then c:instantiate() end
    end
    function cls:removeChild(c)
        for i = #self.children, 1, -1 do
            if self.children[i] == c then table.remove(self.children, i) end
        end
        if c.parent == self then c.parent = nil end
    end
    function cls:setX(v) self.x = v end
    function cls:setY(v) self.y = v end
    function cls:setWidth(v) self.width = v end
    function cls:setHeight(v) self.height = v end
    function cls:getX() return self.x end
    function cls:getY() return self.y end
    function cls:getWidth() return self.width end
    function cls:getHeight() return self.height end
    function cls:getAbsoluteX() return (self.parent and self.parent:getAbsoluteX() or 0) + (self.x or 0) end
    function cls:getAbsoluteY() return (self.parent and self.parent:getAbsoluteY() or 0) + (self.y or 0) end
    function cls:setVisible(v) self.visible = v == true end
    function cls:isVisible() return self.visible ~= false end
    function cls:getIsVisible() return self.visible ~= false end
    function cls:isMouseOver() return false end
    function cls:getMouseX() return 0 end
    function cls:getMouseY() return 0 end
    function cls:setWantKeyEvents(v) self.wantKeyEvents = v == true end
    function cls:setWantMouseEvents(v) self.wantMouseEvents = v == true end
    function cls:setAlwaysOnTop(v) self.alwaysOnTop = v == true end
    function cls:bringToTop() end
    function cls:setCapture() end
    function cls:addToUIManager()
        for i = 1, #uiList do if uiList[i] == self then return end end
        uiList[#uiList + 1] = self
    end
    function cls:removeFromUIManager()
        for i = #uiList, 1, -1 do if uiList[i] == self then table.remove(uiList, i) end end
    end
    function cls:drawRect() end
    function cls:drawRectBorder() end
    function cls:drawText() end
    function cls:drawTextureScaled() end
    function cls:drawTextureScaledAspect() end
    function cls:setStencilRect() end
    function cls:clearStencilRect() end
    function cls:titleBarHeight() return 24 end
    function cls:resizeWidgetHeight() return 10 end
    function cls:onResize() end
    function cls:prerender() end
    function cls:render() end
    function cls:update() end
    return cls
end

local Base = makeBaseClass("ISUIElement")
ISUIElement = Base
ISPanel = Base:derive("ISPanel")
ISCollapsableWindow = Base:derive("ISCollapsableWindow")
ISButton = Base:derive("ISButton")
function ISButton:new(x, y, w, h, title, target, onclick)
    local o = Base.new(self, x, y, w, h)
    o.title = title; o.target = target; o.onclick = onclick
    function o:setEnable(e) self.enable = e end
    function o:setTitle(t) self.title = t end
    return o
end
ISTextEntryBox = Base:derive("ISTextEntryBox")
function ISTextEntryBox:new(text, x, y, w, h)
    local o = Base.new(self, x, y, w, h)
    o._text = text or ""
    o._textRGBA = { 1, 1, 1, 1 }
    function o:getText() return self._text end
    function o:setText(v) self._text = tostring(v or "") end
    function o:setPlaceholderText(v) self._placeholder = v end
    function o:setTextRGBA(r, g, b, a) self._textRGBA = { r, g, b, a } end
    function o:setPlaceholderTextRGBA(r, g, b, a) self._phRGBA = { r, g, b, a } end
    function o:setOnlyNumbers(v) self._onlyNumbers = v end
    function o:setMaxTextLength(v) self._maxLen = v end
    function o:setEditable(v) self._editable = v end
    function o:setClearButton(v) self._clearBtn = v end
    function o:setDoingTextEntry(v) self._doingText = v == true; self._focused = v == true end
    function o:unfocus() self._focused = false; self._doingText = false; if Core.currentTextEntryBox == self then Core.currentTextEntryBox = nil end end
    function o:focus() self._focused = true; self._doingText = true; Core.currentTextEntryBox = self end
    return o
end
ISComboBox = Base:derive("ISComboBox")
function ISComboBox:new(x, y, w, h, target, onChange)
    local o = Base.new(self, x, y, w, h)
    o.options = {}; o.target = target; o.onChange = onChange
    function o:addOption(t) self.options[#self.options + 1] = t end
    function o:clear() self.options = {} end
    return o
end
ISScrollingListBox = Base:derive("ISScrollingListBox")
function ISScrollingListBox:new(x, y, w, h)
    local o = Base.new(self, x, y, w, h)
    o.items = {}; o.count = 0; o.itemheight = 24; o.selected = 0; o.yScroll = 0; o.scrollHeight = 0
    function o:clear() self.items = {}; self.count = 0; self.scrollHeight = 0 end
    function o:getYScroll() return self.yScroll end
    function o:setYScroll(v) self.yScroll = v end
    function o:getScrollHeight() return self.scrollHeight end
    function o:setScrollHeight(v) self.scrollHeight = v end
    function o:addItem(text, item, tooltip)
        local e = { text = text, item = item, tooltip = tooltip, height = self.itemheight, index = #self.items + 1, itemindex = #self.items + 1 }
        self.items[#self.items + 1] = e
        self.count = #self.items
        self.scrollHeight = self.scrollHeight + self.itemheight
        return e
    end
    return o
end
ISTickBox = Base:derive("ISTickBox")
function ISTickBox:new(x, y, w, h)
    local o = Base.new(self, x, y, w, h)
    o.options = {}; o.selected = {}
    function o:addOption(l, d) self.options[#self.options + 1] = { label = l, data = d }; return #self.options end
    function o:setSelected(i, v) self.selected[i] = v end
    function o:isSelected(i) return self.selected[i] == true end
    return o
end

ISScrollBar = Base:derive("ISScrollBar")
package.loaded["ISUI/ISUIElement"] = true
package.loaded["ISUI/ISPanel"] = true
package.loaded["ISUI/ISCollapsableWindow"] = true
package.loaded["ISUI/ISButton"] = true
package.loaded["ISUI/ISTextEntryBox"] = true
package.loaded["ISUI/ISComboBox"] = true
package.loaded["ISUI/ISScrollingListBox"] = true
package.loaded["ISUI/ISScrollBar"] = true
package.loaded["ISUI/ISTickBox"] = true

-- 1. Load top-level EmberUI facade and verify zero host-mod leakage
local EmberUI = require "EmberUI"
check(EmberUI and EmberUI.VERSION == "1.1.0", "EmberUI top-level facade loads with VERSION 1.1.0")
for k in pairs(package.loaded) do
    check(not tostring(k):find("EmberRoutes"), "Zero EmberRoutes modules loaded: " .. tostring(k))
end

-- 2. Clock + Zero-GC Theme in-place mutation + Chrome SPI
local nowVal = 1000
EmberUI.Core.Clock.setProvider(function() return nowVal end)
check(EmberUI.Core.Clock.nowMs() == 1000, "Core Clock custom provider works")

local windowColorRef = EmberUI.Theme.window
EmberUI.Theme.applyPreset("ae2")
check(EmberUI.Theme.window == windowColorRef and windowColorRef.b > windowColorRef.r, "Theme.applyPreset mutates color table in-place without breaking cached references")
EmberUI.Theme.applyPreset("github")

local customCalls = 0
local spyBackend = {
    caps = { name = "spy-gl", roundedRect = true, pill = true, shadow = true, titleBar = true, vector = true, roundedClip = true },
    roundedRect = function() customCalls = customCalls + 1 end,
}
EmberUI.Chrome.registerBackend(spyBackend)
check(EmberUI.Chrome.getCaps().vector == true, "Chrome RenderBackend SPI exposes custom caps")
EmberUI.Chrome.roundedRect({}, 0, 0, 100, 40, { r = 1, g = 1, b = 1, a = 1 })
check(customCalls == 1, "Chrome RenderBackend SPI receives draw call")
EmberUI.Chrome.registerBackend(nil)

-- 3. P0 ToastManager: tight bounds, non-occluding, auto-unmounts on clear/expire
local Toast = EmberUI.Widgets.ToastManager
Toast.reset()
check(#uiList == 0, "ToastManager does not mount before push")
Toast.info("Hello toast", 1000)
local toastInst = Toast.getInstance()
check(Toast.isActive() and toastInst:getWidth() < 400 and toastInst:getHeight() < 120, "ToastManager uses tight bounding box instead of full-screen overlay")
check(toastInst:isPointOver(100, 100) == false and toastInst:isMouseOver() == false, "ToastManager never blocks hover/mouse underneath")
nowVal = 2500
toastInst:prerender()
check(not Toast.isActive() and #uiList == 0, "ToastManager auto-unmounts from UIManager once last toast expires")

-- 4. P0 HoverCard: non-occluding and unmounts cleanly
local HoverCard = EmberUI.HoverCard
local prep = HoverCard.show("owner1", { title = "VeryLongHeaderTitleThatShouldTruncateCleanly", badge = { label = "OK" }, body = "Body text" }, 100, 100)
check(prep ~= nil and prep.width <= 320, "HoverCard.show prepares within maxWidth")
HoverCard.hide("owner1")
check(HoverCard.getCurrent() == nil, "HoverCard.hide clears current owner")

-- 5. P0 WindowHost & FocusManager: wantKeyEvents + isKeyConsumed + eatKeyPress + unfocusTree + Cordis Scope Bridge
local win = EmberUI.WindowHost:new(10, 10, 420, 280, { title = "TestWin" })
win:initialise(); win:instantiate(); win:addToUIManager()
check(win.wantKeyEvents == true, "WindowHost enables wantKeyEvents for B42 UIManager key routing")
local entryRef = nil
local handles = win:setContentSpec(EmberUI.UI.Column({ padding = 8, gap = 6 }, {
    EmberUI.UI.TextInput("abc", win, nil, { assign = { { }, "tmp" }, h = 24, focusGroup = win }),
}))
check(handles ~= nil, "WindowHost mounts TextInput")
-- Focus entry inside window and test ESC unfocuses entry + eats key instead of closing window immediately when UITextBox2 handles ESC
local txt = win.contentHost._leafItems[1].target
entryRef = txt
txt:focus()
check(Core.currentTextEntryBox == txt, "TextInput gained Core focus")
txt:onOtherKey(Keyboard.KEY_ESCAPE)
check(Core.currentTextEntryBox == nil and (eatenKeys[Keyboard.KEY_ESCAPE] or 0) >= 1, "FocusManager.bindTextEntry unfocuses on ESC and calls GameKeyboard.eatKeyPress")
-- Now pressing ESC on WindowHost consumes key and closes window
local prevEat = eatenKeys[Keyboard.KEY_ESCAPE] or 0
check(win:onKeyPress(Keyboard.KEY_ESCAPE) == true, "WindowHost onKeyPress consumes ESC")
check(win:isKeyConsumed(Keyboard.KEY_ESCAPE) == true, "WindowHost isKeyConsumed reports true for ESC")
check((eatenKeys[Keyboard.KEY_ESCAPE] or 0) > prevEat and win.disposed == true, "WindowHost ESC eats key and disposes window")

-- Bidirectional Cordis Scope Bridge test
local extDisposed = 0
local extCleanups = {}
local fakeCordisScope = {
    effect = function(_, fn)
        local clean = fn()
        if type(clean) == "function" then extCleanups[#extCleanups + 1] = clean end
    end,
    dispose = function(self)
        if self._done then return end
        self._done = true
        extDisposed = extDisposed + 1
        for i = #extCleanups, 1, -1 do extCleanups[i]() end
    end,
}
local winScopeA = EmberUI.WindowHost:new(0, 0, 300, 200, { title = "ScopeA", scope = fakeCordisScope })
winScopeA:initialise(); winScopeA:instantiate()
winScopeA:close()
check(extDisposed == 1, "Closing WindowHost disposes attached Cordis scope once (zero loop)")

local fakeCordisScope2 = {
    effect = function(_, fn)
        local clean = fn()
        if type(clean) == "function" then _G.__sc2Clean = clean end
    end,
    dispose = function(self)
        if self._done then return end
        self._done = true
        if _G.__sc2Clean then _G.__sc2Clean() end
    end,
}
local winScopeB = EmberUI.WindowHost:new(0, 0, 300, 200, { title = "ScopeB", scope = fakeCordisScope2 })
winScopeB:initialise(); winScopeB:instantiate()
fakeCordisScope2:dispose()
check(winScopeB.disposed == true, "Disposing external Cordis scope automatically closes bound WindowHost")
_G.__sc2Clean = nil

-- 6. P1 LayoutHost 0-frame prerender flush (works even when paused without UIManager.doTick)
local winFlush = EmberUI.WindowHost:new(0, 0, 400, 240, { title = "FlushWin" })
winFlush:initialise(); winFlush:instantiate()
local dynRect = EmberUI.UI.Rect()
local hFlush = winFlush:setContentSpec(EmberUI.UI.Column({ padding = 8, gap = 4 }, {
    EmberUI.UI.Item(dynRect, { key = "dyn", basis = 24, grow = 1 }),
}))
winFlush.contentHost:setItemVisible(hFlush.dyn, false)
check(winFlush.contentHost.rootNode.dirty == true, "setItemVisible marks layout dirty")
winFlush.contentHost:prerender() -- Simulates render frame while game is paused (update() not called)
check(winFlush.contentHost.rootNode.dirty == false and dynRect.visible == false, "LayoutHost:prerender flushes dirty geometry in 0 frames")
winFlush:close()

-- 7. P1 Runtime OnMainMenuEnter & OnResolutionChange
local winRes = EmberUI.WindowHost:new(1000, 500, 400, 300, { title = "ResWin" })
winRes:initialise(); winRes:instantiate(); winRes:addToUIManager()
local modal = EmberUI.Widgets.ModalDialog.show({ title = "Confirm", message = "Proceed?" })
check(modal.wantKeyEvents == true and modal:isKeyConsumed(Keyboard.KEY_ESCAPE) == true, "ModalDialog consumes ESC cleanly")
screenW, screenH = 800, 600
events_res = Events.OnResolutionChange
events_res.trigger(1280, 720, 800, 600)
check(winRes.x + winRes.width <= 800 and modal.width == 800 and modal.cardX == math.floor((800 - modal.cardWidth) / 2), "OnResolutionChange clamps WindowHost and recenters ModalDialog")
Events.OnMainMenuEnter.trigger()
check(winRes.disposed == true and modal.disposed == true and #uiList == 0, "OnMainMenuEnter tears down all active WindowHost/ModalDialog surfaces cleanly")

-- 8. Field (including Stepper fix!), SplitView, PickSet + BulkBar, CachedList.reconcile, OrderList
local stepperField = EmberUI.Widgets.Field:new(0, 0, 320, 48, {
    label = "Target Stock",
    type = "stepper",
    value = 12,
    min = 1,
    max = 99,
    rules = { required = true, type = "number", min = 5 },
})
stepperField:instantiate()
check(stepperField:getValue() == 12 and stepperField:validate() == true, "Field(type='stepper') initializes StepperInput with proper steps & validates")
stepperField.control:setValue(2)
stepperField:setValue(2, false)
check(stepperField:validate() == false and stepperField.errorText ~= nil, "Field(type='stepper') reports validation error below min")

local cachedList = EmberUI.UI.List({ w = 240, h = 180 })
local rows1 = { { id = "a", count = 5 }, { id = "b", count = 10 } }
EmberUI.Widgets.CachedList.reconcile(cachedList, rows1, function(r) return r.id .. ":" .. r.count end, function(r) return r.id end, true, 1)
local itemsRef = cachedList.items
local rows2 = { { id = "a", count = 8 }, { id = "b", count = 10 } }
EmberUI.Widgets.CachedList.reconcile(cachedList, rows2, function(r) return r.id .. ":" .. r.count end, function(r) return r.id end, true, 2)
check(cachedList.items == itemsRef and cachedList.items[1].text == "a:8", "CachedList.reconcile updates non-structural count changes in-place without reallocating items array")

local ol = EmberUI.OrderList:new(0, 0, 260, 140, { items = { "One", "Two", "Three" } })
ol:prerender()
check(ol:moveItem(1, 3) and ol.items[3] == "One", "OrderList renders via static Viewport.draw and reorders items")

local sv = EmberUI.SplitView:new(0, 0, 500, 300, { ratio = 0.4, minFirst = 100, minSecond = 150, first = ISPanel:new(0, 0, 100, 100), second = ISPanel:new(0, 0, 100, 100) })
sv:syncBounds()
check(sv.firstPane.width >= 100 and sv.secondPane.width >= 150, "SplitView enforces min constraints")

local picks = EmberUI.PickSet.new()
picks:add("x"); picks:add("y")
local bb = EmberUI.BulkBar:new(0, 0, 400, 34, { pickSet = picks, allIds = { "x", "y", "z" }, actions = { { id = "act", label = "Go" } } })
bb:instantiate()
check(bb.lastCount == 2 and bb:isVisible() == true and bb.clearButton.emberPrimary == false, "BulkBar syncs count and renders Clear button as non-primary")

-- 9. SlotRegistry: static slots survive clearCapabilities() on session reset
local Slots = EmberUI.SlotRegistry
Slots.clear()
local s1 = Slots.register({ id = "demo.tab", slot = "nav.tabs", requires = { "svc.ready" } })
Slots.provideCapability("svc.ready", true)
check(#Slots.resolve("nav.tabs") == 1, "Slot resolves when capability active")
Slots.clearCapabilities()
check(#Slots.resolve("nav.tabs") == 0 and Slots.get("demo.tab") ~= nil, "clearCapabilities hides gated slot on menu exit while preserving static declaration")
s1:release()

print("PASS " .. checks .. " standalone EmberUI v1.1.0 checks")
