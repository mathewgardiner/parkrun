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
| `data/history.json` | Family totals per build date. `build.ps1` adds an entry each build and compares with the latest one at least 6 days older for the "+3 since 15 Nov" lines on the family tiles. Don't edit it by hand. |
| `data/raefarer-latched.json` | Each runner's most Raefarer rounds finished. `build.ps1` keeps it up to date, so a new event never takes a finished round away. Don't edit it by hand. |
| `data/milestones.json` | parkrun's milestone t-shirt counts (25, 50, 100, 200, 250, then every 100 to 1000), for runs and volunteer credits. |
| `data/start-times.json` | Saturday start time for each event shown on the page. Written by `scripts/set-start-time.ps1`. |
| `scripts/extract-start-time.js` | Run on an event's parkrun page; returns its Saturday start time, e.g. `7:00am`. |
| `scripts/set-start-time.ps1` | Saves one event's start time to `data/start-times.json`. |
| `scripts/refresh-status.ps1` | From the runner files: whether each runner's result for this week (since Saturday midnight) is in, who has changed since the last build, and whether the week is done. `-Mark` records a build in `dist/last-build.json`. |
| `data/retired-events.json` | Closed events (e.g. Jindabyne Sport and Recreation): their runs still count, but `build.ps1` doesn't warn that they're missing from the feed. |
| `data/events.json` | parkrun's event feed, downloaded by `refresh.ps1`. |
| `scripts/build.ps1` | All the rules: Raefarer rounds, who's-going rankings, NENDYs, totals. Writes `dist/`. |
| `scripts/refresh.ps1` | Downloads the feed, flags possible new Sydney events, runs the build. |
| `scripts/share-card.ps1` | Renders `dist/share.png` (Messenger image) with headless Edge. Called by `refresh.ps1`. |
| `scripts/site.ps1` | Writes `../docs/raefarer-dash/index.html`: the page with data built in, for the public copy. |
| `scripts/publish-site.ps1` | Commits the runner files and the site, then pushes (Git's saved sign-in). `-NoPush` commits only. |
| `scripts/dataset-docs.ps1` | Writes the dataset updates (`dist/ds/*.json`) for new upload ids. |
| `src/index.html` | The dashboard page. `build.ps1` wraps it as `dist/page.json`. |

## When it runs

parkrun events post results at different times, so the refresh tries several times and updates for whoever has results so far. One scheduled task, `parkrun-dashboard-refresh`, runs it at 9:30am, 10:30am, 12:30pm, 3:30pm and 8:30pm on both Saturday and Sunday. Sunday 8:30pm is the last attempt of the week. An attempt only builds when something is new, and attempts stop at step 0 once all three results are in and built.

0. **Should this attempt run?** Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\refresh-status.ps1`.
   - If it prints `WEEK DONE: YES`, stop: report "All three results are in and on the dashboard" and do nothing else.
   - **Every attempt except the last** (Sunday 8:30pm): call `get_usage` (mcp__ccd_session_mgmt__get_usage). If any plan window shows 90% used or more, stop and report it; the next attempt will try again.
   - Otherwise do step 1.
   - **Waiting for the human check** (step 1): send one notification, then wait until 10 minutes before the next attempt on the same day (10:20am, 12:20pm, 3:20pm, 8:20pm), or until 11:59pm for an 8:30pm attempt. The last attempt (Sunday 8:30pm) also sends one reminder at about 10pm. When the time is up, keep any runner files already copied and go on to step 1b.1b. **Anything new?** After step 1, run `refresh-status.ps1` again.
   - If it prints `NEW SINCE LAST BUILD: none`, stop without building: report which runners don't have this week's result yet (its `no result this week yet` lines), and that the next attempt will check again.
   - Otherwise do steps 2–8, and in the step 7 report include its `no result this week yet` lines, if any.
## Weekly refresh

1. **Copy the profiles.** For each runner, open `https://www.parkrun.com.au/parkrunner/<number>/` in the built-in browser. Wait a few seconds between pages. Run the contents of `scripts/extract-profile.js` with the browser's JavaScript tool, and write the returned text exactly as-is to `data/A<id>.txt`.
   - If the result starts with `ERROR`, or the page says "Let's confirm you are human", don't write the file. Ask the user to click Begin in the browser pane; never try to get around the check.
   Then **fill in start times.** Run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build.ps1 -ListMissingStartTimes`. It writes nothing; it prints `MISSING START TIME: <event> | <url>` for each Sydney event or NENDY with no start time yet (usually none, or a new NENDY). For each line, open the url in the built-in browser, run `scripts/extract-start-time.js`, and if it returns a time (not `ERROR`), run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\set-start-time.ps1 -Event '<event>' -Time '<time>'`, using the event name exactly as printed. The human check rule above applies here too; if an event still can't be read, leave it (the page shows "—") and mention it in the report.
2. **Build.** `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\refresh.ps1`
   This also renders the share image, rebuilds the public copy, and commits and pushes it to GitHub.
   Keep its `CHANGES SINCE LAST BUILD` lines (these include any milestone reached), the `site published` line, and any `NEW EVENT NEAR SYDNEY` warning for the report.
3. **Upload** `dist\runners.json`, `dist\sydney_table.json`, `dist\combos.json`, `dist\nendy.json` and `dist\family.json`: one Artifact `publish` call each, with `url` = the dashboard, `asset: true` and `file_path`. Note each returned asset id.
4. **Write the dataset updates.**
   `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\dataset-docs.ps1 -runners <id> -sydney_table <id> -combos <id> -nendy <id> -family <id>`
5. **Apply them.** ArtifactData `list` on collection `datasets` to get each document's `version` and its old `source.url`. Then send one `batch` with five `update` entries `{op: "update", collection: "datasets", doc_id: <name>, file_path: "C:\\Users\\mgard\\dev\\parkrun\\raefarer-dash\\dist\\ds\\<name>.json", if_version: <version>}`.
6. **Delete the old files.** Artifact `delete` with `url` = the dashboard and `path` = each old asset id (the 32 characters after `/_blob/`).
7. **Report.** Send `dist\share.png` to the user (SendUserFile, status `proactive`, caption: the `CHANGES SINCE LAST BUILD` lines). Mention any new-event warning.
8. **Record it.** `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\refresh-status.ps1 -Mark`. This records what was built, so later attempts only build again when someone has a new result.

## Only when the page changes

After editing `src/index.html`, run `build.ps1`, then ArtifactData `set` on `files/index.html` with `file_path: dist\page.json` and the document's current `if_version`. Then run `site.ps1` and `publish-site.ps1` to update the public copy.

## Adding a new Sydney parkrun

Add it to `data/sydney-events.json` with its name (as parkrun shows it, without " parkrun"), slug, loc, lat, lon, and `mins`/`km` drive time from Cammeray. If it doesn't count, add its name to `data/not-raefarer.json` instead. Then do steps 2–6. No other flag is needed: an event none of you has run doesn't count toward finished rounds until one of you runs it. Once it counts, it joins each person's current round; rounds already finished stay finished (`data/raefarer-latched.json`).
