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

	-- Click "Add Filter", then "Choose", then the group row in the popover.
	-- Uses deepClick(): a DEEP search of the whole accessibility tree —
	-- earlier versions only searched the top level of the process, which
	-- is why they failed with "Invalid index" even though the button is
	-- always visibly there. Deep search is slower (a few seconds per
	-- click) but actually reaches nested SwiftUI controls.
	try
		my ensureShortcutsFocus()
		my deepClick("Add Filter", uiDelay)
		delay uiDelay
		-- The filter row reads:  Group  is  Choose  → open the picker.
		my deepClick("Choose", uiDelay)
		delay uiDelay
		-- In the picker's sidebar, click our group (full name first, then
		-- a prefix match in case the accessibility label is truncated).
		try
			my deepClick(groupName, uiDelay)
		on error
			my deepClick("Automation_List", uiDelay)
		end try
		delay uiDelay
		tell application "System Events" to key code 53 -- Escape closes the popover, keeping the selection
		delay uiDelay
	on error innerMsg
		-- Non-fatal: finish this one field by hand if the tree hides it.
		display dialog "Heads up: couldn't auto-set the Contacts filter to \"" & groupName & "\". " & ¬
			"Add it by hand: Find Contacts → Add Filter → Group is → Choose → pick the group." & return & return & ¬
			"(" & innerMsg & ")" buttons {"Continue"} default button "Continue" with icon caution
	end try
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
			my ensureShortcutsFocus()
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
				my ensureShortcutsFocus()
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
--  STEP 7b — Bind Recipients to the "Repeat Item" loop variable via the
--  CONTEXT MENU (the menu you get when you Control-click the Recipients
--  pill: Select Variable / Ask Each Time / … / Repeat Item / Clear).
--  Programmatically, Control-click = the accessibility action
--  "AXShowMenu" on the element; the entries are ordinary menu items,
--  which are far more reliable to click than the contact picker.
--  Result: each loop pass sends to the CURRENT contact — the correct
--  wiring for send-to-everyone-one-at-a-time.
-- =====================================================================
try
	my ensureShortcutsFocus()
	set recipElem to my deepFind("Recipients")
	tell application "System Events"
		perform action "AXShowMenu" of recipElem -- open the Control-click menu
	end tell
	delay (uiDelay * 2) -- give the menu time to appear
	-- Attempt 1: the menu attaches directly to the element in the AX tree.
	set pickedItem to false
	tell application "System Events"
		tell process "Shortcuts"
			try
				click menu item "Repeat Item" of menu 1 of recipElem
				set pickedItem to true
			end try
		end tell
	end tell
	-- Attempt 2 (the one that usually works): the menu is open but macOS
	-- doesn't expose it inside any window, so no element search can see
	-- it. Open menus respond to TYPE-SELECT: typing an item's name
	-- highlights it, Return activates it. We type the full "Repeat Item"
	-- so it can't stop early on "Repeat Index".
	if not pickedItem then
		tell application "System Events"
			tell process "Shortcuts"
				keystroke "Repeat Item"
				delay 0.5
				keystroke return
			end tell
		end tell
	end if
	delay uiDelay
on error innerMsg
	display dialog "Couldn't auto-bind Recipients to Repeat Item. Do it by hand: " & ¬
		"Control-click the Recipients pill in Send Message and choose \"Repeat Item\" " & ¬
		"from the menu." & return & return & "(" & innerMsg & ")" ¬
		buttons {"Continue"} default button "Continue" with icon caution
end try


-- =====================================================================
--  STEP 8 — Name the shortcut (SAFE method — no blind typing)
--
--  ⚠️ Lesson learned: an earlier version pressed Cmd+A and typed the
--  name after Cmd+S. When focus fell back to Script Editor, that
--  keystroke sequence overwrote the script's own source file. So now:
--    • We NEVER type unless we have verified, via accessibility, that
--      a Shortcuts rename field is focused.
--    • Renaming is done by setting the title text field's value
--      directly (no keystrokes at all) when possible.
--  Shortcuts auto-saves continuously, so no Cmd+S is needed at all.
-- =====================================================================
try
	tell application "System Events"
		tell process "Shortcuts"
			my ensureShortcutsFocus()
			set renamed to false
			-- Attempt 1: set the editor window's title text field directly.
			try
				set value of (first text field of window 1) to shortcutName
				set renamed to true
			end try
			delay uiDelay
		end tell
	end tell
	if not renamed then
		display dialog "Couldn't rename the shortcut automatically. In Shortcuts, " & ¬
			"click the title at the top of the editor window and name it:" & return & return & ¬
			"    " & shortcutName ¬
			buttons {"OK"} default button "OK" with icon caution
	end if
