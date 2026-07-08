(*
=====================================================================
  CONTACT IMPORTER  —  Pure, self-contained AppleScript
  Compatible with macOS Ventura (13) and Sonoma (14)
  Save as:  ContactImporter.applescript
  Run with: Script Editor  (Run button)  or  osascript ContactImporter.applescript
=====================================================================

  WHAT THIS DOES
  --------------
  1. Opens a "Choose File" dialog so you can pick a .csv or .txt file.
  2. Parses each line as:  FirstName, LastName, PhoneNumber
       - A line with only ONE value is treated as a phone number.
         First Name becomes "Imported" and Last Name becomes the
         last 4 digits of that number.
  3. Creates (or re-creates) a Contacts group named
       "Automation_List_YYYY-MM-DD".  If a group with that name
       already exists it is DELETED first so you never get duplicates.
  4. Adds every valid contact to that group, saving the phone number
       to the MOBILE phone field.
  5. Shows a summary dialog: how many imported, how many failed,
       and the line numbers that failed.

  ---------------------------------------------------------------
  ⚠️  PRIVACY / PERMISSIONS  ⚠️
  ---------------------------------------------------------------
  The FIRST time you run this, macOS will pop up permission
  requests.  You MUST click "OK"/"Allow" for:
      • Contacts   (so the script can create people & groups)
      • Automation / Accessibility (so it can control the apps)

  If the script fails silently or errors with "not authorized",
  grant access manually:
      System Settings  ->  Privacy & Security  ->  Contacts
          -> enable "Script Editor" (or "osascript"/"Terminal")
      System Settings  ->  Privacy & Security  ->  Accessibility
          -> enable the app you are running the script from
  Then quit and re-run the script.
  ---------------------------------------------------------------

  EASY-TO-EDIT SETTINGS are grouped in the CONFIGURATION block below.
=====================================================================
*)


-- =====================================================================
-- CONFIGURATION  — change these values to customise behaviour
-- =====================================================================
set groupPrefix to "Automation_List_" -- text placed before the date in the group name
set csvDelimiter to ","               -- change to ";" or tab, etc. if your file uses another delimiter
set defaultFirstName to "Imported"    -- first name used for phone-only lines
-- COUNTRY CODE SAFETY -------------------------------------------------
-- Numbers saved WITHOUT a "+<countrycode>" get guessed by macOS (that's
-- how Indian numbers once became unreachable +44 UK numbers). Rules:
--   • Numbers in the CSV that already start with "+" are kept EXACTLY
--     as written  →  mix +91… (India), +1… (US), etc. freely.
--   • Bare numbers (no "+") get defaultCountryCode prepended so nothing
--     ambiguous is ever saved.
set defaultCountryCode to "+91"       -- applied only to numbers lacking a "+" prefix
-- The date format is controlled by the formatDate() handler near the
-- bottom of this file. Edit that handler to change YYYY-MM-DD to
-- something else (e.g. MM-DD-YYYY).
-- =====================================================================


-- =====================================================================
-- STEP 1 — Build the dated group name (e.g. Automation_List_2026-07-08)
-- =====================================================================
set todayDate to (current date)
set dateString to my formatDate(todayDate)
set groupName to groupPrefix & dateString


-- =====================================================================
-- STEP 2 — Ask the user to choose the input file
-- =====================================================================
try
	set theFile to choose file with prompt "Select a .csv or .txt file containing your contacts:" without invisibles
on error
	-- User pressed Cancel in the file dialog: stop quietly.
	return
end try


-- =====================================================================
-- STEP 3 — Read the file as plain UTF-8 text and split into lines
--   "paragraphs" automatically handles Mac, Unix and Windows line breaks.
-- =====================================================================
try
	set fileText to read theFile as «class utf8»
on error
	-- Fallback for files that are not UTF-8 encoded.
	set fileText to read theFile
end try
set fileLines to paragraphs of fileText


