# GUI Verification Protocol (tkinter)

WSL2 cannot run tkinter GUIs for live verification. Compensate with the following protocol (karo + gunshi + ashigaru involvement):

1. **gui_review_required: true** (task YAML): Gunshi reviews frame design before implementation
2. **manual_verification_required: true** (task YAML): Register Lord's hands-on verification as a dashboard [action] item
3. **py_compile static check** (ashigaru): Detect import errors and syntax errors in advance
4. **Manual verification request** (dashboard): Karo asks the Lord (via [action] tag) to verify the behavior on Windows

Note: Tasks with `gui_review_required: true` remain on the dashboard after completion until Karo deletes them manually.