on error errMsg
	my failStep("Step 8 – naming the shortcut", errMsg)
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
			my ensureShortcutsFocus() -- refuse to type if Shortcuts isn't frontmost
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
-- reorderUp(actionName, moveCount, pauseSec)
-- BEST-EFFORT reorder. Tries to select the named action's row, then
-- presses Cmd+Ctrl+Up `moveCount` times. Silently tolerates failure
-- because Shortcuts frequently ignores this. Swap the key combo below
-- if needed. (NOTE: don't rename moveCount to "times" — that word is
-- part of AppleScript's `repeat n times` syntax and won't compile.)
-- ---------------------------------------------------------------------
on reorderUp(actionName, moveCount, pauseSec)
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
			repeat moveCount times
				try
					my ensureShortcutsFocus()
					-- Cmd+Ctrl+Up : honoured by some builds; harmless otherwise.
					key code 126 using {command down, control down}
				end try
				delay pauseSec
			end repeat
		end tell
	end tell
end reorderUp

-- ---------------------------------------------------------------------
-- deepFind(targetText)
-- Searches EVERY UI element in EVERY window of the Shortcuts process
-- (name, description, and value) for one containing targetText.
-- This is what earlier versions got wrong: they queried only the top
-- level of the process, so nested SwiftUI controls were never found.
-- `entire contents` is slow — expect a few seconds per lookup.
-- ---------------------------------------------------------------------
on deepFind(targetText)
	tell application "System Events"
		tell process "Shortcuts"
			repeat with w in windows
				set elems to {}
				try
					-- HARD TIMEOUT: with the action library open this crawl
					-- can hang for minutes; give up on this window after 25s
					-- and fall through to the failure dialog instead.
					with timeout of 25 seconds
						set elems to entire contents of w
					end timeout
				end try
				repeat with e in elems
					try
						set n to ""
						try
							set n to (name of e) as string
						end try
						if n contains targetText then return (contents of e)
						set d to ""
						try
							set d to (description of e) as string
						end try
						if d contains targetText then return (contents of e)
						set v to ""
						try
							set v to (value of e) as string
						end try
						if v contains targetText then return (contents of e)
					end try
				end repeat
			end repeat
		end tell
	end tell
	error "No UI element matching \"" & targetText & "\" found in any Shortcuts window."
end deepFind

-- ---------------------------------------------------------------------
-- deepClick(targetText, pauseSec)
-- deepFind + click (falling back to the AXPress accessibility action,
-- which works on elements that don't respond to a plain click).
-- ---------------------------------------------------------------------
on deepClick(targetText, pauseSec)
	set theElem to my deepFind(targetText)
	tell application "System Events"
		try
			click theElem
		on error
			perform action "AXPress" of theElem
		end try
	end tell
	delay pauseSec
end deepClick

-- ---------------------------------------------------------------------
-- ensureShortcutsFocus()
-- SAFETY GUARD: raises an error unless Shortcuts is genuinely the
-- frontmost app. Every keystroke in this script goes to whichever app
-- has focus — this guard is what prevents stray typing from landing in
-- Script Editor (which once overwrote this very script's source file).
-- Never remove it.
-- ---------------------------------------------------------------------
on ensureShortcutsFocus()
	tell application "System Events"
		set frontApp to name of first process whose frontmost is true
		if frontApp is not "Shortcuts" then
			tell process "Shortcuts" to set frontmost to true
			delay 0.5
			set frontApp to name of first process whose frontmost is true
			if frontApp is not "Shortcuts" then
				error "Shortcuts lost focus (frontmost app is \"" & frontApp & ¬
					"\"). Aborting this step so keystrokes don't land in the wrong app."
			end if
		end if
	end tell
end ensureShortcutsFocus

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
