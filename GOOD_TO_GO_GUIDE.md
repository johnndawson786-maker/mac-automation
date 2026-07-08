# Good To Go — One-Click Contact Import + Rotating Mass Messaging

## ⭐ The easy way: `MasterAutomation.applescript`

One script does **everything** in order — import contacts, then send —
with **multiple messages that rotate across your contacts**.

| File | What it is |
|------|-----------|
| `MasterAutomation.applescript` | **Run this.** Imports `contacts.csv` → builds the group → reads `messages.txt` → sends, rotating messages across contacts → summary |
| `contacts.csv` | Your numbers, one per line (or `First,Last,Number`) |
| `messages.txt` | Your messages, separated by a line containing only `===` |
| `START_HERE.md` | This guide |
| `ContactImporter.applescript` | *(Optional)* just the import step, standalone |
| `MassMessageSender.applescript` | *(Optional)* just the send step (single message), standalone |
| `MassMessageSetup.applescript` | *(Legacy — ignore)* old Shortcuts-app builder |

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

## ⚠️ Before a real run
- **Test first:** put ONLY your own number in `contacts.csv` and one line in
  `messages.txt`, run it, confirm you receive it.
- **Country codes:** numbers without `+` use your region default. If sends
  fail, use full international format (e.g. `+18585876735`).
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
