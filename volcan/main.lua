-- Sauve les Animaux ! The volcano is waking up: bring the forest animals
-- to the pens on the hill before the lava arrives. 1 or 2 players, together.

local input = require("input")
local sfx = require("sfx")
local art = require("art")
local world = require("world")
local musique = require("musique")

local W, H = 1280, 720
local g = love.graphics
local state = "select"
local fonts = {}

-- Character select: each player picks Rami, Zina or Lila.
local pick = {}
local stickWasOut = {}

local function resetSelect()
    pick[1] = { joined = true, choice = 1, ready = false }
    pick[2] = { joined = false, choice = 2, ready = false }
end

local function taken(p, choice)
    local other = pick[3 - p]
    return other.joined and other.choice == choice
end

local function moveChoice(p, dir)
    local c = pick[p].choice
    repeat c = (c - 1 + dir) % #art.KIDS + 1 until not taken(p, c)
    pick[p].choice = c
    sfx.play("select")
end

local function startIfReady()
    for p = 1, 2 do
        if pick[p].joined and not pick[p].ready then return end
    end
    local chosen = {}
    for p = 1, 2 do
        if pick[p].joined then table.insert(chosen, { player = p, kid = pick[p].choice }) end
    end
    world.start(chosen)
    state = "play"
end

local function selectAction(p, action)
    local me = pick[p]
    if not me.joined then
        me.joined, me.ready = true, false
        if taken(p, me.choice) then moveChoice(p, 1) end
        sfx.play("ready")
        return
    end
    if action == "left" and not me.ready then
        moveChoice(p, -1)
    elseif action == "right" and not me.ready then
        moveChoice(p, 1)
    elseif action == "grab" or action == "start" then
        me.ready = true
        sfx.play("ready")
        startIfReady()
    elseif action == "drop" then
        if me.ready then me.ready = false
        elseif p == 2 then me.joined = false end
    end
end

function love.load()
    sfx.load()
    world.load()
    musique.load()
    fonts.title = g.newFont(64)
    fonts.big = g.newFont(36)
    fonts.mid = g.newFont(24)
    fonts.small = g.newFont(18)
    resetSelect()
    for _, js in ipairs(love.joystick.getJoysticks()) do
        input.joystickadded(js)
    end
end

function love.update(dt)
    dt = math.min(dt, 1 / 30)
    if state == "select" then
        -- let the stick move the choice too, one step per push
        for p = 1, 2 do
            local x = input.stickX(p)
            local out = math.abs(x) > 0.6
            if out and not stickWasOut[p] and pick[p].joined and not pick[p].ready then
                moveChoice(p, x > 0 and 1 or -1)
            end
            stickWasOut[p] = out
        end
        musique.speed(1)
    else
        world.update(dt)
        -- the music hurries up a little as the lava advances
        musique.speed(world.phase == "play" and 1 + 0.15 * world.lavaProgress or 1)
        if world.done then
            resetSelect()
            state = "select"
        end
    end
end

local function outlined(text, font, x, y, w, color)
    g.setFont(font)
    g.setColor(0.15, 0.08, 0.05, 0.85)
    for ox = -2, 2, 2 do
        for oy = -2, 2, 2 do g.printf(text, x + ox, y + oy, w, "center") end
    end
    g.setColor(color or { 1, 1, 1 })
    g.printf(text, x, y, w, "center")
end

local PLAYER_COLORS = { { 1, 0.7, 0.2 }, { 0.4, 0.75, 1 } }

