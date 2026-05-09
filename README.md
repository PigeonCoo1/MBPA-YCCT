# MBPA-YCCT — Random Edge Searcher

A tiny Windows tool that, while **Microsoft Edge is your active (foreground) window**,
periodically opens a new tab and runs a random nonsense Bing search like:

- `the apple crosses the road to where`
- `apple go to which store`
- `banana eat apple when`

Every phrase it has ever used is saved to `used_searches.txt` in this folder, so
**it never repeats a phrase — even if you close `start.bat` and reopen it later.**

## Requirements

- Windows 10 or 11
- Microsoft Edge installed
- PowerShell (built in)

## Usage

1. Download or clone this folder onto your PC.
2. Double-click **`start.bat`**.
3. Bring **Microsoft Edge** to the front and use it normally.
4. Every 15 seconds, while Edge is the active window, a new tab will open with a fresh random search.
5. To stop: close the black `start.bat` window (or press `Ctrl+C` in it).

If Edge is **not** the active window, nothing happens — the script just waits.

## Tweaking

Open `random_edge_searcher.ps1` in Notepad and change:

- `$IntervalSeconds = 15` — how often to fire a search while Edge is active.
- The `$Nouns`, `$Verbs`, `$Places`, `$Adjectives` arrays — to add your own words.
- The `$Templates` array — to add new sentence shapes.

## Files

| File | Purpose |
| --- | --- |
| `start.bat` | Double-click to run. |
| `random_edge_searcher.ps1` | The actual script. |
| `used_searches.txt` | Created on first run. The permanent memory of every phrase used. **Do not delete** unless you want it to forget. |

## Troubleshooting

- **"Running scripts is disabled on this system"** — `start.bat` already passes `-ExecutionPolicy Bypass`, so this normally won't appear. If it does, run `start.bat` instead of the `.ps1` directly.
- **Edge doesn't open** — make sure Edge is installed at one of the standard locations. The script tries the `microsoft-edge:` URI first and falls back to `msedge.exe`.
- **It searches even when I tab away** — the script checks the foreground window right before each search, so it should stop within ~15 seconds of you switching apps. Note that opening a new Edge tab can briefly bring Edge back to the foreground.
- **It says it can't find a new phrase** — you've genuinely exhausted the combinations (millions are possible by default). Add more words or templates in the `.ps1`.
