-- journal.lua: a log of every real game, to improve the gameplay later.
--
-- One file per game, in the game's save folder:
--   macOS: ~/Library/Application Support/LOVE/sauve-les-animaux/parties/
--   Linux: ~/.local/share/love/sauve-les-animaux/parties/
-- One JSON object per line: {"t": seconds into the game, "e": event, ...}.
-- Only main.lua turns it on (journal.enabled), so tests don't write anything;
-- VOLCAN_NO_LOG=1 in the environment also turns it off.

local journal = { enabled = false }
local file, t0, positionsAt

local function encode(v)
    local kind = type(v)
    if kind == "number" then
        return (v == math.floor(v)) and string.format("%d", v) or string.format("%.2f", v)
    elseif kind == "boolean" then
        return tostring(v)
    elseif kind == "string" then
        return '"' .. v:gsub('[%c"\\]', function(c) return string.format("\\u%04x", c:byte()) end) .. '"'
    elseif kind == "table" then
        if #v > 0 or next(v) == nil then
            local parts = {}
            for _, x in ipairs(v) do parts[#parts + 1] = encode(x) end
            return "[" .. table.concat(parts, ",") .. "]"
        end
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = encode(tostring(k)) .. ":" .. encode(v[k]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return "null"
end

-- A new game: setup = { players, kids, mode, lang, total, ... }
function journal.start(setup)
    file = nil
    if not journal.enabled or os.getenv("VOLCAN_NO_LOG") then return end
    love.filesystem.createDirectory("parties")
    file = "parties/" .. os.date("%Y-%m-%d_%H-%M-%S") .. ".jsonl"
    t0 = love.timer.getTime()
    positionsAt = 0
    setup.e, setup.t, setup.date = "debut", 0, os.date("%Y-%m-%d %H:%M:%S")
    love.filesystem.write(file, encode(setup) .. "\n")
end

-- An event during the game: journal.log("attrape", { joueur = 1, animal = "renard" })
function journal.log(event, data)
    if not file then return end
    data = data or {}
    data.e = event
    data.t = math.floor((love.timer.getTime() - t0) * 10) / 10
    love.filesystem.append(file, encode(data) .. "\n")
end

-- Every frame: the kids' positions, every 2 seconds.
function journal.tick(kids)
    if not file then return end
    local t = love.timer.getTime() - t0
    if t < positionsAt then return end
    positionsAt = t + 2
    local pos = {}
    for _, k in ipairs(kids) do
        pos[#pos + 1] = { k.player, math.floor(k.x), math.floor(k.y), #k.followers + (k.fish or 0) }
    end
    journal.log("positions", { enfants = pos })
end

-- The end: how = "fin" (played to the end), "accueil" or "quitte" (stopped).
function journal.finish(how, summary)
    if not file then return end
    summary = summary or {}
    summary.comment = how
    journal.log("fin", summary)
    file = nil
end

function journal.folder()
    return love.filesystem.getSaveDirectory() .. "/parties"
end

return journal