local function drawSelect()
    local t = love.timer.getTime()
    if not art.grass(W, H, world.GRASS_TILE) then
        g.setColor(0.5, 0.75, 0.35)
        g.rectangle("fill", 0, 0, W, H)
        g.setColor(0.56, 0.8, 0.4)
        for i = 0, 12 do g.ellipse("fill", (i * 173) % 1200 + 40, (i * 251) % 640 + 80, 90, 50) end
    end
    local moods = { "calme", "surpris", "fume", "erupt" }
    art.volcano(1120, 260, t, 0.5 + 0.5 * math.sin(t * 3), moods[math.floor(t / 2) % 4 + 1])
    for i, x in ipairs({ 60, 170, 1230 }) do art.tree(x, 700, 1.1, false, ({ "chene", "sapin", "pommier" })[i]) end
    local kinds = { "poule", "ecureuil", "marcassin", "herisson", "renard" }
    for i, kind in ipairs(kinds) do
        art.animal(kind, 300 + i * 120, 714 - math.abs(math.sin(t * 4 + i)) * 6, 1, 1.0)
    end

    outlined("SAUVE LES ANIMAUX !", fonts.title, 0, 30, W, { 1, 0.85, 0.3 })
    outlined("Choisis ton personnage", fonts.mid, 0, 110, W)

    for i, k in ipairs(art.KIDS) do
        local x = 220 + (i - 1) * 320 - 60
        for p = 1, 2 do
            local me = pick[p]
            if me.joined and me.choice == i then
                local c = PLAYER_COLORS[p]
                g.setColor(c[1], c[2], c[3], 0.3)
                g.rectangle("fill", x - 110, 160, 220, 360, 24)
                g.setColor(c)
                g.setLineWidth(me.ready and 8 or 4)
                g.rectangle("line", x - 110, 160, 220, 360, 24)
            end
        end
        local bounce = 0
        for p = 1, 2 do
            if pick[p].joined and pick[p].choice == i then bounce = math.abs(math.sin(t * 5)) * 10 end
        end
        art.kid(k, x, 460 - bounce, 1, 3.0, 0)
        outlined(k.name, fonts.big, x - 110, 470, 220)

        -- what makes them special, in pictures: bolts = speed, hens = how many animals
        g.setColor(0.2, 0.12, 0.08, 0.6)
        g.rectangle("fill", x - 125, 524, 250, 82, 14)
        outlined(k.trait, fonts.small, x - 160, 528, 320, { 1, 0.95, 0.6 })
        local bolts = k.speed > 1.1 and 3 or k.speed < 0.95 and 1 or 2
        for b = 1, bolts do art.bolt(x - 100 + (b - 1) * 22, 578, 1.5) end
        for c = 1, k.carry do art.animal("poule", x - 18 + (c - 1) * 30, 598, 1, 0.8, false) end
        if k.reach > 100 then art.heart(x + 100, 574, 1.3) end
        for p = 1, 2 do
            local me = pick[p]
            if me.joined and me.choice == i then
                outlined("J" .. p .. (me.ready and "  Prêt !" or ""), fonts.mid, x - 110, 170, 220,
                    PLAYER_COLORS[p])
            end
        end
    end

    outlined("Gauche / droite pour choisir  ·  Bouton du bas : c'est parti !", fonts.small, 0, 616, W)
    if not pick[2].joined then
        outlined("Joueur 2 : appuie sur un bouton pour jouer aussi !", fonts.small, 0, 642, W, PLAYER_COLORS[2])
    end
end

function love.draw()
    -- Draw at 1280x720 and scale to fit the window.
    local w, h = g.getDimensions()
    local s = math.min(w / W, h / H)
    g.clear(0, 0, 0)
    g.translate((w - W * s) / 2, (h - H * s) / 2)
    g.scale(s)
    g.setScissor((w - W * s) / 2, (h - H * s) / 2, W * s, H * s)
    if state == "select" then drawSelect() else world.draw() end
    g.setScissor()
end

local function onAction(p, action)
    if state == "select" then selectAction(p, action) else world.action(p, action) end
end

function love.joystickadded(joystick)
    input.joystickadded(joystick)
end

function love.joystickremoved(joystick)
    input.joystickremoved(joystick)
end

function love.gamepadpressed(joystick, button)
    local p, action = input.gamepadpressed(joystick, button)
    if p then onAction(p, action) end
end

function love.keypressed(key)
    local p, action = input.keypressed(key)
    if p then onAction(p, action) end
end
