-- lang.lua: every text of the game, in French and in English.
-- Switch on the home screen with a shoulder button (L1/R1) or the L key.

local lang = { current = "fr" }

local TEXTS = {
    fr = {
        title = "SAUVE LES ANIMAUX !",
        choose = "Choisis ton personnage",
        player = "J",
        ready = "Prêt !",
        sound_on = "Son : oui", sound_off = "Son : non",
        language = "Français",
        how = "Gauche / droite pour choisir  ·  Bouton du bas : c'est parti !",
        join = "Joueur 2 : appuie sur un bouton pour jouer aussi !",
        trait_rami = "Rapide !", trait_zina = "Costaude !", trait_lila = "Amie des animaux !",
        saved = "Sauvés : ",
        lava = "Lave",
        win3 = "Super héros !", win2 = "Bravo !", win1 = "Bien joué !",
        result = "Vous avez sauvé %d animaux sur %d !",
        again = "Appuie sur le bouton du bas pour rejouer",
    },
    en = {
        title = "SAVE THE ANIMALS!",
        choose = "Choose your character",
        player = "P",
        ready = "Ready!",
        sound_on = "Sound: on", sound_off = "Sound: off",
        language = "English",
        how = "Left / right to choose  ·  Bottom button: let's go!",
        join = "Player 2: press any button to play too!",
        trait_rami = "Fast!", trait_zina = "Strong!", trait_lila = "Animal friend!",
        saved = "Saved: ",
        lava = "Lava",
        win3 = "Super heroes!", win2 = "Well done!", win1 = "Good job!",
        result = "You saved %d animals out of %d!",
        again = "Press the bottom button to play again",
    },
}

-- The text for `key` in the current language (with %d filled in if given).
function lang.t(key, ...)
    local s = TEXTS[lang.current][key] or TEXTS.fr[key] or key
    if select("#", ...) > 0 then s = string.format(s, ...) end
    return s
end

function lang.toggle()
    lang.current = lang.current == "fr" and "en" or "fr"
end

return lang
