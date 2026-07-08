# Good To Go — One-Click Contact Import + Rotating Mass Messaging

## Two master scripts — pick one

| Master script | What it runs | When to use |
|---------------|--------------|-------------|
| `MasterPipeline.applescript` | The full 3-stage chain: **ContactImporter → MassMessageSetup (builds the Shortcut, auto-clicks filter + recipient) → MassMessageSender** | You want the Shortcut built in the Shortcuts app too |
| `MasterAutomation.applescript` | Import + send directly (no Shortcuts app), with **multiple messages rotating across contacts** from `messages.txt` | You just want messages sent, incl. 10-messages-to-100-contacts rotation |

Both need the data files next to them in the same folder.

| File | What it is |
|------|-----------|
| `MasterPipeline.applescript` | Runs all three scripts in order (see above) |
| `MasterAutomation.applescript` | Import + rotating multi-message send, self-contained |
| `contacts.csv` | Your numbers, one per line (or `First,Last,Number`) |
| `messages.txt` | Your messages, separated by a line containing only `===` (used by MasterAutomation) |
| `START_HERE.md` | This guide |
| `ContactImporter.applescript` | Stage 1 — import contacts |
| `MassMessageSetup.applescript` | Stage 2 — build the Shortcut; deep-searches the UI to click Add Filter → Group → your list, and Recipients → your list → first contact → mobile number |
| `MassMessageSender.applescript` | Stage 3 — the actual looped sending via Messages |

### Notes on Stage 2 (Shortcut building)
- **Don't touch the keyboard/mouse while it runs.** It's driving the UI.
- The deep accessibility search takes a few seconds per click — be patient.
- If Shortcuts still hides a control from automation, you get a dialog telling
  you the exact manual click to finish; the pipeline continues either way, and
  Stage 3 does the real sending regardless.
- The Recipient it pins is the **first contact** of your group (fixed). For
  in-Shortcut looping, rewire Recipients to the **Repeat Item** variable by hand.

---

## How the message rotation works

Messages in `messages.txt` are assigned to contacts **in order, cycling**:

```
contact 1  → message 1
contact 2  → message 2
contact 3  → message 3
…
contact N  → message N
contact N+1 → message 1   (wraps around)
```

So with **10 messages and 100 contacts**, each message goes to 10 people
(every 10th contact). Add or remove messages freely — the rotation adjusts.

### `messages.txt` format
Separate each message with a line that is **just** `===`. Messages may span
multiple lines. Example:

```
Hi! First message here.
Can be multiple lines.
===
Second message.
===
Third message.
```

---

## One-time permissions

**System Settings → Privacy & Security:**
- **Accessibility** → enable **Script Editor** (+ button → add
  `/System/Applications/Utilities/Script Editor.app` if missing)
- **Contacts** → enable **Script Editor**
- **Automation** → allow Script Editor to control **Contacts** and **Messages**

Open **Messages** and make sure it's signed in (Messages → Settings → iMessage).
For SMS to non-iMessage numbers, pair your iPhone with **Text Message
Forwarding** on.

---

## Run it

1. Keep `MasterAutomation.applescript`, `contacts.csv`, and `messages.txt`
   **in the same folder**.
2. Open `MasterAutomation.applescript` in Script Editor → **Run** (▶).
   (It finds the two files next to itself; if it can't, it asks you to pick
   the folder.)
3. It imports the contacts, then shows a confirmation with the recipient count,
   how many messages will rotate, and a preview of message 1.
4. Click **Send Now**. It sends to everyone automatically, one at a time, with
   a 2-second gap, then shows a full summary.

That's the whole thing — one run, no manual steps, no Shortcuts app.

---

## ☎️ Phone number format (READ — this is what caused "Not Delivered")

macOS guesses a country code for any number saved **without** one, and it
guessed wrong before (Indian numbers became unreachable `+44` UK numbers). The
scripts now protect you:

- A number that **already starts with `+`** is saved **exactly as written**.
  → Mix countries freely: `+9185…` (India), `+1415…` (US), etc.
- A **bare** number (no `+`) gets the **`defaultCountryCode`** prepended
  automatically (set to `+91` at the top of `ContactImporter.applescript` and
  `MasterAutomation.applescript`).

**So for a mixed India + US list, write US numbers with their `+1` prefix:**

```
8585876735            ← bare → becomes +918585876735 (default +91)
+918219522292         ← explicit India
+14155551234          ← explicit US
```

If most of your list is US, change `defaultCountryCode` to `+1` and let the US
numbers be bare instead. Either way, **anything with a `+` is never touched.**

Re-importing also now **deletes the old group's contact cards**, so stale
wrongly-formatted numbers from earlier runs don't linger in All Contacts.

## ⚠️ Also before a real run
- **Test first:** put ONLY your own number in `contacts.csv` and one line in
  `messages.txt`, run it, confirm you receive it.
- **Non-iMessage (Android/SMS) numbers** can only be sent from a Mac if your
  **iPhone is paired with Text Message Forwarding ON** (iPhone → Settings →
  Messages → Text Message Forwarding). A Mac alone cannot send plain SMS.
- **Don't spam:** only message people expecting to hear from you — Apple and
  carriers block accounts that send unsolicited bulk messages.

---

## Customising `MasterAutomation.applescript`
Edit the CONFIGURATION block at the top:

| Setting | Default | Purpose |
|---------|---------|---------|
| `contactsFileName` | `"contacts.csv"` | Input contact file name |
| `messagesFileName` | `"messages.txt"` | Input message file name |
| `csvDelimiter` | `","` | Field separator in contacts.csv |
| `delayBetween` | `2` | Seconds between sends |
| `useIMessageOnly` | `false` | `true` = iMessage only, no SMS fallback |
| `askBeforeSending` | `true` | `false` = skip the confirm dialog |
| `groupPrefix` | `"Automation_List_"` | Group name prefix (date appended) |

Change the date format in the `formatDate()` handler at the bottom.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "not authorized" / won't run | Grant Accessibility + Contacts + Automation (above) |
| "Couldn't read contacts.csv" | Keep it in the same folder as the script, or pick the folder when asked |
| "No messages found" | `messages.txt` empty or missing `===` separators |
| All sends fail | Messages not signed in, or numbers unreachable — try `+…` format |
| Some fail | Those numbers aren't iMessage and SMS forwarding isn't set up — see the failed list |
| Wrong message to wrong person | Remember it's rotation by order — reorder `contacts.csv`/`messages.txt` to change assignment |
