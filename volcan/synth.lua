-- synth.lua: a tiny synthesizer. Everything is made in code at launch (no
-- sound files): instruments, animal voices, effects, a little reverb.
--
-- A sound is built in a buffer (a Lua table of samples), then turned into a
-- LÖVE Source. Times are in seconds, frequencies in Hz.

local synth = {}
synth.RATE = 32000
local RATE = synth.RATE
local sin, exp, abs, floor, random, pi = math.sin, math.exp, math.abs, math.floor, love.math.random, math.pi
local TAU = 2 * pi

function synth.buffer(seconds)
    local b = {}
    for i = 1, floor(seconds * RATE) do b[i] = 0 end
    return b
end

function synth.hz(note) return 440 * 2 ^ ((note - 69) / 12) end

-- Envelope: a quick attack, then an exponential decay.
local function env(t, attack, decay)
    if t < attack then return t / attack end
    return exp(-(t - attack) * decay)
end

-- Instruments ------------------------------------------------------------------
-- Each one adds a note into buffer b starting at time t0.

-- Marimba / kalimba: a sine with a soft bright attack (FM), warm and round.
function synth.marimba(b, t0, f, dur, vol)
    local n0, n = floor(t0 * RATE), floor((dur + 0.6) * RATE)
    for i = 0, n do
        local t = i / RATE
        local e = env(t, 0.003, 5.5)
        local mod = sin(TAU * f * 4 * t) * 1.6 * exp(-t * 30)
        local v = sin(TAU * f * t + mod) * e + sin(TAU * f * 2 * t) * 0.15 * e * exp(-t * 8)
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + v * vol end
    end
end

-- Bell: inharmonic partials, long shimmering tail.
function synth.bell(b, t0, f, dur, vol)
    local n0, n = floor(t0 * RATE), floor((dur + 1.2) * RATE)
    for i = 0, n do
        local t = i / RATE
        local v = sin(TAU * f * t) * exp(-t * 2.5) + sin(TAU * f * 2.76 * t) * 0.4 * exp(-t * 5)
            + sin(TAU * f * 5.4 * t) * 0.2 * exp(-t * 9)
        v = v * (t < 0.002 and t / 0.002 or 1)
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + v * vol end
    end
end

-- Plucked string (Karplus-Strong): like a little harp or ukulele.
function synth.pluck(b, t0, f, dur, vol)
    local period = floor(RATE / f)
    local ring = {}
    for i = 1, period do ring[i] = random() * 2 - 1 end
    local n0, n = floor(t0 * RATE), floor((dur + 0.4) * RATE)
    local idx = 1
    for i = 0, n do
        local nxt = idx % period + 1
        local v = ring[idx]
        ring[idx] = (ring[idx] + ring[nxt]) * 0.4985
        idx = nxt
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + v * vol end
    end
end

-- Soft bass: a triangle with a little sine underneath.
function synth.bass(b, t0, f, dur, vol)
    local n0, n = floor(t0 * RATE), floor(dur * RATE)
    local ph = 0
    for i = 0, n do
        local t = i / RATE
        ph = ph + f / RATE
        local p = ph % 1
        local tri = p < 0.5 and (4 * p - 1) or (3 - 4 * p)
        local e = math.min(1, t * 80) * math.min(1, (dur - t) * 20) * (0.7 + 0.3 * exp(-t * 4))
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + (tri * 0.7 + sin(TAU * ph) * 0.5) * e * vol end
    end
end

-- Pad: slow, soft chord tone (detuned sines), for warmth.
function synth.pad(b, t0, f, dur, vol)
    local n0, n = floor(t0 * RATE), floor(dur * RATE)
    for i = 0, n do
        local t = i / RATE
        local e = math.min(1, t / 0.4) * math.min(1, (dur - t) / 0.5)
        local v = sin(TAU * f * t) + sin(TAU * f * 1.004 * t) * 0.7 + sin(TAU * f * 2.002 * t) * 0.2
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + v * e * vol end
    end
end

-- Drums.
function synth.kick(b, t0, vol)
    local n0, n = floor(t0 * RATE), floor(0.3 * RATE)
    local ph = 0
    for i = 0, n do
        local t = i / RATE
        ph = ph + (45 + 110 * exp(-t * 35)) / RATE
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + sin(TAU * ph) * exp(-t * 12) * vol end
    end
