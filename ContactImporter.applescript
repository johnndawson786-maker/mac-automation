(*
=====================================================================
  CONTACT IMPORTER  —  Pure, self-contained AppleScript
  Compatible with macOS Ventura (13) and Sonoma (14)
  Save as:  ContactImporter.applescript
  Run with: Script Editor  (Run button)  or  osascript ContactImporter.applescript
=====================================================================

  WHAT THIS DOES  (folder-based — no manual file picking)
  ------------------------------------------------------
  1. Looks for a "recipients" folder that sits NEXT TO this script.
     (If it can't find one, it asks you to choose a folder once.)
  2. AUTOMATICALLY reads EVERY .csv / .txt file inside that folder and
     parses each line as:  FirstName, LastName, PhoneNumber
       - A line with only ONE value is treated as a phone number.
         First Name becomes "Imported" and Last Name becomes the
         last 4 digits of that number.
  3. Creates (or re-creates) a Contacts group named
       "Automation_List_YYYY-MM-DD".  If a group with that name
       already exists it is DELETED first so you never get duplicates.
  4. Adds every valid contact to that group, saving the phone number
       to the MOBILE phone field.
  5. Writes the group name to ~/Desktop/contact_group_name.txt so
       MassMessageSender.applescript picks up the right group with no
       manual step.
  6. ARCHIVES each processed file into recipients/processed/ and writes
       a fresh run-log there, so the inbox folder is left empty and
       ready for the next batch of files. (Toggle with archiveProcessed.)
  7. Shows a summary dialog: how many imported, how many failed,
       and which files / lines failed.

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
set recipientsFolderName to "recipients" -- the inbox folder (kept next to this script)
set handoffFileName to "contact_group_name.txt" -- written to the Desktop for MassMessageSender
set archiveProcessed to true          -- true = move imported files into recipients/processed/ after a run
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
-- STEP 2 — Locate the recipients folder and collect every input file
--   Preference order:
--     1. A "recipients" folder next to this script.
--     2. Otherwise, ask the user to choose a folder once.
-- =====================================================================
set recipientsFolder to my resolveRecipientsFolder(recipientsFolderName)

set inputFiles to my listInputFiles(recipientsFolder)
if (count of inputFiles) is 0 then
	display dialog "No .csv or .txt files were found in:" & return & return & ¬
		recipientsFolder & return & return & ¬
		"Drop your recipient files into that folder and run again." ¬
		buttons {"OK"} default button "OK" with title "Contact Importer" with icon caution
	return
end if


-- =====================================================================
-- STEP 3 — Prepare / reset the Contacts group
--   If a group with this name already exists we delete it first, so a
--   re-run never produces duplicate group entries.
-- =====================================================================
tell application "Contacts"
	activate
	-- Delete any pre-existing groups that share our target name.
	set duplicateGroups to (every group whose name is groupName)
	repeat with g in duplicateGroups
		delete g
	end repeat
	save
	-- Create a fresh, empty group.
	set newGroup to (make new group with properties {name:groupName})
	save
end tell


-- =====================================================================
-- STEP 4 — Loop through every file, parse each line, create contacts
-- =====================================================================
set successCount to 0        -- how many contacts were imported OK across all files
set failCount to 0           -- how many lines we could not import
set errorLog to ""           -- human-readable log of what went wrong
set fileSummaries to ""      -- per-file breakdown for the summary dialog
set processedFiles to {}     -- POSIX paths of files we successfully read

repeat with filePath in inputFiles
	set filePath to filePath as string

	-- Read the file as UTF-8 text, falling back to the default encoding.
	set fileText to ""
	set fileReadOK to true
	try
		set fileText to (read (POSIX file filePath) as «class utf8»)
	on error
		try
			set fileText to (read (POSIX file filePath))
		on error errMsg
			set fileReadOK to false
			set errorLog to errorLog & "Could not read file: " & filePath & " — " & errMsg & return
		end try
	end try

	if fileReadOK then
		-- "paragraphs" handles Mac, Unix and Windows line breaks automatically.
		set fileLines to paragraphs of fileText
		set fileImported to 0
		set fileFailed to 0
		set lineNumber to 0

		repeat with rawLine in fileLines
			set lineNumber to lineNumber + 1
			set thisLine to (rawLine as string)

			-- Skip blank / whitespace-only lines silently (not counted as failures).
			if (my trimText(thisLine)) is not "" then
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
					set fileImported to fileImported + 1
				else
					-- No digits found: record the failure and keep going.
					set failCount to failCount + 1
					set fileFailed to fileFailed + 1
					set errorLog to errorLog & (my baseName(filePath)) & " line " & lineNumber & ¬
						": no valid digits in \"" & thisLine & "\"" & return
				end if
			end if
		end repeat

		set end of processedFiles to filePath
		set fileSummaries to fileSummaries & "  • " & (my baseName(filePath)) & ¬
			":  " & fileImported & " imported, " & fileFailed & " failed" & return
	end if
end repeat

-- Persist all the changes we made to the Contacts database.
tell application "Contacts"
	save
end tell


-- =====================================================================
-- STEP 5 — Hand the group name off to MassMessageSender
--   Writing ~/Desktop/contact_group_name.txt lets the sender find this
--   exact group with no dialogs or guessing.
-- =====================================================================
set handoffOK to my writeHandoff(handoffFileName, groupName)


-- =====================================================================
-- STEP 6 — Archive the processed files and write a run-log
--   Each run moves the imported files into recipients/processed/ and
--   drops a fresh timestamped log there, leaving the inbox empty for
--   the next batch.
-- =====================================================================
set archiveNote to ""
if archiveProcessed and (count of processedFiles) > 0 then
	set archiveNote to my archiveRun(recipientsFolder, processedFiles, groupName, successCount, failCount, todayDate)
end if


-- =====================================================================
-- STEP 7 — Report the results to the user
-- =====================================================================
set summaryText to "Import finished." & return & return & ¬
	"Group:            " & groupName & return & ¬
	"Files read:      " & (count of processedFiles) & return & ¬
	"Imported OK:  " & successCount & return & ¬
	"Failed lines:   " & failCount & return & return & ¬
	"Per file:" & return & fileSummaries

if handoffOK then
	set summaryText to summaryText & return & "Handoff written — MassMessageSender will target this group automatically."
end if
if archiveNote is not "" then
	set summaryText to summaryText & return & return & archiveNote
end if

display dialog summaryText buttons {"OK"} default button "OK" with title "Contact Importer" with icon note


-- =====================================================================
-- =====================  HANDLER / HELPER SECTION  ====================
--  These reusable sub-routines keep the main logic above tidy.
-- =====================================================================

-- Find the folder this script file lives in, returned as a POSIX path
-- that ends with a trailing slash. Returns "" if it can't be determined
-- (e.g. the script has never been saved).
on getScriptFolder()
	try
		set myPosix to POSIX path of (path to me)
		if myPosix ends with "/" then set myPosix to text 1 thru -2 of myPosix
		set oldDelims to AppleScript's text item delimiters
		set AppleScript's text item delimiters to "/"
		set parts to text items of myPosix
		set parts to items 1 thru -2 of parts
		set folderPath to (parts as text) & "/"
		set AppleScript's text item delimiters to oldDelims
		return folderPath
	on error
		return ""
	end try
end getScriptFolder

-- Locate the recipients folder. Prefer one next to this script; if that
-- doesn't exist, let the user choose a folder once. Returns a POSIX path
-- ending in "/".
on resolveRecipientsFolder(folderName)
	set scriptFolder to my getScriptFolder()
	if scriptFolder is not "" then
		set candidate to scriptFolder & folderName & "/"
		try
			do shell script "test -d " & quoted form of candidate
			return candidate
		on error
			-- Folder isn't there yet; create it so the user has somewhere to drop files.
			try
				do shell script "mkdir -p " & quoted form of candidate
				return candidate
			end try
		end try
	end if
	-- Fallback: ask the user to point us at a folder.
	set chosen to (choose folder with prompt "Select the folder that holds your recipient .csv / .txt files:")
	return POSIX path of chosen
end resolveRecipientsFolder

-- Return a list of POSIX paths for every top-level .csv/.txt file in the
-- given folder (the processed/ subfolder is ignored because we only look
-- one level deep).
on listInputFiles(folderPath)
	set rawList to ""
	try
		set rawList to do shell script "find " & quoted form of folderPath & ¬
			" -maxdepth 1 -type f \\( -iname '*.csv' -o -iname '*.txt' \\) 2>/dev/null | LC_ALL=C sort"
	end try
	set fileList to {}
	if rawList is "" then return fileList
	repeat with p in paragraphs of rawList
		set p to my trimText(p as string)
		if p is not "" then set end of fileList to p
	end repeat
	return fileList
end listInputFiles

-- Write the group name to ~/Desktop/<fileName>. Returns true on success.
on writeHandoff(fileName, groupName)
	try
		set deskPath to (POSIX path of (path to desktop)) & fileName
		do shell script "printf '%s' " & quoted form of groupName & " > " & quoted form of deskPath
		return true
	on error
		return false
	end try
end writeHandoff

-- Move each processed file into recipients/processed/ (timestamp-prefixed)
-- and write a run-log describing what happened. Returns a short human note.
on archiveRun(recipientsFolder, processedFiles, groupName, importedCount, failedCount, runDate)
	set stamp to my formatStamp(runDate)
	set processedDir to recipientsFolder & "processed/"
	try
		do shell script "mkdir -p " & quoted form of processedDir
	on error
		return "(Could not create the processed/ folder — files left in place.)"
	end try

	set movedCount to 0
	set logBody to "Import run " & stamp & return & ¬
		"Group: " & groupName & return & ¬
		"Imported OK: " & importedCount & return & ¬
		"Failed lines: " & failedCount & return & return & ¬
		"Files processed:" & return
	repeat with filePath in processedFiles
		set filePath to filePath as string
		set base to my baseName(filePath)
		set dest to processedDir & stamp & "__" & base
		try
			do shell script "mv " & quoted form of filePath & " " & quoted form of dest
			set movedCount to movedCount + 1
			set logBody to logBody & "  • " & base & return
		on error errMsg
			set logBody to logBody & "  • " & base & " (move failed: " & errMsg & ")" & return
		end try
	end repeat

	-- Drop a fresh log file for this run (the "new file each time").
	try
		set logPath to processedDir & "run_" & stamp & ".log"
		do shell script "printf '%s' " & quoted form of logBody & " > " & quoted form of logPath
	end try

	return "Archived " & movedCount & " file(s) to recipients/processed/ and wrote run_" & stamp & ".log"
end archiveRun

-- Return just the final path component (file name) from a POSIX path.
on baseName(posixPath)
	set posixPath to posixPath as string
	if posixPath ends with "/" then set posixPath to text 1 thru -2 of posixPath
	set oldDelims to AppleScript's text item delimiters
	set AppleScript's text item delimiters to "/"
	set parts to text items of posixPath
	set base to item -1 of parts
	set AppleScript's text item delimiters to oldDelims
	return base
end baseName

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

-- Format a date+time stamp as YYYY-MM-DD_HHMMSS for archive names.
on formatStamp(d)
	set datePart to my formatDate(d)
	set secs to (time of d) -- seconds since midnight
	set hh to secs div 3600
	set mn to (secs mod 3600) div 60
	set ss to secs mod 60
	set hh to text -2 thru -1 of ("0" & hh)
	set mn to text -2 thru -1 of ("0" & mn)
	set ss to text -2 thru -1 of ("0" & ss)
	return datePart & "_" & hh & mn & ss
end formatStamp

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
