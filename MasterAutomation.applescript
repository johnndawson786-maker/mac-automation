-- =====================================================================
--  MasterAutomation.applescript
--
--  ONE script that runs the whole pipeline in order, no manual steps:
--     1. Reads  contacts.csv   → imports numbers into a dated Contacts
--                                 group  Automation_List_<today>
--     2. Reads  messages.txt   → a list of messages (separated by "===")
--     3. Sends  via the Messages app, ROTATING the messages across the
--        contacts:  contact 1 → msg 1, contact 2 → msg 2, … wrapping
--        back to msg 1 after the last message.
--     4. Shows a full summary (imported / sent / failed).
--
--  Put this script in the SAME FOLDER as contacts.csv and messages.txt.
--  (If it can't find them next to itself, it asks you to pick the folder.)
--
--  ------------------------------------------------------------------
--  PERMISSIONS (grant once — see START_HERE.md for the click-by-click)
--    System Settings → Privacy & Security →
--      • Accessibility → the app you run this from (Script Editor/Terminal)
--      • Contacts      → same app
--      • Automation    → allow it to control "Contacts" and "Messages"
--    …and make sure the Messages app is signed in.
--  ------------------------------------------------------------------
--  ⚠️ Sends REAL messages. Test with only your own number first. Only
--     message people expecting to hear from you.
-- =====================================================================


-- =====================================================================
--  CONFIGURATION
-- =====================================================================
set contactsFileName to "contacts.csv"   -- input contact list
set messagesFileName to "messages.txt"   -- input message list (=== separated)
set groupPrefix to "Automation_List_"    -- Contacts group name prefix
set csvDelimiter to ","                   -- field separator in contacts.csv
set defaultFirstName to "Imported"        -- first name for number-only lines
set delayBetween to 2                     -- seconds between each send
set useIMessageOnly to false              -- true = iMessage only (no SMS fallback)
set askBeforeSending to true              -- confirm dialog before blasting


-- =====================================================================
--  STEP 0 — Locate the data folder (next to this script, or ask)
-- =====================================================================
set dataFolder to my findDataFolder(contactsFileName)
set contactsPath to dataFolder & contactsFileName
set messagesPath to dataFolder & messagesFileName


-- =====================================================================
--  STEP 1 — Build today's group name and read the two input files
-- =====================================================================
set todayString to my formatDate(current date)
set groupName to groupPrefix & todayString

-- Read contacts.csv
set contactsRaw to my readFile(contactsPath)
if contactsRaw is "" then
	display dialog "Couldn't read " & contactsFileName & " at:" & return & contactsPath ¬
		buttons {"OK"} default button "OK" with icon stop
	return
end if
set contactLines to my splitLines(contactsRaw)

-- Read messages.txt and split into individual messages on "===" lines
set messagesRaw to my readFile(messagesPath)
set messageList to my parseMessages(messagesRaw)
if (count of messageList) is 0 then
	display dialog "No messages found in " & messagesFileName & "." & return & ¬
		"Put one or more messages there, separated by a line containing only ===" ¬
		buttons {"OK"} default button "OK" with icon stop
	return
end if


-- =====================================================================
--  STEP 2 — Import contacts into a fresh dated group
-- =====================================================================
set importedCount to 0
set importFailedLines to {}
set lineNumber to 0

tell application "Contacts"
	activate
	-- Delete any existing group with our name, then create a fresh one.
	repeat with g in (every group whose name is groupName)
		delete g
	end repeat
	save
	set theGroup to (make new group with properties {name:groupName})
	save

	repeat with rawLine in contactLines
		set lineNumber to lineNumber + 1
		set thisLine to my trimWhitespace(rawLine as string)
		if thisLine is not "" then
			set fields to my splitText(thisLine, csvDelimiter)
			set fieldCount to (count of fields)
			set firstName to ""
			set lastName to ""
			set rawPhone to ""

			if fieldCount is 1 then
				set rawPhone to my trimWhitespace(item 1 of fields)
				set firstName to defaultFirstName
			else if fieldCount is 2 then
				set firstName to my trimWhitespace(item 1 of fields)
				set rawPhone to my trimWhitespace(item 2 of fields)
			else
				set firstName to my trimWhitespace(item 1 of fields)
				set lastName to my trimWhitespace(item 2 of fields)
				set rawPhone to my trimWhitespace(item 3 of fields)
			end if

			set cleanNumber to my cleanPhone(rawPhone)
			if cleanNumber is "" then
				-- No usable digits → record as a failed line.
				set end of importFailedLines to lineNumber
			else
				-- For number-only lines, last name = last 4 digits.
				if fieldCount is 1 then
					if (length of cleanNumber) ≥ 4 then
						set lastName to text -4 thru -1 of cleanNumber
					else
						set lastName to cleanNumber
					end if
				end if
				-- Create the person with the number in the MOBILE phone field.
				set newPerson to (make new person with properties {first name:firstName, last name:lastName})
				make new phone at end of phones of newPerson with properties {label:"mobile", value:cleanNumber}
				add newPerson to theGroup
				set importedCount to importedCount + 1
			end if
		end if
	end repeat
	save
end tell

-- Hand-off file (kept for compatibility with the standalone sender).
try
	do shell script "printf '%s' " & quoted form of groupName & " > " & ¬
		quoted form of ((POSIX path of (path to desktop)) & "contact_group_name.txt")
end try

if importedCount is 0 then
	display dialog "No contacts were imported (check " & contactsFileName & ")." ¬
		buttons {"OK"} default button "OK" with icon stop
	return
end if


-- =====================================================================
--  STEP 3 — Gather the group members' phone numbers (in order)
-- =====================================================================
set recipientList to {} -- {personName, phoneNumber}
tell application "Contacts"
	set theGroup to item 1 of (every group whose name is groupName)
	repeat with p in (people of theGroup)
		set phoneList to (value of phones of p)
		if (count of phoneList) > 0 then
			set cleanNumber to my cleanPhone((item 1 of phoneList) as string)
			if cleanNumber is not "" then
				set end of recipientList to {(name of p), cleanNumber}
			end if
		end if
	end repeat
end tell

set totalRecipients to (count of recipientList)
set totalMessages to (count of messageList)


-- =====================================================================
--  STEP 4 — Confirm
-- =====================================================================
if askBeforeSending then
	set previewMsg to item 1 of messageList
	set confirm to button returned of (display dialog ¬
		"Ready to send." & return & return & ¬
		"Group:        " & groupName & return & ¬
		"Recipients:   " & totalRecipients & return & ¬
		"Messages:     " & totalMessages & " (rotating across recipients)" & return & return & ¬
		"First message preview:" & return & "\"" & previewMsg & "\"" & return & return & ¬
		"Proceed?" buttons {"Cancel", "Send Now"} default button "Cancel" with icon caution)
	if confirm is not "Send Now" then return
end if


-- =====================================================================
--  STEP 5 — Send, rotating messages across recipients
-- =====================================================================
set sentCount to 0
set failCount to 0
set failLog to ""

tell application "Messages"
	set iMessageService to missing value
	try
		set iMessageService to (1st account whose service type is iMessage)
	end try
end tell

set idx to 0
repeat with r in recipientList
	set idx to idx + 1
	set personName to item 1 of r
	set phoneNumber to item 2 of r

	-- Rotate: pick message ((idx-1) mod totalMessages) + 1
	set msgIndex to ((idx - 1) mod totalMessages) + 1
	set thisMessage to item msgIndex of messageList

	set didSend to false
	if iMessageService is not missing value then
		try
			tell application "Messages"
				send thisMessage to participant phoneNumber of iMessageService
			end tell
			set didSend to true
		end try
	end if
	if (not didSend) and (not useIMessageOnly) then
		try
			tell application "Messages"
				set smsService to (1st account whose service type is SMS)
				send thisMessage to participant phoneNumber of smsService
			end tell
			set didSend to true
		end try
	end if

	if didSend then
		set sentCount to sentCount + 1
	else
		set failCount to failCount + 1
		set failLog to failLog & "   • " & personName & " (" & phoneNumber & ")" & return
	end if

	delay delayBetween
end repeat


-- =====================================================================
--  STEP 6 — Summary
-- =====================================================================
set summary to "All done." & return & return & ¬
	"Group:            " & groupName & return & ¬
	"Imported:         " & importedCount & return & ¬
	"Import failures:  " & (count of importFailedLines)
if (count of importFailedLines) > 0 then
	set summary to summary & " (lines " & my joinList(importFailedLines, ", ") & ")"
end if
set summary to summary & return & ¬
	"Messages used:    " & totalMessages & " (rotated)" & return & ¬
	"Sent OK:          " & sentCount & " of " & totalRecipients & return & ¬
	"Send failures:    " & failCount
if failCount > 0 then
	set summary to summary & return & return & "Failed to send to:" & return & failLog & ¬
		return & "(Not reachable via iMessage/SMS, Messages not signed in, or no country code — try +… format.)"
end if
display dialog summary buttons {"OK"} default button "OK" with icon note


-- =====================================================================
--  =========================  HANDLERS  ==============================
-- =====================================================================

-- Locate the folder holding the input files: prefer the folder this
-- script lives in; if the data file isn't there, ask the user.
on findDataFolder(probeFileName)
	set candidate to ""
	try
		set myPosix to POSIX path of (path to me)
		if myPosix ends with "/" then set myPosix to text 1 thru -2 of myPosix -- strip trailing / on .app
		set AppleScript's text item delimiters to "/"
		set parts to text items of myPosix
		set parts to items 1 thru -2 of parts
		set candidate to (parts as text) & "/"
		set AppleScript's text item delimiters to ""
	end try
	-- Does the probe file exist in that folder?
	if candidate is not "" then
		try
			do shell script "test -f " & quoted form of (candidate & probeFileName)
			return candidate
		end try
	end if
	-- Fall back to asking.
	set chosen to (choose folder with prompt "Select the folder containing " & probeFileName & " and messages.txt:")
	return POSIX path of chosen
end findDataFolder

-- Read a UTF-8 text file at a POSIX path; "" if it can't be read.
on readFile(posixPath)
	set txt to ""
	try
		set txt to (do shell script "cat " & quoted form of posixPath)
	end try
	return txt
end readFile

-- Split messagesRaw into a list, breaking on lines that are exactly "==="
-- (allowing surrounding whitespace). Trims each message; drops empties.
on parseMessages(rawText)
	set outList to {}
	if rawText is "" then return outList
	set allLines to my splitLines(rawText)
	set current to ""
	repeat with ln in allLines
		set lineStr to (ln as string)
		if my trimWhitespace(lineStr) is "===" then
			set trimmed to my trimWhitespace(current)
			if trimmed is not "" then set end of outList to trimmed
			set current to ""
		else
			if current is "" then
				set current to lineStr
			else
				set current to current & linefeed & lineStr
			end if
		end if
	end repeat
	set trimmed to my trimWhitespace(current)
	if trimmed is not "" then set end of outList to trimmed
	return outList
end parseMessages

-- cleanPhone: keep a leading "+" and all digits, drop everything else.
on cleanPhone(raw)
	set raw to raw as string
	set outStr to ""
	set isFirst to true
	repeat with i from 1 to (length of raw)
		set c to character i of raw
		if c is in "0123456789" then
			set outStr to outStr & c
		else if c is "+" and isFirst then
			set outStr to outStr & c
		end if
		set isFirst to false
	end repeat
	return outStr
end cleanPhone

-- splitLines(t): split into lines, tolerating CRLF, CR, or LF endings.
on splitLines(t)
	set t to t as string
	set t to my replaceText(t, (return & linefeed), linefeed) -- CRLF -> LF
	set t to my replaceText(t, return, linefeed) -- lone CR -> LF
	return my splitText(t, linefeed)
end splitLines

-- replaceText(t, find, repl): replace all occurrences.
on replaceText(t, findStr, replStr)
	set AppleScript's text item delimiters to findStr
	set parts to text items of (t as string)
	set AppleScript's text item delimiters to replStr
	set outStr to parts as string
	set AppleScript's text item delimiters to ""
	return outStr
end replaceText

-- splitText(theText, theDelim): standard AppleScript split.
on splitText(theText, theDelim)
	set AppleScript's text item delimiters to theDelim
	set theItems to text items of theText
	set AppleScript's text item delimiters to ""
	return theItems
end splitText

-- joinList(theList, sep): join a list into a string.
on joinList(theList, sep)
	set AppleScript's text item delimiters to sep
	set s to theList as string
	set AppleScript's text item delimiters to ""
	return s
end joinList

-- formatDate(theDate) -> "YYYY-MM-DD".  EDIT HERE to change the format.
on formatDate(theDate)
	set y to year of theDate as integer
	set m to (month of theDate as integer)
	set d to day of theDate as integer
	set mm to text -2 thru -1 of ("0" & m)
	set dd to text -2 thru -1 of ("0" & d)
	return (y as string) & "-" & mm & "-" & dd
end formatDate

-- trimWhitespace(t): strip leading/trailing spaces, tabs, returns, newlines.
on trimWhitespace(t)
	set t to t as string
	set wsChars to {" ", tab, return, linefeed}
	repeat while (length of t) > 0 and (character 1 of t) is in wsChars
		if (length of t) is 1 then
			set t to ""
		else
			set t to text 2 thru -1 of t
		end if
	end repeat
	repeat while (length of t) > 0 and (character -1 of t) is in wsChars
		if (length of t) is 1 then
			set t to ""
		else
			set t to text 1 thru -2 of t
		end if
	end repeat
	return t
end trimWhitespace
