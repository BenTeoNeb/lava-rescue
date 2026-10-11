-- events.lua: surprises during a game.
--   The golden animal: once per game an animal turns golden. It is shy (it
--   trots away from the kids) and worth 5.
--   The big animal: a big mother boar (or images/ours.png if there is one)
--   that only moves when TWO kids hold it together. Worth 3. 2+ players only.

local events = {}
local g = love.graphics
local W, ctx        -- the world, and helpers given by world.lua

local GOLD_VALUE = 5
local GOLD_AT = { 25, 15 }      -- seconds into the game: normal game, calm mode
local BIG_VALUE = 3
local BIG_AT = 12               -- seconds into the game
local BIG_REACH = 80            -- how close a kid must be to take hold of it
local BIG_LEASH = 70            -- the two kids can't get further than this from it
local BIG_LET_GO = 120          -- a kid alone holding it lets go if further than this

function events.setup(world, helpers)
    W, ctx = world, helpers
end

function events.start(players)
    W.gold = { at = GOLD_AT[W.calm and 2 or 1], done = false }
    W.total = W.total + (GOLD_VALUE - 1)
    W.big = nil
    if players >= 2 then
        W.big = { state = "waiting", at = BIG_AT, holders = {}, facing = 1, walk = 0, wobble = 0 }
        W.total = W.total + BIG_VALUE
    end
end

-- Points brought by the events (on top of 1 per animal and fish).
function events.bonus()
    local n = 0
    for _, a in ipairs(W.animals) do
        if a.golden and a.state == "home" then n = n + GOLD_VALUE - 1 end
    end
    if W.big and W.big.state == "home" then n = n + BIG_VALUE end
    return n
end

