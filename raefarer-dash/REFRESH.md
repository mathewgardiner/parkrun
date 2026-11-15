# Refreshing parkrun HQ

Dashboard: https://claude.ai/artifact/UVYPWkHQjcJpyWdUENpen3 (Claude "Data" dashboard)
Public copy (no login): https://mathewgardiner.github.io/parkrun/raefarer-dash/
Project folder: `C:\Users\mgard\dev\parkrun\raefarer-dash` inside the git repo `C:\Users\mgard\dev\parkrun` (github.com/mathewgardiner/parkrun). GitHub Pages serves the repo's `docs/` folder.
Runners (display order): Judi A7342171 (orange), Katie A3947996 (blue), Mathew A7157558 (green).

All rules and arithmetic live in `scripts/build.ps1`. The page (`src/index.html`) only displays its output.
The weekly refresh copies three pages, runs scripts, and swaps five files. It doesn't work anything out.

## Files

| Path | What it is |
|---|---|
| `data/A<id>.txt` | One per runner, produced by `scripts/extract-profile.js`. |
| `data/sydney-events.json` | The 36 Raefarer events, with drive time from Cammeray. |
| `data/not-raefarer.json` | Nearby events already decided not to count (so they aren't flagged as new). |
| `data/events.json` | parkrun's event feed, downloaded by `refresh.ps1`. |
| `scripts/build.ps1` | All the rules: Raefarer rounds, who's-going rankings, NENDYs, totals. Writes `dist/`. |
| `scripts/refresh.ps1` | Downloads the feed, flags possible new Sydney events, runs the build. |
| `scripts/share-card.ps1` | Renders `dist/share.png` (Messenger image) with headless Edge. Called by `refresh.ps1`. |
| `scripts/site.ps1` | Writes `../docs/raefarer-dash/index.html`: the page with data built in, for the public copy. |
| `scripts/publish-site.ps1` | Commits the runner files and the site, then pushes (Git's saved sign-in). `-NoPush` commits only. |
| `scripts/dataset-docs.ps1` | Writes the dataset updates (`dist/ds/*.json`) for new upload ids. |
| `src/index.html` | The dashboard page. `build.ps1` wraps it as `dist/page.json`. |

## Weekly refresh

1. **Copy the profiles.** For each runner, open `https://www.parkrun.com.au/parkrunner/<number>/` in the built-in browser. Wait a few seconds between pages. Run the contents of `scripts/extract-profile.js` with the browser's JavaScript tool, and write the returned text exactly as-is to `data/A<id>.txt`.
   - If the result starts with `ERROR`, or the page says "Let's confirm you are human", don't write the file. Ask the user to click Begin in the browser pane; never try to get around the check.
2. **Build.** `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\refresh.ps1`
   This also renders the share image, rebuilds the public copy, and commits and pushes it to GitHub.
   Keep its `CHANGES SINCE LAST BUILD` lines, the `site published` line, and any `NEW EVENT NEAR SYDNEY` warning for the report.
3. **Upload** `dist\runners.json`, `dist\sydney_table.json`, `dist\combos.json`, `dist\nendy.json` and `dist\family.json`: one Artifact `publish` call each, with `url` = the dashboard, `asset: true` and `file_path`. Note each returned asset id.
4. **Write the dataset updates.**
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dataset-docs.ps1 -runners <id> -sydney_table <id> -combos <id> -nendy <id> -family <id>`
5. **Apply them.** ArtifactData `list` on collection `datasets` to get each document's `version` and its old `source.url`. Then send one `batch` with five `update` entries `{op: "update", collection: "datasets", doc_id: <name>, file_path: "C:\\Users\\mgard\\dev\\parkrun\\raefarer-dash\\dist\\ds\\<name>.json", if_version: <version>}`.
6. **Delete the old files.** Artifact `delete` with `url` = the dashboard and `path` = each old asset id (the 32 characters after `/_blob/`).
7. **Report.** Send `dist\share.png` to the user (SendUserFile, status `proactive`, caption: the `CHANGES SINCE LAST BUILD` lines). Mention any new-event warning.

## Only when the page changes

After editing `src/index.html`, run `build.ps1`, then ArtifactData `set` on `files/index.html` with `file_path: dist\page.json` and the document's current `if_version`. Then run `site.ps1` and `publish-site.ps1` to update the public copy.

## Adding a new Sydney parkrun

Add it to `data/sydney-events.json` with its name (as parkrun shows it, without " parkrun"), slug, loc, lat, lon, and `mins`/`km` drive time from Cammeray. If it doesn't count, add its name to `data/not-raefarer.json` instead. Then do steps 2â€“6. No other flag is needed: an event none of you has run doesn't count toward finished rounds until one of you runs it.
