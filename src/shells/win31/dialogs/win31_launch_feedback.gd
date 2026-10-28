class_name Win31LaunchFeedback
extends Control
## Batch-launch progress toast (port of components/LaunchFeedback.tsx + .launch-feedback CSS),
## driven by UIState.launch_feedback. Bottom-right, 12px from the edges, never takes input.
## Mounted full-rect above the shell by Win31Shell.

const MIN_W := 260
const MAX_W := 360
const MARGIN := 12
const PAD := 8
const ICON := 28
const METER_H := 12


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false


func _ready() -> void:
	UIState.launch_feedback_changed.connect(_sync)
	resized.connect(queue_redraw)
	_sync()


func _sync() -> void:
	visible = bool(UIState.launch_feedback.get("visible", false))
	queue_redraw()


## {rect, title, detail, icon, progress, status} of the toast for the current state (no drawing).
func layout(fb: Dictionary = UIState.launch_feedback) -> Dictionary:
	var title := W31DialogLogic.feedback_status_text(fb)
	var detail := W31DialogLogic.feedback_detail_text(fb)
	var f := W31.font()
	var text_w := maxi(f.measure(title), f.measure(detail))
	var w := clampi(2 + 2 * PAD + ICON + 8 + text_w, MIN_W, mini(MAX_W, int(size.x) - 2 * MARGIN))
	var h := 2 + 2 * PAD + (13 + 2 + 13 + 6 + METER_H)
	var rect := Rect2(size.x - MARGIN - w, size.y - MARGIN - h, w, h)
	return {"rect": rect, "title": title, "detail": detail, "icon": W31DialogLogic.feedback_icon_text(fb),
		"progress": W31DialogLogic.feedback_progress(fb), "status": fb.get("status", "idle")}


func _draw() -> void:
	var fb: Dictionary = UIState.launch_feedback
	if not fb.get("visible", false):
		return
	var l := layout(fb)
	var r: Rect2 = l.rect
	Px.fill_rect(self, r, W31.FACE)
	Px.outline(self, r, W31.BLACK)
	Px.hline(self, r.position.x + 1, r.position.y + 1, r.size.x - 2, W31.WHITE)
	Px.vline(self, r.position.x + 1, r.position.y + 1, r.size.y - 2, W31.WHITE)
	Px.hline(self, r.position.x + 1, r.end.y - 2, r.size.x - 2, W31.SHADOW)
	Px.vline(self, r.end.x - 2, r.position.y + 1, r.size.y - 2, W31.SHADOW)
	var x := r.position.x + 1 + PAD
	var y := r.position.y + 1 + PAD
	var icon_rect := Rect2(x, y, ICON, ICON)
	Px.fill_rect(self, icon_rect, W31.MAROON if l.status == "error" else W31.NAVY)
	Px.outline(self, icon_rect, W31.BLACK)
	var icon_text: String = l.icon
	var iw := W31.text_w(icon_text, 12, true)
	W31.text(self, x + floorf((ICON - iw) / 2.0), y + 7, icon_text, W31.WHITE, 12, {"bold": true, "line_height": 13})
	var bx := x + ICON + 8
	var bw := r.end.x - 1 - PAD - bx
	var f := W31.font()
	f.draw(self, Vector2(bx, y), f.clip(l.title, int(bw)), W31.BLACK)
	f.draw(self, Vector2(bx, y + 15), f.clip(l.detail, int(bw)), W31.SHADOW)
	var meter := Rect2(bx, y + 15 + 13 + 6, bw, METER_H)
	Px.fill_rect(self, meter, W31.WHITE)
	W31.border2(self, meter, W31.SHADOW, W31.WHITE)
	var inner := meter.grow(-1)
	var fill_w := floorf(inner.size.x * float(l.progress) / 100.0)
	if fill_w > 0:
		Px.fill(self, inner.position.x, inner.position.y, fill_w, inner.size.y, W31.NAVY)
		var stripe := W31.NAVY.lerp(Color.WHITE, 0.35)
		var sx := 4.0
		while sx < fill_w:
			Px.fill(self, inner.position.x + sx, inner.position.y, minf(4.0, fill_w - sx), inner.size.y, stripe)
			sx += 8.0
