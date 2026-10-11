-- mare.lua: Rami's idea! A pond in the forest with fish. Catch them with a net
-- (same button as for the animals) and bring them to the jar hut on the hill,
-- before the lava reaches the pond and dries it up.

local mare = {}
local g = love.graphics
local W, ctx   -- the world, and helper functions given by world.lua

local FISH_COLORS = {
    { 1, 0.55, 0.15 }, { 1, 0.8, 0.2 }, { 0.95, 0.35, 0.3 }, { 0.4, 0.65, 1 }, { 1, 0.6, 0.7 },
}

function mare.setup(world, helpers)
    W, ctx = world, helpers
end

-- Is (x, y) inside the pond, made `grow` pixels bigger?
local function inPond(x, y, grow)
    local p = W.pond
    local dx, dy = (x - p.x) / (p.rx + grow), (y - p.y) / (p.ry + grow * 0.5)
    return dx * dx + dy * dy < 1
end
mare.inPond = inPond

function mare.start(nFish, jarHut)
    local rand = ctx.rand
    -- with the drawing, the pond is rounder and a bit bigger (rocks all around)
    local drawn = ctx.art.image("mare")
    W.pond = { x = rand(560, 700), y = rand(ctx.TOP + 150, W.H - 140),
        rx = drawn and 110 or 95, ry = drawn and 85 or 52, dried = false }
    W.jarHut = jarHut
    W.fish = {}
    local looks = {}
    for i = 1, 10 do looks[i] = "poisson" .. i end
    for i = #looks, 2, -1 do
        local j = love.math.random(i)
        looks[i], looks[j] = looks[j], looks[i]
    end
    for i = 1, nFish do
        local a, r = rand(0, math.pi * 2), rand(0, 0.7)
        table.insert(W.fish, {
            x = W.pond.x + math.cos(a) * W.pond.rx * r, y = W.pond.y + math.sin(a) * W.pond.ry * r,
            tx = W.pond.x, ty = W.pond.y, state = "swim", facing = 1, wiggle = rand(0, 6),
            color = FISH_COLORS[(i - 1) % #FISH_COLORS + 1], img = looks[(i - 1) % #looks + 1], jump = 0,
        })
    end
end

function mare.count(state)
    local n = 0
    for _, f in ipairs(W.fish) do
        if f.state == state then n = n + 1 end
    end
    return n
end

-- Walking into the pond is not allowed: push `o` back to the shore.
function mare.block(o, body)
    local p = W.pond
    if p.dried then return end
    local rx, ry = p.rx + body, p.ry + body * 0.5
    local dx, dy = (o.x - p.x) / rx, (o.y - p.y) / ry
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 1 then
        if d < 0.01 then dx, dy, d = 1, 0, 1 end
        o.x, o.y = p.x + dx / d * rx, p.y + dy / d * ry
    end
end

-- The fish this kid could catch right now (the nearest one in reach).
local function fishInReach(k)
    if W.pond.dried then return end
    local best, bestD
    for _, f in ipairs(W.fish) do
        if f.state == "swim" then
            local d = ctx.dist(k, f)
            if d < k.look.reach + 25 and (not bestD or d < bestD) then best, bestD = f, d end
        end
    end
    return best
end

-- The grab button near the pond. Returns true if a fish was caught, "full" if
-- there was one but no room left, false if no fish is in reach.
function mare.tryCatch(k)
    local f = fishInReach(k)
    if not f then return false end
    -- one fish at a time in the net (and it still counts in what the kid carries)
    if (k.fish or 0) >= 1 or #k.followers + (k.fish or 0) >= k.look.carry then return "full" end
    f.state, f.kid = "carried", k
    k.fish = (k.fish or 0) + 1
    k.net = 0.5                        -- swing the net
    for _ = 1, 8 do                    -- splash!
        table.insert(W.particles, { splash = true, x = f.x, y = f.y, vx = ctx.rand(-60, 60),
            vy = ctx.rand(-120, -50), r = ctx.rand(2, 4), life = 0.6, max = 0.6 })
    end
    ctx.sfx.play("splash")
    return true
end

-- The kid touched the lava: the fish in the net jump back into the pond.
function mare.dropFish(k)
    for _, f in ipairs(W.fish) do
        if f.state == "carried" and f.kid == k then
            f.kid = nil
            if W.pond.dried then
                f.state = "lost"
            else
                f.state, f.x, f.y = "swim", W.pond.x, W.pond.y
            end
        end
    end
    k.fish = 0
end

local function inRect(o, r)
    return o.x > r.x + 8 and o.x < r.x + r.w - 8 and o.y > r.y + 8 and o.y < r.y + r.h - 4
end

function mare.update(dt)
    local p, rand = W.pond, ctx.rand

    -- the lava reaches the pond: it dries up and the fish still in it jump away
    if not p.dried and W.phase == "play" and ctx.lavaX(p.y) > p.x - p.rx * 0.3 then
        p.dried = true
        for _ = 1, 25 do ctx.smoke(p.x + rand(-p.rx, p.rx), p.y + rand(-p.ry, p.ry)) end
        for _, f in ipairs(W.fish) do
            if f.state == "swim" then
                f.state, f.jump = "leap", 0
                f.vx, f.vy = rand(60, 160), rand(-380, -260)
            end
        end
        ctx.sfx.play("burn")
    end

    for _, f in ipairs(W.fish) do
        f.wiggle = f.wiggle + dt * 10
        if f.state == "swim" then
            -- swim slowly to random spots in the pond, with a little jump now and then
            if ctx.dist(f, { x = f.tx, y = f.ty }) < 4 or love.math.random() < dt * 0.3 then
                local a, r = rand(0, math.pi * 2), rand(0, 0.75)
                f.tx, f.ty = p.x + math.cos(a) * p.rx * r, p.y + math.sin(a) * p.ry * r
            end
            local dx, dy = f.tx - f.x, f.ty - f.y
            local d = math.max(1, math.sqrt(dx * dx + dy * dy))
            f.x, f.y = f.x + dx / d * 35 * dt, f.y + dy / d * 35 * dt
            if math.abs(dx) > 1 then f.facing = dx > 0 and 1 or -1 end
            f.jump = math.max(0, f.jump - dt)
            if f.jump == 0 and love.math.random() < dt * 0.15 then f.jump = 0.6 end
        elseif f.state == "leap" then
            f.x, f.y = f.x + f.vx * dt, f.y + f.vy * dt
            f.vy = f.vy + 500 * dt
            if f.y > W.H + 40 or f.x > W.W + 40 then f.state = "lost" end
        end
    end

    -- bring the fish to the jar hut: each one goes into a jar
    for _, k in ipairs(W.kids) do
        k.net = math.max(0, (k.net or 0) - dt)
        if (k.fish or 0) > 0 and inRect(k, W.jarHut) then
            for _, f in ipairs(W.fish) do
                if f.state == "carried" and f.kid == k then
                    f.state, f.kid = "jar", nil
                    ctx.popup("+1", k.x, k.y - 100, { 0.4, 0.75, 1 }, true)
                end
            end
            k.fish = 0
            k.cheer = math.min(1.8, ctx.art.duration(k.look.id, "saut") or 0)
            ctx.sfx.play("home")
        end
    end
end

-- Drawing ---------------------------------------------------------------------------

local OUTLINE = { 0.23, 0.14, 0.09 }

-- fish: a fish (its drawing is used if there is one) or just a color.
function mare.drawFish(x, y, f, s, fish, wiggle)
    s = s or 1
    local im = fish.img and ctx.art.image(fish.img)
    if im then
        -- a little wiggle: tilt and squeeze in rhythm
        local sc = 17 * s / im:getHeight()
        local w = math.sin(wiggle or 0)
        g.setColor(1, 1, 1)
        g.draw(im, x, y, w * 0.12, sc * f * (1 - 0.06 * math.abs(w)), sc, im:getWidth() / 2, im:getHeight() / 2)
        return
    end
    local color = fish.color or fish
    local w = math.sin(wiggle or 0) * 3 * s
    g.setColor(color)
    g.polygon("fill", x - f * 9 * s, y, x - f * 17 * s, y - 6 * s + w, x - f * 17 * s, y + 6 * s + w)
    g.ellipse("fill", x, y, 11 * s, 6.5 * s)
    g.setColor(OUTLINE)
    g.setLineWidth(1.5 * s)
    g.ellipse("line", x, y, 11 * s, 6.5 * s)
    g.circle("fill", x + f * 5 * s, y - 1.5 * s, 1.6 * s)
end

local POND_WIDTH = 270   -- how wide the pond drawing is shown, rocks included

-- The pond, under everything (drawn with the ground).
function mare.drawPond(t)
    local p = W.pond
    local im = ctx.art.image(p.dried and "mare_seche" or "mare")
    if im then
        local sc = POND_WIDTH / im:getWidth()
        g.setColor(1, 1, 1)
        g.draw(im, p.x, p.y, 0, sc, sc, im:getWidth() / 2, im:getHeight() * 0.49)
        if not p.dried then
            for _, f in ipairs(W.fish) do
                if f.state == "swim" then
                    local hop = f.jump > 0 and math.sin(f.jump / 0.6 * math.pi) * 18 or 0
                    mare.drawFish(f.x, f.y - hop, f.facing, 1.1, f, f.wiggle)
                end
            end
        end
        return
    end
    if p.dried then
        g.setColor(0.45, 0.33, 0.22)
        g.ellipse("fill", p.x, p.y, p.rx, p.ry)
        g.setColor(OUTLINE)
        g.setLineWidth(3)
        g.ellipse("line", p.x, p.y, p.rx, p.ry)
        g.setLineWidth(2)
        for i = 0, 6 do   -- cracks in the dry mud
            local a = i * 0.9
            g.line(p.x + math.cos(a) * 10, p.y + math.sin(a) * 6,
                p.x + math.cos(a) * p.rx * 0.8, p.y + math.sin(a + 0.3) * p.ry * 0.8)
        end
        return
    end
    g.setColor(0.35, 0.6, 0.3)
    g.ellipse("fill", p.x, p.y + 4, p.rx + 8, p.ry + 6)      -- grassy bank
    g.setColor(0.3, 0.6, 0.85)
    g.ellipse("fill", p.x, p.y, p.rx, p.ry)
    g.setColor(0.45, 0.75, 0.95)
    g.ellipse("fill", p.x - 12, p.y - 8, p.rx * 0.75, p.ry * 0.6)
    -- fish, seen through the water
    for _, f in ipairs(W.fish) do
        if f.state == "swim" then
            local hop = f.jump > 0 and math.sin(f.jump / 0.6 * math.pi) * 18 or 0
            mare.drawFish(f.x, f.y - hop, f.facing, 1, f, f.wiggle)
        end
    end
    -- ripples and lily pads
    g.setColor(1, 1, 1, 0.5)
    g.setLineWidth(2)
    for i = 0, 2 do
        local k = (t * 0.4 + i / 3) % 1
        g.ellipse("line", p.x + (i - 1) * 35, p.y + (i % 2) * 15 - 8, 6 + 20 * k, (6 + 20 * k) * 0.45)
    end
    for i, o in ipairs({ { -60, 18 }, { 55, -22 }, { 70, 20 } }) do
        g.setColor(0.3, 0.65, 0.3)
        g.arc("fill", p.x + o[1], p.y + o[2], 11, 0.4 + i, 0.4 + i + math.pi * 1.75)
        g.setColor(OUTLINE)
        g.setLineWidth(1.5)
        g.arc("line", "closed", p.x + o[1], p.y + o[2], 11, 0.4 + i, 0.4 + i + math.pi * 1.75)
    end
    g.setColor(OUTLINE)
    g.setLineWidth(3)
    g.ellipse("line", p.x, p.y, p.rx, p.ry)
end

-- Fish jumping away when the pond dries up (drawn above everything).
function mare.drawLeaping()
    for _, f in ipairs(W.fish) do
        if f.state == "leap" then mare.drawFish(f.x, f.y, 1, 1.2, f, f.wiggle * 2) end
    end
end

-- The net in the kid's hand, with the fish they caught: carried over the
-- shoulder, and swung forward when catching a fish.
function mare.drawNet(k, kidHeight)
    if (k.fish or 0) == 0 and (k.net or 0) == 0 then return end
    local f = k.facing
    local hx, hy = k.x + f * 8, k.y - kidHeight * 0.5
    local ang = -2.15                                  -- up and behind the shoulder
    if (k.net or 0) > 0 then                           -- the catching swing
        ang = -2.15 + math.sin((1 - k.net / 0.5) * math.pi) * 1.9
    end
    -- the drawings: empty net, or the full one when carrying fish. For each:
    -- where the handle end, the hoop center and the bottom of the bag are (in %).
    local full = (k.fish or 0) > 0 and ctx.art.image("epuisette_pleine")
    local im = full or ctx.art.image("epuisette")
    if im then
        local m = full and { 0.014, 0.965, 0.674, 0.251, 0.767, 0.781 }
            or { 0.015, 0.967, 0.712, 0.305, 0.75, 0.75 }
        local iw, ih = im:getDimensions()
        local vx, vy = (m[3] - m[1]) * iw, (m[4] - m[2]) * ih
        local sc = kidHeight * 0.55 / math.sqrt(vx * vx + vy * vy)
        -- held in front of the kid, as drawn (handle forward and up, bag hanging);
        -- when catching, it dips down toward the water and comes back
        local rot = 0
        if (k.net or 0) > 0 then rot = math.sin((1 - k.net / 0.5) * math.pi) * 1.1 end
        rot = rot * f
        local hx, hy = k.x + f * kidHeight * 0.12, k.y - kidHeight * 0.42
        g.setColor(1, 1, 1)
        g.draw(im, hx, hy, rot, sc * f, sc, m[1] * iw, m[2] * ih)
        -- the fish, in the bottom of the bag (same transform as the drawing)
        local bx, by = (m[5] - m[1]) * iw * sc * f, (m[6] - m[2]) * ih * sc
        local cs, sn = math.cos(rot), math.sin(rot)
        local px, py = hx + bx * cs - by * sn, hy + bx * sn + by * cs
        local i, n = 0, k.fish or 0
        for _, fish in ipairs(W.fish) do
            if fish.state == "carried" and fish.kid == k then
                i = i + 1
                mare.drawFish(px + (i - (n + 1) / 2) * 9 * f, py - 4 - (i % 2) * 6, f, 0.95, fish,
                    k.animT * 12 + i)
            end
        end
        return
    end
    local len = kidHeight * 0.75
    local cx, cy = hx + f * math.cos(ang) * len, hy + math.sin(ang) * len
    g.setColor(OUTLINE)
    g.setLineWidth(5)
    g.line(hx, hy, cx, cy)
    g.setColor(0.7, 0.48, 0.28)
    g.setLineWidth(3)
    g.line(hx, hy, cx, cy)
    -- the net and the fish in it
    g.setColor(1, 1, 1, 0.45)
    g.ellipse("fill", cx, cy, 18, 13)
    local i = 0
    for _, fish in ipairs(W.fish) do
        if fish.state == "carried" and fish.kid == k then
            i = i + 1
            mare.drawFish(cx + (i - 2.5) * 7, cy + 2 + (i % 2) * 4, f, 0.75, fish, k.animT * 12 + i)
        end
    end
    g.setColor(1, 1, 1, 0.6)
    g.setLineWidth(1.5)
    for i = -2, 2 do g.line(cx + i * 7, cy - 12, cx + i * 6, cy + 12) end
    g.line(cx - 17, cy, cx + 17, cy)
    g.setColor(OUTLINE)
    g.setLineWidth(3)
    g.ellipse("line", cx, cy, 18, 13)
end

-- The jar hut on the hill: a hut, and shelves of jars full of water.
function mare.drawJarHut(t)
    local r = W.jarHut
    g.setColor(0.75, 0.88, 0.95, 0.5)
    g.rectangle("fill", r.x, r.y, r.w, r.h, 10)
    ctx.art.hut(r.x + r.w - 45, r.y + 80, { 0.3, 0.75, 0.75 }, "bocaux")
    local total, n = #W.fish, 0
    local cols = math.ceil(total / 2)
    for i = 1, total do
        local row, col = math.floor((i - 1) / cols), (i - 1) % cols
        local x, y = r.x + 22 + col * 30, r.y + 70 + row * 52
        if row == 0 then
            g.setColor(0.55, 0.36, 0.2)
            g.rectangle("fill", r.x + 6, r.y + 92, cols * 30 + 8, 6)
            g.rectangle("fill", r.x + 6, r.y + 144, cols * 30 + 8, 6)
        end
        -- the jar: one of the jar drawings (taking turns), or a simple drawn one
        local im = ctx.art.image("bocal" .. ((i - 1) % 6 + 1))
        if im then
            local sc = 40 / im:getHeight()
            g.setColor(1, 1, 1)
            g.draw(im, x, y + 22, 0, sc, sc, im:getWidth() / 2, im:getHeight())
        else
            g.setColor(0.55, 0.8, 0.95, 0.85)
            g.rectangle("fill", x - 11, y - 8, 22, 30, 7)
            g.setColor(0.85, 0.95, 1, 0.9)
            g.rectangle("fill", x - 9, y - 14, 18, 6, 2)
            g.setColor(OUTLINE)
            g.setLineWidth(1.5)
            g.rectangle("line", x - 11, y - 8, 22, 30, 7)
            g.rectangle("line", x - 9, y - 14, 18, 6, 2)
        end
        n = n + 1
    end
    -- the saved fish, one per jar
    local i = 0
    for _, f in ipairs(W.fish) do
        if f.state == "jar" then
            local row, col = math.floor(i / cols), i % cols
            local x, y = r.x + 22 + col * 30, r.y + 70 + row * 52
            mare.drawFish(x + math.sin(t * 2 + i) * 2, y + 10 + math.sin(t * 1.3 + i) * 2,
                (i % 2 == 0) and 1 or -1, 0.65, f, t * 6 + i)
            i = i + 1
        end
    end
end

return mare
