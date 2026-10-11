-- sfx.lua: little sounds, made in code so we don't need sound files.

local sfx = {}
local RATE = 44100
local sounds = {}

-- kind: "square" (default), "sine", "noise" or "rumble" (low noise)
local function tone(fromHz, toHz, duration, kind, volume)
    local n = math.floor(duration * RATE)
    local sd = love.sound.newSoundData(n, RATE, 16, 1)
    local phase, low = 0, 0
    volume = volume or 0.15
    for i = 0, n - 1 do
        local t = i / n
        phase = phase + (fromHz + (toHz - fromHz) * t) / RATE
        local v
        if kind == "noise" then
            v = love.math.random() * 2 - 1
        elseif kind == "rumble" then
            low = low * 0.985 + (love.math.random() * 2 - 1) * 0.015
            v = low * 12
        elseif kind == "sine" then
            v = math.sin(phase * math.pi * 2)
        else
            v = (phase % 1) < 0.5 and 1 or -1
        end
        local env = math.min(1, t * 20) * (1 - t)
        sd:setSample(i, math.max(-1, math.min(1, v * volume * env)))
    end
    return love.audio.newSource(sd, "static")
end

local function melody(notes, noteDuration)
    local per = math.floor(noteDuration * RATE)
    local sd = love.sound.newSoundData(per * #notes, RATE, 16, 1)
    local i = 0
    for _, hz in ipairs(notes) do
        local phase = 0
        for j = 0, per - 1 do
            phase = phase + hz / RATE
            local v = math.sin(phase * math.pi * 2) * 0.6 + ((phase % 1) < 0.5 and 0.15 or -0.15)
            sd:setSample(i, v * 0.25 * (1 - j / per))
            i = i + 1
        end
    end
    return love.audio.newSource(sd, "static")
end

function sfx.load()
    sounds.grab = tone(600, 1200, 0.12, "sine", 0.3)
    sounds.drop = tone(600, 300, 0.12, "sine", 0.3)
    sounds.full = tone(200, 200, 0.15, "square", 0.1)
    sounds.home = melody({ 659, 784, 1047 }, 0.08)
    sounds.burn = tone(900, 250, 0.3, "square", 0.08)
    sounds.rumble = tone(0, 0, 1.5, "rumble", 0.9)
    sounds.oops = melody({ 523, 415, 349 }, 0.15)
    sounds.select = tone(800, 800, 0.05, "sine", 0.3)
    sounds.ready = melody({ 523, 784 }, 0.1)
    sounds.win = melody({ 523, 659, 784, 1047, 784, 1047 }, 0.14)
end

function sfx.play(name)
    local s = sounds[name]
    if s then
        s:stop()
        s:play()
    end
end

return sfx
