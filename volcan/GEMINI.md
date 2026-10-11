# Les images du jeu avec Gemini — guide de style

Le jeu utilise automatiquement les images du dossier `images/`. S'il manque
une image, il garde le dessin actuel : on peut avancer une image à la fois.

## Le secret de la cohérence : 3 règles

1. **Un bloc de style identique** collé dans *chaque* prompt (ci-dessous).
2. **Une image de référence** (étape 0) que vous joignez à *chaque* nouveau
   prompt dans Gemini, avec la phrase « Use the attached image as the strict
   style reference ».
3. **Une seule conversation Gemini** pour tout. Si Gemini commence à dériver,
   rejoignez l'image de référence.

Prompts en anglais : Gemini les suit plus précisément.

---

## Les deux blocs à coller

### STYLE (dans tous les prompts)
```
ART STYLE: warm, cute children's picture-book illustration for 6-year-olds.
Rounded, chunky, simple shapes; big heads; big friendly eyes with a small white
highlight; a thick, clean, uniform dark-brown outline (#3B2416) around every
shape; flat colors with one soft cel-shading tone and a small highlight;
soft warm palette (no neon, no harsh black); light coming from the top-left.
No photorealism, no 3D render look, no texture noise, no text, no watermark.
```

### FOND (dans tous les prompts sauf le sol)
```
BACKGROUND: perfectly flat, uniform pure magenta (#FF00FF) filling the whole
image. No floor, no horizon, no cast shadow, no vignette, no gradient.
The whole subject is visible with an empty margin around it, nothing cropped.
```

---

## Étape 0 — L'image de référence → `planches/reference.png`
On la fait en premier ; elle fixe le style de tout le reste. Regénérez-la
jusqu'à ce qu'elle vous plaise vraiment.
```
A style reference lineup for a children's video game, in one single
horizontal row with big empty gaps between them: a small 5-year-old boy with
short dark curly hair, blue t-shirt and navy shorts; a red fox; a white hen;
a round leafy green tree. All seen from the side, facing RIGHT, standing.
Wide 16:9 image.
[STYLE]
[FOND]
```
(Pas besoin de la découper : elle sert seulement de modèle.)

---

## Étape 1 — Les personnages, UN par image
Une image par personnage : meilleure qualité, et c'est l'image de départ
idéale pour animer ensuite avec Veo. Commencez chaque prompt par :
```
Use the attached image as the strict style reference: same outline
thickness, same colors, same shading, same eye style.
```
puis le texte du personnage, puis `[STYLE]` et `[FOND]`.

Position commune (à inclure) :
```
POSE: full body, side view facing RIGHT, standing calmly, feet/paws flat on
an invisible ground line at the bottom, neutral pose with legs slightly apart.
```

### Les enfants
Adaptez les descriptions pour qu'ils ressemblent aux vôtres. Les tailles
relatives sont réglées dans le jeu : Rami sera automatiquement plus petit.

| Fichier | Description à coller |
|---|---|
| `rami` | `Rami, a cute small boy about 5 years old, short dark curly hair, round face, blue t-shirt with a small white star, navy shorts, brown sneakers, a big happy smile. Turned three-quarters toward the right.` |
| `zina` | `Zina, a cute girl about 7 years old, dark hair in two round puffs tied with a yellow bow, pink dress, brown shoes, a confident smile. Turned three-quarters toward the right.` |
| `lila` | `Lila, a cute girl about 7 years old, long chestnut hair with a small red bow, teal dress, brown shoes, a gentle smile. Turned three-quarters toward the right.` |

