-- Draws the game's icon (the erupting volcano, a fox and a hen, on a round
-- tile) from the game's own images, and saves it as icone.png (512 px) in
-- this tool's save folder; then copy it to volcan/icone.png.
--   /Applications/love.app/Contents/MacOS/love volcan/outils/icone
local GAME = love.filesystem.getSource() .. "/../.."

-- the game's images are outside this tool's folder: read them directly
local function image(name)
    local f = assert(io.open(GAME .. "/images/" .. name .. ".png", "rb"))
    local data = f:read("*a")
    f:close()
    local im = love.graphics.newImage(love.filesystem.newFileData(data, name .. ".png"), { mipmaps = true })
    im:setMipmapFilter("linear")
    return im
end

local volcano, fox, hen
local done = false

function love.load()
    volcano, fox, hen = image("volcan_erupt"), image("renard"), image("poule")
end

-- draw an image `w` pixels wide, its bottom middle at (x, y)
local function put(im, x, y, w, flip)
    local k = w / im:getWidth()
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(im, x, y, 0, flip and -k or k, k, im:getWidth() / 2, im:getHeight())
end

function love.draw()
    local g = love.graphics
    g.clear(0, 0, 0, 0)
    -- the tile: a warm sky over green grass, dark-brown rim
    g.setColor(0.23, 0.14, 0.09)
    g.rectangle("fill", 16, 16, 480, 480, 110)
    g.stencil(function() g.rectangle("fill", 30, 30, 452, 452, 98) end, "replace", 1)
    g.setStencilTest("equal", 1)
    for i = 0, 40 do          -- sky: orange at the bottom (the lava's glow), blue at the top
        local u = i / 40
        g.setColor(0.45 + 0.5 * u, 0.7 - 0.1 * u, 0.95 - 0.6 * u)
        g.rectangle("fill", 30, 30 + i * 9, 452, 10)
    end
    g.setColor(0.45, 0.72, 0.32)
    g.ellipse("fill", 256, 470, 300, 110)
    put(volcano, 280, 400, 390)
    put(fox, 140, 452, 170)
    put(hen, 390, 456, 120, true)
    g.setStencilTest()
end

function love.update()
    if done or not volcano then return end
    done = true
    love.graphics.captureScreenshot(function(img)
        img:encode("png", "icone.png")
        print("OK " .. love.filesystem.getSaveDirectory() .. "/icone.png")
        love.event.quit()
    end)
end
