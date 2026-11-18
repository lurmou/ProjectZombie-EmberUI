-- EmberUI Lifecycle & Dual Scope Infrastructure (+ Cordis Kernel Scope Bridge)
--
-- Responsibilities:
-- 1. Dual Scope Architecture:
--    - PageLifetimeScope (instance level): lives from page creation until page disposal.
--    - ActivationScope (viewport session level): lives from page activation to page deactivation.
-- 2. Explicit Disposer Protocol: own(resource, disposer) requires an explicit disposer function.
-- 3. Idempotent cleanup handles & LIFO error-isolated disposal.
-- 4. Stale token rejection via wrapCallback.
-- 5. Bidirectional External Scope Bridge (`attachExternalScope`) for Cordis micro-kernels
--    (e.g. EmberRoutesV2 `ctx:scope(label)`): closing the UI disposes `extScope`, and
--    tearing down `extScope` from root session disposal closes the UI without re-entrancy loops.

local Lifecycle = {}
local TooltipManager = require 'EmberUI/Core/TooltipManager'

local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        print("[PageLifecycle] Error during resource release: " .. tostring(err))
    end
    return ok, err
end

local function releaseEntry(entry)
    if not entry or entry.released then return end
    entry.released = true

    local entryType = entry.type
    local fn = entry.fn
    local resource = entry.resource

    entry.fn = nil
    entry.resource = nil

    if entryType == "resource" then
        safeCall(fn, resource)
    else
        safeCall(fn)
    end
end

local function makeHandle(entry)
    local handle = {}
    setmetatable(handle, {
        __call = function(t) t:release() end,
    })
    function handle:release()
        releaseEntry(entry)
    end
    return handle
end

----------------------------------------------------------------
-- PageLifetimeScope (Page Instance Lifetime)
----------------------------------------------------------------

---@class EmberRoutesLifetimeScope
local LifetimeScope = {}
LifetimeScope.__index = LifetimeScope

function LifetimeScope.new(page)
    return setmetatable({
        page = page,
        disposed = false,
        entries = {},
    }, LifetimeScope)
end

function LifetimeScope:isDisposed()
    return self.disposed == true or (self.page ~= nil and self.page.disposed == true)
end

