# Games made with Rami, Zina and Lila

Two small 2D games for young children (from about 5 years old), played with
**game controllers** (8BitDo, Xbox, PlayStation... or the keyboard), alone or
**two players on the same screen**. Made with [LÖVE](https://love2d.org) 11.5.

| Game | Folder | In one sentence |
|---|---|---|
| **Sauve les Animaux !** | [`volcan/`](volcan) | The volcano wakes up: save the forest animals and the pond fish before the lava reaches them. |
| **Rugby de la Jungle** | [`mygame/`](mygame) | Lions, parrots and hyenas grab the balls thrown by a tower and bring them home. |

The game ideas come from the children; the art was made with image and video
generation (Gemini, Veo) from their descriptions.

## Sauve les Animaux !

- **1 or 2 players**, cooperative. Choose Rami (fast, carries 2 animals),
  Zina (strong, carries 4) or Lila (calls animals from further away).
- Bring the animals to the **pens on the hill** and the fish (with the net) to
  the **jar hut**, before the lava arrives. Don't put the **fox** with the hens
  or the squirrels! An animal can be taken back out of a pen.
- Surprises: a **golden animal** (+5), and with 2 players a **big mama** that
  only moves when both kids hold her (+3; her babies count double in her pen).
- **Calm mode** (no lava, no time limit) for the youngest. French or English.
- No reading needed while playing: icons, numbers and sounds only.

**Controls**

| | Controller | Keyboard (player 1 / player 2) |
|---|---|---|
| Move | stick or D-pad | arrows / W A S D |
| Call an animal, catch a fish, choose | bottom button (A) — hold it to call several | Space / F |
| Let go of one animal | right button (B) | Enter / G |
| Menu (pause, mode, sound, language, quit) | Start | Escape / Tab |
| Sound on / off | Select (View) | M |
| Language (home screen) | L1 / R1 | L |

## Play

Install LÖVE 11.5 (https://love2d.org), then from this folder:

```bash
/Applications/love.app/Contents/MacOS/love volcan     # macOS
love volcan                                           # Linux / Windows (LÖVE in the PATH)
```

Or make the ready-to-play versions (Mac, Windows, Linux / Steam Deck, .love):

```bash
sh volcan/outils/build.sh       # -> dist/
```
The Mac and Windows versions are not signed: the first time, right-click →
Open (Mac) or "More info → Run anyway" (Windows).

## How it is made

```
volcan/
  main.lua          menus, home screen, sound / language / fullscreen
  world.lua         the game: lava, kids, animals, pens, score, end screen
  mare.lua          the pond, the fish, the net, the jar hut
  events.lua        golden animal, big mama
  art.lua           drawing the characters, animals, decor (images + fallbacks)
  lave.lua          the lava (shader)
  synth.lua         sound synthesizer (everything is made in code)
  sfx.lua           sound effects and animal voices
  musique.lua       adaptive music (tension layer follows the lava) and ambience
  lang.lua          all texts, French and English
  input.lua         controllers and keyboard
  journal.lua       log of real games (local only, not in the shipped builds)
  images/           game images (made by the tools below, for screens up to 4K)
  planches/         original sheets from Gemini (sources of images/)
  videos/           Veo videos of the children (sources of their animations)
  art.json          description of every image: on-screen size, prompt...
  GEMINI.md         prompts and method for making the images by hand
  outils/
    build.sh        ready-to-play versions -> dist/
    hd.py           rebuild every image for 4K from planches/
    decoupe.py      cut a sheet (magenta background) into images
    video.py        Veo video (green screen) -> animation frames (24 fps)
    texture.py      seamless ground tile
    bake.py         4K sizing and even outlines
    parties.py      summary of the logged games
.claude/skills/game-art/   the same art pipeline, driving the Gemini image and
                           Veo APIs (sizes, 4K, style, budget cap)
```

Logged games (when playing from this folder) are in
`~/Library/Application Support/LOVE/sauve-les-animaux/parties/` (macOS);
`python3 volcan/outils/parties.py --detail` summarizes them.

## License

Two parts — see [LICENSE](LICENSE):

- **Anyone may download and play the games**, and share them free and unchanged.
- **Code: [PolyForm Noncommercial 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0)**
  — the `.lua` files, the tools, the `game-art` skill and the docs: anyone may
  reuse, modify and share it in their own projects, **noncommercially**.
- **Assets: all rights reserved** — images, animations, sheets, videos, the
  titles and the characters: **no reuse in any other project**.
- **Selling the games** (Steam, stores...) is reserved to the author. The
  children's names and likenesses may not be used.
