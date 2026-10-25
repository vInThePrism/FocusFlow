# FocusFlow

A native macOS pomodoro timer (SwiftUI, no third-party code).

- Focus / Short Break / Long Break, 4-pomodoro cycles
- When time's up: **+5 / +10 / +15 min**, as many times as you like — it all stays one session
- Day / Month / Year stats: timeline, goal ring, focus by type, strongest hours, calendar heatmap, monthly bars
- **Plan**: a daily study target (hours), split into recurring tasks (hours per day, chosen weekdays); bulk add with `Name | hours | note` lines (`30m` for minutes); per-day completion; a day/week timeline of time blocks
- **Two goals side by side**: pomodoro sessions per day, and study hours per day
- **Link session to task**: focus time counts toward a plan task; "Today's plan" and "What I did" on the Focus page
- **Calendar + DDL**: month/week/list view with daily completion rings, focus dots and deadlines
- **History + manual log**: search, filter, and add past focus sessions by hand (optionally left out of stats)
- Three color themes — Tomato, Pink and a dark Purple (Settings → Appearance, or the ••• menu)
- Menu bar timer, floating mini timer, notifications with "+5 more" / "Take break"

## Install

Needs macOS 13+ and the Xcode command line tools (`xcode-select --install`).

```bash
cd FocusFlow
bash build.sh --install
```

## Your data

Saved only on this Mac, at `~/Library/Application Support/FocusFlow/sessions.json` — sessions, plan tasks, time blocks and deadlines all live in this one file.

- Every write is atomic, so a crash can't leave a half-written file.
- A running session is saved every 30 seconds.
- `Backups/` keeps one copy per day for 30 days.
- If the file is ever unreadable, it's kept aside and the newest good backup is restored.
- Deleting or reinstalling the app doesn't touch this folder.

Settings → Data & backup lets you export JSON/CSV, import a backup, or move the data to another folder (for example iCloud Drive).

## LeetCode

- On first use, NeetCode 150 and Blind 75 are available offline. Problems shared between lists share notes and progress. Sources and pinned data revision are in `THIRD_PARTY_NOTICES.md`.
- Choose a topic (NeetCode algorithm categories plus imported tags) and 2 / 3 / 5 / 8 problems, then generate a fixed daily queue. Regenerating requires confirmation and preserves all progress.
- **Import problem** accepts a LeetCode `.com` or `.cn` problem URL. Known problems fill their metadata; unknown problems need a title and can include difficulty and topics. Imported lists open immediately.
- **Import list** supports common lists, CSV/JSON, or one known problem URL/number per line. Public list URL support is limited to the bundled NeetCode 150 / Blind 75 snapshots; arbitrary shared lists are not scraped.
- CSV headers: `url,title,difficulty,topics` (`id` may replace URL for known problems). Separate CSV topics with semicolons. JSON accepts an array of problem objects or `{ "name": "My list", "problems": [...] }`, with topics as an array or separated text. Unknown problems require a URL and title. Imports preview duplicates and rejected rows before saving.
- Notes save automatically. **Record result** logs a solve without a timer. **Start Focus** uses the existing timer; finish/break/reset asks Yes / With hints / Not yet / Skip. Repeated extensions stay in one session. As before, unfinished timed sessions shorter than one minute are not retained.
- Solves (independent or with hints) start reviews at 1 / 3 / 7 / 14 / 30 local calendar days. Again resets to the next day; Remembered advances, finishing after the final review. Review time never counts as a new problem automatically.
- History manual records can optionally link a problem. Their existing statistics toggle still applies. All LeetCode data is included in existing JSON backup/export/import; CSV session export includes the associated problem and result.

### Verification

`swift test` runs the import, shared-progress, legacy-data, persistence, review-date and timer-association regressions. `bash build.sh` creates the app; `bash build.sh --install` replaces the installed app.

## Interview Preparation

In Plan, use **View preparation** on the existing Interview Preparation task. Start Focus uses the shared timer; Finish or Take break offers optional **Save / Skip** output logging. Extensions remain part of the same session.

Track Coding Questions, Project BQs, Project Reviews, General Questions and Mock Interviews separately. Use **Add item** for multiple outputs. History's manual record panel has optional preparation details and **Record quantities only (0 min)**; use a session's **Preparation details…** menu to add, edit or delete outputs. Counts never add focus minutes or change task completion goals. Stats shows the same selected day/month/year with a small quantity trend. JSON backups and imports include all preparation entries; deleting a session deletes its linked outputs.
