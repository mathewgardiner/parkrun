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
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;500;600;700&display=swap">
<style>
  :root {
    --color-fg: #272727; --color-fg-muted: #666666; --color-bg: #f2f1f5; --color-panel: #ffffff;
    --color-border-line: #e4e2ea; --color-ok: #2f8a4a; --color-warn: #e89400; --color-bad: #c2412d;
    --font-anthropic-sans: "Montserrat", "Segoe UI", system-ui, -apple-system, Roboto, sans-serif;
    --font-anthropic-serif: Georgia, "Times New Roman", serif;
    --cds-font-size-caption: 13px; --cds-font-size-body: 15px; --cds-font-size-heading: 20px; --cds-font-size-title: 30px;
    --cds-font-weight-medium: 600;
    --cds-gap-xs: 4px; --cds-gap-sm: 8px; --cds-gap-md: 14px; --cds-gap-lg: 20px; --cds-gap-xl: 32px;
    --cds-pad-xs: 4px; --cds-pad-sm: 8px; --cds-pad-md: 12px; --cds-pad-lg: 18px; --cds-pad-xl: 28px;
    --cds-radius: 10px;
    --cds-chart-grid: #e7e5ee; --cds-chart-axis: #b5b0c2; --cds-chart-muted: #c4c0d0;
    --cds-surface-popover: #ffffff; --cds-border: #dcd9e4; --cds-shadow-popover: 0 4px 16px rgba(43,35,61,.14);
    --cds-text-secondary: #666666;
    color-scheme: light;
  }
  @media (prefers-color-scheme: dark) {
    :root {
      --color-fg: #f1eef6; --color-fg-muted: #b5adc4; --color-bg: #17131f; --color-panel: #231d30;
      --color-border-line: #3a3249; --color-ok: #5cbf78; --color-warn: #ffa300; --color-bad: #e8705c;
      --cds-chart-grid: #342c44; --cds-chart-axis: #5e5572; --cds-chart-muted: #574e69;
      --cds-surface-popover: #2b233d; --cds-border: #463d58; --cds-shadow-popover: 0 4px 16px rgba(0,0,0,.5);
      --cds-text-secondary: #b5adc4;
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
