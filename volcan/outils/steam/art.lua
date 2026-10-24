-- Makes the Steam library artwork from the game's own drawing (a game in
-- progress: the lava, the volcano, the animals, two kids), saved in the
-- game's save folder:
--   steam_cover.png  600x900   (the library's portrait capsule)
--   steam_wide.png   920x430   (the wide capsule, and recent games)
--   steam_hero.png   1920x620  (the banner at the top of the game's page)
--   steam_logo.png   1280x400  (the title, transparent, shown over the hero)
-- Copy them into outils/linux/steam/: build.sh puts them in the Linux
-- package and install.sh gives them to Steam.
--   /Applications/love.app/Contents/MacOS/love volcan --steam-art
-- (main.lua loads this file after its own code when it sees --steam-art)
function love.errorhandler(msg) print("ERROR", msg, debug.traceback("", 2)); os.exit(1) end
local world = require("world")
local g = love.graphics
local gameLoad = love.load
love.focus = function() end

local W, H, S = 1280, 720, 3          -- the scene, drawn 3x (3840x2160)
local scene

-- the title, centered in a box w wide at (x, y), never wider than the box
local function title(font, x, y, w, scale, text)
    text = text or "Lava Rescue!"
    local widest = 0
    for line in (text .. "\n"):gmatch("(.-)\n") do widest = math.max(widest, font:getWidth(line)) end
    scale = math.min(scale, (w - 20) / (widest + 20))
    g.push()
    g.translate(x, y)
    g.scale(scale)
    g.setFont(font)
    g.setColor(0.15, 0.08, 0.05, 0.9)
    for i = 0, 15 do
        local a = i / 16 * math.pi * 2
        g.printf(text, math.cos(a) * 7, math.sin(a) * 7, w / scale, "center")
    end
    g.setColor(1, 0.78, 0.2)
    g.printf(text, 0, 0, w / scale, "center")
    g.pop()
end

local function save(canvas, name)
    canvas:newImageData():encode("png", name)
    print("OK " .. love.filesystem.getSaveDirectory() .. "/" .. name)
end

-- a crop of the scene (sx, sy, sw, sh in scene pixels) into a w x h canvas
local function crop(w, h, sx, sy, sw, sh)
    local c = g.newCanvas(w, h, { dpiscale = 1 })
    g.setCanvas(c)
    g.clear(0, 0, 0, 1)
    g.setColor(1, 1, 1)
    g.draw(scene, -sx * w / sw, -sy * h / sh, 0, w / sw, h / sh)
    return c
end

function love.load()
    gameLoad()
    love.audio.setVolume(0)
    love.math.setRandomSeed(5)
    math.randomseed(5)
    world.start({ { player = 1, kid = 1 }, { player = 2, kid = 2 } }, false)
    for _ = 1, 30 * 14 do world.update(1 / 30) end
    world.noHud, world.popups, world.banner, world.shake = true, {}, nil, 0

    scene = g.newCanvas(W * S, H * S, { dpiscale = 1 })
    g.setCanvas({ scene, stencil = true })
    g.clear(0, 0, 0, 1)
    g.push()
    g.scale(S)
    world.draw()
    g.pop()
    g.setCanvas()

    local big = g.newFont(160, "normal", 1)
    local hero = crop(1920, 620, 0, 120, 3840, 3840 * 620 / 1920)     -- (the volcano's face in)
    g.setCanvas(); save(hero, "steam_hero.png")
    local sh = 3840 * 430 / 920
    local wide = crop(920, 430, 0, (H * S - sh) / 2, 3840, sh)
    g.setCanvas(wide)
    g.setColor(0, 0, 0, 0.3)
    g.rectangle("fill", 0, 0, 920, 140)
    title(big, 0, 22, 920, 0.6)
    g.setCanvas(); save(wide, "steam_wide.png")
    -- portrait cover: the volcano and the edge of the lava, the title on top
    local cw = H * S * 600 / 900
    local cover = crop(600, 900, 0, 0, cw, H * S)
    g.setCanvas(cover)
    g.setColor(0, 0, 0, 0.35)
    g.rectangle("fill", 0, 620, 600, 280)
    title(big, 0, 640, 600, 0.75, "Lava\nRescue!")
    g.setCanvas(); save(cover, "steam_cover.png")
    local logo = g.newCanvas(1280, 400, { dpiscale = 1 })
    g.setCanvas(logo)
    g.clear(0, 0, 0, 0)
    title(big, 0, 100, 1280, 1.5)
    g.setCanvas(); save(logo, "steam_logo.png")
    love.event.quit()
end
love.update = function() end
love.draw = function() end
