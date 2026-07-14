# Resume PDF Layout Guide

This guide explains how to fit a Markdown resume into a controlled PDF layout without changing the paper size, making the text unreadable, or accidentally hiding content. It is written for the repository's Pandoc and Chromium export workflow, but the debugging method applies to most HTML-to-PDF resume pipelines.

## Core Principle

Treat these as separate controls:

1. **Paper size** controls the physical PDF page, such as A4 or Letter.
2. **Content width** controls how much horizontal space the resume uses inside that page.
3. **Typography** controls font size, line height, and wrapping.
4. **Vertical spacing** controls margins around headings, paragraphs, and lists.
5. **Content length** controls how much information must fit.

Do not change the paper size to make content wider. Keep the page explicitly A4 or Letter and change the content margins or body width instead.

## Export Commands

The export helper accepts a Markdown file, theme CSS, output directory, and optional margin profile:

```bash
./export.sh path/to/resume.md path/to/resume-theme.css out
./export.sh path/to/resume.md path/to/resume-theme.css out compact
```

The default profile keeps the normal exporter margins. The compact profile injects a later `@page` rule so it can override margins defined by the theme.

## The Width Problem

Pandoc's standalone HTML may apply a narrow maximum width to `body`. Typora themes often style a `#write` element instead, but Pandoc output does not necessarily contain that wrapper.

This creates a common failure mode:

- The PDF page is normal A4.
- Large blank areas appear on both sides.
- Changing `#write`, PDF margins, or page size appears to do nothing.
- Text wraps early and spills onto another page.

The fix is to target the element that exists in the exported HTML:

```css
@media print {
  @page {
    size: A4;
  }

  body {
    max-width: none;
    width: auto;
    margin: 0;
    padding: 0;
  }
}
```

The important declaration is `max-width: none`. Without it, reducing page margins may not widen the text block.

## Where Page Margins Must Be Applied

The theme may already define an `@page` rule. A rule loaded earlier can override or conflict with margin options passed to Chromium.

For a special export profile, inject the final page rule after loading the HTML:

```javascript
await page.goto(fileUrl);

if (marginProfile === "compact") {
  await page.addStyleTag({
    content: "@page { size: A4; margin: 8mm 26mm 10mm; }",
  });
}
```

Because this style is added after the theme, it wins the cascade. Keep left and right margins equal so the content remains centered.

The margin values above are only a starting point. Larger side margins make the content narrower and taller. Smaller side margins make it wider and shorter.

## Recommended Tuning Order

Change one category at a time and regenerate after each meaningful adjustment.

### 1. Confirm the paper size

Use a fixed page size:

```css
@page {
  size: A4;
}
```

Do not use a wider custom paper size to solve wrapping.

### 2. Remove hidden width constraints

Before tuning margins, remove Pandoc's body constraint:

```css
body {
  max-width: none;
  width: auto;
  margin: 0;
  padding: 0;
}
```

If a width change has no visible effect, inspect the generated HTML and confirm which element actually wraps the content.

### 3. Tune side margins

Side margins are the main width control:

| Goal | Adjustment |
| --- | --- |
| Fewer wrapped lines | Reduce left and right margins |
| More vertical use | Increase left and right margins |
| Keep content centered | Use equal left and right values |
| Preserve paper size | Keep `size: A4` or `size: Letter` |

A practical search method is:

1. Start around `20mm` per side.
2. Export and count pages.
3. If it spills, try `16mm`, then `12mm`.
4. If it leaves too much space at the bottom, try `22mm`, then `24mm`.
5. Stop at the narrowest content width that still produces the desired page count.

This is faster and more reliable than repeatedly shrinking the font.

### 4. Tune font size

For a dense technical resume, `9pt` is a reasonable lower target. Avoid going below it unless the typeface remains clearly readable at 100% zoom and in print.

```css
body {
  font-size: 9pt;
}
```

Use width before font size. A narrow body can make even small text wrap excessively.

### 5. Tune line height

Once the width and page count are correct, use line height to balance readability and page fill:

```css
body,
li {
  line-height: 1.24;
}
```

Useful ranges:

| Element | Typical range |
| --- | --- |
| Body and bullets | `1.18` to `1.28` |
| Name | `1.20` to `1.35` |
| Contact block | `1.22` to `1.38` |
| Compact metadata | `1.15` to `1.25` |

If the page fits with substantial blank space, increase line height before increasing font size. This improves readability without changing wrapping as aggressively.

### 6. Tune section spacing

Use margins to adjust rhythm after width, font size, and line height are stable:

