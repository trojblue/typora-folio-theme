# Document export guide

A Typora-friendly light theme plus a sample Markdown document you can export to HTML or PDF with pandoc and headless Chromium. Everything here is ready for a public GitHub clone—no machine-specific paths required.

## Contents
- `sample-document.md` — sample content styled with the theme
- `sample-document.html` — HTML produced by pandoc
- `sample-document.pdf` — PDF exported via headless Chromium
- `folio-light.css` — Typora theme

## Prerequisites
- `pandoc` installed (for HTML export)
- Node.js + npm (for the PDF step)
- Chromium or Chrome installed; set `CHROMIUM_PATH` if the binary is not available as `chromium`/`google-chrome`
- Optional: Typora to preview the theme

**macOS quick installs:**

- Chromium: `brew install --cask chromium` then `xattr -cr /Applications/Chromium.app` to clear quarantine
- Node.js + npm: `brew install node`

## Setup
- Clone the repo wherever you like.
- Typora users: Preferences → Appearance → Open Theme Folder, then drop `folio-light.css` in and select it inside Typora.
- Ensure your browser path is known. Examples:
  - macOS: `export CHROMIUM_PATH="/Applications/Chromium.app/Contents/MacOS/Chromium"`
  - Linux: `export CHROMIUM_PATH="$(command -v chromium)"`

## Export HTML with pandoc
From the repo root:
```bash
pandoc sample-document.md -c folio-light.css -s -o sample-document.html
```

## Export HTML + PDF with the helper script
Use `export.sh` to generate both formats in one go. It installs Playwright in a temp folder each run, leaving the repo clean.
```bash
# example: write outputs to ./out
./export.sh sample-document.md folio-light.css out
```

Notes:
- Set `CHROMIUM_PATH` (or `CHROME_PATH`) to the browser binary if `chromium` is not on your `PATH`.
- Outputs are `<basename>.html` and `<basename>.pdf` in the target directory.
- Regenerate if you edit your Markdown or CSS before exporting again.
