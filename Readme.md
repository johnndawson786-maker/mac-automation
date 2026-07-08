# Mac Automation — Folder-Based Contact Import + Mass Messaging

Pure AppleScript. Drop recipient files into a folder, run one script, and it
imports everyone into a dated Contacts group and messages them via the Messages
app. **No manual file picking, no Shortcuts app.**

## The `recipients/` folder is your inbox

Instead of choosing a single `contacts.csv` by hand, the automation reads
**every `.csv` / `.txt` file** inside the `recipients/` folder (which sits next
to the scripts). Put as many files in there as you like:

```
recipients/
  batch-example.csv      ← one phone number per line
  named-example.csv      ← First,Last,+Number per line
  processed/             ← files land here automatically after each run
```

Each line in a file can be:

| Line format                | Becomes                                   |
|----------------------------|-------------------------------------------|
| `8585876735`               | Contact `Imported 6735`, mobile = number  |
| `Jane,+18585876735`        | Contact `Jane`, mobile = number           |
| `Jane,Doe,+18585876735`    | Contact `Jane Doe`, mobile = number       |

## Files

| File | What it does |
|------|--------------|
| `ContactImporter.applescript` | Auto-reads **every file** in `recipients/`, builds the Contacts group `Automation_List_<today>`, writes the group name to `~/Desktop/contact_group_name.txt`, then archives the files it read into `recipients/processed/` with a fresh run-log. |
| `MassMessageSender.applescript` | Reads that group (via the handoff file — no guessing) and sends your message to every member, one at a time, through Messages. |
| `MasterPipeline.applescript` | One click: runs the importer, then the sender. |

## How each run works

1. **Import** — `ContactImporter.applescript` scans `recipients/`, imports every
   file into `Automation_List_<today>`, and writes the group name to the Desktop
   handoff file so the sender knows exactly which group to use.
2. **Archive** — the imported files are moved into `recipients/processed/`,
   timestamp-prefixed, and a new `run_<timestamp>.log` is written there. The
   inbox is left empty, ready for the next batch — so **every run leaves a fresh
   file behind and only picks up files you've newly added.**
3. **Send** — `MassMessageSender.applescript` reads the group and messages
   everyone (iMessage first, SMS fallback), with a confirm dialog and a
   success/failure summary.

Run the two steps yourself, or run `MasterPipeline.applescript` to do both.

## One-time permissions

System Settings → Privacy & Security:

- **Contacts** → enable the app you run from (Script Editor / Terminal)
- **Automation** → allow that app to control **Contacts** and **Messages**

Open **Messages** and make sure it's signed in. For SMS to non-iMessage numbers,
your iPhone must be paired with **Text Message Forwarding** on.

## Configuration

Edit the `CONFIGURATION` block at the top of each script:

- `ContactImporter` — `recipientsFolderName`, `archiveProcessed` (set `false` to
  leave files in place), `groupPrefix`, `csvDelimiter`.
- `MassMessageSender` — `defaultMessage`, `delayBetween`, `useIMessageOnly`,
  `askBeforeSending`.

## ⚠️ Before you send to a real list

- **Test first:** put only your own number in one file, run both scripts, and
  confirm you receive the message.
- **Country codes:** if a send fails, use full international format (e.g.
  `+18585876735`) and re-import.
- **Don't spam:** only message people expecting to hear from you. Apple and
  carriers rate-limit or block accounts that send unsolicited bulk messages.
