(*
=====================================================================
  MassMessageSetup.applescript
  Creates a REAL "Mass Message Sender" shortcut in the Shortcuts app.

  WHY THIS VERSION IS DIFFERENT (please read once)
  ------------------------------------------------
  The previous version tried to BUILD the shortcut by driving the
  Shortcuts app's UI with System Events — typing action names, clicking
  "Add Filter", pressing keyboard combos to reorder rows, etc. That is
  the reason "the shortcut is not getting created": the Shortcuts editor
  exposes almost nothing to accessibility, so a single mistargeted
  keystroke, a missing Accessibility grant, or any Shortcuts UI change
  breaks the chain and you end up with a half-built (or no) shortcut.

  This version never touches the Shortcuts UI. Instead it:
    1. Reads the Contacts group ContactImporter created (via the handoff
       file ~/Desktop/contact_group_name.txt) and collects the members'
       mobile numbers.
    2. Writes a proper shortcut definition (a .plist) with those numbers
       baked into a List, a Repeat that walks the List, and a Send
       Message inside the loop.
    3. Signs it with Apple's own `shortcuts` command-line tool and opens
       the signed .shortcut so Shortcuts imports it in one click.

  Because the file is a valid, signed shortcut, creation is reliable —
  there is no UI puppetry to go wrong.

  ------------------------------------------------------------------
  PERMISSIONS (grant once)
  ------------------------------------------------------------------
  System Settings -> Privacy & Security ->
    - Contacts   -> enable the app you run this from (Script Editor /
                    Terminal / the exported .app)
    - Automation -> allow that app to control "Contacts"
  Signing contacts Apple's servers, so you must be ONLINE the first time.

  ------------------------------------------------------------------
  NOTE ON HOW THE SHORTCUT TARGETS PEOPLE
  ------------------------------------------------------------------
  The recipient numbers are embedded in the shortcut when it is built.
  If you import new contacts later, just run this script again to refresh
  the shortcut with the new list.
=====================================================================
*)


-- =====================================================================
--  CONFIGURATION — tweak these, then run
-- =====================================================================
set shortcutBaseName to "Mass Message Sender" -- name prefix; date is appended
set placeholderText to "Hello from automation – replace me later." -- message body
set delayBetween to 2 -- seconds to wait between each send (0 = no wait)
set handoffFileName to "contact_group_name.txt" -- file written by ContactImporter
set signMode to "anyone" -- shortcuts signing mode: "anyone" or "people-who-know-me"
-- =====================================================================


-- =====================================================================
--  STEP 0 — Work out today's date and the final shortcut name
-- =====================================================================
set todayString to my formatDate(current date)
set shortcutName to shortcutBaseName & " [" & todayString & "]"


-- =====================================================================
--  STEP 1 — Resolve the Contacts group and collect its phone numbers
-- =====================================================================
set groupName to my resolveGroupName(handoffFileName, todayString)

set recipientNumbers to {}
tell application "Contacts"
	set matchingGroups to (every group whose name is groupName)
	if (count of matchingGroups) is 0 then
		display dialog "No Contacts group named \"" & groupName & "\" was found." & return & ¬
			"Run ContactImporter.applescript first." buttons {"OK"} default button "OK" with icon stop
		return
	end if
	set theGroup to item 1 of matchingGroups
	repeat with p in (people of theGroup)
		set phoneList to (value of phones of p)
		if (count of phoneList) > 0 then
			set cleanNumber to my cleanPhone((item 1 of phoneList) as string)
			if cleanNumber is not "" then set end of recipientNumbers to cleanNumber
		end if
	end repeat
end tell

if (count of recipientNumbers) is 0 then
	display dialog "The group \"" & groupName & "\" has no contacts with usable phone numbers." ¬
		buttons {"OK"} default button "OK" with icon stop
	return
end if


-- =====================================================================
--  STEP 2 — Build the shortcut definition (.plist)
--
--  Action layout that gets written:
--     List            <- the recipient phone numbers, baked in
--     Repeat with Each (over the List)
--         Send Message [message text] to [Repeat Item]
--         Wait         [delayBetween] seconds
--     End Repeat
-- =====================================================================
-- Fresh UUIDs so the List output, the Repeat block, and the actions all
-- reference each other unambiguously.
set listUUID to my newUUID()
set repeatGroupUUID to my newUUID()
set repeatStartUUID to my newUUID()
set sendUUID to my newUUID()
set waitUUID to my newUUID()
set repeatEndUUID to my newUUID()

