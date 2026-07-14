#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <markdown.md> <theme.css> <output-dir> [default|compact]"
  exit 1
fi

MARKDOWN="$1"
CSS="$2"
OUTDIR="$3"
MARGIN_PROFILE="${4:-default}"

if [[ "$MARGIN_PROFILE" != "default" && "$MARGIN_PROFILE" != "compact" ]]; then
  echo "Unknown margin profile: $MARGIN_PROFILE (expected default or compact)" >&2
  exit 1
fi

if [[ ! -f "$MARKDOWN" ]]; then
  echo "Markdown file not found: $MARKDOWN" >&2
  exit 1
fi
if [[ ! -f "$CSS" ]]; then
  echo "CSS file not found: $CSS" >&2
  exit 1
fi

mkdir -p "$OUTDIR"

BASENAME="$(basename "${MARKDOWN%.*}")"
HTML_OUT="$OUTDIR/${BASENAME}.html"
PDF_OUT="$OUTDIR/${BASENAME}.pdf"
HTML_ABS="$(cd "$(dirname "$HTML_OUT")" && pwd)/$(basename "$HTML_OUT")"
PDF_ABS="$(cd "$(dirname "$PDF_OUT")" && pwd)/$(basename "$PDF_OUT")"

echo "Generating HTML -> $HTML_OUT"
TMPDIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Inline CSS into HTML for portability
{
  echo "<style>"
  cat "$CSS"
  echo "</style>"
} > "$TMPDIR/inline.css"

pandoc "$MARKDOWN" -s -H "$TMPDIR/inline.css" -o "$HTML_OUT"

cat > "$TMPDIR/export.js" <<'EOF'
const { chromium } = require('playwright-core');
const path = require('path');
const fs = require('fs');

const [htmlPath, pdfPath, marginProfile = 'default'] = process.argv.slice(2);
const candidatePaths = [
  process.env.CHROMIUM_PATH,
  process.env.CHROME_PATH,
  '/Applications/Chromium.app/Contents/MacOS/Chromium',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/opt/homebrew/bin/chromium',
  'chromium',
  'google-chrome',
  'chrome',
].filter(Boolean);

function pickExecutable() {
  for (const p of candidatePaths) {
    if (fs.existsSync(p)) return p;
    try {
      const resolved = require('child_process').execSync(`command -v ${p}`, {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      }).trim();
      if (resolved) return resolved;
    } catch (_) {
      // continue
    }
  }
  return null;
}

const executablePath = pickExecutable();

if (!htmlPath || !pdfPath) {
  console.error('Usage: node export.js <htmlPath> <pdfPath>');
  process.exit(1);
}

(async () => {
  if (!fs.existsSync(htmlPath)) {
    console.error(`HTML file not found: ${htmlPath}`);
    process.exit(1);
  }

  if (!executablePath) {
    console.error('Could not find Chromium/Chrome executable. Set CHROMIUM_PATH or CHROME_PATH to the binary.');
    process.exit(1);
  }

  const browser = await chromium.launch({
    headless: true,
    executablePath,
    args: ['--no-sandbox', '--disable-gpu', '--disable-dev-shm-usage'],
  });

  const page = await browser.newPage();
  const fileUrl = 'file://' + htmlPath;
  await page.goto(fileUrl);
  if (marginProfile === 'compact') {
    await page.addStyleTag({
      content: '@page { size: A4; margin: 8mm 26mm 10mm; }',
    });
  }
  const margins = marginProfile === 'compact'
    ? { top: '0', bottom: '0', left: '0', right: '0' }
    : { top: '0.5in', bottom: '0.7in', left: '0.6in', right: '0.6in' };
  await page.pdf({
    path: pdfPath,
    printBackground: true,
    displayHeaderFooter: true,
    headerTemplate: '<div></div>',
    footerTemplate: '<div style="font-size:9px; width:100%; text-align:center; color:#444; padding:6px 0;"><span class="pageNumber"></span>/<span class="totalPages"></span></div>',
    margin: margins,
    preferCSSPageSize: true,
  });

  await browser.close();
})();
EOF

cd "$TMPDIR"
npm init -y >/dev/null 2>&1
npm install playwright-core >/dev/null 2>&1

echo "Generating PDF -> $PDF_OUT"
node "$TMPDIR/export.js" "$HTML_ABS" "$PDF_ABS" "$MARGIN_PROFILE"

echo "Done."