```css
h2 {
  margin-top: 0.64rem;
  margin-bottom: 0.16rem;
}

ul,
ol {
  margin-block: 0.11rem 0.22rem;
}

li {
  margin-block: 0.025rem;
}
```

Do not remove all spacing merely to reach one page. Section boundaries must remain obvious during a quick scan.

### 7. Edit content last

If layout adjustments cannot remove a small overflow without harming readability:

- move a certificate into Education;
- shorten long technology inventories;
- remove low-priority skills;
- combine closely related bullets;
- remove repeated claims.

Do not delete high-value evidence before confirming that the problem is not a hidden width constraint.

## A Resume-Local Print Override

Place a small print-only style block in the Markdown resume when one document needs different typography from the shared theme:

```html
<style>
@media print {
  @page { size: A4; }

  body {
    max-width: none;
    width: auto;
    margin: 0;
    padding: 0;
    font-size: 9pt;
    line-height: 1.24;
  }

  h1 {
    font-size: 1.25rem;
    line-height: 1.32;
  }

  h1 + p {
    font-size: 0.78rem;
    line-height: 1.34;
  }

  li {
    line-height: 1.24;
  }
}
</style>
```

This keeps shared theme behavior unchanged for other documents.

## Verification Workflow

Page count alone is not enough. A PDF can report one page while clipping text, producing an unreadable layout, or omitting content from the text layer.

### 1. Check page count and paper dimensions

On systems where `file` reports PDF pages:

```bash
file out/resume.pdf
```

An optional Python check using `PyPDF2`:

```bash
python3 -c 'from PyPDF2 import PdfReader; r=PdfReader("out/resume.pdf"); p=r.pages[0]; print("pages:", len(r.pages)); print("size:", float(p.mediabox.width), float(p.mediabox.height))'
```

Typical A4 dimensions are approximately `595 x 842` points.

### 2. Check the text layer

Verify that the last sections survived export and that the footer shows the expected total:

```bash
python3 -c 'from PyPDF2 import PdfReader; r=PdfReader("out/resume.pdf"); print("\n".join(p.extract_text() or "" for p in r.pages))'
```

Check for:

- the final skill or education line;
- the expected page number, such as `1/1`;
- correct reading order;
- no unexpected blank page.

### 3. Render the PDF to an image

On macOS, render the first page with `sips`:

```bash
sips -s format png out/resume.pdf --out /tmp/resume-preview.png
```

Then inspect `/tmp/resume-preview.png` with an image-viewing tool. In Codex, use the local image viewing capability rather than inferring layout from source code or page count.

### 4. Perform a visual checklist

Inspect the rendered page for:

- balanced left and right margins;
- a normal A4 or Letter aspect ratio;
- no clipped name, contact details, bullets, or footer;
- readable type at normal zoom;
- no headings stranded at the bottom of a page;
- no unexpected large blank region caused by excessive width;
- no dense wall of text caused by insufficient line height;
- consistent section-rule width;
- content that fills the page without touching the edges.

If the visual result disagrees with assumptions from the CSS, trust the rendered image and inspect computed constraints in the generated HTML.

## Common Failure Modes

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Large side whitespace | Pandoc `body` has a narrow `max-width` | Set `body { max-width: none; }` in print CSS |
| Changing `#write` does nothing | Pandoc HTML has no `#write` wrapper | Target `body` or inspect the generated HTML |
| Export margin changes do nothing | Theme `@page` rule wins the cascade | Inject a later `@page` rule after page load |
| PDF becomes visually too wide | Side margins are too small | Increase left and right margins equally |
| One or two lines spill to page 2 | Width or vertical spacing is just below threshold | Adjust side margins first, then line height and section spacing |
| One page has a large blank bottom area | Content is too wide or spacing is too tight | Increase side margins or line height |
| Page count is correct but content is missing | Clipping or failed rendering | Extract text and inspect a rendered image |
| Header is clipped | Top margin is too small or body padding is negative | Increase top margin and remove negative positioning |
| Footer is missing | Bottom margin is too small for the footer template | Reserve sufficient bottom margin and verify the text layer |

## Final Rule

Use this sequence:

1. Fix the page size.
2. Remove hidden body-width constraints.
3. Tune symmetric side margins.
4. Set a readable font size.
5. Adjust line height.
6. Adjust section spacing.
7. Edit content only if necessary.
8. Verify page count, text content, and a rendered image.

The most important lesson is that a width problem should be solved as a width problem. Repeatedly shrinking fonts or changing the paper size can hide the real cause and produce a worse resume.
