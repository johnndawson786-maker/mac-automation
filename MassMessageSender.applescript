-- =====================================================================
--  MassMessageSender.applescript
--
--  FULLY AUTOMATED mass messenger. No Shortcuts app, no UI scripting,
--  no manual steps. It reads the Contacts group created by
--  ContactImporter.applescript and sends your message to every member,
--  one at a time, through the Messages app.
--
--  WHY THIS REPLACES THE SHORTCUTS APPROACH
--  ----------------------------------------
--  The macOS Shortcuts app does NOT expose its action editor to
--  AppleScript/accessibility, so steps like "set the group filter",
--  "bind Recipients to Repeat Item", and "rename the shortcut" can
--  never be automated reliably — they fail with "Invalid index".
--  Talking to Messages directly avoids all of that and needs ZERO
--  manual finishing.
--
--  ------------------------------------------------------------------
--  PERMISSIONS (grant once, or the script fails immediately)
--  ------------------------------------------------------------------
--  System Settings → Privacy & Security →
--     • Contacts   → enable the app you run this from (Script Editor /
--                    Terminal / the exported .app)
--     • Automation → allow that app to control "Contacts" and "Messages"
--  Also make sure the Messages app is signed in (Messages → Settings →
--  iMessage). SMS to non-iMessage numbers only works if your iPhone is
--  paired with Text Message Forwarding enabled.
--
--  ------------------------------------------------------------------
--  ⚠️  PLEASE READ — this sends REAL messages
--  ------------------------------------------------------------------
--  • TEST with a group containing only your own number first.
--  • Only message people who expect to hear from you. Sending
--    unsolicited bulk messages can get your Apple ID / phone number
--    rate-limited or blocked by Apple and carriers.
-- =====================================================================


-- =====================================================================
--  CONFIGURATION — edit these, then run
-- =====================================================================
set defaultMessage to "Hello from automation – replace me later." -- pre-filled in the prompt
set delayBetween to 2          -- seconds to wait between each send
set useIMessageOnly to false   -- true = only send via iMessage; false = allow SMS fallback
set handoffFileName to "contact_group_name.txt" -- written by ContactImporter
set askBeforeSending to true   -- true = show a confirm dialog with the recipient count first


-- =====================================================================
--  STEP 1 — Work out which Contacts group to message
-- =====================================================================
set todayString to my formatDate(current date)
set groupName to my resolveGroupName(handoffFileName, todayString)


-- =====================================================================
--  STEP 2 — Pull every member (name + mobile number) out of that group
-- =====================================================================
set recipientList to {} -- list of {personName, phoneNumber} pairs
tell application "Contacts"
	-- Find the group by name.
	set matchingGroups to (every group whose name is groupName)
	if (count of matchingGroups) is 0 then
		display dialog "No Contacts group named \"" & groupName & "\" was found." & return & ¬
			"Run ContactImporter.applescript first." buttons {"OK"} default button "OK" with icon stop
		return
	end if
	set theGroup to item 1 of matchingGroups

	-- Walk each person in the group and grab their first phone number.
	repeat with p in (people of theGroup)
		set personName to (name of p)
		set phoneList to (value of phones of p)
		if (count of phoneList) > 0 then
			set rawNumber to (item 1 of phoneList) as string
			-- Strip spaces, parentheses, and dashes; keep digits and a leading +.
			set cleanNumber to my cleanPhone(rawNumber)
			if cleanNumber is not "" then
				set end of recipientList to {personName, cleanNumber}
			end if
		end if
	end repeat
end tell

set totalRecipients to (count of recipientList)
if totalRecipients is 0 then
	display dialog "The group \"" & groupName & "\" has no contacts with usable phone numbers." ¬
		buttons {"OK"} default button "OK" with icon stop
	return
end if


-- =====================================================================
--  STEP 3 — Ask for the message text (pre-filled with the default)
-- =====================================================================
set theMessage to text returned of (display dialog ¬
	"Message to send to all " & totalRecipients & " contact(s) in \"" & groupName & "\":" ¬
	default answer defaultMessage buttons {"Cancel", "Continue"} default button "Continue")
if theMessage is "" then
	display dialog "Empty message — nothing sent." buttons {"OK"} default button "OK" with icon caution
	return
end if


-- =====================================================================
--  STEP 4 — Final confirmation (optional but recommended)
-- =====================================================================
if askBeforeSending then
	set confirm to button returned of (display dialog ¬
		"About to send this message to " & totalRecipients & " contact(s):" & return & return & ¬
		"\"" & theMessage & "\"" & return & return & ¬
		"Proceed?" buttons {"Cancel", "Send Now"} default button "Cancel" with icon caution)
	if confirm is not "Send Now" then return
end if


-- =====================================================================
--  STEP 5 — Send to each recipient, one at a time, with a delay
-- =====================================================================
set sentCount to 0
set failCount to 0
set failLog to ""

tell application "Messages"
	-- Grab the iMessage service once, up front.
	set iMessageService to missing value
	try
		set iMessageService to (1st account whose service type is iMessage)
	end try
end tell

repeat with r in recipientList
	set personName to item 1 of r
	set phoneNumber to item 2 of r
	set didSend to false

	-- Attempt 1: iMessage.
	if iMessageService is not missing value then
		try
			tell application "Messages"
				set theBuddy to participant phoneNumber of iMessageService
				send theMessage to theBuddy
			end tell
			set didSend to true
		end try
	end if

	-- Attempt 2: SMS fallback (only if allowed and iMessage didn't work).
	if (not didSend) and (not useIMessageOnly) then
		try
			tell application "Messages"
				set smsService to (1st account whose service type is SMS)
				set theBuddy to participant phoneNumber of smsService
				send theMessage to theBuddy
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

	-- Pause between sends so we don't hammer Messages / trip rate limits.
	delay delayBetween
end repeat


-- =====================================================================
--  STEP 6 — Summary
-- =====================================================================
set summary to "Done." & return & return & ¬
	"Group:       " & groupName & return & ¬
	"Sent OK:     " & sentCount & " of " & totalRecipients & return & ¬
	"Failed:      " & failCount
if failCount > 0 then
	set summary to summary & return & return & "Failed recipients:" & return & failLog & ¬
		return & "(Common causes: number not reachable via iMessage/SMS, " & ¬
		"Messages not signed in, or no country code — try +1… format.)"
end if
display dialog summary buttons {"OK"} default button "OK" with icon note


-- =====================================================================
--  ========================  HANDLERS  ===============================
-- =====================================================================

-- cleanPhone(raw) -> keeps a leading "+" and all digits, drops the rest.
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

-- resolveGroupName(fileName, dateStr): read ~/Desktop/<fileName>, else ask.
on resolveGroupName(fileName, dateStr)
	set deskPath to (POSIX path of (path to desktop)) & fileName
	set foundName to ""
	try
		set foundName to (do shell script "cat " & quoted form of deskPath)
	end try
	set foundName to my trimWhitespace(foundName)
	if foundName is not "" then return foundName

	set defaultGuess to "Automation_List_" & dateStr
	try
		set answer to text returned of (display dialog ¬
			"Couldn't find ~/Desktop/" & fileName & "." & return & return & ¬
			"Enter the Contacts group name to message:" ¬
			default answer defaultGuess buttons {"Cancel", "Use This"} default button "Use This" with icon caution)
		set answer to my trimWhitespace(answer)
		if answer is "" then error "No group name provided."
		return answer
	on error
		display dialog "No group name available. Aborting." buttons {"OK"} default button "OK" with icon stop
		error number -128
	end try
end resolveGroupName

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
