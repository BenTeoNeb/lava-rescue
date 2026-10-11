-- musique.lua: the music and the forest atmosphere, made in code at launch.
--
-- The music is a cheerful 16-bar tune (marimba, bass, soft pad), plus a
-- "tension" layer (drums, shaker, plucked arpeggios) that plays in sync and
-- fades in as the lava gets closer. Calm mode: no tension layer.
-- The atmosphere: forest birds (they go quiet as the lava advances) and the
-- bubbling of the lava.
--
--   musique.load()                                     at launch
--   musique.update(dt, tension, lava, inGame)          every frame (0..1 values)
--   musique.duck(seconds)                              lower the music (big sounds)
--
-- To use your own music instead, put musique.ogg or musique.mp3 in the game
-- folder (it replaces the tune; the atmosphere stays).

local synth = require("synth")
local S, hz = synth, synth.hz

local musique = {}
local base, tension, birds, lava
local custom = false
local level = { tension = 0, birds = 0, lava = 0, duck = 0 }

local BEAT = 0.6                 -- 100 beats per minute
local EIGHTH = BEAT / 2
local BAR = BEAT * 4
local LENGTH = BAR * 16

-- Chords, one per bar (root note for the bass, and the 3 notes of the chord).
local CHORDS = {
    C = { 48, 60, 64, 67 }, G = { 43, 59, 62, 67 }, Am = { 45, 60, 64, 69 }, F = { 41, 60, 65, 69 },
}
local PROGRESSION = { "C", "G", "Am", "F", "C", "G", "F", "G",
                      "Am", "F", "C", "G", "F", "G", "C", "C" }

-- The tune, in eighth notes (MIDI notes, 0 = silence), one line per bar.
local MELODY = {
    72, 0, 76, 79, 76, 0, 74, 72,
    71, 0, 74, 79, 74, 0, 72, 71,
    69, 0, 72, 76, 74, 72, 71, 69,
    69, 0, 72, 77, 76, 0, 74, 0,
    72, 0, 76, 79, 81, 79, 76, 74,
    71, 74, 79, 0, 77, 76, 74, 0,
    72, 0, 74, 76, 77, 76, 74, 72,
    74, 0, 71, 0, 74, 0, 0, 0,
    76, 0, 76, 79, 81, 0, 79, 76,
    77, 0, 77, 81, 84, 0, 81, 77,
    79, 0, 76, 72, 76, 0, 79, 0,
    79, 0, 74, 71, 74, 0, 79, 0,
    81, 0, 77, 72, 77, 81, 84, 81,
    79, 0, 74, 71, 74, 77, 79, 0,
    84, 0, 79, 76, 79, 76, 72, 0,
    72, 0, 0, 0, 0, 0, 0, 0,
}

local function buildBase()
    local b = S.buffer(LENGTH + 2)
    for bar, name in ipairs(PROGRESSION) do
        local t = (bar - 1) * BAR
        local c = CHORDS[name]
        S.bass(b, t, hz(c[1]), BEAT * 1.6, 0.32)
        S.bass(b, t + BEAT * 2, hz(c[1] + (bar % 2 == 0 and 7 or 0)), BEAT * 1.6, 0.28)
        for k = 2, 4 do S.pad(b, t, hz(c[k]), BAR, 0.035) end
        S.noise(b, t + BEAT, 0.12, 0.06, 0.6, 30)            -- soft brush on 2 and 4
        S.noise(b, t + BEAT * 3, 0.12, 0.06, 0.6, 30)
    end
    for i, n in ipairs(MELODY) do
        if n > 0 then S.marimba(b, (i - 1) * EIGHTH, hz(n), EIGHTH, 0.3) end
    end
    S.reverb(b, 0.35)
    S.fold(b, LENGTH)
    return S.source(b, 0.85, "static", true)
end

