# Landing-page explainer video

`composition.html` is a 28-second motion piece built from the Mesto brand system (paper/pine/clay palette, Literata and Manrope, the five-row cell wordmark). Every property is a pure function of time, so renders are deterministic.

Story: a buyer's questions → start with an address → pinpoint the exact apartment → public sources stack up as map layers → they collapse into a sourced report → end card.

### Landing-page cut: from dark to clear

`story.html` is the version on the landing page, in Bulgarian and English (`?lang=en`). It tells the same product story as problem → solution. A neighbourhood sits at dusk, full of unanswered questions. The buyer checks the address in Mesto, the clay "your place" cell drops into the building, and light spreads outwards, turning each question into a sourced answer before the scene becomes the report. Render it with `--comp story`; files are named `mesto-explainer-story-<lang>.*`, and its poster is the first frame so the page never flashes a lit frame before playback. `story.css` builds on `composition.css`, so keep both.

## Preview

Open `composition.html` in a browser. Space plays or pauses, arrow keys scrub (hold Shift for bigger steps). Add `?lang=en` for English or `?t=18.5` to freeze on a moment.

## Render

```sh
cd script/explainer_video
npm install
npm run render            # landing-page cut, both languages
node render.mjs --lang en --stills 3,12.5,22.5 --out ../../tmp   # review stills
```

Each language writes `mesto-explainer-<lang>.mp4`, `.webm` and `-poster.jpg` to `app/assets/videos/`. The lossless master is kept in `tmp/`. Rendering takes about ten minutes per language at 60 fps.

All data in the video is illustrative and labelled as such on screen. Keep claims in line with the product limits in the root README: the report shows public information and what remains to verify. It does not verify ownership or encumbrances.
