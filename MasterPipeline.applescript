(*
=====================================================================
  MasterPipeline.applescript
  Runs the whole toolchain IN ORDER, one click:

      Stage 1  ContactImporter.applescript   → reads EVERY file in the
               "recipients" folder, builds the Contacts group
               Automation_List_<today>, and hands the group name off.
      Stage 2  MassMessageSender.applescript → loops that group via the
               Messages app and sends your message, one contact at a
               time, fully automatic.

  Keep this file in the SAME FOLDER as the two scripts above, with the
  "recipients" folder alongside it.

  -----------------------------------------------------------------
  PERMISSIONS: Contacts + Automation (Contacts, Messages) for the app
  you run this from, and Messages signed in.
  -----------------------------------------------------------------
  ⚠️  Stage 2 sends REAL messages (it asks you to confirm first).
=====================================================================
*)

set stageNames to {"ContactImporter.applescript", "MassMessageSender.applescript"}
set stageLabels to {"Stage 1 — import every recipient file into a dated group", ¬
	"Stage 2 — send the message to that group via Messages"}

-- ---------------------------------------------------------------------
-- Locate the folder that holds the two scripts: prefer the folder this
-- file lives in; otherwise ask.
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
	set chosen to (choose folder with prompt "Select the folder containing the .applescript files:")
	set scriptFolder to POSIX path of chosen
end if

-- ---------------------------------------------------------------------
-- Confirm the plan, then run each stage in order.
-- ---------------------------------------------------------------------
set confirm to button returned of (display dialog ¬
	"Master pipeline will run, in order:" & return & return & ¬
	"    1. " & item 1 of stageLabels & return & ¬
	"    2. " & item 2 of stageLabels & return & return & ¬
	"Stage 2 sends real messages (it asks to confirm first)." ¬
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
			"Keep both scripts in the same folder as this pipeline." ¬
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
			stageLabel & " failed:" & return & return & errMsg & return & return & ¬
			"Continue with the remaining stages anyway?" ¬
			buttons {"Stop Pipeline", "Continue"} default button "Stop Pipeline" with icon caution)
		if choice is "Stop Pipeline" then return
	end try

	delay 1 -- small breather between stages
end repeat

display dialog "Master pipeline finished both stages." & return & return & ¬
	"Check the Stage 2 summary for the send results." ¬
	buttons {"Done"} default button "Done" with icon note