-- =====================================================================
-- STEP 4 — Prepare / reset the Contacts group
--   If a group with this name already exists we delete it first, so a
--   re-run never produces duplicate group entries.
-- =====================================================================
tell application "Contacts"
	activate
	-- Delete any pre-existing groups that share our target name — AND the
	-- person cards inside them, so stale/wrongly-formatted contacts from
	-- earlier runs don't pile up in All Contacts.
	set duplicateGroups to (every group whose name is groupName)
	repeat with g in duplicateGroups
		try
			set oldPeople to (people of g)
			repeat with p in oldPeople
				try
					delete p
				end try
			end repeat
		end try
		delete g
	end repeat
	save
	-- Create a fresh, empty group.
	set newGroup to (make new group with properties {name:groupName})
	save
end tell

-- Save the group name to a hand-off file on the Desktop so downstream
-- automations (e.g. MassMessageSetup.applescript) can read which group
-- was just created. Overwrites any previous value.
try
	set handoffPath to (POSIX path of (path to desktop)) & "contact_group_name.txt"
	do shell script "printf '%s' " & quoted form of groupName & " > " & quoted form of handoffPath
end try


-- =====================================================================
-- STEP 5 — Loop through every line, parse it, and create contacts
-- =====================================================================
set successCount to 0        -- how many contacts were imported OK
set failedLineNumbers to {}  -- line numbers we could not import
set errorLog to ""           -- human-readable log of what went wrong
set lineNumber to 0          -- 1-based counter for reporting
set batchSize to 50          -- commit to Contacts every N people (avoids the
--                              "Connection is invalid" error on big lists)
set sinceLastSave to 0       -- counter toward the next batch save

repeat with rawLine in fileLines
	set lineNumber to lineNumber + 1
	set thisLine to (rawLine as string)

	-- Skip blank / whitespace-only lines silently (not counted as failures).
	if (my trimText(thisLine)) is "" then
		-- do nothing, just move on
	else
		-- Split the line into fields using the configured delimiter.
		set fields to my splitText(thisLine, csvDelimiter)
		set fieldCount to (count of fields)

		-- Defaults for this record.
		set firstName to ""
		set lastName to ""
		set rawPhone to ""

		if fieldCount is 1 then
			-- Only one value on the line -> treat it as a phone number.
			set rawPhone to my trimText(item 1 of fields)
			set firstName to defaultFirstName
			-- Last name = last 4 digits of the number (computed after cleaning).
		else if fieldCount is 2 then
			-- Two values -> assume "FirstName, PhoneNumber".
			set firstName to my trimText(item 1 of fields)
			set lastName to ""
			set rawPhone to my trimText(item 2 of fields)
		else
			-- Three or more values -> FirstName, LastName, PhoneNumber.
			set firstName to my trimText(item 1 of fields)
			set lastName to my trimText(item 2 of fields)
			set rawPhone to my trimText(item 3 of fields)
		end if

		-- Clean the phone number: remove spaces so "+1 234 567" -> "+1234567".
		set cleanPhone to my stripSpaces(rawPhone)

		-- COUNTRY CODE SAFETY: never save a bare number. If it has no "+"
		-- prefix, prepend the configured default country code so macOS
		-- can't mis-guess the region (e.g. turning +91 numbers into +44).
		if cleanPhone is not "" and cleanPhone does not start with "+" then
			set cleanPhone to defaultCountryCode & (my keepDigits(cleanPhone))
		end if

		-- Validate: a usable number must contain at least one digit.
		if my hasDigit(cleanPhone) then
			-- For phone-only lines, derive the last name from the digits.
			if fieldCount is 1 then
				set justDigits to my keepDigits(cleanPhone)
				if (length of justDigits) ≥ 4 then
					set lastName to text -4 thru -1 of justDigits
				else
					set lastName to justDigits
				end if
			end if

			-- Create the person and attach the phone as a MOBILE number.
			tell application "Contacts"
				set newPerson to (make new person with properties {first name:firstName, last name:lastName})
				make new phone at end of phones of newPerson with properties {label:"mobile", value:cleanPhone}
				add newPerson to newGroup
			end tell

			set successCount to successCount + 1
			set sinceLastSave to sinceLastSave + 1

			-- BATCH SAVE: commit every `batchSize` people so a big import
			-- doesn't pile up one giant transaction (which triggers the
			-- "Connection is invalid" error). After saving, re-fetch the
			-- group by name so our reference can't go stale.
			if sinceLastSave ≥ batchSize then
				tell application "Contacts"
					save
					set newGroup to (first group whose name is groupName)
				end tell
				set sinceLastSave to 0
			end if
		else
			-- No digits found: record the failure and keep going.
			set end of failedLineNumbers to lineNumber
			set errorLog to errorLog & "Line " & lineNumber & ": no valid digits in \"" & thisLine & "\"" & return
		end if
	end if