### Les animaux (petits, bébés, adorables)
| Fichier | Description à coller |
|---|---|
| `renard` | `A cute baby red fox, orange fur, white chest and white muzzle, white tip on a big fluffy tail, black little paws, pointy ears, sly but friendly look.` |
| `poule` | `A cute plump white hen, small red comb and wattle, yellow beak, orange legs, round body, little tail feathers.` |
| `ecureuil` | `A cute red squirrel, orange-brown fur, cream belly, big fluffy tail curled up behind its back, tufted ears, sitting up on its hind legs.` |
| `marcassin` | `A cute wild boar piglet (marcassin), light brown with cream horizontal stripes along its body, pink snout, small ears, tiny curly tail, four short legs.` |
| `herisson` | `A cute round hedgehog, brown spines, cream-colored face and belly, small black nose, tiny feet, shy smile.` |

Découper chaque image (depuis le dossier `games`) :
```
python3 volcan/outils/decoupe.py volcan/planches/renard.png renard
```

---

## Étape 2 — Le décor
Même début (« Use the attached image as the strict style reference… »), puis :

**Arbres** → `planches/arbres.png`, découpage `arbre1 arbre2 arbre3`
```
A sheet of 3 different cute forest trees in one single row with big empty
gaps between them: a round oak, a tall bushy tree, a small apple tree with a
few red apples. Full trees with trunk, side view.
[STYLE]
[FOND]
```

**Maisons** → `planches/maisons.png`, découpage `maison_rouge maison_bleue maison_jaune`
```
A sheet of 3 small cute wooden animal shelters in one single row with big
empty gaps between them, front view, each with a round door and a little
window. Left: RED roof. Middle: BLUE roof. Right: YELLOW roof. Exactly the same
hut shape, only the roof color changes.
[STYLE]
[FOND]
```

**Volcan** → `planches/volcan.png`, découpage `volcan`
```
One cute friendly cartoon volcano, side view, grey-brown rounded rocky cone,
glowing orange lava in the crater and two lava streams running down its
sides, a small puff of smoke. Not scary at all.
[STYLE]
[FOND]
```

**Petits objets** (je les brancherai dans le jeu ensuite) → `planches/objets.png`,
découpage `champignon fleurs rocher buisson buche`
```
A sheet of 5 small forest props in one single row with big empty gaps between
them: a red mushroom with white dots, a small cluster of wild flowers, a grey
rock, a round bush with red berries, a cut wooden log.
[STYLE]
[FOND]
```

**Le sol** → une texture qui se répète (le jeu la répète en petites tuiles,
réglable avec `GRASS_TILE` dans `world.lua`). Pas de fond magenta : envoyez-la
telle quelle, je la prépare (lumière égalisée, raccords).
```
Use the attached image as the strict style reference: same outline
thickness, same colors, same shading.

A SEAMLESS TILEABLE TEXTURE of a soft green forest meadow ground, seen
straight from above (top-down, orthographic, no perspective), for a 2D
children's video game. Square image, 1:1.

Content: short green grass with many SMALL grass tufts, a few tiny wild
flowers (yellow, white, light blue), a few small patches of lighter grass.
Everything is small: each tuft is about 1/25 of the image width.
Evenly spread over the whole image, no big empty areas, no cluster in the
middle, no large objects (no trees, no rocks, no bushes, no characters,
no paths).

Very important for tiling: perfectly uniform lighting and color over the
whole image, no vignette, no light spot, no gradient, no shadows from the
top or the sides. The left edge must continue seamlessly into the right
edge, and the top edge into the bottom edge.

Style: cute children's picture-book illustration, soft warm colors, thin
dark-brown outlines on the tufts and flowers, flat colors with soft
cel-shading. No text, no watermark.
```

---

## Si Gemini rate une image
- Fond pas uni ou ombre au sol : *"Same image, but the background must be a
  perfectly flat pure magenta #FF00FF, with no shadow at all."*
- Dessins qui se touchent : *"Same image with much bigger gaps between the items."*
- Style qui dérive : rejoignez `reference.png` et redemandez *"Redo it in the
  exact style of the attached reference."*
- Vérifier avant de découper : ajoutez `--apercu` à la commande.

## Régler les tailles dans le jeu
Si un personnage paraît trop grand ou trop petit, changez son chiffre dans
`HEIGHTS`, en haut de `art.lua`.

