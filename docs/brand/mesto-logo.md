# Mesto modular wordmark

The Mesto wordmark is a bespoke five-row construction made from 61 equal square cells. Its invisible grid connects the product name to parcels, blocks, homes, and the idea that one meaningful place exists among many.

## Construction

- The wordmark is always exactly five cells high.
- Every cell has the same dimensions and subtle corner radius.
- One empty grid column separates adjacent letters.
- All letters share a stable baseline; the open `M` and inset `O` soften the top silhouette.
- The component outputs a real SVG `rect` for every cell. Each rect exposes `data-cell`, `data-letter`, and `data-tone` attributes.

The canonical coordinate data lives in `MestoLogoHelper::LETTERFORMS`. Do not redraw the letters independently in page templates.

## Variants

```erb
<%# Primary lockup: one clay square represents “your place”. %>
<%= mesto_wordmark(variant: :accent, theme: :light) %>

<%# One-color use on photography, documents, or constrained production. %>
<%= mesto_wordmark(variant: :monochrome, theme: :dark) %>

<%# Controlled seasonal/campaign palette. %>
<%= mesto_wordmark(variant: :campaign, theme: :light) %>
```

Custom campaign cells can be addressed without changing the letterforms:

```erb
<%= mesto_wordmark(
  variant: :monochrome,
  highlighted_cells: {
    "M:1:1" => :secondary,
    "O:2:4" => :accent
  }
) %>
```

Available tones are `primary`, `accent`, `secondary`, and `tertiary`. Light and dark themes map those semantic tones to approved colors.

## Motion

Pass `animate: true` for the intro assembly. Cells enter in a measured left-to-right sequence over roughly 1.5 seconds; once the word has settled, the default accent changes from pine to clay and remains static. The component respects `prefers-reduced-motion` and immediately renders its final state when reduced motion is requested.

Use the assembly once in a page context, not repeatedly in a scrolling section. Hover may shift the single accent from clay to moss; avoid movement or randomized flicker across the full grid.

## Usage rules

- **Minimum digital width:** 112 px for the full wordmark. Below that size, use the modular `M` favicon rather than compressing the word.
- **Clear space:** keep at least one cell module on every side, measured from the visible cell bounds.
- **Light backgrounds:** use the light theme with pine primary cells and the optional clay accent.
- **Dark backgrounds:** use the dark theme with warm-paper primary cells. Never place pine cells on another dark green.
- **Default accents:** exactly one accent square, always at the inner point of the `M` (`M:2:2`) to match the favicon.
- **Campaign accents:** no more than four colored squares, preferably separated across different letters.
- **Monochrome:** always remains valid and should be used when color reproduction is uncertain.
- Never stretch, shear, outline, gradient-fill, rotate individual cells, change the five-row geometry, or fill the counters inside the letterforms.

The modular `M` in `public/icon.svg` is the approved small-format derivative. The full wordmark remains the primary brand signature.
