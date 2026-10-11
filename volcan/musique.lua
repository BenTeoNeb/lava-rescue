-- musique.lua: a cheerful little forest tune, made in code (no music file).
-- 8 bars at 120 beats per minute, played in a loop. During the game it speeds
-- up a little as the lava advances.
--
-- To use your own music instead, put a file named musique.ogg or musique.mp3
-- in the game folder: it will be played in place of this tune.

local musique = {}
local RATE = 22050
local source

local BPM = 120
local EIGHTH = 60 / BPM / 2

-- The tune, in eighth notes (MIDI note numbers, 72 = the C above middle C, 0 = silence).
local MELODY = {
    72, 76, 79, 76, 77, 76, 74, 72,   -- C
    74, 71, 67, 71, 74, 76, 74, 71,   -- G
    72, 76, 81, 79, 76, 74, 72, 69,   -- A minor
    69, 72, 77, 76, 74, 72, 74, 76,   -- F
    79, 76, 72, 76, 79, 81, 79, 76,   -- C
    74, 79, 83, 81, 79, 76, 74, 71,   -- G
    72, 77, 76, 74, 74, 79, 77, 74,   -- F then G
    72, 76, 79, 84, 79, 76, 72, 0,    -- C
}
-- The bass, in quarter notes.
local BASS = {
    48, 55, 48, 55,   43, 50, 43, 50,   45, 52, 45, 52,   41, 48, 41, 48,
    48, 55, 48, 55,   43, 50, 43, 50,   41, 48, 43, 50,   48, 55, 48, 43,
}

local function hz(note) return 440 * 2 ^ ((note - 69) / 12) end

local function build()
    local n = math.floor(#MELODY * EIGHTH * RATE)
    local sd = love.sound.newSoundData(n, RATE, 16, 1)
    local seed = 1
    local function noise()   -- the same "random" every time, so the loop is identical
        seed = (seed * 1103515245 + 12345) % 2147483648
        return seed / 1073741824 - 1
    end
    for i = 0, n - 1 do
        local t = i / RATE
        local e = math.floor(t / EIGHTH)           -- which eighth note
        local te = t - e * EIGHTH                  -- time inside it
        local v = 0

        -- melody: a soft square wave, short and bouncy
        local m = MELODY[e + 1]
        if m and m > 0 then
            local ph = (t * hz(m)) % 1
            local env = math.min(1, te * 200) * math.exp(-te * 7)
            v = v + ((ph < 0.25) and 1 or -1) * 0.13 * env
        end

        -- bass: a round triangle wave
        local q = math.floor(e / 2)
        local tq = t - q * EIGHTH * 2
        local b = BASS[q + 1]
        if b then
            local ph = (t * hz(b)) % 1
            local tri = ph < 0.5 and (4 * ph - 1) or (3 - 4 * ph)
            v = v + tri * 0.16 * math.min(1, tq * 100) * math.exp(-tq * 3)
        end

        -- drums: kick on beats 1 and 3, snare on 2 and 4, a little hi-hat on each eighth
        local beat = q % 4
        if beat == 0 or beat == 2 then
            v = v + math.sin(2 * math.pi * (60 + 90 * math.exp(-tq * 30)) * tq) * 0.22 * math.exp(-tq * 18)
        else
            v = v + noise() * 0.07 * math.exp(-tq * 25)
        end
        v = v + noise() * 0.025 * math.exp(-te * 60)

        sd:setSample(i, math.max(-1, math.min(1, v)))
    end
    return love.audio.newSource(sd, "static")
end

function musique.load()
    for _, file in ipairs({ "musique.ogg", "musique.mp3" }) do
        if love.filesystem.getInfo(file) then
            source = love.audio.newSource(file, "stream")
            break
        end
    end
    source = source or build()
    source:setLooping(true)
    source:setVolume(0.35)
    source:play()   -- (the sound on/off switch in main.lua mutes everything)
end

function musique.playing()
    return source ~= nil and source:isPlaying()
end

-- speed: 1 = normal; a bit more makes it faster and higher, like a hurry.
function musique.speed(s)
    if source then source:setPitch(s) end
end

return musique
