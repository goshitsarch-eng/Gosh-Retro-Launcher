class_name Win95LaunchProgress
extends RefCounted
## The progress window a batch launch (Start > Programs > Launch Groups, the Launch Groups manager)
## shows while it runs, modelled on the Windows 95 file-copy progress dialog: the caption names the
## launch group ("Launching Group 1: Morning"), the item being started sits beside its icon
## ("Starting Notepad..."), a segmented blue progress bar and "3 of 5" follow, and Cancel stops the
## items not started yet. Win95Shell.launch_buckets drives it (texts from Win95LaunchGroupLogic).
##   var p := Win95LaunchProgress.open(shell, total)
##   p.show_step(step, title)   # before each item; p.set_done(n) after it; p.cancelled; p.close()
## Automation: w95.launch-progress (frame), w95.launch-progress.text, w95.launch-progress.count,
## w95.launch-progress.bar, w95.dialog.button:Cancel.

const SIZE := Vector2(330, 133)
const CX := 9.0
const CY := 10.0

var modal: Win95Modal
var icon: Win95IconBox
var line: Win95Label
var count: Win95Label
var bar: Win95ProgressBar
var cancel_button: Win95Button
var cancelled := false
var total := 0


static func open(shell: Control, p_total: int, p_title: String = "Launching") -> Win95LaunchProgress:
	var p := Win95LaunchProgress.new()
	p.total = p_total
	p._build(shell, p_title)
	return p


func _build(shell: Control, p_title: String) -> void:
	modal = Win95Modal.open(shell, p_title, SIZE)
	modal.set_meta("auto_id", "w95.launch-progress")
	var cw: float = modal.body.size.x - CX * 2
	icon = Win95IconBox.make("application", Vector2.ZERO)
	modal.add(icon, Vector2(CX, CY))
	line = Win95Label.make("", Vector2.ZERO, {"show_access": false, "max_width": int(cw) - 42})
	modal.add(line, Vector2(CX + 42, CY + 10))
	_auto(line, "w95.launch-progress.text")
	bar = Win95ProgressBar.new()
	modal.add(bar, Vector2(CX, CY + 42))
	bar.size = Vector2(cw, 16)
	_auto(bar, "w95.launch-progress.bar")
	cancel_button = Win95Button.new()
	cancel_button.label = "Cancel"
	var row_y := CY + 42 + 16 + 8
	modal.add(cancel_button, Vector2(modal.body.size.x - CX - cancel_button.size.x, row_y))
	count = Win95Label.make("", Vector2.ZERO, {"show_access": false})
	modal.add(count, Vector2(CX, row_y + 5))
	_auto(count, "w95.launch-progress.count")
	modal.set_default(cancel_button)
	cancel_button.pressed.connect(cancel)
	modal.on_cancel = cancel
	set_done(0)


static func _auto(c: Control, id: String) -> void:
	c.set_meta("auto_id", id)
	c.add_to_group("pm_auto")


func is_open() -> bool:
	return modal != null and is_instance_valid(modal) and not modal.is_queued_for_deletion()


## Shows the item of Win95LaunchGroupLogic.batch_steps() step `step` under the caption `title`.
func show_step(step: Dictionary, title: String) -> void:
	if not is_open():
		return
	if modal.title != title:
		modal.title = title
		modal.queue_redraw()
	icon.icon = String(step.item.get("icon", "application"))
	line.text = Win95LaunchGroupLogic.escape(Win95LaunchGroupLogic.progress_line(step.item))
	count.text = Win95LaunchGroupLogic.progress_count(int(step.index), total)


func set_done(done: int) -> void:
	if is_open():
		bar.set_progress(done, total)


## Cancel / Esc: the items not started yet are skipped; the window stays until the batch loop ends.
func cancel() -> void:
	if cancelled:
		return
	cancelled = true
	if is_open():
		cancel_button.disabled = true
		line.text = "Canceling..."


func close() -> void:
	if is_open():
		modal.close()
