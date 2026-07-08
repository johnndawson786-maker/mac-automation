# Good To Go — Fully Automated Contact Import + Mass Messaging

Two scripts. Run each once. **No manual steps inside any app, no Shortcuts
fiddling.**

| File | What it does |
|------|--------------|
| `ContactImporter.applescript` | Imports numbers from `contacts.csv` into a Contacts group `Automation_List_<today>` and records the group name |
| `MassMessageSender.applescript` | **⭐ The one you want.** Reads that group and sends your message to every member automatically, one at a time, via the Messages app |
| `contacts.csv` | Your numbers — currently `8585876735` and `7876730373`, one per line |
| `message_content.txt` | A place to draft your message |
| `MassMessageSetup.applescript` | *(Legacy — ignore.)* The old Shortcuts-builder. See "Why not Shortcuts" below |
| `START_HERE.md` | This guide |

---

## Why this is different (please read once)

Earlier versions tried to build a **Shortcut** in the Shortcuts app by
automating its UI. That path **cannot be fully automated** — the Shortcuts app
doesn't expose its action editor to macOS automation, so setting the group
filter, binding the recipient, and renaming always fail ("Invalid index").
That's a limitation of Apple's app, not something any script can fix.

`MassMessageSender.applescript` skips Shortcuts entirely and talks to the
**Messages** app directly. That IS fully scriptable — so it needs **zero manual
finishing**. Import, then send. Done.

---

## One-time permissions

**System Settings → Privacy & Security:**
- **Accessibility** → enable **Script Editor** (use **+** and add
  `/System/Applications/Utilities/Script Editor.app` if it's missing)
- **Contacts** → enable **Script Editor**
- **Automation** → allow Script Editor to control **Contacts** and **Messages**

Also: open **Messages**, make sure it's signed in (Messages → Settings →
iMessage). For SMS to non-iMessage numbers, your iPhone must be paired with
**Text Message Forwarding** on.

Click **OK** on any permission pop-ups the first time you run.

---

## Step 1 — Import the contacts (run once)

1. Open `ContactImporter.applescript` in Script Editor → **Run** (▶).
2. Choose `contacts.csv` from this folder.
3. Your two numbers become contacts `Imported 6735` and `Imported 0373` in the
   group `Automation_List_<today>`. (Want real names? Edit `contacts.csv` lines
   to `FirstName,LastName,Number` first.)

## Step 2 — Send the messages (run once — this is the whole thing)

1. Open `MassMessageSender.applescript` in Script Editor → **Run** (▶).
2. It shows how many recipients it found and asks for your message
   (pre-filled — edit it right there in the dialog).
3. It asks you to confirm, then sends to **every contact automatically**, one
   at a time, with a 2-second gap.
4. A summary tells you how many sent and which (if any) failed.

That's it. You do **not** run it once per person and you do **not** touch
Messages — the script loops through the whole group by itself.

---

## ⚠️ Before you send to a real list

- **Test first:** put ONLY your own number in `contacts.csv`, run both scripts,
  and confirm you receive the message.
- **Country codes:** the two included numbers have no `+` prefix. If a send
  fails, edit `contacts.csv` to full international format (e.g. `+18585876735`)
  and re-run Step 1.
- **Don't spam:** only message people expecting to hear from you. Apple and
  carriers rate-limit or block accounts that send unsolicited bulk messages.

---

## Customising `MassMessageSender.applescript`

Edit the CONFIGURATION block at the top:

| Setting | Default | Purpose |
|---------|---------|---------|
| `defaultMessage` | `"Hello from automation …"` | Text pre-filled in the prompt |
| `delayBetween` | `2` | Seconds between each send |
| `useIMessageOnly` | `false` | `true` = iMessage only, no SMS fallback |
| `askBeforeSending` | `true` | `false` = skip the confirm dialog |

Change the date format in the `formatDate()` handler at the bottom.

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| "not authorized" / script won't run | Grant Accessibility + Automation + Contacts (permissions above) |
| "No Contacts group named…" | Run `ContactImporter.applescript` first |
| All sends fail | Messages not signed in, or numbers unreachable — check Messages, try `+1…` format |
| Some fail | Those numbers aren't on iMessage and SMS forwarding isn't set up — see the failed list in the summary |
| Nothing happens in Messages | Automation permission for Messages not granted |

---

## Why not the Shortcuts version?

`MassMessageSetup.applescript` is kept only for reference. It builds the
Shortcut's actions fine but **cannot** auto-configure the group filter,
recipient binding, or name, because Shortcuts blocks automation of those
controls. If you specifically want a reusable Shortcut, run it, then finish
those three fields by hand (filter, Recipients = Repeat Item, name). For actual
hands-free sending, use `MassMessageSender.applescript` instead.
