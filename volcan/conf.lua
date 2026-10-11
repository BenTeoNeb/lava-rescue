function love.conf(t)
    t.identity = "sauve-les-animaux"   -- name of the save folder
    t.version = "11.5"                 -- the LÖVE version the game is made for
    t.window.title = "Sauve les Animaux !"
    t.window.width = 1280
    t.window.height = 720
    t.window.resizable = true
    t.window.fullscreen = true         -- fullscreen by default (switch in the menu)
    t.window.fullscreentype = "desktop"
    t.window.msaa = 0                  -- no antialiasing: it cost ~25% of the speed on a 5K
                                       -- screen (the drawings are smooth anyway)
    t.window.highdpi = true            -- full resolution on Retina screens
    t.modules.joystick = true
end
