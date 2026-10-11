-- lave.lua: how the lava looks. A shader draws flowing, cartoon-shaded lava
-- (dark crust with glowing cracks, red, orange and yellow bands) inside the
-- shape given by world.lavaX; the edge gets a dark outline like the drawings,
-- the grass in front is scorched and glows, bubbles pop and embers fly.

local lave = {}
local g = love.graphics
local shader, glow

local SHADER = [[
varying vec2 wpos;
varying float vfront;

#ifdef VERTEX
attribute float VertexFront;
vec4 position(mat4 transform_projection, vec4 vertex_position) {
    wpos = vertex_position.xy;
    vfront = VertexFront;
    return transform_projection * vertex_position;
}
#endif

#ifdef PIXEL
uniform float time;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
    vec2 i = floor(p), f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
    float v = 0.0, a = 0.5;
    for (int i = 0; i < 4; i++) { v += a * noise(p); p *= 2.03; a *= 0.5; }
    return v;
}

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float edge = vfront - wpos.x;                // pixels from the edge

    // swirling flow, drifting toward the forest
    vec2 p = wpos / 120.0;
    p.x -= time * 0.10;
    vec2 q = vec2(fbm(p + vec2(0.0, time * 0.05)), fbm(p + vec2(5.2, -time * 0.04)));
    float n = fbm(p + 2.2 * q);

    // flat cartoon bands, like the cel-shading of the drawings
    vec3 crust  = vec3(0.48, 0.12, 0.07);
    vec3 red    = vec3(0.84, 0.23, 0.07);
    vec3 orange = vec3(1.00, 0.52, 0.12);
    vec3 yellow = vec3(1.00, 0.85, 0.36);
    vec3 col = crust;
    col = mix(col, red,    smoothstep(0.36, 0.39, n));
    col = mix(col, orange, smoothstep(0.50, 0.53, n));
    col = mix(col, yellow, smoothstep(0.64, 0.67, n));

    // glowing cracks in the dark crust
    float c = abs(fbm(p * 1.8 + q * 1.5 + 3.1) - 0.5);
    float crack = (1.0 - smoothstep(0.012, 0.03, c)) * (1.0 - smoothstep(0.36, 0.39, n));
    col = mix(col, orange, crack);

    // very hot rim just inside the edge
    col = mix(col, orange, 1.0 - smoothstep(16.0, 24.0, edge));
    col = mix(col, yellow, 1.0 - smoothstep(6.0, 11.0, edge));
    return vec4(col, 1.0);
}
#endif
]]

local STRIP = 4
local mesh
local verts = {}

function lave.load()
    shader = g.newShader(SHADER)
    -- one smooth shape: a strip of triangles between the left side and the edge
    local rows = math.ceil(720 / STRIP) + 3
    mesh = g.newMesh({ { "VertexPosition", "float", 2 }, { "VertexFront", "float", 1 } },
        rows * 2, "strip", "stream")
    for i = 1, rows * 2 do verts[i] = { 0, 0, 0 } end
    local d = love.image.newImageData(64, 1)
    for i = 0, 63 do d:setPixel(i, 0, 1, 1, 1, (1 - i / 63) ^ 2) end
    glow = g.newImage(d)
end

-- lavaX: function(y) -> x of the edge; t: time; H: height of the screen
function lave.draw(lavaX, t, H)
    -- in front of the lava: scorched grass and a flickering orange glow
    for y = 0, H, STRIP do
        local x = lavaX(y + STRIP / 2)
        g.setColor(0.25, 0.14, 0.06, 0.5)
        g.draw(glow, x, y, 0, 30 / 64, STRIP)
        local flicker = 0.28 + 0.08 * math.sin(t * 7 + y * 0.03) + 0.05 * math.sin(t * 13 + y * 0.11)
        g.setColor(1, 0.55, 0.15, flicker)
        g.draw(glow, x, y, 0, 90 / 64, STRIP)
    end

    -- the lava itself: one smooth shape, colored by the shader
    -- (the vertex tables are made once and reused: no garbage every frame)
    for i = 0, mesh:getVertexCount() / 2 - 1 do
        local y = (i - 1) * STRIP
        local x = math.max(0, lavaX(y))
        local a, b = verts[2 * i + 1], verts[2 * i + 2]
        a[1], a[2], a[3] = 0, y, x
        b[1], b[2], b[3] = x, y, x
    end
    mesh:setVertices(verts)
    shader:send("time", t)
    g.setShader(shader)
    g.setColor(1, 1, 1)
    g.draw(mesh)
    g.setShader()

    -- cartoon bubbles that swell and pop
    for i = 0, 22 do
        local by = (i * 53 + 17) % H
        local bx = lavaX(by) - 30 - (i * 61) % 260
        if bx > 10 then
            local phase = (t * 0.55 + i * 0.37) % 1
            if phase < 0.8 then
                local r = 3 + 9 * phase / 0.8
                g.setColor(1, 0.75, 0.25)
                g.circle("fill", bx, by, r)
                g.setColor(0.35, 0.1, 0.05)
                g.setLineWidth(2)
                g.circle("line", bx, by, r)
                g.setColor(1, 1, 0.85, 0.9)
                g.circle("fill", bx - r * 0.35, by - r * 0.35, r * 0.25)
            else
                local k = (phase - 0.8) / 0.2
                g.setColor(1, 0.85, 0.4, 1 - k)
                g.setLineWidth(2)
                g.circle("line", bx, by, 12 + 10 * k)
            end
        end
    end

    -- dark outline, like the drawings
    local pts = {}
    for y = -10, H + 10, STRIP do
        table.insert(pts, lavaX(y))
        table.insert(pts, y)
    end
    g.setLineJoin("bevel")
    g.setLineWidth(5)
    g.setColor(0.23, 0.14, 0.09)
    g.line(pts)
end

return lave
