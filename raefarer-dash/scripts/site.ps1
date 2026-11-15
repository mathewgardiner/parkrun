# Writes <repo>/docs/raefarer-dash/index.html: the same page as the dashboard (src/index.html) with
# this week's data built in, served by GitHub Pages without a login. Run after build.ps1.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$dist = Join-Path $root 'dist'
$out = Join-Path (Split-Path $root -Parent) 'docs\raefarer-dash'
New-Item -ItemType Directory -Force $out | Out-Null

$ids = 'runners', 'sydney_table', 'combos', 'nendy', 'family'
$json = '{' + (($ids | % { "`"$_`":" + [System.IO.File]::ReadAllText((Join-Path $dist "$_.json")).Trim() }) -join ',') + '}'
$page = [System.IO.File]::ReadAllText((Join-Path $root 'src\index.html'))
$page = $page -replace '<meta name="dash-one-writer">\s*', ''

$html = @"
<!doctype html>
<html lang="en-AU">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<meta name="robots" content="noindex">
<title>parkrun HQ</title>
<style>
  :root {
    --color-fg: #1d1f1c; --color-fg-muted: #6b6d66; --color-bg: #f6f4ef; --color-panel: #ffffff;
    --color-border-line: #e3e0d8; --color-ok: #2f8a4a; --color-warn: #c98a12; --color-bad: #c2412d;
    --font-anthropic-sans: "Segoe UI", system-ui, -apple-system, Roboto, sans-serif;
    --font-anthropic-serif: Georgia, "Times New Roman", serif;
    --cds-font-size-caption: 13px; --cds-font-size-body: 15px; --cds-font-size-heading: 20px; --cds-font-size-title: 30px;
    --cds-font-weight-medium: 600;
    --cds-gap-xs: 4px; --cds-gap-sm: 8px; --cds-gap-md: 14px; --cds-gap-lg: 20px; --cds-gap-xl: 32px;
    --cds-pad-xs: 4px; --cds-pad-sm: 8px; --cds-pad-md: 12px; --cds-pad-lg: 18px; --cds-pad-xl: 28px;
    --cds-radius: 10px;
    --cds-chart-grid: #e9e6de; --cds-chart-axis: #b9b5aa; --cds-chart-muted: #c6c2b8;
    --cds-surface-popover: #ffffff; --cds-border: #ddd9cf; --cds-shadow-popover: 0 4px 16px rgba(0,0,0,.12);
    --cds-text-secondary: #6b6d66;
    color-scheme: light;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --color-fg: #ecebe6; --color-fg-muted: #a3a29b; --color-bg: #1b1c1a; --color-panel: #252623;
      --color-border-line: #383934; --color-ok: #5cbf78; --color-warn: #e0a83a; --color-bad: #e8705c;
      --cds-chart-grid: #34352f; --cds-chart-axis: #5d5e57; --cds-chart-muted: #55564f;
      --cds-surface-popover: #2c2d2a; --cds-border: #44453f; --cds-shadow-popover: 0 4px 16px rgba(0,0,0,.5);
      --cds-text-secondary: #a3a29b;
      color-scheme: dark;
    }
  }
  html, body { margin: 0; background: var(--color-bg); color: var(--color-fg); font-family: var(--font-anthropic-sans); font-size: 15px; }
  #dash-root { max-width: 1100px; margin: 0 auto; padding-block: 28px 48px;
    padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
</style>
<script src="https://cdnjs.cloudflare.com/ajax/libs/d3/7.8.5/d3.min.js"></script>
<script>
  // Stand-in for the Claude dashboard's 'dash' object: data is built in, drawings run on load and resize.
  (function () {
    const DATA = $json;
    const draws = {}, listeners = [];
    window.dash = {
      colors: ['var(--gp-judi)', 'var(--gp-katie)', 'var(--gp-mathew)'],
      data: (id) => (id in DATA ? { status: 'ok', data: DATA[id], columns: DATA[id][0] ? Object.keys(DATA[id][0]) : [] } : { status: 'missing', data: [] }),
      onData: (fn) => { listeners.push(fn); },
      draw: (name, fn) => {
        if (fn) { draws[name] = typeof fn === 'function' ? fn : (fn.update ? (el) => fn.update(el, fn.mount && fn.mount(el)) : () => {}); return; }
        document.querySelectorAll('[data-draw="' + name + '"]').forEach((el) => draws[name] && draws[name](el));
      },
      calc: () => {}, loader: () => {}, setLink: () => {}, refresh: () => {},
      params: () => ({}), setParams: () => {}, resetParams: () => {}
    };
    window.__dashRun = () => {
      listeners.forEach((f) => f());
      Object.keys(draws).forEach((n) => window.dash.draw(n));
    };
    let w = 0;
    window.addEventListener('resize', () => { if (Math.abs(window.innerWidth - w) > 20) { w = window.innerWidth; window.__dashRun(); } });
  })();
</script>
</head>
<body>
<div id="dash-root">
$page
</div>
<script>window.__dashRun();</script>
</body>
</html>
"@

[System.IO.File]::WriteAllText((Join-Path $out 'index.html'), $html, (New-Object System.Text.UTF8Encoding $false))
"site written: $(Join-Path $out 'index.html') ($([math]::Round($html.Length / 1KB)) KB)"