-- Recipient numbers as <string> items inside the List action.
set itemsXML to ""
repeat with num in recipientNumbers
	set itemsXML to itemsXML & "				<string>" & my xmlEscape(num as string) & "</string>" & linefeed
end repeat

-- Optional Wait action (only if a delay is configured).
set waitActionXML to ""
if delayBetween > 0 then
	set waitActionXML to ¬
		"		<dict>" & linefeed & ¬
		"			<key>WFWorkflowActionIdentifier</key>" & linefeed & ¬
		"			<string>is.workflow.actions.delay</string>" & linefeed & ¬
		"			<key>WFWorkflowActionParameters</key>" & linefeed & ¬
		"			<dict>" & linefeed & ¬
		"				<key>UUID</key>" & linefeed & ¬
		"				<string>" & waitUUID & "</string>" & linefeed & ¬
		"				<key>WFDelayTime</key>" & linefeed & ¬
		"				<real>" & (delayBetween as string) & "</real>" & linefeed & ¬
		"			</dict>" & linefeed & ¬
		"		</dict>" & linefeed
end if

set plistText to ¬
	"<?xml version=\"1.0\" encoding=\"UTF-8\"?>" & linefeed & ¬
	"<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">" & linefeed & ¬
	"<plist version=\"1.0\">" & linefeed & ¬
	"<dict>" & linefeed & ¬
	"	<key>WFWorkflowActions</key>" & linefeed & ¬
	"	<array>" & linefeed & ¬
	"		<dict>" & linefeed & ¬
	"			<key>WFWorkflowActionIdentifier</key>" & linefeed & ¬
	"			<string>is.workflow.actions.list</string>" & linefeed & ¬
	"			<key>WFWorkflowActionParameters</key>" & linefeed & ¬
	"			<dict>" & linefeed & ¬
	"				<key>UUID</key>" & linefeed & ¬
	"				<string>" & listUUID & "</string>" & linefeed & ¬
	"				<key>WFItems</key>" & linefeed & ¬
	"				<array>" & linefeed & ¬
	itemsXML & ¬
	"				</array>" & linefeed & ¬
	"			</dict>" & linefeed & ¬
	"		</dict>" & linefeed & ¬
	"		<dict>" & linefeed & ¬
	"			<key>WFWorkflowActionIdentifier</key>" & linefeed & ¬
	"			<string>is.workflow.actions.repeat.each</string>" & linefeed & ¬
	"			<key>WFWorkflowActionParameters</key>" & linefeed & ¬
	"			<dict>" & linefeed & ¬
	"				<key>UUID</key>" & linefeed & ¬
	"				<string>" & repeatStartUUID & "</string>" & linefeed & ¬
	"				<key>GroupingIdentifier</key>" & linefeed & ¬
	"				<string>" & repeatGroupUUID & "</string>" & linefeed & ¬
	"				<key>WFControlFlowMode</key>" & linefeed & ¬
	"				<integer>0</integer>" & linefeed & ¬
	"				<key>WFInput</key>" & linefeed & ¬
	"				<dict>" & linefeed & ¬
	"					<key>Value</key>" & linefeed & ¬
	"					<dict>" & linefeed & ¬
	"						<key>OutputUUID</key>" & linefeed & ¬
	"						<string>" & listUUID & "</string>" & linefeed & ¬
	"						<key>OutputName</key>" & linefeed & ¬
	"						<string>List</string>" & linefeed & ¬
	"						<key>Type</key>" & linefeed & ¬
	"						<string>ActionOutput</string>" & linefeed & ¬
	"					</dict>" & linefeed & ¬
	"					<key>WFSerializationType</key>" & linefeed & ¬
	"					<string>WFTextTokenAttachment</string>" & linefeed & ¬
	"				</dict>" & linefeed & ¬
	"			</dict>" & linefeed & ¬
	"		</dict>" & linefeed & ¬
	"		<dict>" & linefeed & ¬
	"			<key>WFWorkflowActionIdentifier</key>" & linefeed & ¬
	"			<string>is.workflow.actions.sendmessage</string>" & linefeed & ¬
	"			<key>WFWorkflowActionParameters</key>" & linefeed & ¬
	"			<dict>" & linefeed & ¬
	"				<key>UUID</key>" & linefeed & ¬
	"				<string>" & sendUUID & "</string>" & linefeed & ¬
	"				<key>WFSendMessageContent</key>" & linefeed & ¬
	"				<dict>" & linefeed & ¬
	"					<key>Value</key>" & linefeed & ¬
	"					<dict>" & linefeed & ¬
	"						<key>string</key>" & linefeed & ¬
	"						<string>" & my xmlEscape(placeholderText) & "</string>" & linefeed & ¬
	"						<key>attachmentsByRange</key>" & linefeed & ¬
	"						<dict/>" & linefeed & ¬
	"					</dict>" & linefeed & ¬
	"					<key>WFSerializationType</key>" & linefeed & ¬
	"					<string>WFTextTokenString</string>" & linefeed & ¬
	"				</dict>" & linefeed & ¬
	"				<key>WFSendMessageRecipients</key>" & linefeed & ¬
	"				<dict>" & linefeed & ¬
	"					<key>Value</key>" & linefeed & ¬
	"					<dict>" & linefeed & ¬
	"						<key>Type</key>" & linefeed & ¬
	"						<string>Variable</string>" & linefeed & ¬
	"						<key>VariableName</key>" & linefeed & ¬
	"						<string>Repeat Item</string>" & linefeed & ¬
	"					</dict>" & linefeed & ¬
	"					<key>WFSerializationType</key>" & linefeed & ¬
	"					<string>WFTextTokenAttachment</string>" & linefeed & ¬
	"				</dict>" & linefeed & ¬
	"			</dict>" & linefeed & ¬
	"		</dict>" & linefeed & ¬
	waitActionXML & ¬
	"		<dict>" & linefeed & ¬
	"			<key>WFWorkflowActionIdentifier</key>" & linefeed & ¬
	"			<string>is.workflow.actions.repeat.each</string>" & linefeed & ¬
	"			<key>WFWorkflowActionParameters</key>" & linefeed & ¬
	"			<dict>" & linefeed & ¬
	"				<key>UUID</key>" & linefeed & ¬
	"				<string>" & repeatEndUUID & "</string>" & linefeed & ¬
	"				<key>GroupingIdentifier</key>" & linefeed & ¬
	"				<string>" & repeatGroupUUID & "</string>" & linefeed & ¬
	"				<key>WFControlFlowMode</key>" & linefeed & ¬
	"				<integer>2</integer>" & linefeed & ¬
	"			</dict>" & linefeed & ¬
	"		</dict>" & linefeed & ¬
	"	</array>" & linefeed & ¬
	"	<key>WFWorkflowClientVersion</key>" & linefeed & ¬
	"	<string>1146.0.2</string>" & linefeed & ¬
	"	<key>WFWorkflowMinimumClientVersion</key>" & linefeed & ¬
	"	<integer>900</integer>" & linefeed & ¬
	"	<key>WFWorkflowMinimumClientVersionString</key>" & linefeed & ¬
	"	<string>900</string>" & linefeed & ¬
	"	<key>WFWorkflowIcon</key>" & linefeed & ¬
	"	<dict>" & linefeed & ¬
	"		<key>WFWorkflowIconStartColor</key>" & linefeed & ¬
	"		<integer>4274264319</integer>" & linefeed & ¬
	"		<key>WFWorkflowIconGlyphNumber</key>" & linefeed & ¬
	"		<integer>61440</integer>" & linefeed & ¬
	"	</dict>" & linefeed & ¬
	"	<key>WFWorkflowImportQuestions</key>" & linefeed & ¬
	"	<array/>" & linefeed & ¬
	"	<key>WFWorkflowTypes</key>" & linefeed & ¬
	"	<array>" & linefeed & ¬
	"		<string>NCWidget</string>" & linefeed & ¬
	"		<string>WatchKit</string>" & linefeed & ¬
	"	</array>" & linefeed & ¬
	"	<key>WFWorkflowInputContentItemClasses</key>" & linefeed & ¬
	"	<array>" & linefeed & ¬
	"		<string>WFAppStoreAppContentItem</string>" & linefeed & ¬
	"		<string>WFContactContentItem</string>" & linefeed & ¬
	"		<string>WFDateContentItem</string>" & linefeed & ¬
	"		<string>WFEmailAddressContentItem</string>" & linefeed & ¬
	"		<string>WFGenericFileContentItem</string>" & linefeed & ¬
	"		<string>WFImageContentItem</string>" & linefeed & ¬
	"		<string>WFLocationContentItem</string>" & linefeed & ¬
	"		<string>WFPhoneNumberContentItem</string>" & linefeed & ¬
	"		<string>WFRichTextContentItem</string>" & linefeed & ¬
	"		<string>WFStringContentItem</string>" & linefeed & ¬
	"		<string>WFURLContentItem</string>" & linefeed & ¬
	"	</array>" & linefeed & ¬
	"</dict>" & linefeed & ¬
	"</plist>" & linefeed


