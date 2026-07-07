# Contact Importer — How to Use

A pure AppleScript that imports phone numbers from a `.csv` or `.txt` file into
the macOS **Contacts** app, placing them in a dated group like
`Automation_List_2026-07-08`.

Compatible with **macOS Ventura (13)** and **Sonoma (14)**.

---

## 1. What's in the package

| File | Purpose |
|------|---------|
| `ContactImporter.applescript` | The automation script itself |
| `HOW_TO_USE.md` | This guide |
| `sample_contacts.csv` | An example input file you can test with |

---

## 2. Prepare your input file

Plain text, one contact per line, comma-separated:

```
John,Smith,+14155551234
Maria,Garcia,+34 600 111 222
+447700900123
Ahmed,Khan,03001234567
```

**Rules:**

- `FirstName,LastName,PhoneNumber` — the normal case.
- A line with **only a phone number** (e.g. `+447700900123`) is imported as
  First Name = `Imported`, Last Name = last 4 digits (e.g. `0123`).
- A line with **two values** is treated as `FirstName,PhoneNumber`.
- Spaces inside numbers are stripped automatically (`+34 600 111 222` → `+34600111222`).
- Lines without any digits are **skipped** and reported at the end with their
  line numbers.
- Blank lines are ignored.
- Save the file as plain text (`.csv` or `.txt`), UTF-8 preferred.
  If exporting from Excel/Numbers, use **File → Export → CSV**.

---

## 3. Run the script

### Option A — Script Editor (easiest)

1. Double-click `ContactImporter.applescript` — it opens in **Script Editor**.
2. Press the **Run** button (▶) or `⌘R`.
3. A file chooser appears — select your `.csv` / `.txt` file.
4. Approve the permission prompts (see section 4).
5. When finished, a dialog shows how many contacts imported and which line
   numbers failed.

### Option B — Terminal / osascript

```bash
osascript ~/Downloads/ContactImporter.applescript
```

(Adjust the path to wherever you saved the file.)

### Option C — Turn it into a double-clickable app

1. Open the script in Script Editor.
2. **File → Export…** → File Format: **Application**.
3. Save it (e.g. to Applications or Desktop). Now you can double-click it
   like any app. macOS will ask for permissions the first time.

---

## 4. Permissions (important — first run only)

macOS will show pop-ups asking for access. Click **OK / Allow** for:

- **Contacts** — required to create people and groups.
- **Automation / Accessibility** — required to control the Contacts app.

If you accidentally denied a prompt, or the script errors with
*"Not authorized to send Apple events"*:

1. Open **System Settings → Privacy & Security → Contacts**
   → enable **Script Editor** (or **Terminal**/**osascript** if you run it from the shell).
2. Open **System Settings → Privacy & Security → Automation**
   → under Script Editor (or Terminal), enable **Contacts**.
3. If needed: **System Settings → Privacy & Security → Accessibility**
   → enable the app you launch the script from.
4. Quit and re-run the script.

---

## 5. What the script does, step by step

1. Opens a native **Choose File** dialog.
2. Reads the file and parses it line by line.
3. In Contacts, **deletes** any existing group named
   `Automation_List_<today's date>` (so re-runs never create duplicates),
   then creates a fresh one.
4. Creates a person per valid line and saves the number in the
   **mobile Phone field** (never Email/Address).
5. Adds each person to the group and saves.
6. Shows a summary dialog: imported count, failed count, and failed line numbers.

> ⚠️ Note: deleting the group removes the group itself; re-running the script
> the same day creates fresh person entries, so the group is always clean, but
> person cards created by *earlier* runs remain in All Contacts. Delete them
> from Contacts manually if you re-import the same file.

---

## 6. Customising

Open the script in Script Editor and edit the **CONFIGURATION** block at the top:

| Setting | Default | What it does |
|---------|---------|--------------|
| `groupPrefix` | `"Automation_List_"` | Text before the date in the group name |
| `csvDelimiter` | `","` | Change to `";"` or `tab` for other file formats |
| `defaultFirstName` | `"Imported"` | First name for phone-only lines |

To change the **date format** (default `YYYY-MM-DD`), edit the `formatDate()`
handler near the bottom of the script — the comment there shows where.

---

## 7. Troubleshooting

| Symptom | Fix |
|---------|-----|
| "Not authorized to send Apple events to Contacts" | Grant permissions — see section 4 |
| File dialog never appears | Make sure Script Editor is the frontmost app; check Accessibility permission |
| Weird characters in names | Save your CSV as **UTF-8** plain text |
| Everything fails with "no valid digits" | Your file probably uses a different delimiter — change `csvDelimiter` |
| Group not visible in Contacts | Groups only show in the sidebar (**View → Show Groups** or `⌘1` in Contacts); iCloud may take a moment to sync |
| Script does nothing after Cancel | That's by design — Cancel in the file dialog exits quietly |

---

## 8. Testing safely

Before running on your real list, test with the included
`sample_contacts.csv` (4 rows incl. one phone-only line and one invalid line)
and verify the group and contacts appear as expected in Contacts.
