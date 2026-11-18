-- LayoutHostLifecycle.lua - EmberUI Core
-- Host lifecycle: activation, visibility handles, debouncer registry,
-- 0-frame prerender geometry flush (bypassing B42's 100ms UIManager.doTick throttle
-- and functioning while paused), per-tick update, disposal with reverse leaf release,
-- and conditional (when / UI.Show) visibility sync.
local S = require 'EmberUI/Core/LayoutHostShared'
local Clock = require 'EmberUI/Core/Clock'
local release = S.release
local detach = S.detach

---@param Host EmberRoutesLayoutHost
local function attach(Host)

function Host:setItemVisible(handle, visible)
    assert(not self.closed and not self.closing, 'HOST_CLOSED')
    assert(handle and handle.host == self and handle.item, 'INVALID_LAYOUT_HANDLE')
    assert(handle.item.owner and handle.item.owner.root == self.rootNode, 'STALE_LAYOUT_HANDLE')
    assert(type(visible) == 'boolean', 'INVALID_VISIBILITY')
    if handle.item.visible == visible then return true end

    handle.item.owner:setItemVisible(handle.item, visible)
    if not visible then
        if handle.kind == 'native' then handle.target:setVisible(false)
        elseif handle.kind == 'rect' then handle.target.visible = false end
    end
    self:requestLayout()
    return true
end

function Host:deactivate()
    self.scope = false
    for i = 1, #self._leafItems do
        local e = self._leafItems[i]
        if e.kind == 'native' and e.target and type(e.target.deactivate) == 'function' then
            pcall(e.target.deactivate, e.target)
        end
    end
end

function Host:setActivation(scope)
    assert(not self.closed and not self.closing and not self._pending
        and not self._building and not self._buildPending, 'HOST_NOT_READY')
    assert(scope and scope:isCurrent(), 'INVALID_ACTIVATION')
    self.scope = scope
    self.sealed = true
    self.failedSolveRevision = -1
    self.failedApplyRevision = -1
    self.appliedRevision = -1
    for i = 1, #self._leafItems do
        local e = self._leafItems[i]
        if e.kind == 'native' and e.target and type(e.target.setActivation) == 'function' then
            pcall(e.target.setActivation, e.target, scope)
        end
    end
    return self:resolveLayout()
end

function Host:isActivationValid()
    return not self.closed and not self.closing and not self._building
        and not self._buildPending and self.scope and self.scope:isCurrent()
end

function Host:_tickDebouncers(now)
    local ds = self._debouncers
    if not ds or #ds == 0 then return end
    now = now or Clock.nowMs()
    for i = 1, #ds do
        ds[i]:tick(now)
    end
end

function Host:registerDebouncer(d)
    assert(d and type(d.tick) == 'function', 'INVALID_DEBOUNCER')
    self._debouncers = self._debouncers or {}
    for i = 1, #self._debouncers do
        if self._debouncers[i] == d then return end
    end
    self._debouncers[#self._debouncers + 1] = d
end

function Host:unregisterDebouncer(d)
    if not self._debouncers then return end
    for i = 1, #self._debouncers do
        if self._debouncers[i] == d then
            table.remove(self._debouncers, i)
            return
        end
    end
end

local function stepHostFrame(self)
    if not self.closed and not self.closing then
        self:_tickDebouncers()
        if self:isActivationValid() then
            if self._layoutRequested or self.rootNode.dirty then
                self:flushLayout()
            end
        end
    end
end

---Flushes dirty layout BEFORE UIElement.render() iterates child controls,
---eliminating B42's 100ms UIManager.doTick latency and updating cleanly while paused.
function Host:prerender()
    stepHostFrame(self)
    ISPanel.prerender(self)
end

function Host:update()
    ISPanel.update(self)
    stepHostFrame(self)
end

function Host:dispose()
    if self.closed then return true end
    if self._building then return nil, 'BUILD_IN_PROGRESS' end
    self.closing = true
    self.scope = false
    local failed = false
    if self._buildPending then
        local ok, err = self:_rollbackBuild()
        if not ok then failed = err end
    end
    if self._pending then
        local ok, err = pcall(release, self, self._pending, true)
        if ok then self._pending = false else failed = err end
    end
    for i = #self._leafItems, 1, -1 do
        local ok, err = pcall(release, self, self._leafItems[i], false)
        if ok then table.remove(self._leafItems, i) else failed = err end
    end
    if failed then self.errorStage = 'CLEANUP_PENDING'; self.errorMessage = failed; return nil, failed end
    local parent = self:getParent()
    if parent then
        local ok, err = pcall(detach, parent, self)
        if not ok then self.errorStage = 'CLEANUP_PENDING'; self.errorMessage = err; return nil, err end
    end
    self.rootNode:dispose()
    self._boundSnapshots = {}
    self._conditionals = {}
    if self._debouncers then
        for i = 1, #self._debouncers do
            self._debouncers[i]:cancel()
        end
        self._debouncers = {}
    end
    self._autoBasisItems = {}
    self._layoutRequested = false
    self.closed = true
    self.closing = false
    self.errorStage = false
    self.errorMessage = false
    self.errorSlot = false
    self.errorSetter = false
    return true
end

function Host:syncVisibility(context)
    assert(not self.closed and not self.closing, 'HOST_CLOSED')
    local conds = self._conditionals
    if not conds or #conds == 0 then return true end
    for i = 1, #conds do
        local c = conds[i]
        local visible = false
        if type(c.when) == 'function' then
            visible = c.when(context) == true
        elseif type(c.when) == 'boolean' then
            visible = c.when
        end
        self:setItemVisible(c.handle, visible)
    end
    return true
end

end

return attach
