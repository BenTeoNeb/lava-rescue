-- Sauve les Animaux ! The volcano is waking up: bring the forest animals
-- to the pens on the hill before the lava arrives. 1 or 2 players, together.

local input = require("input")
local sfx = require("sfx")
local art = require("art")
local world = require("world")
local musique = require("musique")
local lang = require("lang")
local T = lang.t

-- Sound on/off (music and sound effects together): off by default,
-- Select on the controller (or M on the keyboard) switches it.
local soundOn = false
local function setSound(on)
    soundOn = on
    love.audio.setVolume(on and 1 or 0)
end

local W, H = 1280, 720
local g = love.graphics
local state = "select"
local calmMode = false    -- calm mode: the volcano sleeps (chosen in the menu)
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
    world.start(chosen, calmMode)
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
    elseif action == "grab" then
        me.ready = true
        sfx.play("ready")
        startIfReady()
    elseif action == "drop" then
        if me.ready then me.ready = false
        elseif p == 2 then me.joined = false end
    end
end

-- The menu (Start): pauses the game. Up/down to move, bottom button to choose,
-- Start or the right button to close it.
local menu = nil          -- { sel = n } while the menu is open
local drawMenu
local menuStickOut = {}

local function menuItems()
    local items = { "resume" }
    if state == "play" then table.insert(items, "to_title") end
    if state == "select" then table.insert(items, "mode") end
    table.insert(items, "fullscreen")
    table.insert(items, "sound")
    table.insert(items, "language")
    table.insert(items, "quit")
    return items
end

local function menuLabel(item)
    if item == "mode" then return T(calmMode and "mode_calme" or "mode_volcan") end
    if item == "fullscreen" then return T(love.window.getFullscreen() and "fullscreen_on" or "fullscreen_off") end
    if item == "sound" then return T(soundOn and "sound_on" or "sound_off") end
    if item == "language" then return T("language_item") end
    return T(item)
end

local function openMenu()
    menu = { sel = 1 }
    sfx.play("select")
end

local function menuChoose()
    local item = menuItems()[menu.sel]
    sfx.play("select")
    if item == "resume" then
        menu = nil
    elseif item == "to_title" then
        menu = nil
        resetSelect()
        state = "select"
    elseif item == "mode" then
        calmMode = not calmMode
    elseif item == "fullscreen" then
        love.window.setFullscreen(not love.window.getFullscreen(), "desktop")
    elseif item == "sound" then
        setSound(not soundOn)
    elseif item == "language" then
        lang.toggle()
    elseif item == "quit" then
        love.event.quit()
    end
end

local function menuAction(action)
    local n = #menuItems()
    if action == "up" then
        menu.sel = (menu.sel - 2) % n + 1
        sfx.play("select")
    elseif action == "down" then
        menu.sel = menu.sel % n + 1
        sfx.play("select")
    elseif action == "grab" then
        menuChoose()
    elseif action == "start" or action == "drop" then
        menu = nil
    end
end

local makeFonts

-- Make the fonts for the real size of the screen: the 1280x720 picture is
-- scaled up (x3 in 4K), and on Retina screens there are 2 pixels per point.
local fontScale
makeFonts = function()
    local w, h = g.getDimensions()
    local s = math.min(w / W, h / H) * g.getDPIScale()
    if fontScale and math.abs(s - fontScale) < 0.01 then return end
    fontScale = s
    art.fontScale = s
    art.resetFonts()
    fonts.title = art.font(64)
    fonts.big = art.font(36)
    fonts.mid = art.font(24)
    fonts.small = art.font(20)
    world.makeFonts()
end

function love.resize()
    makeFonts()
end

function love.load()
    sfx.load()
    world.load()
    musique.load()
    art.preload()
    setSound(false)
    makeFonts()
    resetSelect()
    for _, js in ipairs(love.joystick.getJoysticks()) do
        input.joystickadded(js)
    end
end

