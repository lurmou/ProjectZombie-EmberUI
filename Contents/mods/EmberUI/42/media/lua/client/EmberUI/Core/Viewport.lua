-- Native stencil scope for custom canvases. Content coordinates remain intact:
-- partially visible text/icons are submitted and clipped by the renderer.
-- Supports passing an explicit `arg` (defaulting to `owner`) into `draw` so
-- callers can pass static methods without per-frame closure allocations.
local Failsafe = require "EmberUI/Core/Failsafe"

local Viewport = {}

function Viewport.draw(owner, bounds, draw, arg)
    local native = owner.setStencilRect and owner.clearStencilRect
    if native then owner:setStencilRect(bounds.x, bounds.y, bounds.width, bounds.height) end
    local targetArg = arg ~= nil and arg or owner
    local ok, result = pcall(draw, targetArg)
    if native then
        owner:clearStencilRect()
        if owner.doRepaintStencil and owner.repaintStencilRect then
            owner:repaintStencilRect(bounds.x, bounds.y, bounds.width, bounds.height)
        end
    end
    if not ok then error(result) end
    return result
end

---Guarded stencil scope: isolates callback failures into Failsafe without leaving stencil dirty.
function Viewport.drawGuarded(owner, bounds, guardKey, draw, fallbackTitle, arg)
    if Failsafe.hasFailed(guardKey) then
        Failsafe.drawFallback(owner, bounds.x, bounds.y, bounds.width, bounds.height, guardKey, fallbackTitle)
        return false
    end
    local native = owner.setStencilRect and owner.clearStencilRect
    if native then owner:setStencilRect(bounds.x, bounds.y, bounds.width, bounds.height) end
    local targetArg = arg ~= nil and arg or owner
    local ok, result = Failsafe.guard(guardKey, draw, targetArg)
    if native then
        owner:clearStencilRect()
        if owner.doRepaintStencil and owner.repaintStencilRect then
            owner:repaintStencilRect(bounds.x, bounds.y, bounds.width, bounds.height)
        end
    end
    if not ok then
        Failsafe.drawFallback(owner, bounds.x, bounds.y, bounds.width, bounds.height, guardKey, fallbackTitle)
        return false
    end
    return true, result
end

function Viewport.install(panel)
    local original = panel.prerender
    local cachedBounds = { x = 0, y = 0, width = 0, height = 0 }
    panel.prerender = function(self)
        cachedBounds.width = self.width
        cachedBounds.height = self.height
        return Viewport.draw(self, cachedBounds, original, self)
    end
end

return Viewport
