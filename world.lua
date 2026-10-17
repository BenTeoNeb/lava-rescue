-- world.lua: the rescue! The lava creeps from the volcano toward the hill.
-- Bring the animals to the pens on the hill before it gets them.

local input = require("input")
local sfx = require("sfx")
local art = require("art")
local lave = require("lave")
local mare = require("mare")
local events = require("events")
-- the game log (journal.lua) is not shipped (see build.sh): without it, nothing is logged
local hasJournal, journal = pcall(require, "journal")
if not hasJournal then
    journal = setmetatable({}, { __index = function() return function() end end })
end
local T = require("lang").t

local world = {}
local g = love.graphics

world.W, world.H = 1280, 720

-- Tweak these to make the game easier or harder.
local INTRO = 5               -- seconds before the lava starts moving
local DURATION = 150          -- seconds until the volcano calms down
-- Each kid changes these with their own speed, carry and reach (see art.KIDS).
local KID_SPEED = 230         -- running, arms free
local KID_WALK_SPEED = 185    -- walking, when animals are following you
-- How many of each animal: 20 for one player, 35 for two.
local ANIMAL_COUNTS = {
    { poule = 5, ecureuil = 4, marcassin = 4, herisson = 4, renard = 3 },
    { poule = 8, ecureuil = 7, marcassin = 7, herisson = 7, renard = 6 },
}
local PREY = { poule = true, ecureuil = true }   -- what the fox scares

local HILL_X = 1010           -- the safe high ground starts here
local LAVA_START, LAVA_END = 170, HILL_X - 90
local ERUPTION_EVERY = 30     -- seconds between eruptions; the lava surges after each
local LAVA_STEP = 4           -- the lava edge is remembered every 4 pixels of height
local GRASS_TILE = 380        -- width of one tile of the grass drawing, in pixels
world.GRASS_TILE = GRASS_TILE
local TOP = 70                -- below the score bar

local PENS = {
    { x = 1050, y = 78, w = 210, h = 148, roof = { 0.9, 0.25, 0.2 }, name = "rouge" },
    { x = 1050, y = 234, w = 210, h = 148, roof = { 0.25, 0.5, 0.95 }, name = "bleue", top = false },
    { x = 1050, y = 390, w = 210, h = 148, roof = { 1, 0.78, 0.15 }, name = "jaune", top = false },
}

-- The huts of the pens are picked at random among these drawings, three
-- different ones each game (the ones whose image exists).
local HUTS = {
    "cabane_souche", "cabane_coquillage", "cabane_pomme_de_pin", "cabane_rondins",
    "cabane_champignon", "maison_rouge", "maison_bleue", "maison_jaune",
}