function LifetimeScope:own(resource, disposer)
    assert(type(disposer) == "function", "PageLifetimeScope:own requires an explicit disposer function")
    if resource == nil then
        return { release = function() end }
    end
    if self:isDisposed() then
        safeCall(disposer, resource)
        return { release = function() end }
    end

    local entry = {
        type = "resource",
        resource = resource,
        fn = disposer,
        released = false,
    }
    self.entries[#self.entries + 1] = entry
    return makeHandle(entry)
end

function LifetimeScope:defer(cleanupFn)
    assert(type(cleanupFn) == "function", "PageLifetimeScope:defer requires a cleanup function")
    if self:isDisposed() then
        safeCall(cleanupFn)
        return { release = function() end }
    end

    local entry = {
        type = "cleanup",
        fn = cleanupFn,
        released = false,
    }
    self.entries[#self.entries + 1] = entry
    return makeHandle(entry)
end

function LifetimeScope:dispose()
    if self.disposed then return end
    self.disposed = true

    local page = self.page
    if page then
        page.disposed = true
        if page.activationScope and not page.activationScope.disposed then
            page.activationScope:dispose()
        end
    end

    local entries = self.entries
    for i = #entries, 1, -1 do
        releaseEntry(entries[i])
    end
    self.entries = {}

    if page then
        TooltipManager.unregisterOwner(page)
    end
end

----------------------------------------------------------------
-- ActivationScope (Viewport Session Lifetime)
----------------------------------------------------------------

---@class EmberRoutesActivationScope
local ActivationScope = {}
ActivationScope.__index = ActivationScope

function ActivationScope.new(page)
    local token = {}
    page.active = true
    page.activation = token
    return setmetatable({
        page = page,
        token = token,
        active = true,
        disposed = false,
        entries = {},
    }, ActivationScope)
end

function ActivationScope:isCurrent()
    return self.active == true
        and not self.disposed
        and self.page ~= nil
        and self.page.active == true
        and self.page.activation == self.token
        and not self.page.disposed
end

function ActivationScope:wrapCallback(fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        if not self:isCurrent() then return end
        return fn(...)
    end
end

function ActivationScope:own(resource, disposer)
    assert(type(disposer) == "function", "ActivationScope:own requires an explicit disposer function")
    if resource == nil then
        return { release = function() end }
    end
    if not self:isCurrent() then
        safeCall(disposer, resource)
        return { release = function() end }
    end

    local entry = {
        type = "resource",
        resource = resource,
        fn = disposer,
        released = false,
    }
    self.entries[#self.entries + 1] = entry
    return makeHandle(entry)
end

function ActivationScope:defer(cleanupFn)
    assert(type(cleanupFn) == "function", "ActivationScope:defer requires a cleanup function")
    if not self:isCurrent() then
        safeCall(cleanupFn)
        return { release = function() end }
    end

    local entry = {
        type = "cleanup",
        fn = cleanupFn,
        released = false,
    }
    self.entries[#self.entries + 1] = entry
    return makeHandle(entry)
end

function ActivationScope:subscribe(store, projectFn)
    if not store or type(store.subscribe) ~= "function" then
        return { release = function() end }
    end
    if not self:isCurrent() then
        return { release = function() end }
    end

    local wrappedProject = self:wrapCallback(projectFn)
    local unsubscribe = store:subscribe(wrappedProject)
    if type(unsubscribe) == "function" then
        return self:defer(unsubscribe)
    end
    return { release = function() end }
end

function ActivationScope:watch(watchFn, receiveFn, guardFn)
    if type(watchFn) ~= "function" then
        return nil, "INVALID_WATCH_FN"
    end
    if not self:isCurrent() then
        return nil, "SCOPE_NOT_CURRENT"
    end

    local wrappedReceive = self:wrapCallback(function(snapshot)
        if guardFn then
            local ok = guardFn(self.page, snapshot)
            if ok == false then return end
        end
        if receiveFn then
            receiveFn(snapshot)
        end
    end)

    local release, reason = watchFn(wrappedReceive)

    if not self:isCurrent() then
        if type(release) == "function" then
            safeCall(release)
        end
        return nil, reason
    end

    if type(release) == "function" then
        self:defer(release)
    elseif release == nil and receiveFn then
        receiveFn({ state = "ERROR", rows = {}, counts = {}, reason = reason })
    end

    return release, reason
end

function ActivationScope:bindStore(store, callback)
    if not store or type(callback) ~= "function" then
        return { release = function() end }
    end
    local guarded = self:wrapCallback(callback)
    local unsub = self:subscribe(store, guarded)
    if self:isCurrent() and store.value ~= nil then
        guarded(store.value, nil)
    end
    return unsub
end

function ActivationScope:bindTheme(themeModule, callback)
    if not themeModule or type(themeModule.watch) ~= "function" or type(callback) ~= "function" then
        return { release = function() end }
    end
    local guarded = self:wrapCallback(callback)
    local unwatch = themeModule.watch(guarded)
    local handle = self:own(unwatch, function(fn) fn() end)
    if self:isCurrent() then
        guarded(themeModule.revision or 0)
    end
    return handle
end

function ActivationScope:dispose()
    if self.disposed then return end
    self.disposed = true
    self.active = false

    local page = self.page
    if page then
        page.active = false
        page.activation = nil
        TooltipManager.dismissOwner(page)
    end

    local entries = self.entries
    for i = #entries, 1, -1 do
        releaseEntry(entries[i])
    end
    self.entries = {}

    if page and page.activationScope == self then
        page.activationScope = nil
    end
end

----------------------------------------------------------------
-- Factory, Cordis Bridge & Facade API
----------------------------------------------------------------

function Lifecycle.createLifetimeScope(page)
    if not page then return nil end
    if page.disposed then return nil end

    local existing = page.lifetimeScope
    if existing then
        if not existing.disposed then
            return existing
        else
            print("[PageLifecycle] Error: attempted to create LifetimeScope for page with disposed scope")
            return nil
        end
    end

    local scope = LifetimeScope.new(page)
    page.lifetimeScope = scope
    return scope
end

function Lifecycle.createActivationScope(page)
    if not page or page.active or page.disposed then return nil end
    local scope = ActivationScope.new(page)
    page.activationScope = scope
    return scope
end

---Bidirectionally links a Cordis-style external scope (e.g. `ctx:scope(label)` with
---`:dispose()` and optional `:effect(fn)` / `:defer(fn)`) to `page`'s LifetimeScope:
---1. Closing/disposing `page` automatically calls `extScope:dispose()`.
---2. Disposing `extScope` externally (e.g. session `OnMainMenuEnter`) automatically closes `page`.
---@param page table
---@param extScope table?
---@return table handle
function Lifecycle.attachExternalScope(page, extScope)
    if not page or type(extScope) ~= "table" then
        return { release = function() end }
    end
    local life = Lifecycle.createLifetimeScope(page)
    if not life then
        if type(extScope.dispose) == "function" then
            safeCall(extScope.dispose, extScope)
        end
        return { release = function() end }
    end

    local closed = false
    local function closeFromExternal()
        if closed then return end
        closed = true
        if not page.disposed then
            if type(page.close) == "function" then
                safeCall(page.close, page)
            else
                Lifecycle.dispose(page)
            end
        end
    end

    local function disposeExternal()
        if closed then return end
        closed = true
        if type(extScope.dispose) == "function" then
            safeCall(extScope.dispose, extScope)
        elseif type(extScope.release) == "function" then
            safeCall(extScope.release, extScope)
        end
    end

    if type(extScope.effect) == "function" then
        extScope:effect(function()
            return closeFromExternal
        end)
    elseif type(extScope.defer) == "function" then
        extScope:defer(closeFromExternal)
    end

    page.externalScope = extScope
    return life:defer(disposeExternal)
end

function Lifecycle.dispose(page)
    if not page then return end

    local lifetime = page.lifetimeScope
    if lifetime then
        if not lifetime.disposed then
            lifetime:dispose()
        end
        return
    end

    if page.activationScope then
        if not page.activationScope.disposed then
            page.activationScope:dispose()
        end
    elseif page.active then
        Lifecycle.unmount(page)
    end

    page.disposed = true
    TooltipManager.unregisterOwner(page)
end

function Lifecycle.mount(page, watch, receive)
    if not page or page.active or page.disposed then return false end
    local scope = Lifecycle.createActivationScope(page)
    if not scope then return false end

    if page.store and page.project then
        page.unsubscribe = scope:subscribe(page.store, function(value, changed)
            page:project(value, changed)
        end)
    end

    local release = scope:watch(watch, receive, function(p)
        if p.owner and type(p.owner.valid) == "function" and not p.owner:valid() then
            if type(p.owner.close) == "function" then p.owner:close() end
            return false
        end
        return true
    end)

    page.release = release
    return true
end

function Lifecycle.unmount(page)
    if not page then return end

    local scope = page.activationScope
    local oldRelease = page.release
    local oldUnsubscribe = page.unsubscribe

    page.release = nil
    page.unsubscribe = nil

    if scope then
        scope:dispose()
    else
        page.active = false
        page.activation = nil
        if oldUnsubscribe then
            if type(oldUnsubscribe) == "table" and type(oldUnsubscribe.release) == "function" then
                oldUnsubscribe:release()
            elseif type(oldUnsubscribe) == "function" then
                safeCall(oldUnsubscribe)
            end
        end
        if oldRelease then
            if type(oldRelease) == "table" and type(oldRelease.release) == "function" then
                oldRelease:release()
            elseif type(oldRelease) == "function" then
                safeCall(oldRelease)
            end
        end
        TooltipManager.dismissOwner(page)
    end
end

return Lifecycle
