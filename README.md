# MBPA-YCCT — Random Edge Searcher

A tiny Windows tool that, while **Microsoft Edge is your active (foreground) window**,
periodically opens a new tab and runs a random nonsense Bing search like:

- `the apple crosses the road to where`
- `apple go to which store`
- `banana eat apple when`

Every phrase it has ever used is saved to `used_searches.txt` in this folder, so
**it never repeats a phrase — even if you close `start.bat` and reopen it later.**

## Microsoft Rewards points

If you want these searches to earn Microsoft Rewards points:

1. **Sign into your Microsoft account in Edge** (top-right profile icon — the same one tied to Rewards). If you're not signed in, no searches will count.
2. Make sure Edge is the active window when the search fires (the script already enforces this).
3. The script paces itself with a randomized 18–32 second interval and stops at **33 searches/day** (the desktop Rewards cap is ~30). The daily counter persists in `state.txt` across restarts so you don't burn unique phrases past the cap.
4. Points usually appear within a few minutes; sometimes Microsoft delays attribution by several hours. Check your Rewards dashboard at <https://rewards.bing.com/>.

If points still don't show up after 30+ searches:
- Confirm the Rewards profile icon in Edge is green/active.
- Try one search manually from `bing.com` while signed in — if that doesn't earn points either, your account/region is the issue, not the script.
- Avoid running this in an InPrivate window (private tabs aren't tied to your account).

## Requirements

- Windows 10 or 11
- Microsoft Edge installed
- PowerShell (built in)

## Usage

1. Download or clone this folder onto your PC.
2. Double-click **`start.bat`**.
3. Bring **Microsoft Edge** to the front and use it normally.
4. Every 18–32 seconds (randomized), while Edge is the active window, a new tab will open with a fresh random search — up to 33 searches per day.
5. To stop: close the black `start.bat` window (or press `Ctrl+C` in it).

If Edge is **not** the active window, nothing happens — the script just waits.

## Updates

`start.bat` now auto-updates `random_edge_searcher.ps1` from GitHub every time you launch it. So:

- **Normal updates:** just re-open `start.bat`. It pulls the latest script before running. No re-download needed.
- **Offline / GitHub unreachable:** it silently falls back to your local copy and runs that.
- **Pin a version:** open `start.bat` in Notepad and set `AUTO_UPDATE=0`.
- **Update `start.bat` itself:** rare, but if the launcher changes, you'll need to re-download the ZIP. Your `used_searches.txt` and `state.txt` are local-only — copy them to the new folder before running, and the memory + daily counter carry over.

## Tweaking

Open `random_edge_searcher.ps1` in Notepad and change:

- `$MinIntervalSeconds` / `$MaxIntervalSeconds` — search pacing (default 18–32s).
- `$DailyCap` — max searches per calendar day (default 33).
- The `$Nouns`, `$Verbs`, `$Places`, `$Adjectives` arrays — to add your own words.
- The `$Templates` array — to add new sentence shapes.

## Files

| File | Purpose |
| --- | --- |
| `start.bat` | Double-click to run. |
| `random_edge_searcher.ps1` | The actual script. |
| `used_searches.txt` | Created on first run. The permanent memory of every phrase used. **Do not delete** unless you want it to forget. |
| `state.txt` | Tracks today's date and search count so the daily cap survives restarts. |

## Troubleshooting

- **"Running scripts is disabled on this system"** — `start.bat` already passes `-ExecutionPolicy Bypass`, so this normally won't appear. If it does, run `start.bat` instead of the `.ps1` directly.
- **Edge doesn't open** — make sure Edge is installed at one of the standard locations. The script tries the `microsoft-edge:` URI first and falls back to `msedge.exe`.
- **It searches even when I tab away** — the script checks the foreground window right before each search, so it should stop within ~15 seconds of you switching apps. Note that opening a new Edge tab can briefly bring Edge back to the foreground.
- **It says it can't find a new phrase** — you've genuinely exhausted the combinations (millions are possible by default). Add more words or templates in the `.ps1`.