-- The jar hut, below the pens, where the fish go (Rami's idea).
local JAR_HUT = { x = 1050, y = 548, w = 210, h = 160 }
local FISH_COUNTS = { 5, 8 }    -- fish in the pond, for one or two players

local FLOWER_COLORS = { { 1, 0.5, 0.6 }, { 0.7, 0.5, 1 }, { 1, 1, 1 }, { 1, 0.75, 0.3 } }

local fonts = {}

local function dist(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2)
end

local function clamp(v, lo, hi)
    return math.max(lo, math.min(hi, v))
end

local function rand(a, b)
    return a + love.math.random() * (b - a)
end

-- How far the lava has come, from 0 to 1. It surges right after each eruption,
-- then slows down until the next one (it is never completely still).
local LAVA_RUSH_AT, LAVA_RUSH = 0.7, 2   -- from 70% of its way, the lava flows 2x faster

local function lavaProgress(time)
    local e = time - INTRO
    if e > DURATION * LAVA_RUSH_AT then e = DURATION * LAVA_RUSH_AT + (e - DURATION * LAVA_RUSH_AT) * LAVA_RUSH end
    local t = clamp(e / DURATION, 0, 1)
    local n = DURATION / ERUPTION_EVERY
    local k = math.floor(t * n)
    if k >= n then return 1 end
    local u = t * n - k
    local eased = 0.75 * (1 - (1 - u) ^ 3) + 0.25 * u
    return (k + eased) / n
end

-- A lava tongue: a narrow finger that shoots out after an eruption and keeps
-- growing for a few seconds.
local function addTongue()
    table.insert(world.tongues, {
        y = rand(TOP, world.H), w = rand(28, 65), len = rand(110, 210),
        grow = rand(6, 12), t0 = world.time,
    })
end

-- The shape of the lava edge at height y: deep curves that grow as the lava
-- spreads and slowly change, the tongues, and a lead near the volcano.
local function lavaShape(y)
    local t, spread = world.time, 0.25 + 0.75 * world.lavaProgress
    local big = (love.math.noise(y * 0.005, world.lavaSeed) - 0.5) * 2 * 160 * spread
    local mid = (love.math.noise(y * 0.016, world.lavaSeed + 7.3, t * 0.03) - 0.5) * 2 * 60 * spread
    local lead = 90 * math.max(0, 1 - y / 450)
    local fingers = 0
    for _, tg in ipairs(world.tongues) do
        local u = (y - tg.y) / tg.w
        if u > -1 and u < 1 then
            local k = clamp((t - tg.t0) / tg.grow, 0, 1)
            fingers = math.max(fingers, tg.len * (1 - (1 - k) ^ 2) * (1 - u * u) ^ 2)
        end
    end
    return math.min(HILL_X - 20, world.lavaBase + lead + big + mid + fingers)
end

-- Remember the furthest the lava has been at each height: it never goes back.
local function updateLavaFront()
    for i = 0, math.ceil(world.H / LAVA_STEP) + 1 do
        world.lavaFront[i] = math.max(world.lavaFront[i] or -1e9, lavaShape(i * LAVA_STEP))
    end
end

-- Where the lava edge is at height y (with a little bubbling ripple on top).
function world.lavaX(y)
    local f = clamp(y / LAVA_STEP, 0, #world.lavaFront - 1)
    local i = math.floor(f)
    local a, b = world.lavaFront[i], world.lavaFront[i + 1] or world.lavaFront[i]
    return a + (b - a) * (f - i) + 6 * math.sin(y * 0.05 + world.time * 1.6)
end

local function inLava(o, margin)
    return o.x < world.lavaX(o.y) + (margin or 0)
end

local function penAt(o)
    for i, r in ipairs(PENS) do
        if o.x > r.x + 8 and o.x < r.x + r.w - 8 and o.y > r.y + 8 and o.y < r.y + r.h - 4 then
            return i
        end
    end
end

-- Trees are solid: push `o` out of every trunk. Each trunk is a flat ellipse at
-- the foot of the tree, so you can still walk behind the leaves.
local BODY = 10            -- half-width of a kid or an animal's feet
local function blockByTrees(o)
    for _, tr in ipairs(world.trees) do
        local r = (art.TRUNKS[tr.kind] or 15) * tr.s + BODY
        local dx, dy = o.x - tr.x, (o.y - tr.y) / 0.5
        local d = math.sqrt(dx * dx + dy * dy)
        if d < r then
            if d < 0.01 then dx, dy, d = 1, 0, 1 end
            o.x = tr.x + dx / d * r
            o.y = tr.y + dy / d * r * 0.5
        end
    end
end

-- Two kids can't walk through each other: if their feet overlap, push them
-- apart (half each), then make sure neither was pushed into a tree.
local KID_GAP = 26         -- how close the feet of two kids can get
local function separateKids()
    local a, b = world.kids[1], world.kids[2]
    if not (a and b) then return end
    local dx, dy = b.x - a.x, (b.y - a.y) / 0.5
    local d = math.sqrt(dx * dx + dy * dy)
    if d >= KID_GAP then return end
    if d < 0.01 then dx, dy, d = 1, 0, 1 end
    local push = (KID_GAP - d) / 2
    local nx, ny = dx / d, dy / d * 0.5
    a.x, a.y = a.x - nx * push, a.y - ny * push
    b.x, b.y = b.x + nx * push, b.y + ny * push
    blockByTrees(a)
    blockByTrees(b)
end

-- The fences of the pens are solid for the kids: you can only get in through
-- the entrance on the forest side. (px, py) is where the kid was before moving,
-- to know which side of a fence they come from.
local WALL = 7             -- how thick a fence is, for the feet
local function blockByFences(o, px, py)
    for _, r in ipairs(PENS) do
        local top, bottom = r.y + 6, r.y + r.h - 2
        local gapTop, gapBottom = r.y + r.h * art.PEN_GAP[1], r.y + r.h * art.PEN_GAP[2]
        -- horizontal fences (top and bottom)
        for _, y in ipairs({ top, bottom }) do
            if o.x > r.x - BODY and o.x < r.x + r.w + BODY and math.abs(o.y - y) < WALL then
                local side = py < y and -1 or 1
                o.y = y + side * WALL
            end
        end
        -- vertical fences: right side, and the left side around the entrance
        local sides = { { r.x + r.w, top, bottom }, { r.x, top, gapTop }, { r.x, gapBottom, bottom } }
        for _, v in ipairs(sides) do
            local x, y1, y2 = v[1], v[2], v[3]
            if o.y > y1 - WALL and o.y < y2 + WALL and math.abs(o.x - x) < BODY then
                local side = px < x and -1 or 1
                o.x = x + side * BODY
            end
        end
    end
end

local SCORE_X, SCORE_Y = 640, 36      -- where the score is shown (top, middle)

-- A floating text. Points ("+1", "+5"...) rise a little, then fly to the score.
local function popup(text, x, y, color, big)
    table.insert(world.popups, { text = text, x = x, y = y, x0 = x, y0 = y, age = 0, life = 1.4,
        color = color, big = big, fly = text:sub(1, 1) == "+" })
end

local function banner(text, seconds, color)
    world.banner = { text = text, life = seconds or 3, color = color or { 1, 1, 1 } }
end

local function smoke(x, y, dark)
    table.insert(world.particles, {
        x = x, y = y, vx = rand(-15, 15), vy = rand(-50, -25), r = rand(6, 11),
        life = 1.2, max = 1.2, color = dark and { 0.3, 0.3, 0.3 } or { 0.85, 0.85, 0.85 },
    })
end

-- Setup --------------------------------------------------------------------------

-- (Re)make the fonts, sharp for the current screen size.
function world.makeFonts()
    fonts.huge = art.font(64)
    fonts.big = art.font(40)
    fonts.mid = art.font(26)
    fonts.small = art.font(20)
end

function world.load()
    world.makeFonts()
    lave.load()
    events.setup(world, { rand = rand, dist = dist, clamp = clamp, popup = popup, smoke = smoke, sfx = sfx,
        art = art, mare = mare, inPond = mare.inPond, blockByTrees = blockByTrees, penAt = penAt,
        inLava = inLava, lavaX = function(y) return world.lavaX(y) end,
        PENS = PENS, HILL_X = HILL_X, TOP = TOP, log = journal.log })
    mare.setup(world, { rand = rand, dist = dist, popup = popup, smoke = smoke, sfx = sfx, art = art,
        lavaX = function(y) return world.lavaX(y) end, TOP = TOP, log = journal.log })
end

-- calm: the calm mode (no lava coming, no time limit).
function world.start(chosen, calm)
    world.calm = calm and true or false
    world.time = 0
    world.lavaBase = LAVA_START
    world.lavaProgress = 0
    world.lavaSeed = love.math.random() * 100
    world.lavaFront = {}
    world.tongues = {}
    updateLavaFront()
    world.phase = "play"
    world.done = false
    world.starsLit, world.starFlash, world.scorePop = 0, nil, 0
    world.shake = 0
    world.nextEruption = INTRO
    world.popups, world.particles, world.rocks = {}, {}, {}

    world.kids = {}
    for i, c in ipairs(chosen) do
        table.insert(world.kids, {
            player = c.player, look = art.KIDS[c.kid],
            x = HILL_X - 20, y = 300 + (i - 1) * 140, facing = -1,
            walk = 0, burn = 0, followers = {}, fish = 0, anim = "repos", animT = 0, cheer = 0,
        })
    end

    -- three different huts for the pens this time
    local huts = {}
    for _, name in ipairs(HUTS) do
        if art.image(name) then table.insert(huts, name) end
    end
    for i = #huts, 2, -1 do
        local j = love.math.random(i)
        huts[i], huts[j] = huts[j], huts[i]
    end
    for i, pen in ipairs(PENS) do pen.hut = huts[i] end

    mare.start(FISH_COUNTS[math.min(#chosen, 2)], JAR_HUT)

    world.animals = {}
    for kind, n in pairs(ANIMAL_COUNTS[math.min(#chosen, 2)]) do
        for _ = 1, n do
            local a = { kind = kind, state = "free", facing = 1, walk = 0, wait = rand(0, 2) }
            repeat
                a.x, a.y = rand(330, HILL_X - 70), rand(TOP + 40, world.H - 30)
                local ok = not mare.inPond(a.x, a.y, 40)
                for _, b in ipairs(world.animals) do
                    if dist(a, b) < 55 then ok = false end
                end
            until ok
            a.tx, a.ty = a.x, a.y
            table.insert(world.animals, a)
        end
    end
    world.total = #world.animals + #world.fish
    events.start(#chosen)
    local kidNames = {}
    for _, k in ipairs(world.kids) do kidNames[#kidNames + 1] = k.look.id end
    journal.start({ joueurs = #chosen, enfants = kidNames, mode = world.calm and "calme" or "volcan",
        langue = require("lang").current, animaux = #world.animals, poissons = #world.fish,
        total = world.total, maman = world.big and world.big.family or false })

    world.trees, world.flowers, world.mushrooms = {}, {}, {}
    -- a few trees, spread out so they don't hide the kids too much,
    -- each one a different species as long as there are enough
    local kinds = {}
    for kind in pairs(art.TREES) do table.insert(kinds, kind) end
    table.sort(kinds)
    for i = #kinds, 2, -1 do
        local j = love.math.random(i)
        kinds[i], kinds[j] = kinds[j], kinds[i]
    end
    for _ = 1, 200 do
        local tree = { x = rand(240, HILL_X - 50), y = rand(TOP + 80, world.H - 10), s = rand(0.8, 1),
            kind = kinds[#world.trees % #kinds + 1], f = love.math.random() < 0.5 and -1 or 1 }
        local ok = not mare.inPond(tree.x, tree.y, 70)
        for _, other in ipairs(world.trees) do
            if dist(tree, other) < 170 then ok = false end
        end
        if ok then table.insert(world.trees, tree) end
        if #world.trees >= 12 then break end
    end
    for _ = 1, 110 do
        table.insert(world.flowers, { x = rand(0, HILL_X), y = rand(TOP, world.H),
            color = FLOWER_COLORS[love.math.random(#FLOWER_COLORS)] })
    end
    for _ = 1, 14 do
        table.insert(world.mushrooms, { x = rand(250, HILL_X - 30), y = rand(TOP + 20, world.H - 10) })
    end
    -- the stone wall along the hill: random stones stacked from top to bottom
    world.wall = {}
    if art.image("pierre1") then
        local y = -6
        while y < world.H + 30 do
            local name = "pierre" .. love.math.random(8)
            local im = art.image(name)
            if im then
                local w = rand(28, 40)
                local h = w * im:getHeight() / im:getWidth()
                y = y + math.max(12, h * 0.7)
                table.insert(world.wall, { name = name, x = HILL_X - 4 + rand(-3, 3), y = y, w = w,
                    f = love.math.random() < 0.5 and -1 or 1 })
            end
        end
    end

    -- the drawn forest things, if their images exist
    world.props = {}
    if art.image("fleurs") then
        for _ = 1, art.image("herbe") and 50 or 75 do
            local prop = { name = art.randomProp(), x = rand(20, HILL_X - 25),
                y = rand(TOP + 15, world.H - 5), f = love.math.random() < 0.5 and -1 or 1, s = rand(0.85, 1.15) }
            if not mare.inPond(prop.x, prop.y, 15) then table.insert(world.props, prop) end
        end
        table.sort(world.props, function(a, b) return a.y < b.y end)
    end

end

-- Actions ------------------------------------------------------------------------

local tryGrab, followTrail

local function kidOf(p)
    for _, k in ipairs(world.kids) do
        if k.player == p then return k end
    end
end

local function releaseFollowers(k)
    for _, a in ipairs(k.followers) do
        a.state, a.leader = "free", nil
        a.tx, a.ty, a.wait = a.x, a.y, rand(1, 2)
    end
    k.followers = {}
end

local function stopFollowing(a)
    for _, k in ipairs(world.kids) do
        for i, b in ipairs(k.followers) do
            if b == a then table.remove(k.followers, i) return end
        end
    end
end

-- Call the nearest animal (or catch the nearest fish). `fresh`: the button was
-- just pressed (not held), so a "no room" warning is shown.
local GRAB_REPEAT = 0.35   -- seconds between two grabs while the button is held
tryGrab = function(k, fresh)
    k.grabWait = GRAB_REPEAT
    if events.tryGrab(k) then return end
    local caught = mare.tryCatch(k)
    if caught == true then return end
    local best, bestD
    for _, a in ipairs(world.animals) do
        if a.state == "free" or a.state == "scared" or a.state == "back" then
            local d = dist(k, a)
            if d < k.look.reach and (not bestD or d < bestD) then best, bestD = a, d end
        end
    end
    if caught == "full" or (best and #k.followers + k.fish >= k.look.carry) then
        if fresh then sfx.play("full"); journal.log("plein", { joueur = k.player }) end   -- "bonk"
        return
    end
    -- inside a pen: take an animal back out (a fox put with the hens...), only
    -- on a real press: holding the button must not empty the pen
    if not best and fresh then
        local here = penAt(k)
        for _, a in ipairs(world.animals) do
            if here and a.state == "home" and a.pen == here then
                local d = dist(k, a)
                if d < k.look.reach and (not bestD or d < bestD) then best, bestD = a, d end
            end
        end
        if best and #k.followers + k.fish >= k.look.carry then
            if fresh then sfx.play("full"); journal.log("plein", { joueur = k.player }) end
            return
        end
    end
    if not best then return end
    journal.log(best.state == "home" and "ressorti" or "attrape",
        { joueur = k.player, animal = best.kind, enclos = best.pen, dore = best.golden or nil,
          x = math.floor(best.x), y = math.floor(best.y) })
    best.pen = nil
    best.vx, best.vy = 0, 0
    best.state = "follow"
    table.insert(k.followers, best)
    table.insert(world.particles, { heart = true, x = best.x, y = best.y - 40,
        vx = 0, vy = -50, r = 1, life = 0.8, max = 0.8 })
    sfx.play("grab_" .. best.kind)       -- each animal has its own voice
end

function world.action(p, action)
    if world.phase == "results" then
        if action == "grab" or action == "start" then world.done = true end
        return
    end
    if world.phase ~= "play" then return end
    local k = kidOf(p)
    if not k or k.burn > 0 then return end

    if action == "grab" then
        tryGrab(k, true)
    elseif action == "drop" and events.drop(k) then
        return
    elseif action == "drop" and #k.followers > 0 then
        journal.log("lache", { joueur = k.player, animal = k.followers[#k.followers].kind })
        -- let go of one animal only (the last in line), not all of them
        local a = table.remove(k.followers)
        a.state, a.tx, a.ty, a.wait = "free", a.x, a.y, rand(1, 2)
        sfx.play("drop")
    end
end

-- Update -------------------------------------------------------------------------

local function moveToward(o, x, y, speed, dt)
    local dx, dy = x - o.x, y - o.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d < 2 then return false end
    local step = math.min(d, speed * dt)
    o.x, o.y = o.x + dx / d * step, o.y + dy / d * step
    if math.abs(dx) > 2 then o.facing = dx > 0 and 1 or -1 end
    o.walk = o.walk + dt * 12
    o.moving = speed
    return true
end

local setAnim

-- The animal runs off the screen (it comes back later). `scared`: it was not
-- burned, just frightened, so no smoke on its bottom and no sound.
local function burnAnimal(a, scared)
    if not scared then a.burns = (a.burns or 0) + 1 end
    journal.log(scared and "effraye" or "brule", { animal = a.kind, x = math.floor(a.x), y = math.floor(a.y) })
    stopFollowing(a)
    a.state = "flee"
    a.scared = scared
    a.vy = a.y < world.H / 2 and -260 or 260
    a.facing = 1
    if not scared then sfx.play("burn") end
end

function setAnim(o, name)
    if o.anim ~= name then o.anim, o.animT = name, 0 end
end

local function updateKid(k, dt)
    k.animT = k.animT + dt
    k.cheer = math.max(0, k.cheer - dt)
    k.grabWait = math.max(0, (k.grabWait or 0) - dt)
    -- holding the grab button keeps calling animals, one after the other
    if world.phase == "play" and k.burn <= 0 and k.grabWait == 0 and input.held(k.player, "grab") then
        tryGrab(k, false)
    end
    if k.burn > 0 then
        -- Ouch! Bounce away from the lava.
        k.burn = k.burn - dt
        k.x = k.x + 190 / math.max(0.6, art.duration(k.look.id, "aie") or 0.6) * dt
        blockByTrees(k)
        if love.math.random() < dt * 20 then smoke(k.x - 10, k.y - 20) end
        return
    end
    local dx, dy = input.move(k.player)
    local len = math.sqrt(dx * dx + dy * dy)
    if len > 1 then dx, dy = dx / len, dy / len end
    local leading = #k.followers > 0 or k.fish > 0
    local px, py = k.x, k.y
    local speed = (leading and KID_WALK_SPEED or KID_SPEED) * k.look.speed
    if k.holdingBig then speed = speed * 0.7 end
    k.x = clamp(k.x + dx * speed * dt, 20, world.W - 20)
    k.y = clamp(k.y + dy * speed * dt, TOP + 20, world.H - 8)
    -- footprints: the followers walk along this trail, in a neat line
    k.trail = k.trail or {}
    local last = k.trail[1]
    if not last or (k.x - last.x) ^ 2 + (k.y - last.y) ^ 2 > 16 then
        table.insert(k.trail, 1, { x = k.x, y = k.y })
        if #k.trail > 400 then table.remove(k.trail) end
    end
    blockByTrees(k)
    blockByFences(k, px, py)
    mare.block(k, BODY)
    if len > 0.1 then
        k.walk = k.walk + dt * 12
        if math.abs(dx) > 0.1 then k.facing = dx > 0 and 1 or -1 end
    else
        k.walk = 0
    end
    if k.cheer > 0 then setAnim(k, "saut")
    elseif len > 0.1 then setAnim(k, leading and "marche" or "course")
    else setAnim(k, "repos") end

    if world.phase == "play" and inLava(k, 12) then
        k.burn = 0.6
        setAnim(k, "aie")
        -- the animals following them get scared and run away
        local scared = k.followers
        k.followers = {}
        for _, a in ipairs(scared) do burnAnimal(a, true) end
        mare.dropFish(k)
        journal.log("aie", { joueur = k.player, perdus = #k.followers + k.fish,
            x = math.floor(k.x), y = math.floor(k.y) })
        k.burn = math.min(1.4, art.duration(k.look.id, "aie") or 0.6)
        sfx.play("burn")
    end

    -- Walk into a pen: the animals following you go inside.
    -- Walk into a pen: the animals following you go inside (only when you
    -- arrive, so an animal you take back out doesn't go straight back in).
    local pen = penAt(k)
    local arriving = pen and pen ~= k.lastPen
    k.lastPen = pen
    if arriving and #k.followers > 0 then
        for _, a in ipairs(k.followers) do
            journal.log("depose", { joueur = k.player, animal = a.kind, enclos = pen, dore = a.golden or nil })
            a.state, a.pen, a.wait = "home", pen, rand(0.5, 1.5)
            a.tx, a.ty = a.x, a.y
            -- a baby joining its mama counts double (+2), with more hearts
            local reunited = world.big and world.big.state == "home" and world.big.pen == pen
                and world.big.family == a.kind
            popup("+" .. ((a.value or 1) + (reunited and 1 or 0)), a.x, a.y - 40, { 1, 0.4, 0.5 }, true)
            if reunited then
                for _ = 1, 4 do
                    table.insert(world.particles, { heart = true, x = a.x + rand(-15, 15), y = a.y - 30,
                        vx = rand(-20, 20), vy = rand(-80, -40), r = rand(0.6, 1), life = 1.4, max = 1.4 })
                end
            end
            for _ = 1, 3 do
                table.insert(world.particles, { heart = true, x = a.x + rand(-15, 15), y = a.y - 30,
                    vx = rand(-20, 20), vy = rand(-70, -40), r = rand(0.6, 1), life = 1.2, max = 1.2 })
            end
        end
        k.followers = {}
        k.cheer = math.min(1.8, art.duration(k.look.id, "saut") or 0)
        sfx.play("home")
    end
end

-- Where follower number i should be: FOLLOW_GAP pixels behind the one in front,
-- measured along the kid's footprints (so the line takes the same turns).
local FOLLOW_FIRST, FOLLOW_GAP = 42, 40
local function trailPoint(k, along)
    local px, py = k.x, k.y
    for _, p in ipairs(k.trail or {}) do
        local d = math.sqrt((p.x - px) ^ 2 + (p.y - py) ^ 2)
        if d >= along then
            local u = along / d
            return px + (p.x - px) * u, py + (p.y - py) * u
        end
        along = along - d
        px, py = p.x, p.y
    end
    return px, py
end

-- Smooth following: the animal's speed eases toward where it should be (no
-- stop-and-go), it only turns around when it really goes the other way, and
-- its walk / run animation changes with some margin (no flickering).
followTrail = function(a, k, i, dt)
    local tx, ty = trailPoint(k, FOLLOW_FIRST + (i - 1) * FOLLOW_GAP)
    local dx, dy = tx - a.x, ty - a.y
    local wantX, wantY = dx * 7, dy * 7                 -- faster when further behind
    local w = math.sqrt(wantX * wantX + wantY * wantY)
    if w > 380 then wantX, wantY = wantX / w * 380, wantY / w * 380 end
    local blend = 1 - math.exp(-10 * dt)
    a.vx = (a.vx or 0) + (wantX - (a.vx or 0)) * blend
    a.vy = (a.vy or 0) + (wantY - (a.vy or 0)) * blend
    a.x, a.y = a.x + a.vx * dt, a.y + a.vy * dt
    local v = math.sqrt(a.vx * a.vx + a.vy * a.vy)
    if math.abs(a.vx) > 30 then a.facing = a.vx > 0 and 1 or -1 end
    a.walk = a.walk + dt * v / 20
    -- animation, with hysteresis: run above 190, walk above 22, else stand
    local cur = a.anim
    if v > 190 or (cur == "course" and v > 140) then a.moving = 200
    elseif v > 22 or (cur ~= "repos" and v > 10) then a.moving = 100
    else a.moving = false; a.walk = 0 end
end

local function wander(a, dt, minX, maxX, minY, maxY, speed)
    a.wait = a.wait - dt
    if a.wait <= 0 then
        a.tx = clamp(a.x + rand(-120, 120), minX, maxX)
        a.ty = clamp(a.y + rand(-120, 120), minY, maxY)
        a.wait = rand(2, 4)
    end
    if not moveToward(a, a.tx, a.ty, speed, dt) then a.walk = 0 end
end

local function updateAnimal(a, dt)
    a.moving = false
    a.animT = (a.animT or 0) + dt
    if a.state == "free" then
        if not events.shy(a, dt) then wander(a, dt, 60, HILL_X - 40, TOP + 30, world.H - 20, 40) end
    elseif a.state == "follow" then
        for _, k in ipairs(world.kids) do
            for i, b in ipairs(k.followers) do
                if b == a then followTrail(a, k, i, dt) end
            end
        end
    elseif a.state == "home" then
        local r = PENS[a.pen]
        wander(a, dt, r.x + 30, r.x + r.w - 90, r.y + 50, r.y + r.h - 20, 30)
    elseif a.state == "scared" then
        if not moveToward(a, a.tx, a.ty, 220, dt) then
            a.state, a.wait = "free", rand(1, 2)
        end
    elseif a.state == "flee" then
        a.x = a.x + 90 * dt
        a.y = a.y + a.vy * dt
        a.walk = a.walk + dt * 20
        if not a.scared and love.math.random() < dt * 25 then smoke(a.x - 12, a.y - 10) end
        if a.y < -60 or a.y > world.H + 60 then
            if (a.burns or 0) >= 2 then
                -- burned a second time: it doesn't come back (one second chance only)
                a.state = "lost"
                journal.log("perdu", { animal = a.kind })
            else
                a.state, a.back = "gone", rand(6, 10)
                a.fromTop = a.y < 0
            end
        end
    elseif a.state == "gone" then
        -- after a while, it comes back (same side) into the safe part of the forest
        a.back = (a.back or 0) - dt
        if world.phase == "play" and a.back <= 0 then
            local ty = a.fromTop and rand(TOP + 60, TOP + 220) or rand(world.H - 220, world.H - 40)
            -- far enough from the lava all along its way in, not just where it stops
            local lo = -1e9
            for y = a.fromTop and 0 or ty, a.fromTop and ty or world.H, 10 do
                lo = math.max(lo, world.lavaX(y) + 90)
            end
            local hi = HILL_X - 60
            local tx = lo < hi and rand(lo, hi) or hi
            a.state, a.tx, a.ty = "back", tx, ty
            a.x, a.y = tx, a.fromTop and -40 or world.H + 40
        end
    elseif a.state == "back" then
        if not moveToward(a, a.tx, a.ty, 110, dt) then
            a.state, a.wait = "free", rand(1, 2)
        end
    end

    if a.state ~= "flee" and a.state ~= "gone" and a.state ~= "lost" then
        blockByTrees(a)
        mare.block(a, BODY)
    end

    if world.phase == "play" and (a.state == "free" or a.state == "follow" or a.state == "scared"
        or a.state == "back") and inLava(a, 4) then
        burnAnimal(a)
    end

    if a.state == "flee" or a.state == "scared" or (a.moving and a.moving > 150) then setAnim(a, "course")
    elseif a.moving then setAnim(a, "marche")
    else setAnim(a, "repos") end
end

-- The fox rule: a fox in the same pen as hens or squirrels scares them away.
local function checkPens(dt)
    for i, pen in ipairs(PENS) do
        local fox, prey = false, {}
        for _, a in ipairs(world.animals) do
            if a.state == "home" and a.pen == i then
                if a.kind == "renard" then fox = true end
                if PREY[a.kind] then table.insert(prey, a) end
            end
        end
        if fox and #prey > 0 then
            pen.trouble = (pen.trouble or 0) + dt
            if pen.trouble > 1.5 then
                pen.trouble = nil
                for _, a in ipairs(prey) do
                    a.state = "scared"
                    a.tx, a.ty = rand(HILL_X - 260, HILL_X - 120), clamp(a.y + rand(-80, 80), TOP + 30, world.H - 20)
                end
                sfx.play("oops")
                local kinds = {}
                for _, a in ipairs(prey) do kinds[#kinds + 1] = a.kind end
                journal.log("renard", { enclos = i, effrayes = kinds })
            end
        else
            pen.trouble = nil
        end
    end
end

local function eruption()
    journal.log("eruption", { lave = math.floor(world.lavaProgress * 100) })
    for _ = 1, love.math.random(2, 3) do addTongue() end
    world.shake = 1.2
    sfx.play("boom")
    for _ = 1, 10 do
        local tx = rand(40, world.lavaBase)
        table.insert(world.rocks, { x = 140, y = 100, sx = 140, sy = 100, tx = tx, ty = rand(TOP + 40, world.H - 20),
            t = 0, dur = rand(0.8, 1.4) })
    end
end

-- The volcano's face: calm at first and at the end, surprised just before an
-- eruption (a warning for the players), erupting while the ground shakes.
function world.volcanoMood()
    if world.phase ~= "play" or world.calm then return "calme" end
    if world.shake > 0 then return "erupt" end
    if world.nextEruption - world.time < 2.5 then return "surpris" end
    if world.time < INTRO then return "calme" end
    return "fume"
end

-- Write the end of the game in the log: how = "fin", "accueil" or "quitte".
-- Stars at the end: none if nothing was saved, then 1, 2 (50%) and 3 (80%).
local function starsFor(saved)
    local ratio = saved / world.total
    return saved <= 0 and 0 or ratio >= 0.8 and 3 or ratio >= 0.5 and 2 or 1
end

function world.logEnd(how)
    local byKind, lost = {}, {}
    for _, a in ipairs(world.animals) do
        if a.state == "home" then byKind[a.kind] = (byKind[a.kind] or 0) + 1
        else lost[a.kind] = (lost[a.kind] or 0) + 1 end
    end
    journal.finish(how, { duree = math.floor(world.time), score = world.saved(), total = world.total,
        etoiles = starsFor(world.saved()), sauves = byKind, pas_sauves = lost,
        poissons = mare.count("jar"), maman = world.big and world.big.state == "home" or false,
        lave = math.floor(world.lavaProgress * 100) })
end

-- Animals in the pens plus fish in the jars.
function world.saved()
    return world.count("home") + mare.count("jar") + events.bonus()
end

function world.count(state)
    local n = 0
    for _, a in ipairs(world.animals) do
        if a.state == state then n = n + 1 end
    end
    return n
end

local function updateEffects(dt)
    for i = #world.popups, 1, -1 do
        local p = world.popups[i]
        p.age, p.life = p.age + dt, p.life - dt
        if p.fly then
            if p.age < 0.45 then
                p.y = p.y - 50 * dt
            else                                   -- then off to the score
                local u = math.min(1, (p.age - 0.45) / 0.55)
                local e = u * u
                p.x = p.x + (SCORE_X - p.x) * e
                p.y = p.y + (SCORE_Y - p.y) * e
                if u >= 1 then p.life = 0; world.scorePop = 0.35 end
            end
        else
            p.y = p.y - 40 * dt
        end
        if p.life <= 0 then table.remove(world.popups, i) end
    end
    for i = #world.particles, 1, -1 do
        local p = world.particles[i]
        p.x, p.y, p.life = p.x + p.vx * dt, p.y + p.vy * dt, p.life - dt
        if p.life <= 0 then table.remove(world.particles, i) end
    end
    for i = #world.rocks, 1, -1 do
        local r = world.rocks[i]
        r.t = r.t + dt
        if r.t >= r.dur then
            for _ = 1, 3 do smoke(r.tx, r.ty, true) end
            table.remove(world.rocks, i)
        end
    end
    if world.banner then
        world.banner.life = world.banner.life - dt
        if world.banner.life <= 0 then world.banner = nil end
    end
    world.shake = math.max(0, world.shake - dt)
    -- embers flying up from the lava edge
    if world.phase == "play" and love.math.random() < dt * 10 then
        local y = rand(TOP, world.H)
        table.insert(world.particles, { ember = true, x = world.lavaX(y) - rand(0, 30), y = y,
            vx = rand(-10, 25), vy = rand(-90, -50), r = rand(2, 3.5), life = 1.2, max = 1.2 })
    end
    -- the volcano puffs smoke all the time
    if love.math.random() < dt * 6 then
        table.insert(world.particles, { x = 140 + rand(-20, 20), y = 95, vx = rand(5, 25), vy = rand(-30, -15),
            r = rand(12, 20), life = 2.5, max = 2.5, color = { 0.55, 0.52, 0.5 } })
    end
end

function world.update(dt)
    world.time = world.time + dt
    updateEffects(dt)

    if world.phase == "play" then
        local progress = world.calm and 0 or lavaProgress(world.time)
        world.lavaProgress = progress
        world.lavaBase = LAVA_START + (LAVA_END - LAVA_START) * progress
        updateLavaFront()
        -- the volcano rumbles (and makes its surprised face) just before
        if not world.calm and not world.warned and world.nextEruption - world.time < 2.2 then
            world.warned = true
            sfx.play("rumble")
        end
        if not world.calm and world.time >= world.nextEruption then
            world.warned = false
            world.duck = 1.5
            eruption()
            world.nextEruption = world.nextEruption + ERUPTION_EVERY
        end
        local left = world.count("free") + world.count("follow") + world.count("scared")
            + world.count("gone") + world.count("back") + mare.count("swim") + mare.count("carried")
            + events.left()
        if not world.calm and progress >= 1 then
            world.phase = "calm"
            world.calmTimer = 3
        elseif left == 0 then
            world.phase = "calm"
            world.calmTimer = 2
        end
    elseif world.phase == "calm" then
        world.calmTimer = world.calmTimer - dt
        if world.calmTimer <= 0 then
            world.phase = "results"
            world.resultsTime = 0
            world.logEnd("fin")
            sfx.play(world.saved() > 0 and "win" or "oops")
            world.duck = 3
        end
    elseif world.phase == "results" then
        world.resultsTime = world.resultsTime + dt
    end

    for _, tr in ipairs(world.trees) do
        if not tr.burnt and inLava(tr, -10) then
            tr.burnt = true
            for _ = 1, 8 do smoke(tr.x + rand(-30, 30), tr.y - rand(20, 100), true) end
        end
    end

    for _, k in ipairs(world.kids) do updateKid(k, dt) end
    separateKids()
    mare.update(dt)
    for _, a in ipairs(world.animals) do updateAnimal(a, dt) end
    events.update(dt)
    if world.phase == "play" then journal.tick(world.kids) end
    if world.phase == "play" then checkPens(dt) end
end

-- Drawing ------------------------------------------------------------------------

local function outlined(text, font, x, y, w, color)
    g.setFont(font)
    g.setColor(0.15, 0.08, 0.05, 0.85)
    for i = 0, 11 do   -- a round outline, smooth at any resolution
        local a = i / 12 * math.pi * 2
        g.printf(text, x + math.cos(a) * 2.2, y + math.sin(a) * 2.2, w, "center")
    end
    g.setColor(color or { 1, 1, 1 })
    g.printf(text, x, y, w, "center")
end

local function ground()
    local grass = art.grass(world.W, world.H, GRASS_TILE)
    if not grass then
        g.setColor(0.5, 0.75, 0.35)
        g.rectangle("fill", 0, 0, world.W, world.H)
        -- soft lighter patches
        g.setColor(0.56, 0.8, 0.4)
        for i = 0, 12 do
            g.ellipse("fill", (i * 173) % 1000 + 40, (i * 251) % 640 + 80, 90, 50)
        end
    end
    -- the hill: lighter, and over the grass drawing if there is one
    if grass then g.setColor(1, 1, 0.75, 0.3) else g.setColor(0.62, 0.82, 0.45) end
    g.rectangle("fill", HILL_X, 0, world.W - HILL_X, world.H)
    if #world.wall > 0 then
        -- the little dry-stone wall at the foot of the hill
        g.setColor(1, 1, 1)
        for _, st in ipairs(world.wall) do
            local im = art.image(st.name)
            local sc = st.w / im:getWidth()
            g.draw(im, st.x, st.y, 0, sc * st.f, sc, im:getWidth() / 2, im:getHeight())
        end
    else
        g.setColor(0.55, 0.47, 0.38)
        g.rectangle("fill", HILL_X - 12, 0, 16, world.H)
        g.setColor(0.65, 0.58, 0.5)
        for y = 10, world.H, 34 do g.circle("fill", HILL_X - 5 + (y % 3) * 3, y, 9) end
    end
    if #world.props > 0 then
        for _, p in ipairs(world.props) do art.prop(p.name, p.x, p.y, p.f, p.s) end
    else
        for _, f in ipairs(world.flowers) do art.flower(f.x, f.y, f.color) end
        for _, m in ipairs(world.mushrooms) do art.mushroom(m.x, m.y) end
    end
end

local function lava()
    lave.draw(world.lavaX, world.time, world.H)
end

local function drawKid(k)
    local hop = 0
    if not art.anims(k.look.id) and k.burn > 0 then hop = math.abs(math.sin(k.burn * 12)) * 20 end
    art.kid(k.look, k.x, k.y - hop, k.facing, 1.25, k.walk, k.anim, k.animT)
    mare.drawNet(k, 115 * k.look.size)
    if #world.kids > 1 then
        outlined(T("player") .. k.player, fonts.small, k.x - 30, k.y - 120 * k.look.size - hop, 60,
            k.player == 1 and { 1, 0.75, 0.3 } or { 0.5, 0.8, 1 })
    end
end

local function drawAnimal(a)
    local hop = 0
    if not art.anims(a.kind) and not art.image(a.kind) then
        if a.state == "flee" then hop = math.abs(math.sin(a.walk)) * 14
        elseif a.walk > 0 then hop = math.abs(math.sin(a.walk)) * 3 end
    end
    art.animal(a.kind, a.x, a.y - hop, a.facing, 1.2, true, a.anim, a.animT)
    events.drawGold(a, function() art.animal(a.kind, a.x, a.y - hop, a.facing, 1.2, false, a.anim, a.animT) end)
    if a.state == "home" and a.pen and PENS[a.pen].trouble and PREY[a.kind] then
        outlined("!", fonts.big, a.x - 20, a.y - 85, 40, { 1, 0.3, 0.2 })
    end
end

-- At the top: a heart and the score in big numbers (no words: the kids can't
-- read yet), and the 3 stars of the end, lighting up as the score grows.
local STAR_AT = { 0, 0.5, 0.8 }          -- same thresholds as the end screen
local function hud()
    local score = world.saved()
    world.scorePop = math.max(0, (world.scorePop or 0) - love.timer.getDelta())
    local pop = 1 + 0.35 * math.sin(math.min(1, (world.scorePop or 0) / 0.35) * math.pi)
    g.setColor(0.2, 0.12, 0.08, 0.7)
    g.rectangle("fill", SCORE_X - 175, 6, 340, 62, 22)
    art.heart(SCORE_X - 140, SCORE_Y - 2, 1.6)
    g.push()
    g.translate(SCORE_X - 45, SCORE_Y)        -- the number grows a little when it changes
    g.scale(pop)
    outlined(tostring(score), fonts.huge, -70, -38, 140, { 1, 0.85, 0.85 })
    g.pop()
    -- the stars: light up when a threshold is reached (with a burst)
    world.starsLit = world.starsLit or 0
    local ratio = score / world.total
    for i = 1, 3 do
        local lit = i == 1 and score > 0 or (i > 1 and ratio >= STAR_AT[i])
        if lit and i > world.starsLit then
            world.starsLit = i
            world.starFlash = { i = i, t = 0.6 }
            sfx.play("sparkle")
        end
        local x = SCORE_X + 62 + (i - 1) * 34
        local r = 13
        if world.starFlash and world.starFlash.i == i and world.starFlash.t > 0 then
            r = r * (1 + 0.8 * world.starFlash.t)
        end
        art.star(x, SCORE_Y, r, lit)
    end
    if world.starFlash then world.starFlash.t = world.starFlash.t - love.timer.getDelta() end
end

local function results()
    g.setColor(0, 0, 0, 0.55)
    g.rectangle("fill", 0, 0, world.W, world.H)
    g.setColor(0.98, 0.94, 0.82)
    g.rectangle("fill", 190, 70, 900, 580, 30)
    g.setColor(0.6, 0.4, 0.2)
    g.setLineWidth(6)
    g.rectangle("line", 190, 70, 900, 580, 30)

    local saved = world.saved()
    local stars = starsFor(saved)
    local title = T("win" .. stars)
    outlined(title, fonts.huge, 190, 95, 900, { 1, 0.8, 0.2 })
    for i = 1, 3 do
        local appear = clamp((world.resultsTime - i * 0.4) * 4, 0, 1)
        art.star(640 + (i - 2) * 110, 230, 45 * (i <= stars and appear or 1), i <= stars and appear > 0)
    end
    -- the score, big, with a heart (no sentence: the kids can't read yet)
    art.heart(530, 318, 2.2)
    outlined(saved .. " / " .. world.total, fonts.huge, 530, 280, 330, { 1, 0.45, 0.5 })

    -- the saved animals, lined up (the golden one shines)
    local shown = 0
    for _, a in ipairs(world.animals) do
        if a.state == "home" and shown < 36 then
            local col, row = shown % 12, math.floor(shown / 12)
            local x, y = 330 + col * 56, 410 + row * 60
            if a.golden then
                art.animal(a.kind, x, y, 1, 1.05)
                events.drawGold({ golden = true, x = x, y = y }, function() art.animal(a.kind, x, y, 1, 1.05, false) end)
                outlined("+" .. events.GOLD_VALUE, fonts.small, x - 30, y - 62, 60, { 1, 0.8, 0.2 })
            else
                art.animal(a.kind, x, y, 1, 1.05)
            end
            shown = shown + 1
        end
    end
    -- the saved fish, in a row under the animals
    local nf = 0
    local fy = 410 + math.max(1, math.ceil(shown / 12)) * 60
    for _, f in ipairs(world.fish) do
        if f.state == "jar" then
            mare.drawFish(340 + nf * 42, fy - 10, 1, 1.4, f, world.time * 6 + nf)
            nf = nf + 1
        end
    end
    -- the big mama, if she was saved: big, with her points
    if world.big and world.big.state == "home" then
        local name = "maman_" .. world.big.family
        local bob = math.abs(math.sin(world.time * 3)) * 6
        if art.image(name) then art.animal(name, 870, 615 - bob, -1, 1.0)
        else art.animal(world.big.family, 870, 615 - bob, -1, 2.2) end
        outlined("+" .. events.BIG_VALUE, fonts.big, 900, 470 - bob, 100, { 1, 0.45, 0.5 })
    end
    for i, k in ipairs(world.kids) do
        art.kid(k.look, 250 + (i - 1) * 780, 620, i == 1 and 1 or -1, 1.6,
            0, saved > 0 and "saut" or "repos", world.time % ((art.duration(k.look.id, "saut") or 1) + 0.6))
    end
    art.hint({ "@a", T("again_short") }, world.W / 2, 610, fonts.mid)
end

function world.draw()
    g.push()
    if world.shake > 0 then
        g.translate(rand(-6, 6) * world.shake, rand(-6, 6) * world.shake)
    end

    ground()
    mare.drawPond(world.time)
    for _, r in ipairs(PENS) do art.pen(r) end
    mare.drawJarHut(world.time)
    lava()
    art.volcano(140, 300, world.time, world.shake, world.volcanoMood())

    -- everything with feet, back to front
    local things = {}
    for _, tr in ipairs(world.trees) do table.insert(things, { y = tr.y, tree = tr }) end
    for _, a in ipairs(world.animals) do
        if a.state ~= "gone" and a.state ~= "lost" then table.insert(things, { y = a.y, animal = a }) end
    end
    for _, k in ipairs(world.kids) do table.insert(things, { y = k.y, kid = k }) end
    if world.big and world.big.y then table.insert(things, { y = world.big.y, big = true }) end
    table.sort(things, function(a, b) return a.y < b.y end)
    for _, o in ipairs(things) do
        if o.tree then
            art.tree(o.tree.x, o.tree.y, o.tree.s, o.tree.burnt, o.tree.kind, o.tree.f)
        elseif o.animal then
            drawAnimal(o.animal)
        elseif o.big then
            events.drawBig()
        else
            drawKid(o.kid)
        end
    end

    for _, r in ipairs(world.rocks) do
        local p = r.t / r.dur
        local x = r.sx + (r.tx - r.sx) * p
        local y = r.sy + (r.ty - r.sy) * p - math.sin(p * math.pi) * 200
        g.setColor(0.3, 0.2, 0.15)
        g.circle("fill", x, y, 9)
        g.setColor(1, 0.6, 0.1)
        g.circle("fill", x - 2, y - 2, 4)
    end
    for _, p in ipairs(world.particles) do
        local a = p.life / p.max
        if p.star then
            art.star(p.x, p.y, p.r * a, true)
        elseif p.splash then
            g.setColor(0.75, 0.9, 1, a)
            g.circle("fill", p.x, p.y, p.r)
        elseif p.heart then
            art.heart(p.x, p.y, p.r, { 1, 0.35, 0.45, a })
        elseif p.ember then
            g.setColor(1, 0.7 + 0.3 * a, 0.2, a)
            g.circle("fill", p.x, p.y, p.r)
        else
            g.setColor(p.color[1], p.color[2], p.color[3], a * 0.8)
            g.circle("fill", p.x, p.y, p.r * (1.5 - a * 0.5))
        end
    end
    mare.drawLeaping()
    for _, p in ipairs(world.popups) do
        outlined(p.text, p.big and fonts.big or fonts.mid, p.x - 200, p.y, 400, p.color)
    end
    g.pop()

    hud()
    if world.banner then
        g.setColor(0.2, 0.12, 0.08, 0.7)
        g.rectangle("fill", 300, 100, world.W - 330, 70, 20)
        outlined(world.banner.text, fonts.mid, 300, 120, world.W - 330, world.banner.color)
    end
    if world.phase == "results" then results() end
end

return world
