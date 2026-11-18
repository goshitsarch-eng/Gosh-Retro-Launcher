class_name MacFolderWindow
extends MacWindow
## A folder window: Launcher HD ("computer", lists the groups as folders) or one group ("g:<id>", lists its
## items). Chrome + info bar + framed content (MacFolderView).

var view: MacFolderView


func _init() -> void:
	super._init()
	view = MacFolderView.new()
	view.win = self
	add_child(view)


func _on_state_synced(st: Dictionary) -> void:
	view.visible = not st.shaded
	if st.shaded:
		return
	var c := chrome()
	var content: Rect2 = c.content.grow(-1)
	view.position = content.position
	view.size = content.size
	view.queue_redraw()


func _draw_body(c: Dictionary, _st: Dictionary) -> void:
	var info: Rect2 = c.info
	var fill := MacTheme.b("eeeeee")
	draw_rect(info, fill)
	Px.hline(self, info.position.x, info.position.y, info.size.x, MacTheme.b("888888"))
	Px.vline(self, info.position.x, info.position.y, info.size.y, MacTheme.b("888888"))
	Px.vline(self, info.end.x - 1, info.position.y, info.size.y, MacTheme.b("888888"))
	Px.hline(self, info.position.x + 1, info.position.y + 1, info.size.x - 2, MacTheme.s("ffffff"))
	Px.vline(self, info.position.x + 1, info.position.y + 1, info.size.y - 1, MacTheme.s("ffffff"))
	var programs: int = MacDialogLogic.count_items(ProgramStore.groups).programs
	var line := MacDialogLogic.info_line(view.entries().size(), programs, key == "computer")
	var w := MacDraw.measure(line)
	MacDraw.text_centered_y(self, info.position.x + floorf((info.size.x - w) / 2.0), info.position.y, info.size.y, line, MacTheme.t("000000"))
	Px.outline(self, (c.content as Rect2), MacTheme.b("888888"))