-- =====================================================================
--  STEP 3 — Write, validate, sign, and import
-- =====================================================================
set deskFolder to (POSIX path of (path to desktop))
set unsignedPath to deskFolder & "MassMessageSender.plist"
set signedPath to deskFolder & "MassMessageSender.shortcut"

-- Write the plist as UTF-8.
my writeUTF8(unsignedPath, plistText)

-- Validate the XML before handing it to `shortcuts`.
try
	do shell script "/usr/bin/plutil -lint " & quoted form of unsignedPath
on error lintMsg
	display dialog "The generated shortcut file failed validation:" & return & return & lintMsg & return & return & ¬
		"The unsigned file is on your Desktop (MassMessageSender.plist) if you want to inspect it." ¬
		buttons {"OK"} default button "OK" with icon stop
	return
end try

-- Sign it with Apple's CLI (needs an internet connection).
try
	do shell script "/usr/bin/shortcuts sign --mode " & quoted form of signMode & ¬
		" --input " & quoted form of unsignedPath & ¬
		" --output " & quoted form of signedPath
on error signMsg
	display dialog "Couldn't sign the shortcut." & return & return & signMsg & return & return & ¬
		"Signing needs an internet connection (Apple signs the file). " & ¬
		"Check your connection and run this script again." & return & return & ¬
		"The unsigned definition is on your Desktop: MassMessageSender.plist" ¬
		buttons {"OK"} default button "OK" with icon stop
	return
