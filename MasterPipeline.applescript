-- =====================================================================
--  MasterPipeline.applescript
--
--  Runs the whole toolchain IN ORDER, one click:
--
--    Stage 1  ContactImporter.applescript   → choose contacts.csv; it
--             builds the Contacts group  Automation_List_<today>
--    Stage 2  MassMessageSetup.applescript  → builds the Shortcut in the
--             Shortcuts app, auto-clicking Add Filter → Group →
--             (your list), and Recipients → (your list) → first contact
--             → its mobile number, via deep accessibility search
--    Stage 3  MassMessageSender.applescript → the actual sending: loops
--             the whole group via the Messages app, one contact at a
--             time, fully automatic
--
--  Keep this file in the SAME FOLDER as the three scripts above.
--
--  ------------------------------------------------------------------
--  PERMISSIONS: same as the individual scripts —
--  Accessibility + Contacts + Automation (Contacts, Messages, Shortcuts,
--  System Events) for the app you run this from, Messages signed in.
--  ------------------------------------------------------------------
--  ⚠️ Stage 2 drives the Shortcuts app UI: DO NOT touch the keyboard
--     or mouse while it runs. Stage 3 sends REAL messages.
-- =====================================================================

set stageNames to {"ContactImporter.applescript", "MassMessageSetup.applescript", "MassMessageSender.applescript"}
set stageLabels to {"Stage 1 — import contacts into a dated group", ¬
	"Stage 2 — build the Shortcut (hands off the keyboard!)", ¬
	"Stage 3 — send the messages via Messages"}

-- ---------------------------------------------------------------------
-- Locate the folder that holds the three scripts: prefer the folder
-- this file lives in; otherwise ask.
-- ---------------------------------------------------------------------
set scriptFolder to ""
try
	set myPosix to POSIX path of (path to me)
	if myPosix ends with "/" then set myPosix to text 1 thru -2 of myPosix
	set AppleScript's text item delimiters to "/"
	set parts to text items of myPosix
	set parts to items 1 thru -2 of parts
	set scriptFolder to (parts as text) & "/"
	set AppleScript's text item delimiters to ""
end try
set folderOK to false
if scriptFolder is not "" then
	try
		do shell script "test -f " & quoted form of (scriptFolder & (item 1 of stageNames))
		set folderOK to true
	end try
end if
if not folderOK then
	set chosen to (choose folder with prompt "Select the folder containing the three .applescript files:")
	set scriptFolder to POSIX path of chosen
end if

-- ---------------------------------------------------------------------
-- Confirm the plan, then run each stage in order.
-- ---------------------------------------------------------------------
set confirm to button returned of (display dialog ¬
	"Master pipeline will run, in order:" & return & return & ¬
	"  1. " & item 1 of stageLabels & return & ¬
	"  2. " & item 2 of stageLabels & return & ¬
	"  3. " & item 3 of stageLabels & return & return & ¬
	"During Stage 2, don't touch the keyboard or mouse." & return & ¬
	"Stage 3 sends real messages (it asks to confirm first)." ¬
	buttons {"Cancel", "Start"} default button "Start" with icon caution)
if confirm is not "Start" then return

repeat with i from 1 to (count of stageNames)
	set stageFile to scriptFolder & (item i of stageNames)
	set stageLabel to item i of stageLabels

	-- Make sure the stage's script actually exists before running it.
	try
		do shell script "test -f " & quoted form of stageFile
	on error
		display dialog "Missing file:" & return & stageFile & return & return & ¬
			"Keep all three scripts in the same folder as this pipeline." ¬
			buttons {"OK"} default button "OK" with icon stop
		return
	end try

	try
		-- `run script` compiles and executes the stage inside this same
		-- process, so all permission grants apply to the host app once.
		run script (POSIX file stageFile)
	on error errMsg number errNum
		if errNum is -128 then
			-- User pressed Cancel inside a stage → stop the pipeline quietly.
			display dialog "Pipeline stopped at:" & return & stageLabel ¬
				buttons {"OK"} default button "OK" with icon caution
			return
		end if
		set choice to button returned of (display dialog ¬
			"❌ " & stageLabel & " failed:" & return & return & errMsg & return & return & ¬
			"Continue with the remaining stages anyway?" ¬
			buttons {"Stop Pipeline", "Continue"} default button "Stop Pipeline" with icon caution)
		if choice is "Stop Pipeline" then return
	end try

	delay 1 -- small breather between stages
end repeat

display dialog "✅ Master pipeline finished all three stages." & return & return & ¬
	"Check the Stage 3 summary for the send results." ¬
	buttons {"Done"} default button "Done" with icon note
