-- sfx.lua: the sound effects, made with synth.lua at launch.
--
--   sfx.play(name)                 play a sound (several can overlap)
--   sfx.play("grab_" .. kind)      the voice of an animal (falls back to "grab")
-- Each play is a little higher or lower than the last, so repeated sounds
-- don't get tiring.

local synth = require("synth")

local sfx = {}
local sounds = {}      -- name -> { sources..., next = index, vary = pitch variation }
local VOICES = 4       -- how many copies of a sound can play at the same time

local function make(build, seconds, peak, reverb)
    local b = synth.buffer(seconds)
    build(b)
    if reverb then synth.reverb(b, reverb) end
    return synth.source(b, peak or 0.8)
end

local function add(name, source, vary, volume)
    local entry = { next = 1, vary = vary or 0.05 }
    source:setVolume(volume or 1)
    entry[1] = source
    for i = 2, VOICES do entry[i] = source:clone() end
    sounds[name] = entry
end

local S = synth
local hz = S.hz
local floor = math.floor

function sfx.load()
    -- Animal voices (when a kid calls them) -----------------------------------
    add("grab_renard", make(function(b)           -- a little "yip!" (twice)
        S.chirp(b, 0.00, 700, 1300, 0.09, 0.5, "sine", 0.02, 0.6)
        S.chirp(b, 0.12, 800, 1400, 0.08, 0.4, "sine", 0.02, 0.6)
    end, 0.35, 0.7, 0.15), 0.06)
    add("grab_poule", make(function(b)            -- "bok bok... bogok!"
        for i, t in ipairs({ 0, 0.11, 0.24 }) do
            S.chirp(b, t, 520 + i * 30, 420, i == 3 and 0.12 or 0.07, 0.5, "saw", 0.04)
        end
        S.lowpass(b, 0.25)
    end, 0.45, 0.7, 0.1), 0.06)
    add("grab_ecureuil", make(function(b)         -- quick chitter
        for i = 0, 5 do S.chirp(b, i * 0.045, 2200, 3000, 0.03, 0.35, "sine", nil, 0.5) end
    end, 0.32, 0.6, 0.1), 0.07)
    add("grab_marcassin", make(function(b)        -- "oink!"
        S.chirp(b, 0.0, 260, 340, 0.16, 0.6, "saw", 0.05, 0.4)
        S.lowpass(b, 0.18)
    end, 0.3, 0.75, 0.1), 0.06)
    add("grab_herisson", make(function(b)         -- sniff sniff
        S.noise(b, 0.00, 0.08, 0.5, 0.8, 40)
        S.noise(b, 0.12, 0.08, 0.5, 0.8, 40)
    end, 0.28, 0.6, 0.05), 0.08)
    add("grab", make(function(b)                  -- (any other) a happy "pop"
        S.chirp(b, 0, 500, 1100, 0.1, 0.5, "sine", nil, 0.5)
    end, 0.2, 0.6, 0.1), 0.06)
    add("splash", make(function(b)                -- a fish caught: splash + bubbles
        S.noise(b, 0.0, 0.25, 0.6, 0.7, 14)
        for i = 0, 3 do S.chirp(b, 0.08 + i * 0.05, 600 + i * 180, 1200 + i * 200, 0.04, 0.25, "sine") end
    end, 0.45, 0.6, 0.12), 0.05)

    -- Game events ----------------------------------------------------------------
    add("drop", make(function(b)                  -- let go: a soft "boop" down
        S.chirp(b, 0, 600, 330, 0.14, 0.5, "sine", nil, 0.7)
    end, 0.25, 0.5, 0.1), 0.04)
    add("full", make(function(b)                  -- no room: a wooden "tok"
        S.marimba(b, 0, 196, 0.1, 0.6)
        S.noise(b, 0, 0.03, 0.3, 0.3, 80)
    end, 0.4, 0.5), 0.03)
    add("home", make(function(b)                  -- saved! a little magic arpeggio
        for i, n in ipairs({ 72, 76, 79, 84 }) do S.bell(b, (i - 1) * 0.07, hz(n), 0.4, 0.25) end
    end, 1.6, 0.7, 0.25), 0.02)
    add("burn", make(function(b)                  -- ouch: sizzle + a comic slide down
        S.noise(b, 0, 0.35, 0.4, 0.9, 6)
        S.chirp(b, 0.03, 1400, 500, 0.35, 0.35, "sine", 0.03, 0.6)
    end, 0.5, 0.6, 0.1), 0.06)
    add("oops", make(function(b)                  -- the fox scared them: "wah wah waaah"
        for i, n in ipairs({ 62, 61, 60 }) do
            local d = i == 3 and 0.5 or 0.22
            S.chirp(b, (i - 1) * 0.26, hz(n), hz(n) * (i == 3 and 0.94 or 0.98), d, 0.45, "saw", i == 3 and 0.02 or nil)
        end
        S.lowpass(b, 0.12)
    end, 1.1, 0.6, 0.15), 0)
    add("rumble", make(function(b)                -- the volcano is about to erupt
        local n = #b
        local lp = 0
        for i = 1, n do
            local t = (i - 1) / S.RATE
            lp = lp + ((love.math.random() * 2 - 1) - lp) * 0.02
            local e = math.min(1, t * 2) * math.min(1, (2.2 - t) * 2)
            b[i] = b[i] + (lp * 4 + math.sin(2 * math.pi * 38 * t) * 0.3) * e
        end
        S.kick(b, 1.6, 0.8)
    end, 2.2, 0.9), 0.04)
    add("boom", make(function(b)                  -- eruption
        S.kick(b, 0, 1)
        S.noise(b, 0, 1.0, 0.6, 0.25, 3)
    end, 1.2, 0.9, 0.2), 0.05)
    add("sparkle", make(function(b)               -- the golden animal appears
        for i = 0, 9 do S.bell(b, i * 0.045, hz(84 + (i % 5) * 2 + floor(i / 5) * 12), 0.2, 0.12) end
    end, 1.6, 0.6, 0.3), 0)
    add("big", make(function(b)                   -- the big mama is saved
        for i, n in ipairs({ 60, 64, 67, 72 }) do S.marimba(b, (i - 1) * 0.1, hz(n), 0.3, 0.35) end
        for _, n in ipairs({ 72, 76, 79 }) do S.bell(b, 0.42, hz(n), 1.0, 0.2) end
    end, 2.0, 0.75, 0.3), 0)
    add("win", make(function(b)                   -- the end: a little fanfare
        local notes = { 60, 64, 67, 72, 67, 72, 76 }
        for i, n in ipairs(notes) do S.marimba(b, (i - 1) * 0.13, hz(n), 0.2, 0.35) end
        for _, n in ipairs({ 60, 64, 67, 72 }) do S.pad(b, 0.9, hz(n), 1.4, 0.08) end
        for _, n in ipairs({ 76, 79, 84 }) do S.bell(b, 0.9, hz(n), 1.5, 0.18) end
    end, 3.0, 0.8, 0.3), 0)

    -- Menus ----------------------------------------------------------------------
    add("select", make(function(b) S.pluck(b, 0, hz(79), 0.1, 0.5) end, 0.3, 0.45), 0.03)
    add("ready", make(function(b)
        S.pluck(b, 0, hz(72), 0.1, 0.5)
        S.pluck(b, 0.08, hz(79), 0.2, 0.5)
    end, 0.6, 0.55, 0.15), 0)
end

function sfx.play(name)
    local entry = sounds[name] or (name:sub(1, 5) == "grab_" and sounds.grab)
    if not entry then return end
    local s = entry[entry.next]
    entry.next = entry.next % VOICES + 1
    s:stop()
    s:setPitch(1 + (love.math.random() * 2 - 1) * entry.vary)
    s:play()
end

return sfx