end try

-- Open the signed shortcut so Shortcuts imports it.
try
	do shell script "/usr/bin/open " & quoted form of signedPath
end try


-- =====================================================================
--  DONE — summary
-- =====================================================================
display dialog "Created the shortcut and opened it in Shortcuts:" & return & return & ¬
	"    " & shortcutName & return & return & ¬
	"Recipients baked in:  " & (count of recipientNumbers) & "  (from group \"" & groupName & "\")" & return & return & ¬
	"Click \"Add Shortcut\" in the window that appeared. Then open it, edit the " & ¬
	"message text if you like, and run it to send." & return & return & ¬
	"Re-run this script after importing new contacts to refresh the recipient list." ¬
	buttons {"OK"} default button "OK" with icon note


-- =====================================================================
--  =====================  HANDLERS (helpers)  ========================
-- =====================================================================

-- newUUID() -> a fresh UUID string (e.g. "1E2D...-...").
on newUUID()
	return (do shell script "/usr/bin/uuidgen")
end newUUID

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

-- xmlEscape(t) -> escape &, <, > for safe embedding in XML.
on xmlEscape(t)
	set t to t as string
	set t to my replaceText(t, "&", "&amp;")
	set t to my replaceText(t, "<", "&lt;")
	set t to my replaceText(t, ">", "&gt;")
	return t
end xmlEscape

-- replaceText(t, findStr, replStr) -> string with every findStr replaced.
on replaceText(t, findStr, replStr)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to findStr
	set pieces to text items of (t as string)
	set AppleScript's text item delimiters to replStr
	set t to pieces as string
	set AppleScript's text item delimiters to oldDelims
	return t
end replaceText

-- writeUTF8(posixPath, theText) -> write theText to posixPath as UTF-8.
on writeUTF8(posixPath, theText)
	set fileRef to (open for access (POSIX file posixPath) with write permission)
	try
		set eof fileRef to 0
		write theText to fileRef as «class utf8»
		close access fileRef
	on error errMsg
		try
			close access fileRef
		end try
		error errMsg
	end try
end writeUTF8

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
			"Enter the Contacts group name to target:" default answer defaultGuess ¬
			buttons {"Cancel", "Use This"} default button "Use This" with icon caution)
		set answer to my trimWhitespace(answer)
		if answer is "" then error "No group name provided."
		return answer
	on error
		display dialog "No group name available. Aborting." buttons {"OK"} default button "OK" with icon stop
		error number -128
	end try
end resolveGroupName

-- formatDate(theDate) -> "YYYY-MM-DD".
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