function love.update(dt)
    dt = math.min(dt, 1 / 30)
    if menu then
        for p = 1, 2 do
            local y = input.stickY(p)
            local out = math.abs(y) > 0.6
            if out and not menuStickOut[p] then menuAction(y > 0 and "down" or "up") end
            menuStickOut[p] = out
        end
        return
    end
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
    for i = 0, 11 do   -- a round outline, smooth at any resolution
        local a = i / 12 * math.pi * 2
        g.printf(text, x + math.cos(a) * 2.2, y + math.sin(a) * 2.2, w, "center")
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

    outlined(T("title"), fonts.title, 0, 30, W, { 1, 0.85, 0.3 })
    outlined(T("choose"), fonts.mid, 0, 110, W)

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
        outlined(T(k.trait), fonts.small, x - 160, 528, 320, { 1, 0.95, 0.6 })
        local bolts = k.speed > 1.1 and 3 or k.speed < 0.95 and 1 or 2
        for b = 1, bolts do art.bolt(x - 100 + (b - 1) * 22, 578, 1.5) end
        for c = 1, k.carry do art.animal("poule", x - 18 + (c - 1) * 30, 598, 1, 0.8, false) end
        if k.reach > 100 then art.heart(x + 100, 574, 1.3) end
        for p = 1, 2 do
            local me = pick[p]
            if me.joined and me.choice == i then
                outlined(T("player") .. p .. (me.ready and "  " .. T("ready") or ""), fonts.mid, x - 110, 170, 220,
                    PLAYER_COLORS[p])
            end
        end
    end

    -- sound on/off (View / Select button) and language (shoulder buttons), top left
    g.setColor(0.2, 0.12, 0.08, 0.6)
    g.rectangle("fill", 14, 12, 250, 38, 12)
    g.rectangle("fill", 14, 56, 250, 38, 12)
    art.glyph("view", 38, 31)
    outlined(T(soundOn and "sound_on" or "sound_off"), fonts.small, 56, 20, 200,
        soundOn and { 0.6, 1, 0.6 } or { 0.85, 0.85, 0.85 })
    g.setFont(fonts.small)
    art.glyph("lr", 56, 75, 0.75)
    -- the game mode (changed in the menu): a little volcano, awake or asleep
    g.setColor(0.2, 0.12, 0.08, 0.6)
    g.rectangle("fill", 14, 100, 250, 38, 12)
    art.volcano(42, 134, 0, 0, calmMode and "calme" or "fume", 40)
    outlined(T(calmMode and "mode_calme" or "mode_volcan"), fonts.small, 82, 108, 180,
        calmMode and { 0.6, 0.85, 1 } or { 1, 0.6, 0.3 })
    outlined(T("language"), fonts.small, 82, 64, 180, { 1, 0.95, 0.6 })
    -- how to play, with the buttons as icons
    art.hint({ "@dpad", T("choose_short"), "   ", "@a", T("go"), "   ", "@menu", T("menu_hint") },
        W / 2, 624, fonts.small)
    if not pick[2].joined then
        outlined(T("join"), fonts.small, 0, 648, W, PLAYER_COLORS[2])
    end
end

drawMenu = function()
    g.setColor(0, 0, 0, 0.55)
    g.rectangle("fill", 0, 0, W, H)
    local items = menuItems()
    local ph = 120 + #items * 62
    local py = (H - ph) / 2
    g.setColor(0.98, 0.94, 0.82)
    g.rectangle("fill", 390, py, 500, ph, 28)
    g.setColor(0.6, 0.4, 0.2)
    g.setLineWidth(6)
    g.rectangle("line", 390, py, 500, ph, 28)
    outlined(T("menu"), fonts.big, 390, py + 22, 500, { 1, 0.8, 0.2 })
    for i, item in ipairs(items) do
        local y = py + 92 + (i - 1) * 62
        if i == menu.sel then
            g.setColor(1, 0.8, 0.25)
            g.rectangle("fill", 420, y - 6, 440, 50, 16)
            g.setColor(0.6, 0.4, 0.2)
            g.setLineWidth(3)
            g.rectangle("line", 420, y - 6, 440, 50, 16)
        end
        g.setFont(fonts.mid)
        g.setColor(0.35, 0.22, 0.12)
        g.printf(menuLabel(item), 390, y + 4, 500, "center")
    end
end

function love.draw()
    makeFonts()   -- only rebuilt if the screen size changed
    -- Draw at 1280x720 and scale to fit the window.
    local w, h = g.getDimensions()
    local s = math.min(w / W, h / H)
    g.clear(0.1, 0.22, 0.1)   -- the bars around the picture (e.g. on the 16:10 Steam Deck)
    g.translate((w - W * s) / 2, (h - H * s) / 2)
    g.scale(s)
    g.setScissor((w - W * s) / 2, (h - H * s) / 2, W * s, H * s)
    if state == "select" then drawSelect() else world.draw() end
    if menu then drawMenu() end
    g.setScissor()
end

local function onAction(p, action)
    if action == "back" then setSound(not soundOn) return end   -- Select: sound on/off
    if menu then menuAction(action) return end
    if action == "lang" then                                     -- L1/R1: language
        if state == "select" then lang.toggle() end
        return
    end
    -- Start opens the menu (except on the end screen, where it plays again)
    if action == "start" and not (state == "play" and world.phase == "results") then
        openMenu()
        return
    end
    if state == "select" then selectAction(p, action) else world.action(p, action) end
end

function love.joystickadded(joystick)
    input.joystickadded(joystick)
end

function love.joystickremoved(joystick)
    input.joystickremoved(joystick)
end

function love.focus(focused)
    if not focused and state == "play" and world.phase == "play" and not menu then
        menu = { sel = 1 }
    end
end

function love.gamepadpressed(joystick, button)
    local p, action = input.gamepadpressed(joystick, button)
    if p then onAction(p, action) end
end

function love.keypressed(key)
    if key == "m" then setSound(not soundOn) return end
    if key == "l" and state == "select" then lang.toggle() return end
    local p, action = input.keypressed(key)
    if p then onAction(p, action) end
end