end repeat

-- Persist all the changes we made to the Contacts database.
tell application "Contacts"
	save
end tell


-- =====================================================================
-- STEP 6 — Report the results to the user
-- =====================================================================
set failCount to (count of failedLineNumbers)

if failCount is 0 then
	set failLineText to "None"
else
	set failLineText to my joinList(failedLineNumbers, ", ")
end if

set summaryText to "Import finished." & return & return & ¬
	"Group:            " & groupName & return & ¬
	"Imported OK:  " & successCount & return & ¬
	"Failed:            " & failCount & return & ¬
	"Failed lines:   " & failLineText

display dialog summaryText buttons {"OK"} default button "OK" with title "Contact Importer" with icon note


-- =====================================================================
-- =====================  HANDLER / HELPER SECTION  ====================
--  These reusable sub-routines keep the main logic above tidy.
-- =====================================================================

-- Format a date as YYYY-MM-DD (zero-padded).
-- EDIT HERE to change the date format used in the group name.
on formatDate(d)
	set y to (year of d) as integer
	set m to (month of d) as integer
	set dNum to (day of d) as integer
	-- Zero-pad month and day to two digits.
	set mm to text -2 thru -1 of ("0" & m)
	set dd to text -2 thru -1 of ("0" & dNum)
	return (y as string) & "-" & mm & "-" & dd
end formatDate

-- Split a string into a list using a delimiter, restoring the global
-- text item delimiters afterwards so we don't disturb other code.
on splitText(theText, delim)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delim
	set theItems to text items of theText
	set AppleScript's text item delimiters to oldDelims
	return theItems
end splitText

-- Join a list into a string using a delimiter.
on joinList(theList, delim)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to delim
	set theString to theList as string
	set AppleScript's text item delimiters to oldDelims
	return theString
end joinList

-- Remove leading and trailing spaces, tabs, returns and line feeds.
on trimText(t)
	set t to t as string
	set whitespaceChars to {" ", tab, return, linefeed}
	-- Trim from the front.
	repeat while (length of t) > 0 and ((character 1 of t) is in whitespaceChars)
		if (length of t) is 1 then
			set t to ""
		else
			set t to text 2 thru -1 of t
		end if
	end repeat
	-- Trim from the back.
	repeat while (length of t) > 0 and ((character -1 of t) is in whitespaceChars)
		if (length of t) is 1 then
			set t to ""
		else
			set t to text 1 thru -2 of t
		end if
	end repeat
	return t
end trimText

-- Remove every space character from a string (keeps +, digits, dashes, etc.).
on stripSpaces(t)
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to " "
	set pieces to text items of (t as string)
	set AppleScript's text item delimiters to ""
	set t to pieces as string
	set AppleScript's text item delimiters to oldDelims
	return t
end stripSpaces

-- Return TRUE if the string contains at least one 0-9 digit.
on hasDigit(t)
	repeat with c in characters of (t as string)
		if ((c as string) is in {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}) then
			return true
		end if
	end repeat
	return false
end hasDigit

-- Return only the 0-9 digit characters from a string.
on keepDigits(t)
	set outText to ""
	repeat with c in characters of (t as string)
		if ((c as string) is in {"0", "1", "2", "3", "4", "5", "6", "7", "8", "9"}) then
			set outText to outText & (c as string)
		end if
	end repeat
	return outText
end keepDigits
