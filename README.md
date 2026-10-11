# FocusFlow

A native macOS pomodoro timer (SwiftUI, no third-party code).

- Focus / Short Break / Long Break, 4-pomodoro cycles
- When time's up: **+5 / +10 / +15 min**, as many times as you like — it all stays one session
- Day / Month / Year stats: timeline, goal ring, focus by type, strongest hours, calendar heatmap, monthly bars
- History of every session (right-click to rename or delete)
- Menu bar timer, floating mini timer, notifications with "+5 more" / "Take break"

## Install

Needs macOS 13+ and the Xcode command line tools (`xcode-select --install`).

```bash
cd FocusFlow
bash build.sh --install
```

## Your data

Saved only on this Mac, at `~/Library/Application Support/FocusFlow/sessions.json`.

- Every write is atomic, so a crash can't leave a half-written file.
- A running session is saved every 30 seconds.
- `Backups/` keeps one copy per day for 30 days.
- If the file is ever unreadable, it's kept aside and the newest good backup is restored.
- Deleting or reinstalling the app doesn't touch this folder.

Settings → Data & backup lets you export JSON/CSV, import a backup, or move the data to another folder (for example iCloud Drive).
