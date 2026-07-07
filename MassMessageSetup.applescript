-- =====================================================================
--  MassMessageSetup.applescript
--  Builds a "Mass Message Sender" shortcut inside the macOS Shortcuts app
--  by driving the UI with System Events (keyboard-only, no mouse-drag
--  coordinates).
--
--  Chains off ContactImporter.applescript, which writes the name of the
--  Contacts group it created to:  ~/Desktop/contact_group_name.txt
--
--  ------------------------------------------------------------------
--  ⚠️  PERMISSIONS — READ THIS FIRST
--  ------------------------------------------------------------------
--  This script types and clicks on your behalf, so macOS REQUIRES
--  Accessibility permission for whatever app launches it:
--
--    System Settings → Privacy & Security → Accessibility
--       • Script Editor      (if you press Run in Script Editor)
--       • Terminal / osascript (if you run it from the shell)
--       • The exported .app  (if you saved it as an application)
--    → toggle it ON, then re-run.
--
--  You may also be prompted the first time under:
--    System Settings → Privacy & Security → Automation
--       → allow control of "Shortcuts" and "System Events".
--
--  ------------------------------------------------------------------
--  ⚠️  RELIABILITY WARNING — PLEASE READ
--  ------------------------------------------------------------------
--  The Shortcuts app has very poor scripting/accessibility support.
--  Two steps in particular are FRAGILE and may need manual finishing:
--    • Re-ordering actions. Shortcuts has NO documented keyboard
--      shortcut to move an action up/down. This script attempts
--      Cmd+Ctrl+Up/Down (used by some builds) as a BEST EFFORT and
--      will NOT crash if it does nothing — you can drag to reorder.
--    • Binding Magic Variables (Text output → Message field).
--  Every UI step is wrapped in `try`; if one fails you get a dialog
--  naming the step, and the script keeps going where it safely can.
--  Treat the produced shortcut as a scaffold to finish by hand.
-- =====================================================================


-- =====================================================================
--  CONFIGURATION  — tweak these, then re-run
-- =====================================================================
set shortcutBaseName to "Mass Message Sender" -- name prefix; date is appended
set placeholderText to "Hello from automation – replace me later." -- Text action body
set uiDelay to 0.5            -- base pause (sec) between UI steps; raise on a slow Mac
set longDelay to 1.0          -- longer pause after big actions (new doc, save)
set handoffFileName to "contact_group_name.txt" -- file written by ContactImporter


-- =====================================================================
--  STEP 0 — Work out today's date and the final shortcut name
--  EDIT the formatDate() handler (bottom of file) to change the format.
-- =====================================================================
set todayString to my formatDate(current date)
set shortcutName to shortcutBaseName & " [" & todayString & "]"


