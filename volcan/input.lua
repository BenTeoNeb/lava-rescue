-- input.lua: turns controllers (and the keyboard) into simple player actions.
--
--   input.move(p)    -> dx, dy  (each between -1 and 1)
--   input.stickX(p)  -> left stick x, for menus
-- and main.lua gets (player, action) pairs from gamepadpressed / keypressed.

local input = {}

-- Gamepad buttons (SDL names, the same on every controller) -> actions.
-- On 8BitDo pads "a" is the BOTTOM face button and "b" the RIGHT one.
local BUTTONS = {
    a = "grab", y = "grab", b = "drop", x = "drop",
    start = "start", back = "back",
    leftshoulder = "lang", rightshoulder = "lang",
    dpleft = "left", dpright = "right", dpup = "up", dpdown = "down",
}

-- Keyboard: player 1 = arrows + Space (grab) / Enter (drop),
-- player 2 = WASD + F (grab) / G (drop).
local KEYS = {
    { up = "up", down = "down", left = "left", right = "right",
      grab = "space", drop = "return", start = "escape" },
    { up = "w", down = "s", left = "a", right = "d",
      grab = "f", drop = "g", start = "tab" },
}

local DEADZONE = 0.25
local slots = {}   -- slots[p] = joystick, players 1 and 2

local function playerOf(joystick)
    for p = 1, 2 do
        if slots[p] == joystick then return p end
    end
end

function input.joystickadded(joystick)
    if playerOf(joystick) then return end
    for p = 1, 2 do
        if not slots[p] then
            slots[p] = joystick
            return p
        end
    end
end

function input.joystickremoved(joystick)
    local p = playerOf(joystick)
    if p then slots[p] = nil end
    return p
end

function input.controller(p)
    return slots[p]
end

function input.stickX(p)
    local js = slots[p]
    if js and js:isGamepad() then return js:getGamepadAxis("leftx") end
    if js then return js:getAxis(1) or 0 end
    return 0
end

function input.stickY(p)
    local js = slots[p]
    if js and js:isGamepad() then return js:getGamepadAxis("lefty") end
    if js then return js:getAxis(2) or 0 end
    return 0
end

function input.move(p)
    local dx, dy = 0, 0
    local js = slots[p]
    if js and js:isGamepad() then
        dx = js:getGamepadAxis("leftx")
        dy = js:getGamepadAxis("lefty")
        if js:isGamepadDown("dpleft") then dx = -1 end
        if js:isGamepadDown("dpright") then dx = 1 end
        if js:isGamepadDown("dpup") then dy = -1 end
        if js:isGamepadDown("dpdown") then dy = 1 end
    elseif js then
        -- Controller SDL doesn't know: use its raw first stick.
        dx = js:getAxis(1) or 0
        dy = js:getAxis(2) or 0
    end
    if math.abs(dx) < DEADZONE then dx = 0 end
    if math.abs(dy) < DEADZONE then dy = 0 end
    local k = KEYS[p]
    if love.keyboard.isDown(k.left) then dx = -1 end
    if love.keyboard.isDown(k.right) then dx = 1 end
    if love.keyboard.isDown(k.up) then dy = -1 end
    if love.keyboard.isDown(k.down) then dy = 1 end
    return dx, dy
end

-- Is this action's button held down right now (any of its buttons or keys)?
function input.held(p, action)
    local js = slots[p]
    if js and js:isGamepad() then
        for button, a in pairs(BUTTONS) do
            if a == action and js:isGamepadDown(button) then return true end
        end
    end
    local key = KEYS[p][action]
    return key ~= nil and love.keyboard.isDown(key)
end

function input.gamepadpressed(joystick, button)
    local p, action = playerOf(joystick), BUTTONS[button]
    if p and action then return p, action end
end

function input.keypressed(key)
    for p = 1, 2 do
        for action, k in pairs(KEYS[p]) do
            if k == key then return p, action end
        end
    end
end

return input