end

-- Filtered noise burst: brushes, shakers, splashes (bright = 0..1).
function synth.noise(b, t0, dur, vol, bright, decay)
    local n0, n = floor(t0 * RATE), floor(dur * RATE)
    local lp, prev = 0, 0
    local a = 0.05 + 0.9 * (bright or 0.5)
    for i = 0, n do
        local t = i / RATE
        local w = random() * 2 - 1
        lp = lp + (w - lp) * a
        local hp = lp - prev * 0.6
        prev = lp
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + hp * env(t, 0.002, decay or 25) * vol end
    end
end

-- A sliding tone with vibrato: voices, whistles, chirps.
-- shape: "sine", "saw" or "square"; f1 -> f2 over the duration.
function synth.chirp(b, t0, f1, f2, dur, vol, shape, vibrato, curve)
    local n0, n = floor(t0 * RATE), floor(dur * RATE)
    local ph = 0
    for i = 0, n do
        local t = i / RATE
        local u = t / dur
        local f = f1 + (f2 - f1) * (curve and u ^ curve or u)
        if vibrato then f = f * (1 + vibrato * sin(TAU * 18 * t)) end
        ph = ph + f / RATE
        local p = ph % 1
        local v
        if shape == "saw" then v = 2 * p - 1
        elseif shape == "square" then v = p < 0.5 and 0.7 or -0.7
        else v = sin(TAU * p) end
        local e = math.min(1, t * 300) * math.min(1, (dur - t) * 60)
        local k = n0 + i + 1
        if b[k] then b[k] = b[k] + v * e * vol end
    end
end

-- Effects ------------------------------------------------------------------------

-- One-pole low-pass, in place (softens buzzy sounds).
function synth.lowpass(b, amount)
    local y = 0
    for i = 1, #b do
        y = y + (b[i] - y) * amount
        b[i] = y
    end
end

-- A small, warm room reverb (Schroeder: 4 combs + 2 all-pass), mixed in.
function synth.reverb(b, wet, tail)
    tail = tail or 0.78
    local combs = { 1116, 1188, 1277, 1356 }
    local out = {}
    for i = 1, #b do out[i] = 0 end
    for _, len in ipairs(combs) do
        len = floor(len * RATE / 44100)
        local buf, idx, store = {}, 1, 0
        for i = 1, len do buf[i] = 0 end
        for i = 1, #b do
            local y = buf[idx]
            store = y * 0.6 + store * 0.4                    -- damping
            buf[idx] = b[i] + store * tail
            idx = idx % len + 1
            out[i] = out[i] + y * 0.25
        end
    end
    for _, len in ipairs({ 556, 441 }) do
        len = floor(len * RATE / 44100)
        local buf, idx = {}, 1
        for i = 1, len do buf[i] = 0 end
        for i = 1, #b do
            local y = buf[idx]
            buf[idx] = out[i] + y * 0.5
            out[i] = y - out[i]
            idx = idx % len + 1
        end
    end
    for i = 1, #b do b[i] = b[i] + out[i] * wet end
end

-- Make a loop seamless: the end of the buffer (the reverb tail past `len`) is
-- folded back onto the beginning, then the buffer is cut to `len` seconds.
function synth.fold(b, len)
    local n = floor(len * RATE)
    for i = n + 1, #b do
        local k = i - n
        if k <= n then b[k] = b[k] + b[i] end
        b[i] = nil
    end
end

-- Turn a buffer into a LÖVE Source, scaled so the loudest point is `peak`.
-- One-shot sounds ("static" not looping) get a 15 ms fade at the end: no click.
function synth.source(b, peak, kind, loop)
    if not loop then
        local fade = math.min(#b, floor(0.015 * RATE))
        for i = 0, fade - 1 do b[#b - i] = b[#b - i] * (i / fade) end
    end
    local m = 1e-9
    for i = 1, #b do
        local a = abs(b[i])
        if a > m then m = a end
    end
    local g = (peak or 0.9) / m
    local sd = love.sound.newSoundData(math.max(1, #b), RATE, 16, 1)
    for i = 1, #b do sd:setSample(i - 1, b[i] * g) end
    return love.audio.newSource(sd, kind or "static")
end

return synth