-- =====================================================================
--  STEP 0b — Resolve the Contacts group name
--  Read it from ~/Desktop/contact_group_name.txt; if that's missing,
--  ask the user (defaulting the prompt to today's expected name).
-- =====================================================================
set groupName to my resolveGroupName(handoffFileName, todayString)


-- =====================================================================
--  STEP 1 — Launch Shortcuts and create a blank shortcut
-- =====================================================================
try
	tell application "Shortcuts" to activate
	delay longDelay
	tell application "System Events"
		tell process "Shortcuts"
			set frontmost to true
			delay uiDelay
			keystroke "n" using command down   -- Cmd+N = New Shortcut
		end tell
	end tell
	delay longDelay -- give the new editor window time to render
on error errMsg
	my failStep("Step 1 – launching Shortcuts / creating a new shortcut", errMsg)
	return
end try


-- =====================================================================
--  STEP 2 — Add "Find Contacts" and set its filter to our group
-- =====================================================================
try
	my addAction("Find Contacts", uiDelay)

	-- Click the "Add Filter" button that lives inside the action.
	tell application "System Events"
		tell process "Shortcuts"
			try
				click (first button whose name is "Add Filter")
				delay uiDelay
				-- A "Group" filter row appears with a value dropdown.
				-- Type the group name into it and confirm. Typing into the
				-- focused value field then Return usually selects/commits it.
				keystroke groupName
				delay uiDelay
				keystroke return
				delay uiDelay
			on error innerMsg
				-- Non-fatal: the button name or layout may differ by version.
				display dialog "Heads up: couldn't auto-set the Contacts filter to \"" & groupName & "\". " & ¬
					"Add it by hand in the Find Contacts action after the script finishes." & return & return & ¬
					"(" & innerMsg & ")" buttons {"Continue"} default button "Continue" with icon caution
			end try
		end tell
	end tell
on error errMsg
	my failStep("Step 2 – adding Find Contacts", errMsg)
	return
end try


-- =====================================================================
--  STEP 3 — Add "Repeat with Each"
--  (adds a Repeat start block + an End Repeat at the very bottom)
-- =====================================================================
try
	my addAction("Repeat with Each", uiDelay)
on error errMsg
	my failStep("Step 3 – adding Repeat with Each", errMsg)
	return
end try


-- =====================================================================
--  STEP 4 — Add "Text" (the message body) and type the placeholder
-- =====================================================================
try
	my addAction("Text", uiDelay)
	-- The freshly added Text action's field is usually focused; type into it.
	tell application "System Events"
		tell process "Shortcuts"
			delay uiDelay
			keystroke placeholderText
			delay uiDelay
		end tell
	end tell
on error errMsg
	my failStep("Step 4 – adding the Text action", errMsg)
	return
end try


-- =====================================================================
--  STEP 5 — Add "Send Message"
-- =====================================================================
try
	my addAction("Send Message", uiDelay)
on error errMsg
	my failStep("Step 5 – adding Send Message", errMsg)
	return
end try


-- =====================================================================
--  STEP 6 — Add "Wait" (added before the reorder so we can position it)
-- =====================================================================
try
	my addAction("Wait", uiDelay)
	-- Try to set the duration to 2. The number field is usually focused
	-- right after insertion; select-all + type replaces the default "1".
	tell application "System Events"
		tell process "Shortcuts"
			delay uiDelay
			try
				keystroke "a" using command down
				keystroke "2"
				keystroke return
			end try
		end tell
	end tell
on error errMsg
	my failStep("Step 6 – adding the Wait action", errMsg)
	-- non-fatal; continue
end try


-- =====================================================================
--  STEP 7 — Re-order actions into the desired final layout
--
--  Current (insertion) order:
--     Find Contacts
--     Repeat with Each
--       End Repeat        <- auto-added at the bottom of the block
--     Text
--     Send Message
--     Wait
--
--  Desired order:
--     Find Contacts
--     Repeat with Each
--       Text
--       Send Message
--       Wait
--     End Repeat
--
--  ⚠️  Shortcuts exposes NO reliable keyboard command to move an action.
--  This block is BEST EFFORT: it tries Cmd+Ctrl+Up (a combo some builds
--  honour). If nothing moves, the try blocks swallow it and you finish
--  the ordering by dragging. See the reorderUp() handler at the bottom
--  to change the key combo if your Shortcuts version differs.
-- =====================================================================
try
	-- Move Text above End Repeat (up twice).
	my reorderUp("Text", 2, uiDelay)
	-- Move Send Message above End Repeat (up once relative to new layout).
	my reorderUp("Send Message", 1, uiDelay)
	-- Move Wait above End Repeat.
	my reorderUp("Wait", 1, uiDelay)
on error errMsg
	display dialog "Re-ordering step hit a snag. Shortcuts often ignores keyboard reordering — " & ¬
		"just drag the Text / Send Message / Wait actions above \"End Repeat\" manually." & return & return & ¬
		"(" & errMsg & ")" buttons {"OK"} default button "OK" with icon caution
end try


-- =====================================================================
--  STEP 8 — Save the shortcut with the dated name
-- =====================================================================
try
	tell application "System Events"
		tell process "Shortcuts"
			set frontmost to true
			delay uiDelay
			keystroke "s" using command down   -- Cmd+S
			delay longDelay
			-- If a name/save sheet appears, type the name and confirm.
			try
				keystroke "a" using command down -- select any pre-filled name
				keystroke shortcutName
				delay uiDelay
				keystroke return
			end try
		end tell
	end tell
on error errMsg
	my failStep("Step 8 – saving the shortcut", errMsg)
	return
end try


-- =====================================================================
--  DONE — summary dialog
-- =====================================================================
display dialog "Finished building the shortcut scaffold:" & return & return & ¬
	"    " & shortcutName & return & return & ¬
	"Contacts group used:  " & groupName & return & return & ¬
	"⚠️  Please open Shortcuts and verify the action ORDER and the " & ¬
	"Message → Text Magic Variable binding — those UI steps are the " & ¬
	"least reliable and may need a quick manual touch-up." ¬
	buttons {"Open Shortcuts", "Done"} default button "Done" with icon note
if button returned of result is "Open Shortcuts" then
	tell application "Shortcuts" to activate
end if


-- =====================================================================
--  =====================  HANDLERS (helpers)  ========================
-- =====================================================================

-- ---------------------------------------------------------------------
-- addAction(actionName, pauseSec)
-- Opens the action search, types the action name, and inserts the top
-- match by pressing Return.
--
-- NOTE: Cmd+F focuses the action library search in current Shortcuts
-- builds. If your version differs, change the trigger here in ONE place.
-- ---------------------------------------------------------------------
on addAction(actionName, pauseSec)
	tell application "System Events"
		tell process "Shortcuts"
			set frontmost to true
			delay pauseSec
			keystroke "f" using command down   -- focus the action search field
			delay pauseSec
			-- Clear anything already in the field, then type our query.
			keystroke "a" using command down
			key code 51 -- delete/backspace
			delay (pauseSec / 2)
			keystroke actionName
			delay pauseSec                     -- let the search list populate
			keystroke return                   -- insert the highlighted action
			delay pauseSec
		end tell
	end tell
end addAction

-- ---------------------------------------------------------------------
-- reorderUp(actionName, times, pauseSec)
-- BEST-EFFORT reorder. Tries to select the named action's row, then
-- presses Cmd+Ctrl+Up `times` times. Silently tolerates failure because
-- Shortcuts frequently ignores this. Swap the key combo below if needed.
-- ---------------------------------------------------------------------
on reorderUp(actionName, times, pauseSec)
	tell application "System Events"
		tell process "Shortcuts"
			set frontmost to true
			delay pauseSec
			-- Attempt to click the row whose description/name contains the action.
			try
				set targetRow to (first UI element whose name contains actionName)
				click targetRow
				delay pauseSec
			end try
			repeat times times
				try
					-- Cmd+Ctrl+Up : honoured by some builds; harmless otherwise.
					key code 126 using {command down, control down}
				end try
				delay pauseSec
			end repeat
		end tell
	end tell
end reorderUp

-- ---------------------------------------------------------------------
-- resolveGroupName(fileName, dateStr)
-- Reads ~/Desktop/<fileName>. If present & non-empty, returns its
-- contents. Otherwise prompts the user, defaulting to the expected
-- "Automation_List_<date>" so they can usually just click OK.
-- ---------------------------------------------------------------------
on resolveGroupName(fileName, dateStr)
	set deskPath to (POSIX path of (path to desktop)) & fileName
	set foundName to ""
	try
		set foundName to (do shell script "cat " & quoted form of deskPath)
	end try
	-- Trim whitespace/newlines that a trailing return might leave behind.
	set foundName to my trimWhitespace(foundName)
	if foundName is not "" then return foundName

	-- Fallback: ask the user. Default matches ContactImporter's naming.
	set defaultGuess to "Automation_List_" & dateStr
	try
		set answer to text returned of (display dialog ¬
			"Couldn't find ~/Desktop/" & fileName & "." & return & return & ¬
			"Enter the Contacts group name to target:" ¬
			default answer defaultGuess buttons {"Cancel", "Use This"} default button "Use This" with icon caution)
		set answer to my trimWhitespace(answer)
		if answer is "" then error "No group name provided."
		return answer
	on error
		display dialog "No group name available. Aborting." buttons {"OK"} default button "OK" with icon stop
		error number -128 -- user-cancelled; stop the script cleanly
	end try
end resolveGroupName

-- ---------------------------------------------------------------------
-- failStep(stepDescription, errMsg)
-- Shows a clear, single dialog naming the step that failed.
-- ---------------------------------------------------------------------
on failStep(stepDescription, errMsg)
	display dialog "❌ Automation failed at:" & return & return & ¬
		stepDescription & return & return & ¬
		"macOS reported:" & return & errMsg & return & return & ¬
		"Most common cause: Accessibility permission not granted " & ¬
		"(System Settings → Privacy & Security → Accessibility), or the " & ¬
		"Shortcuts UI changed. Try increasing the uiDelay value at the top." ¬
		buttons {"OK"} default button "OK" with icon stop
end failStep

-- ---------------------------------------------------------------------
-- formatDate(theDate) -> "YYYY-MM-DD"
-- EDIT HERE to change the date format used in the shortcut's name.
-- ---------------------------------------------------------------------
on formatDate(theDate)
	set y to year of theDate as integer
	set m to (month of theDate as integer)
	set d to day of theDate as integer
	set mm to text -2 thru -1 of ("0" & m)
	set dd to text -2 thru -1 of ("0" & d)
	return (y as string) & "-" & mm & "-" & dd
end formatDate

-- ---------------------------------------------------------------------
-- trimWhitespace(t) -> string with leading/trailing spaces, tabs,
-- returns and newlines removed.
-- ---------------------------------------------------------------------
on trimWhitespace(t)
	set t to t as string
	set wsChars to {" ", tab, return, linefeed}
	-- strip leading
	repeat while (length of t) > 0 and (character 1 of t) is in wsChars
		if (length of t) is 1 then
			set t to ""
		else
			set t to text 2 thru -1 of t
		end if
	end repeat
	-- strip trailing
	repeat while (length of t) > 0 and (character -1 of t) is in wsChars
		if (length of t) is 1 then
			set t to ""
		else
			set t to text 1 thru -2 of t
		end if
	end repeat
	return t
end trimWhitespace
