# Mass Message Setup — Shortcuts Builder

`MassMessageSetup.applescript` builds a **"Mass Message Sender \[YYYY-MM-DD\]"**
shortcut inside the macOS **Shortcuts** app by driving the UI with
`System Events` (keyboard only — no mouse-drag coordinates, so it doesn't
break on different screen sizes).

It chains off `ContactImporter.applescript`: that script now writes the name
of the Contacts group it created to `~/Desktop/contact_group_name.txt`, and
this script reads it back to target the right group.

Target environment: **macOS Sonoma / Sequoia**, **Shortcuts 5.0+**.

---

## ⚠️ Read this before you run it (honest expectations)

The Shortcuts app has **poor scripting / accessibility support**. This script
does the reliable parts automatically and degrades gracefully on the fragile
parts instead of crashing. Two steps are known to be unreliable across
versions:

1. **Re-ordering actions.** Shortcuts has **no documented keyboard command**
   to move an action up or down (Apple only supports dragging). The script
   attempts `Cmd+Ctrl+Up` as a best effort; if your build ignores it, nothing
   moves and you finish the ordering by dragging. This is a limitation of the
   app, not a bug you can fully script around.
2. **Magic Variable binding** (wiring the Text action's output into the
   Send Message field) is also unreliable to automate.

**Bottom line:** treat the output as a *scaffold* — the script adds all the
actions and names/saves the shortcut; you may need ~30 seconds to drag the
`Text`, `Send Message`, and `Wait` actions above `End Repeat` and to pick the
Magic Variable by hand. Every UI step is wrapped in `try`, so a failure shows
a dialog naming the step rather than dying silently.

---

## 1. Grant Accessibility permission (required)

Because the script types and clicks for you, macOS needs Accessibility
permission for whatever app launches it:

**System Settings → Privacy & Security → Accessibility** → enable:
- **Script Editor** — if you press Run in Script Editor
- **Terminal** (or **osascript**) — if you run it from the shell
- the exported **.app** — if you saved it as an application

You may also get first-run prompts under **Privacy & Security → Automation**
to allow control of **Shortcuts** and **System Events** — click **OK**.

If the script fails immediately with *"not authorized"* or *"assistive access"*,
this permission is the cause 90% of the time.

---

## 2. Run the contact importer first (recommended)

Run `ContactImporter.applescript` first so the group exists and
`~/Desktop/contact_group_name.txt` is written. If you skip this, the builder
will pop a dialog asking you to type the group name (it pre-fills
`Automation_List_<today>` so you can usually just click **Use This**).

---

## 3. Run the builder

### Option A — Script Editor
1. Open `MassMessageSetup.applescript` in **Script Editor**.
2. Press **Run** (▶ / `⌘R`).
3. **Don't touch the keyboard or mouse while it runs** — it's typing into the
   UI and stealing focus will misdirect keystrokes.

### Option B — Terminal
```bash
osascript ~/Downloads/MassMessageSetup.applescript
```

### Option C — Export as an app
Script Editor → **File → Export… → File Format: Application**.

---

## 4. What it does, step by step

1. `Cmd+N` — new blank shortcut.
2. Adds **Find Contacts**, clicks **Add Filter**, types the group name into
   the filter value.
3. Adds **Repeat with Each** (creates the `End Repeat` block).
4. Adds **Text** and types the placeholder
   `Hello from automation – replace me later.`
5. Adds **Send Message**.
6. Adds **Wait** and sets it to `2`.
7. **Best-effort reorder** so the final layout is:
   ```
   Find Contacts
   Repeat with Each
       Text
       Send Message
       Wait
   End Repeat
   ```
8. `Cmd+S`, names it `Mass Message Sender [YYYY-MM-DD]`, confirms.
9. Shows a summary dialog and offers to open Shortcuts so you can verify.

---

## 5. Finishing by hand (the parts automation can't guarantee)

After the script runs, open the shortcut and:

- **Fix the order** if needed: drag `Text`, `Send Message`, `Wait` so they sit
  *inside* the Repeat block, above `End Repeat`.
- **Bind the message body:** in **Send Message → Message**, delete the default
  and insert the **Magic Variable** for the **Text** action's output.
- **Set the recipient:** in **Send Message → Recipients**, insert the
  **Repeat Item** variable.
- **Turn off "Show When Run"** in Send Message's expanded settings if you want
  it to send silently.

These are one-click/drag operations in the UI; the script gets you to the
point where only they remain.

---

## 6. Customising

Edit the **CONFIGURATION** block at the top of the script:

| Setting | Default | Purpose |
|---------|---------|---------|
| `shortcutBaseName` | `"Mass Message Sender"` | Name before the `[date]` |
| `placeholderText` | `"Hello from automation – replace me later."` | Text action body |
| `uiDelay` | `0.5` | Base pause between UI steps — **raise to 0.6–0.9 on a slow Mac** |
| `longDelay` | `1.0` | Pause after new-doc / save |
| `handoffFileName` | `"contact_group_name.txt"` | File written by ContactImporter |

- **Date format:** edit the `formatDate()` handler at the bottom.
- **Action search trigger:** if `Cmd+F` doesn't focus the action search in
  your Shortcuts version, change it in **one place** — the `addAction()`
  handler.
- **Reorder key combo:** change it in **one place** — the `reorderUp()`
  handler.

---

## 7. Troubleshooting

| Symptom | Likely cause / fix |
|---------|--------------------|
| Fails instantly, *"not authorized to send Apple events"* / *"assistive access"* | Grant **Accessibility** (section 1), then re-run |
| Actions added but wrong order | Expected — drag them above `End Repeat` (section 5). Shortcuts ignores keyboard reorder on most builds |
| Group filter not set | Version/layout difference — set the filter manually; the script warns and continues |
| Keystrokes land in the wrong field | You touched the keyboard/mouse mid-run, **or** UI was still rendering → increase `uiDelay` |
| "Add Filter" button not found | Button label changed between versions — add the filter by hand |
| Nothing happens on `Cmd+F` | Your Shortcuts build focuses the search differently — update `addAction()` |
| Magic Variable not bound | Expected limitation — bind it manually (section 5) |

---

## 8. Why keyboard-only (and its honest limit)

Keyboard automation is screen-size independent, which is why it's used here
instead of mouse coordinates. The trade-off is that it depends on Shortcuts
exposing keyboard commands and stable accessibility labels — and Shortcuts
does **not** expose a reorder command. That single gap is why the reorder step
is best-effort rather than guaranteed. No AppleScript approach can fully
automate reordering in the current Shortcuts app; anyone claiming otherwise is
relying on drag coordinates (fragile) or a private API (unavailable).