local function buildTension()
    local b = S.buffer(LENGTH + 2)
    for bar, name in ipairs(PROGRESSION) do
        local t = (bar - 1) * BAR
        local c = CHORDS[name]
        S.kick(b, t, 0.5)
        S.kick(b, t + BEAT * 2, 0.4)
        S.noise(b, t + BEAT, 0.15, 0.18, 0.4, 18)            -- snare-ish
        S.noise(b, t + BEAT * 3, 0.15, 0.18, 0.4, 18)
        for e = 0, 7 do
            S.noise(b, t + e * EIGHTH, 0.05, 0.05, 1, 60)    -- shaker
            -- plucked arpeggio, an octave up
            S.pluck(b, t + e * EIGHTH, hz(c[2 + e % 3] + 12), EIGHTH, 0.12)
        end
    end
    S.reverb(b, 0.25)
    S.fold(b, LENGTH)
    return S.source(b, 0.8, "static", true)
end

local function buildBirds()
    local len = 13
    local b = S.buffer(len + 1)
    local t = 0.3
    while t < len - 0.5 do
        local f = 2400 + love.math.random() * 1600
        for k = 0, love.math.random(2, 5) do                 -- a little trill
            S.chirp(b, t + k * 0.07, f, f * (1.15 + love.math.random() * 0.3), 0.05, 0.25, "sine", nil, 0.5)
        end
        t = t + 0.8 + love.math.random() * 1.8
    end
    S.reverb(b, 0.4)
    S.fold(b, len)
    return S.source(b, 0.5, "static", true)
end

local function buildLava()
    local len = 8
    local b = S.buffer(len + 1)
    local lp = 0
    for i = 1, #b do
        lp = lp + ((love.math.random() * 2 - 1) - lp) * 0.015
        b[i] = lp * 3
    end
    for _ = 1, 30 do                                       -- bubbles popping
        local t = love.math.random() * (len - 0.2)
        local f = 90 + love.math.random() * 120
        S.chirp(b, t, f, f * 2.2, 0.08, 0.35, "sine", nil, 2)
    end
    S.fold(b, len)
    return S.source(b, 0.6, "static", true)
end

function musique.load()
    for _, file in ipairs({ "musique.ogg", "musique.mp3" }) do
        if love.filesystem.getInfo(file) then
            base = love.audio.newSource(file, "stream")
            custom = true
            break
        end
    end
    base = base or buildBase()
    tension = not custom and buildTension() or nil
    birds, lava = buildBirds(), buildLava()
    for _, s in ipairs({ base, tension, birds, lava }) do
        if s then
            s:setLooping(true)
            s:setVolume(0)
        end
    end
    base:play()
    if tension then tension:play() end
    birds:play()
    lava:play()
end

-- Lower the music for a moment (eruption, victory).
function musique.duck(seconds)
    level.duck = math.max(level.duck, seconds)
end

local function approach(cur, target, speed, dt)
    if cur < target then return math.min(target, cur + speed * dt) end
    return math.max(target, cur - speed * dt)
end

-- tension, lava: 0..1. inGame: false on the menus (music only, no atmosphere).
function musique.update(dt, tensionLevel, lavaLevel, inGame)
    level.duck = math.max(0, level.duck - dt)
    local duck = level.duck > 0 and 0.35 or 1
    level.tension = approach(level.tension, tensionLevel, 0.4, dt)
    level.birds = approach(level.birds, inGame and (1 - lavaLevel) * 0.8 or 0.35, 0.5, dt)
    level.lava = approach(level.lava, inGame and (0.15 + lavaLevel * 0.6) or 0, 0.5, dt)
    base:setVolume(0.32 * duck)
    if tension then
        tension:setVolume(0.3 * level.tension * duck)
        -- keep the two layers exactly together
        if math.abs(tension:tell() - base:tell()) > 0.05 then tension:seek(base:tell()) end
    end
    birds:setVolume(0.16 * level.birds)
    lava:setVolume(0.22 * level.lava)
end

function musique.playing()
    return base ~= nil and base:isPlaying()
end

return musique
