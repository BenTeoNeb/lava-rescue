# Prompt templates

`art.py prompt SHEET` builds these from art.json; they are here to adapt them
by hand. Prompts are in English: the models follow them more precisely.

## Style block (art.json `style.text`) — example: children's picture book

```
ART STYLE: warm, cute children's picture-book illustration for 6-year-olds.
Rounded, chunky, simple shapes; big heads; big friendly eyes with a small white
highlight; a thick, clean, uniform dark-brown outline (#3B2416) around every
shape; flat colors with one soft cel-shading tone and a small highlight;
soft warm palette (no neon, no harsh black); light coming from the top-left.
No photorealism, no 3D render look, no texture noise, no text, no watermark.
```
Keep the outline color explicit: the outline measure and thickening look for
dark lines.

## Background block

```
BACKGROUND: perfectly flat, uniform pure magenta (#FF00FF) filling the whole
image. No floor, no horizon, no cast shadow, no vignette, no gradient, no text.
Every item is fully visible with an empty margin around it, nothing cropped,
and items never touch each other.
```
Avoid magenta / pink / violet items if possible; if needed, they survive the
keying thanks to their dark outline (only background touching the border is
removed).

## Style reference (first, alone)

```
A style reference lineup for a children's video game, in one single
horizontal row with big empty gaps between them: <a character>, <an animal>,
<an object>, <a tree>. Wide 16:9 image. [STYLE] [BACKGROUND]
```

## Every later prompt starts with

```
Use the attached image as the strict style reference: same outline
thickness, same colors, same shading, same eye style.
```

## Sheet of objects / decor

```
A sheet of N separate items for a children's video game, in one single
horizontal row (or: in a grid of R rows and C columns), with big empty gaps
between them, in this reading order, side view, facing RIGHT:
1. ...
2. ...
Draw them TO SCALE relative to each other, with the same line thickness
everywhere: 1 is about 100% of the biggest; 2 is about 40% ...
[STYLE] [BACKGROUND]
```
Variants of the same object (a burnt tree, a dry pond, a volcano's faces):
one sheet each, same order, "same drawing, only <what changes>".

## Character still

```
One <description>, full body, side view facing RIGHT, standing calmly, feet
flat on an invisible ground line at the bottom, neutral pose with legs
slightly apart. [STYLE] [BACKGROUND]
```
One character per image: best quality, and it is the start frame of its video.

## Character video (Veo, from the still on green)

```
Animate the character from the image as a game sprite reference. Static
camera, side view facing right. The character stays centered in the same spot
the whole time, like on a treadmill: never moves across the frame. The
character is small in the frame, with lots of empty space above its head so
it never leaves the frame when jumping. Flat solid green screen background
(#00FF00), even lighting, no shadow, no smoke, no effects, no other objects.
Keep the exact same character, clothes, colors and drawing style in every
frame. Each action starts and ends in the same neutral standing pose.
[00:00-00:02] Walks in place: exactly two smooth, regular walk cycles.
[00:02-00:04] Runs in place, fast and energetic: two regular run cycles.
[00:04-00:06] Jumps straight up in place and lands, twice.
[00:06-00:08] <a fun action>
```
4 actions in 8 s is tight but works; with more, make 2 videos (or "Extend").

## Seamless tile

```
A SEAMLESS TILEABLE TEXTURE of <ground>, seen straight from above (top-down,
orthographic, no perspective), for a 2D video game. Square image. <small
elements>, each about 1/25 of the image width. Evenly spread, no big objects,
no empty areas. Perfectly uniform lighting and color, no vignette, no light
spot, no gradient. The left edge continues seamlessly into the right edge,
the top edge into the bottom edge. [STYLE]
```

## When it goes wrong

| Problem | Say |
|---|---|
| background not flat, shadow under items | "Same image, but the background must be a perfectly flat pure magenta #FF00FF, with no shadow at all." |
| items touching | "Same image with much bigger gaps between the items." |
| style drifting | attach the reference again: "Redo it in the exact style of the attached reference." |
| outline far too thick (a big item) | "Same drawing with a thinner outline, like the attached reference." |
| a side view impossible to get (fences seen from the side...) | use single pieces (a post) and assemble them in code |
| Veo: head out of frame when jumping | "The character is small in the frame, lots of empty space above its head" |
| Veo: actions mixed up | 2 actions per 8 s video, or Extend |
| Veo: character changes between frames | regenerate, "Keep the exact same character in every frame" |
