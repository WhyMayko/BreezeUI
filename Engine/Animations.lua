-- Library/BreezeUI/Engine/Animations.lua
-- Threadless exponential decay animation engine and adaptive FPS sleep throttling.

local Animations = {
    ActiveAnimations = {},
    _targets = {},
    TargetFPS = 20,
    IdleTimer = 0,
    IdleTimeout = 1.0,
    CurrentFocusedWidget = nil,
}

function Animations.RegisterAnimation(id, animConfig)
    animConfig = animConfig or {}
    Animations.ActiveAnimations[id] = {
        Current = animConfig.Current or 0,
        Target = animConfig.Target or 0,
        Lambda = animConfig.Lambda or 15,
        Epsilon = animConfig.Epsilon or 0.005,
        OnUpdate = animConfig.OnUpdate,
        OnComplete = animConfig.OnComplete,
    }
    Animations.TargetFPS = 60
    Animations.IdleTimer = 0
end

function Animations.Tween(id, current, target, lambda, apply)
    Animations.RegisterAnimation(id, {
        Current = current,
        Target = target,
        Lambda = lambda or 20,
        Epsilon = 0.01,
        OnUpdate = apply,
        OnComplete = function() apply(target) end,
    })
end

function Animations.TweenProp(obj, prop, target, lambda)
    if not obj then return end
    local id = tostring(obj) .. ":" .. prop
    if Animations._targets[id] == target then return end
    Animations._targets[id] = target
    Animations.Tween(id, obj[prop] or target, target, lambda or 20, function(v)
        obj[prop] = v
    end)
end

function Animations.NotifyInput()
    Animations.IdleTimer = 0
    Animations.TargetFPS = 60
end

function Animations.GetActiveAnimationCount()
    local n = 0
    for _ in pairs(Animations.ActiveAnimations) do
        n = n + 1
    end
    return n
end

function Animations.Step(rawDt)
    local dt = math.max(0, rawDt or 0)
    local maxDt = 0.1
    if dt > maxDt then dt = maxDt end

    local activeCount = 0
    for id, anim in pairs(Animations.ActiveAnimations) do
        activeCount = activeCount + 1
        local alpha = 1 - math.exp(-anim.Lambda * dt)
        anim.Current = anim.Current + (anim.Target - anim.Current) * alpha
        if math.abs(anim.Target - anim.Current) <= anim.Epsilon then
            anim.Current = anim.Target
            if anim.OnUpdate then anim.OnUpdate(anim.Current) end
            if anim.OnComplete then anim.OnComplete() end
            Animations.ActiveAnimations[id] = nil
        else
            if anim.OnUpdate then anim.OnUpdate(anim.Current) end
        end
    end

    if activeCount > 0 or Animations.CurrentFocusedWidget then
        Animations.TargetFPS = 60
        Animations.IdleTimer = 0
    else
        Animations.IdleTimer = Animations.IdleTimer + dt
        if Animations.IdleTimer >= Animations.IdleTimeout then
            Animations.TargetFPS = 20
        end
    end
    return activeCount, dt
end

function Animations.Reset()
    Animations.ActiveAnimations = {}
    Animations._targets = {}
    Animations.TargetFPS = 20
    Animations.IdleTimer = Animations.IdleTimeout
    Animations.CurrentFocusedWidget = nil
end

return Animations