---

## Plus tard : l'animation — une vidéo Veo par personnage

Chaque personnage, enfants compris, a **une seule vidéo de 8 secondes** avec
**4 actions, 2 cycles chacune**. On donne à Veo l'image fixe du personnage et
le prompt ci-dessous (Veo comprend les horaires). Mon script redécoupe ensuite
la vidéo en animations pour le jeu. Il faudra installer `ffmpeg` :
`brew install ffmpeg`.

**8 vidéos en tout** (5 animaux + 3 enfants), toutes construites pareil :

| Moment | Action | Fichiers produits |
|---|---|---|
| 0 → 2 s | marche | `renard_marche`… |
| 2 → 4 s | course | `renard_course`… |
| 4 → 6 s | saut | `renard_saut`… |
| 6 → 8 s | « Aïe, ça brûle ! » | `renard_aie`… |

(La pose de victoire des enfants reste une image Gemini, voir plus bas.)

### Prompt vidéo (Veo, avec l'image du personnage)
Remplacez `[QUI]` par `the character` (animaux) ou `the child` (enfants).
```
Animate [QUI] from the image as a game sprite reference. Static camera, side
view facing right. [QUI] stays centered in the same spot the whole time, like
on a treadmill: never moves across the frame. Flat solid green screen
background (#00FF00), even lighting, no shadow, no smoke, no effects, no other
objects. The character is small in the frame, with lots of empty space above
its head so it never leaves the frame when jumping. Keep the exact same
character, clothes, colors and drawing style in every frame. Each action
starts and ends in the same neutral standing pose.
[00:00-00:02] Walks in place: exactly two smooth, regular walk cycles.
[00:02-00:04] Runs in place, fast and energetic: two regular run cycles.
[00:04-00:06] Jumps straight up in place and lands, twice: crouch, jump, land.
[00:06-00:08] "Ouch, my bottom is hot!": hops up twice in surprise with a
funny cartoon "ouch!" face (both hands on the bottom for a child, tail up
for an animal), not painful-looking, then lands.
```

### Découper la vidéo
Mettez la vidéo dans `volcan/videos/` (ex. `zina.mp4`), puis depuis le dossier `games` :
1. Regarder où sont les actions (planche avec le numéro de chaque image) :
   ```
   python3 volcan/outils/video.py volcan/videos/zina.mp4 --planche
   ```
2. Découper en donnant les numéros d'images de chaque action :
   ```
   python3 volcan/outils/video.py volcan/videos/zina.mp4 zina marche=12-49 course=50-83 saut=98-121 aie=146-171
   ```
   La marche et la course deviennent des boucles (le script trouve le meilleur
   raccord). L'image la plus calme devient la pose de repos. Les timings de
   Veo ne sont jamais exacts : c'est pour ça qu'on regarde la planche d'abord.
   Je peux aussi le faire pour vous.

### Pose de victoire des enfants (Gemini, avec l'image de l'enfant jointe)
→ `rami_bravo`, `zina_bravo`, `lila_bravo`
```
The same child as in the attached image, cheering happily with both arms up
in the air, big smile, eyes closed with joy, three-quarter view facing right.
[STYLE]
[FOND]
```

### Si Veo mélange les actions
- 4 actions en 8 secondes, c'est serré. Si les actions se mélangent, faire
  deux vidéos : « marche + course » puis « saut + aïe » (4 s chacune).
  Dans Flow, on peut aussi utiliser **Extend** pour continuer la même vidéo.
- Si le personnage change d'apparence pendant la vidéo : regénérer, en insistant
  sur « Keep the exact same character in every frame ».

### En pantin (si Veo ne donne rien de bon)
Une image « en pièces détachées » :
  ```
  The same character as in the attached image, shown as a cut-out puppet kit:
  each body part drawn separately with big gaps between them, in one single
  row: head, body, front leg, back leg, tail. Same style, same colors.
  [STYLE]
  [FOND]
  ```