-- Is the big animal still to be saved? (the game can't end before)
function events.left()
    return (W.big and W.big.state ~= "home") and 1 or 0
end

local function sparkle(x, y, n)
    for _ = 1, n do
        table.insert(W.particles, { star = true, x = x + ctx.rand(-25, 25), y = y + ctx.rand(-40, 0),
            vx = ctx.rand(-30, 30), vy = ctx.rand(-60, -20), r = ctx.rand(3, 6), life = 0.9, max = 0.9 })
    end
end

-- The golden animal -----------------------------------------------------------

local function revealGold()
    W.gold.done = true
    local choices = {}
    for _, a in ipairs(W.animals) do
        if a.state == "free" and a.x > ctx.lavaX(a.y) + 200 then table.insert(choices, a) end
    end
    if #choices == 0 then           -- nobody left to turn golden
        W.total = W.total - (GOLD_VALUE - 1)
        return
    end
    local a = choices[love.math.random(#choices)]
    a.golden, a.value = true, GOLD_VALUE
    sparkle(a.x, a.y - 20, 30)
    ctx.sfx.play("ready")
end

-- A free golden animal trots away from the kids nearby (never into the lava).
function events.shy(a, dt)
    if not a.golden or a.state ~= "free" then return false end
    local near
    for _, k in ipairs(W.kids) do
        local d = ctx.dist(a, k)
        if d < 140 and (not near or d < ctx.dist(a, near)) then near = k end
    end
    if not near then return false end
    local dx, dy = a.x - near.x, a.y - near.y
    local d = math.max(1, math.sqrt(dx * dx + dy * dy))
    a.x = ctx.clamp(a.x + dx / d * 130 * dt, ctx.lavaX(a.y) + 70, ctx.HILL_X - 40)
    a.y = ctx.clamp(a.y + dy / d * 130 * dt, ctx.TOP + 30, W.H - 20)
    a.facing = dx > 0 and 1 or -1
    a.walk, a.moving = a.walk + dt * 12, 160
    a.tx, a.ty = a.x, a.y
    return true
end

-- The big animal ---------------------------------------------------------------

local function release(k)
    local b = W.big
    if not b then return end
    for i, h in ipairs(b.holders) do
        if h == k then table.remove(b.holders, i) break end
    end
    k.holdingBig = false
end

local function releaseAll()
    local b = W.big
    for _, k in ipairs(b.holders) do k.holdingBig = false end
    b.holders = {}
end

local function spawnBig()
    local b = W.big
    for _ = 1, 50 do
        b.x = ctx.rand(math.max(360, ctx.lavaX(400) + 250), ctx.HILL_X - 140)
        b.y = ctx.rand(ctx.TOP + 120, W.H - 60)
        if not ctx.inPond(b.x, b.y, 60) then break end
    end
    b.state, b.homeX, b.homeY = "free", b.x, b.y
    for _ = 1, 20 do ctx.smoke(b.x + ctx.rand(-40, 40), b.y - ctx.rand(0, 30)) end
    ctx.sfx.play("rumble")
end

-- The grab button: take hold of the big animal if it's right there.
function events.tryGrab(k)
    local b = W.big
    if not b or k.holdingBig or (b.state ~= "free" and b.state ~= "held") then return false end
    if #b.holders >= 2 or ctx.dist(k, b) > BIG_REACH then return false end
    table.insert(b.holders, k)
    k.holdingBig = true
    b.state = "held"
    ctx.sfx.play("grab")
    return true
end

-- The drop button lets go of the big animal first.
function events.drop(k)
    if not k.holdingBig then return false end
    release(k)
    if #W.big.holders == 0 then W.big.state = "free" end
    ctx.sfx.play("drop")
    return true
end

local function updateBig(dt)
    local b = W.big
    if b.state == "waiting" then
        if W.time >= b.at then spawnBig() end
        return
    end
    b.wobble = math.max(0, b.wobble - dt)
    if b.state == "free" or b.state == "held" then
        -- a holder who got burned or went too far lets go
        for i = #b.holders, 1, -1 do
            local k = b.holders[i]
            if k.burn > 0 or ctx.dist(k, b) > BIG_LET_GO then release(k) end
        end
        if #b.holders == 0 then b.state = "free" end
        if #b.holders == 2 then
            -- both kids: it follows them, and keeps them close
            local h1, h2 = b.holders[1], b.holders[2]
            local tx, ty = (h1.x + h2.x) / 2, (h1.y + h2.y) / 2
            local dx, dy = tx - b.x, ty - b.y
            local d = math.sqrt(dx * dx + dy * dy)
            if d > 3 then
                local step = math.min(d, 210 * dt)
                b.x, b.y = b.x + dx / d * step, b.y + dy / d * step
                if math.abs(dx) > 2 then b.facing = dx > 0 and 1 or -1 end
                b.walk, b.moving = b.walk + dt * 10, 100
            else
                b.moving = false
            end
            for _, k in ipairs(b.holders) do
                local kd = ctx.dist(k, b)
                if kd > BIG_LEASH then
                    k.x = b.x + (k.x - b.x) / kd * BIG_LEASH
                    k.y = b.y + (k.y - b.y) / kd * BIG_LEASH
                end
            end
        elseif #b.holders == 1 then
            -- one kid alone: it won't budge, it just wobbles
            b.wobble, b.moving = 0.3, false
        else
            -- nobody: it grazes around where it is
            b.moving = false
        end
        ctx.blockByTrees(b)
        ctx.mare.block(b, 30)
        -- into a pen: saved!
        local pen = ctx.penAt(b)
        if pen and #b.holders == 2 then
            for _, k in ipairs(b.holders) do
                k.cheer = math.min(1.8, ctx.art.duration(k.look.id, "saut") or 0)
            end
            releaseAll()
            b.state, b.pen = "home", pen
            ctx.popup("+" .. BIG_VALUE, b.x, b.y - 80, { 1, 0.4, 0.5 }, true)
            sparkle(b.x, b.y - 30, 25)
            ctx.sfx.play("win")
        end
        -- the lava: it runs away, and comes back later
        if b.state ~= "home" and W.phase == "play" and ctx.inLava(b, 10) then
            releaseAll()
            b.state, b.vy = "flee", b.y < W.H / 2 and -200 or 200
            ctx.sfx.play("burn")
        end
    elseif b.state == "flee" then
        b.x, b.y = b.x + 70 * dt, b.y + b.vy * dt
        b.walk, b.moving = b.walk + dt * 16, 200
        if b.y < -80 or b.y > W.H + 80 then b.state, b.back = "gone", 10 end
    elseif b.state == "gone" then
        b.back = b.back - dt
        if b.back <= 0 and W.phase == "play" then spawnBig() end
    elseif b.state == "home" then
        local r = ctx.PENS[b.pen]
        local tx = r.x + 60 + math.sin(W.time * 0.3) * 30
        local dx = tx - b.x
        b.x = b.x + ctx.clamp(dx, -20 * dt, 20 * dt)
        b.y = b.y + ctx.clamp(r.y + r.h - 40 - b.y, -20 * dt, 20 * dt)
        b.moving = math.abs(dx) > 1 and 20 or false
    end
end

function events.update(dt)
    if not W.gold.done and W.phase == "play" and W.time >= W.gold.at then revealGold() end
    -- golden animals sparkle now and then
    for _, a in ipairs(W.animals) do
        if a.golden and a.state ~= "gone" and love.math.random() < dt * 4 then sparkle(a.x, a.y - 10, 1) end
    end
    if W.big then updateBig(dt) end
end

-- Drawing ------------------------------------------------------------------------

-- The big animal (to draw with everything sorted by height).
function events.drawBig()
    local b = W.big
    if not b or b.state == "waiting" or b.state == "gone" then return end
    local wob = b.wobble > 0 and math.sin(W.time * 40) * 3 or 0
    local hop = b.moving and math.abs(math.sin(b.walk)) * 4 or 0
    local kind = ctx.art.image("ours") and "ours" or "marcassin"
    local anim = b.moving and (b.moving > 150 and "course" or "marche") or "repos"
    ctx.art.animal(kind, b.x + wob, b.y - hop, b.facing, kind == "ours" and 1.6 or 2.4, true, anim, W.time)
    -- the ropes from the kids' hands, in front of it
    for _, k in ipairs(b.holders) do
        g.setColor(0.25, 0.15, 0.08)
        g.setLineWidth(6)
        g.line(k.x + k.facing * 10, k.y - 50 * k.look.size, b.x, b.y - 30)
        g.setColor(0.8, 0.6, 0.35)
        g.setLineWidth(3)
        g.line(k.x + k.facing * 10, k.y - 50 * k.look.size, b.x, b.y - 30)
    end
end

-- An extra golden glow over a golden animal (drawn right after the animal).
function events.drawGold(a, draw)
    if not a.golden then return end
    g.setColor(1, 0.85, 0.2, 0.35)
    g.ellipse("fill", a.x, a.y - 18, 34, 26)
    g.setBlendMode("add")
    ctx.art.tint = { 0.55, 0.42, 0.05, 1 }
    draw()
    ctx.art.tint = nil
    g.setBlendMode("alpha")
end

return events
