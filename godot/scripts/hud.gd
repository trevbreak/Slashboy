class_name HUD
extends CanvasLayer
## Visor HUD and menus, built in code.

const CYAN := Color(0.435, 0.953, 1.0)
const CYAN_DIM := Color(0.435, 0.953, 1.0, 0.35)
const AMBER := Color(1.0, 0.71, 0.28)
const RED := Color(1.0, 0.23, 0.31)
const KI := Color(0.725, 0.55, 1.0)

var mono: Font
var light: Font
var bold: Font
var root: Control
var hud: Control
var overlay: Control
var frame: Control
var hp_num: Label
var hp_fill: ColorRect
var hp_ghost: ColorRect
var ki_fill: ColorRect
var threat_fill: ColorRect
var mode_label: Label
var area_label: Label
var timer_label: Label
var area_sub: Label
var msg_label: Label
var hint_label: RichTextLabel
var scan_prog: Control
var scan_fill: ColorRect
var scan_panel: PanelContainer
var scan_title: Label
var scan_text: Label
var boss_box: Control
var boss_name: Label
var boss_fill: ColorRect
var boss_enemy = null
var title_screen: Control
var pause_screen: Control
var death_screen: Control
var end_screen: Control
var end_stats: Label
var end_title: Label
var end_body: Label
var continue_btn: Button
var ability_panel: PanelContainer
var ability_title: Label
var ability_text: Label
var ability_t := 0.0
var map_view: Control
var map_open := false
var msg_t := 0.0
var hint_t := 0.0
var area_t := 0.0
var damage_v := 0.0
var hit_t := 0.0
var ghost_hp := 1.0
var shown := false


func _ready() -> void:
	layer = 3
	mono = load("res://assets/fonts/ShareTechMono-Regular.ttf")
	light = load("res://assets/fonts/Rajdhani-Light.ttf")
	bold = load("res://assets/fonts/Rajdhani-Bold.ttf")
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_hud()
	_build_menus()


func _label(text: String, font: Font, size: int, col: Color, parent: Node) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _wide(c: Control, top: float, h: float) -> void:
	c.anchor_left = 0.0; c.anchor_right = 1.0; c.anchor_top = 0.0; c.anchor_bottom = 0.0
	c.offset_left = 0.0; c.offset_right = 0.0; c.offset_top = top; c.offset_bottom = top + h


func _bar(parent: Control, pos: Vector2, size: Vector2, col: Color, anchor_right := false) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(col.r, col.g, col.b, 0.1)
	bg.position = pos
	bg.size = size
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.color = col
	fill.size = size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.add_child(fill)
	return fill


func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.visible = false
	root.add_child(hud)
	frame = Control.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.draw.connect(_draw_frame)
	hud.add_child(frame)
	# vitals (top-left)
	var vit := Control.new()
	vit.position = Vector2(96, 48)
	vit.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(vit)
	_label("E N E R G Y", mono, 12, Color(CYAN, 0.7), vit)
	hp_num = _label("100", light, 46, CYAN, vit)
	hp_num.position = Vector2(0, 12)
	hp_ghost = _bar(vit, Vector2(0, 70), Vector2(280, 6), Color(1, 1, 1, 0.35))
	hp_fill = _bar(vit, Vector2(0, 70), Vector2(280, 6), CYAN)
	hp_ghost.get_parent().color = Color(0, 0, 0, 0)
	var kl := _label("K I", mono, 12, Color(CYAN, 0.7), vit)
	kl.position = Vector2(0, 84)
	ki_fill = _bar(vit, Vector2(0, 104), Vector2(196, 4), KI)
	# threat (top-right)
	var thr := Control.new()
	thr.anchor_left = 1.0; thr.anchor_right = 1.0
	thr.offset_left = -276; thr.offset_top = 48
	thr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(thr)
	var tl := _label("T H R E A T", mono, 12, Color(1, 0.54, 0.48), thr)
	tl.position = Vector2(84, 0)
	threat_fill = _bar(thr, Vector2(0, 22), Vector2(180, 4), RED)
	mode_label = _label("COMBAT VISOR", mono, 12, Color(CYAN, 0.55), hud)
	mode_label.anchor_left = 1.0; mode_label.anchor_right = 1.0; mode_label.anchor_top = 1.0; mode_label.anchor_bottom = 1.0
	mode_label.offset_left = -300; mode_label.offset_right = -96; mode_label.offset_top = -70; mode_label.offset_bottom = -50
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# overlay: reticle, lock, charge ring, scan markers (drawn every frame)
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	hud.add_child(overlay)
	# area title
	area_label = _label("", light, 36, CYAN, hud)
	_wide(area_label, 190, 50)
	area_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	area_label.modulate.a = 0.0
	area_sub = _label("", mono, 12, Color(CYAN, 0.6), area_label)
	_wide(area_sub, 52, 20)
	area_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label = _label("", light, 30, RED, hud)
	_wide(timer_label, 140, 40)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_label.visible = false
	msg_label = _label("", mono, 15, CYAN, hud)
	_wide(msg_label, 300, 24)
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.modulate.a = 0.0
	hint_label = RichTextLabel.new()
	hint_label.bbcode_enabled = true
	hint_label.fit_content = true
	hint_label.scroll_active = false
	hint_label.add_theme_font_override("normal_font", mono)
	hint_label.add_theme_font_override("bold_font", mono)
	hint_label.add_theme_font_size_override("normal_font_size", 13)
	hint_label.add_theme_font_size_override("bold_font_size", 13)
	hint_label.add_theme_color_override("default_color", Color(0.78, 0.98, 1.0, 0.9))
	hint_label.anchor_left = 0.0; hint_label.anchor_right = 1.0; hint_label.anchor_top = 1.0; hint_label.anchor_bottom = 1.0
	hint_label.offset_top = -90; hint_label.offset_bottom = -60
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.modulate.a = 0.0
	hud.add_child(hint_label)
	# scan progress + panel
	scan_prog = Control.new()
	scan_prog.anchor_left = 0.5; scan_prog.anchor_right = 0.5; scan_prog.anchor_top = 0.5; scan_prog.anchor_bottom = 0.5
	scan_prog.offset_left = -110; scan_prog.offset_top = 70
	scan_prog.visible = false
	scan_prog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(scan_prog)
	scan_fill = _bar(scan_prog, Vector2.ZERO, Vector2(220, 3), AMBER)
	var sl := _label("S C A N N I N G", mono, 11, AMBER, scan_prog)
	sl.position = Vector2(50, 8)
	scan_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.05, 0.0, 0.85)
	sb.border_color = Color(AMBER, 0.6)
	sb.set_border_width_all(1)
	sb.content_margin_left = 22; sb.content_margin_right = 22; sb.content_margin_top = 18; sb.content_margin_bottom = 18
	scan_panel.add_theme_stylebox_override("panel", sb)
	scan_panel.custom_minimum_size = Vector2(640, 0)
	scan_panel.anchor_left = 0.5; scan_panel.anchor_right = 0.5; scan_panel.anchor_top = 1.0; scan_panel.anchor_bottom = 1.0
	scan_panel.offset_left = -320; scan_panel.offset_right = 320; scan_panel.offset_top = -330; scan_panel.offset_bottom = -110
	scan_panel.visible = false
	scan_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(scan_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	scan_panel.add_child(vb)
	scan_title = _label("", mono, 14, AMBER, vb)
	scan_text = _label("", mono, 16, Color(1.0, 0.85, 0.63), vb)
	scan_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	scan_text.custom_minimum_size = Vector2(596, 0)
	_label("[E] CLOSE VISOR  ·  [LMB] CONTINUE", mono, 10, Color(1.0, 0.85, 0.63, 0.55), vb)
	# boss bar
	boss_box = Control.new()
	boss_box.anchor_left = 0.5; boss_box.anchor_right = 0.5
	boss_box.offset_left = -260; boss_box.offset_top = 100
	boss_box.visible = false
	boss_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(boss_box)
	boss_name = _label("", mono, 13, Color(0.92, 0.92, 1.0), boss_box)
	boss_name.size.x = 520
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_fill = _bar(boss_box, Vector2(0, 24), Vector2(520, 5), Color(0.92, 0.88, 1.0))


func _overlay_screen(bg: Color) -> Control:
	var c := ColorRect.new()
	c.color = bg
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.visible = false
	root.add_child(c)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.add_child(center)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 14)
	center.add_child(vb)
	c.set_meta("box", vb)
	return c


func _build_menus() -> void:
	title_screen = _overlay_screen(Color(0.0, 0.02, 0.035, 1.0))
	var tb: VBoxContainer = title_screen.get_meta("box")
	var pre := _label("KUROGANE-9 ORBITAL ARCOLOGY  ·  SIGNAL LOST 41:12:07", mono, 12, Color(CYAN, 0.5), tb)
	pre.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := _label("SLASHBOY", bold, 132, Color(0.87, 0.98, 1.0), tb)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := _label("a  kage-class  operative  is  inbound", mono, 14, Color(CYAN, 0.6), tb)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var btn := _menu_button("N E W   G A M E", func(): G.main.start_game(false))
	continue_btn = _menu_button("C O N T I N U E", func(): G.main.start_game(true))
	tb.add_child(continue_btn)
	tb.add_child(btn)
	var spacer := Control.new(); spacer.custom_minimum_size = Vector2(0, 6); tb.add_child(spacer)
	var grid := GridContainer.new()

	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tb.add_child(grid)
	for row in [["WASD", "move"], ["MOUSE", "look"], ["LMB", "strike · combo"], ["HOLD LMB", "arc wave"], ["RMB", "guard · time it to deflect"], ["SHIFT", "phantom dash"],
			["SPACE", "jump"], ["Q", "lock-on"], ["E", "scan visor"], ["R", "kage focus"], ["F", "grapple (once found)"], ["M", "sector map"], ["G", "graphics preset"], ["F11", "fullscreen"]]:
		var l := _label("%-10s %s" % [row[0], row[1]], mono, 13, Color(1, 1, 1, 0.6), grid)
	var note := _label("Headphones strongly recommended. Play in the dark.", mono, 11, Color(CYAN, 0.4), tb)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_screen.visible = true

	pause_screen = _overlay_screen(Color(0, 0, 0, 0.6))
	var pb: VBoxContainer = pause_screen.get_meta("box")
	_label("P A U S E D", light, 34, CYAN, pb).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("click to resume  ·  esc to release mouse", mono, 13, Color(CYAN, 0.7), pb).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_screen.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed:
			G.main.resume_game())

	death_screen = _overlay_screen(Color(0.12, 0, 0.015, 0.7))
	var db: VBoxContainer = death_screen.get_meta("box")
	_label("S I G N A L   T E R M I N A T E D", light, 34, RED, db).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("reconstituting at last checkpoint...", mono, 13, Color(RED, 0.7), db).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	death_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE

	end_screen = _overlay_screen(Color(0, 0, 0, 1))
	var eb: VBoxContainer = end_screen.get_meta("box")
	end_title = _label("", light, 34, CYAN, eb)
	end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body = _label("", mono, 14, Color(CYAN, 0.75), eb)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_stats = _label("", mono, 12, Color(CYAN, 0.5), eb)
	end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var credits := _label("SLASHBOY  ·  thank you for playing", mono, 11, Color(CYAN, 0.35), eb)
	credits.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# ability acquired panel
	ability_panel = PanelContainer.new()
	var asb := StyleBoxFlat.new()
	asb.bg_color = Color(0.02, 0.05, 0.07, 0.92)
	asb.border_color = Color(1.0, 0.75, 0.3, 0.8)
	asb.set_border_width_all(1)
	asb.content_margin_left = 30; asb.content_margin_right = 30; asb.content_margin_top = 24; asb.content_margin_bottom = 24
	ability_panel.add_theme_stylebox_override("panel", asb)
	ability_panel.anchor_left = 0.5; ability_panel.anchor_right = 0.5; ability_panel.anchor_top = 0.5; ability_panel.anchor_bottom = 0.5
	ability_panel.offset_left = -330; ability_panel.offset_right = 330; ability_panel.offset_top = -120; ability_panel.offset_bottom = 120
	ability_panel.visible = false
	ability_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ability_panel)
	var av := VBoxContainer.new()
	av.add_theme_constant_override("separation", 12)
	ability_panel.add_child(av)
	var ah := _label("A B I L I T Y   A C Q U I R E D", mono, 12, Color(1.0, 0.75, 0.3, 0.8), av)
	ah.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_title = _label("", light, 40, Color(1.0, 0.85, 0.55), av)
	ability_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_text = _label("", mono, 14, Color(1.0, 0.92, 0.8), av)
	ability_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ability_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_text.custom_minimum_size = Vector2(600, 0)

	# sector map
	map_view = Control.new()
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_view.visible = false
	map_view.draw.connect(_draw_map)
	root.add_child(map_view)


func _menu_button(text: String, fn: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_override("font", mono)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", CYAN)
	btn.add_theme_color_override("font_disabled_color", Color(CYAN, 0.25))
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color(0, 0, 0, 0)
	bs.border_color = CYAN
	bs.set_border_width_all(1)
	bs.content_margin_left = 34; bs.content_margin_right = 34; bs.content_margin_top = 12; bs.content_margin_bottom = 12
	var bh := bs.duplicate()
	bh.bg_color = Color(CYAN, 0.12)
	var bd := bs.duplicate()
	bd.border_color = Color(CYAN, 0.2)
	btn.add_theme_stylebox_override("normal", bs)
	btn.add_theme_stylebox_override("hover", bh)
	btn.add_theme_stylebox_override("pressed", bh)
	btn.add_theme_stylebox_override("focus", bh)
	btn.add_theme_stylebox_override("disabled", bd)
	btn.custom_minimum_size = Vector2(300, 0)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(fn)
	return btn


# ------------------------------------------------------------------ API
func set_continue(on: bool) -> void:
	continue_btn.disabled = not on
	continue_btn.visible = on


func ability_get(kind: String) -> void:
	var info: Dictionary = G.ABILITIES[kind]
	ability_title.text = "  ".join(String(info.name).split(""))
	ability_text.text = info.text
	ability_panel.visible = true
	ability_panel.modulate.a = 0.0
	create_tween().tween_property(ability_panel, "modulate:a", 1.0, 0.6)
	ability_t = 7.0


func toggle_map() -> void:
	map_open = not map_open
	map_view.visible = map_open
	map_view.queue_redraw()


func _draw_map() -> void:
	var L = G.level
	if L == null:
		return
	var s := map_view.size
	map_view.draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.02, 0.04, 0.82))
	var rooms: Array = L.map_rooms
	if rooms.is_empty():
		return
	var mn := Vector2(INF, INF); var mx := Vector2(-INF, -INF)
	for r in rooms:
		mn = Vector2(min(mn.x, r[0]), min(mn.y, r[1])); mx = Vector2(max(mx.x, r[2]), max(mx.y, r[3]))
	var area := Rect2(Vector2(s.x * 0.15, s.y * 0.14), Vector2(s.x * 0.7, s.y * 0.72))
	var k: float = min(area.size.x / max(1.0, mx.x - mn.x), area.size.y / max(1.0, mx.y - mn.y))
	var off := area.position + (area.size - (mx - mn) * k) / 2.0
	var to2d := func(x: float, z: float) -> Vector2: return off + (Vector2(x, z) - mn) * k
	var visited: Dictionary = G.progress.visited.get(L.sector_id + "_rooms", {})
	var p: Vector3 = G.player.global_position
	for i in rooms.size():
		var r: Array = rooms[i]
		var a: Vector2 = to2d.call(r[0], r[1]); var b: Vector2 = to2d.call(r[2], r[3])
		var seen: bool = visited.has(str(i))
		var inside: bool = p.x >= r[0] and p.x <= r[2] and p.z >= r[1] and p.z <= r[3] and abs(p.y - r[4]) < r[5] + 2.0
		var fill := Color(CYAN, 0.28 if inside else (0.1 if seen else 0.02))
		map_view.draw_rect(Rect2(a, b - a), fill)
		map_view.draw_rect(Rect2(a, b - a), Color(CYAN, 0.75 if seen else 0.18), false, 1.0)
	for sp in L.save_points:
		map_view.draw_circle(to2d.call(sp.pos.x, sp.pos.z), 5, Color(0.3, 1.0, 1.0))
	for e in L.elevators:
		map_view.draw_rect(Rect2(to2d.call(e.pos.x, e.pos.z) - Vector2(5, 5), Vector2(10, 10)), AMBER)
	for it in L.items:
		if not it.taken and visited.has(str(_room_index(rooms, it.pos))):
			map_view.draw_circle(to2d.call(it.pos.x, it.pos.z), 3.5, Color(1.0, 0.8, 0.4))
	var pp: Vector2 = to2d.call(p.x, p.z)
	var f := Vector2(-sin(G.player.yaw), -cos(G.player.yaw))
	map_view.draw_colored_polygon(PackedVector2Array([pp + f * 12, pp + f.orthogonal() * 6 - f * 5, pp - f.orthogonal() * 6 - f * 5]), Color.WHITE)
	var title := "%s  //  SECTOR MAP" % Sectors.NAMES.get(L.sector_id, "")
	map_view.draw_string(mono, Vector2(s.x * 0.15, s.y * 0.1), "  ".join(title.split("")), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, CYAN)
	var inv := "ENERGY TANKS %d  ·  KI SHARDS %d  ·  ITEMS %d/%d" % [G.progress.tanks, G.progress.shards, G.progress.tanks + G.progress.shards, Sectors.TOTAL_ITEMS]
	map_view.draw_string(mono, Vector2(s.x * 0.15, s.y * 0.92), inv, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(CYAN, 0.6))
	var abil := []
	for a in ["grapple", "phase", "leap"]:
		abil.append(G.ABILITIES[a].name if G.has_ability(a) else "------")
	map_view.draw_string(mono, Vector2(s.x * 0.15, s.y * 0.95), "  ·  ".join(abil), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(AMBER, 0.7))


static func _room_index(rooms: Array, p: Vector3) -> int:
	for i in rooms.size():
		var r: Array = rooms[i]
		if p.x >= r[0] and p.x <= r[2] and p.z >= r[1] and p.z <= r[3]:
			return i
	return -1


func show_hud() -> void:
	hud.visible = true
	title_screen.visible = false
	shown = true


func fade_to(v: float, seconds := 2.0) -> void:
	var tw := create_tween()
	tw.tween_property(G.main, "fade", v, seconds)


func area(title: String, sub: String) -> void:
	area_label.text = "  ".join(title.split(""))
	area_sub.text = "  ".join(sub.split(""))
	create_tween().tween_property(area_label, "modulate:a", 0.9, 1.2)
	area_t = 4.0


## Escape countdown (seconds); negative hides it.
func set_timer(t: float) -> void:
	timer_label.visible = t >= 0.0
	if t < 0.0:
		return
	var cs := int(t * 100.0) % 100
	timer_label.text = "%d:%02d.%02d" % [int(t) / 60, int(t) % 60, cs]
	timer_label.modulate.a = 1.0 if t > 30.0 else 0.55 + 0.45 * absf(sin(t * 6.0))


func message(text: String, seconds := 2.5, warn := false) -> void:
	msg_label.text = " ".join(text.split(""))
	msg_label.add_theme_color_override("font_color", RED if warn else CYAN)
	msg_label.modulate.a = 1.0
	msg_t = seconds


func hint(text: String, seconds := 5.0) -> void:
	hint_label.text = "[center]%s[/center]" % text
	create_tween().tween_property(hint_label, "modulate:a", 0.9, 0.8)
	hint_t = seconds


func damage(amount: float) -> void:
	damage_v = min(1.0, damage_v + amount / 30.0)


func hit_marker() -> void:
	hit_t = 0.12


func boss(enemy, name := "") -> void:
	boss_enemy = enemy
	boss_box.visible = enemy != null
	boss_name.text = "  ".join(name.split(""))


func open_scan(s: Dictionary) -> void:
	scan_title.text = s.title
	scan_text.text = s.text
	scan_panel.visible = true


func close_scan() -> void:
	scan_panel.visible = false


func set_screen(name: String, on: bool) -> void:
	var s: Control = {"pause": pause_screen, "death": death_screen, "end": end_screen, "title": title_screen}[name]
	s.visible = on


# ------------------------------------------------------------------ drawing
func _draw_frame() -> void:
	var s := frame.size
	var c := Color(CYAN, 0.32)
	var t := Color(CYAN, 0.12)
	var r := 150.0
	frame.draw_arc(Vector2(40 + r, 40 + r), r, PI, PI * 1.5, 24, c, 2.0)
	frame.draw_arc(Vector2(s.x - 40 - r, 40 + r), r, PI * 1.5, TAU, 24, c, 2.0)
	frame.draw_arc(Vector2(40 + r, s.y - 40 - r), r, PI * 0.5, PI, 24, c, 2.0)
	frame.draw_arc(Vector2(s.x - 40 - r, s.y - 40 - r), r, 0, PI * 0.5, 24, c, 2.0)
	frame.draw_line(Vector2(s.x * 0.19, 28), Vector2(s.x * 0.81, 28), t, 1.0)
	frame.draw_line(Vector2(s.x * 0.19, s.y - 28), Vector2(s.x * 0.39, s.y - 28), t, 1.0)
	frame.draw_line(Vector2(s.x * 0.61, s.y - 28), Vector2(s.x * 0.81, s.y - 28), t, 1.0)
	frame.draw_line(Vector2(18, s.y * 0.33), Vector2(18, s.y * 0.67), t, 1.0)
	frame.draw_line(Vector2(s.x - 18, s.y * 0.33), Vector2(s.x - 18, s.y * 0.67), t, 1.0)


func _project(p: Vector3):
	var cam := G.camera
	if cam.is_position_behind(p):
		return null
	# camera projects into the window; convert to this canvas (stretch mode scales)
	var vp := root.get_viewport_rect().size
	var win := Vector2(get_viewport().get_visible_rect().size)
	return cam.unproject_position(p) * (vp / win)


func _draw_overlay() -> void:
	var P = G.player
	if P == null:
		return
	var s := overlay.size
	var c := s / 2
	var scan: bool = P.scan_mode
	var col := AMBER if scan else CYAN
	var ring_r := 11.0 * (1.5 if hit_t > 0.0 else 1.0)
	overlay.draw_circle(c, 1.6, col)
	if scan:
		var d := 13.0
		overlay.draw_polyline(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0), c + Vector2(0, -d)]), col, 1.0)
	else:
		overlay.draw_arc(c, ring_r, 0, TAU, 32, Color(1, 1, 1, 0.9) if hit_t > 0.0 else CYAN_DIM, 1.0)
	# lock-on brackets
	if P.lock_target and P.lock_target.alive:
		var sp = _project(P.lock_target.center())
		if sp != null:
			var a := Time.get_ticks_msec() * 0.002
			for i in 4:
				var ang := a + i * PI / 2
				var o: Vector2 = sp + Vector2(cos(ang), sin(ang)) * 32.0
				var t1 := Vector2(cos(ang + PI * 0.75), sin(ang + PI * 0.75)) * 14.0
				var t2 := Vector2(cos(ang - PI * 0.75), sin(ang - PI * 0.75)) * 14.0
				overlay.draw_polyline(PackedVector2Array([o + t1, o, o + t2]), AMBER, 2.0)
	# grapple target
	if P.grapple_candidate != null and not scan:
		var gp = _project(P.grapple_candidate.pos)
		if gp != null:
			var d := 14.0
			overlay.draw_polyline(PackedVector2Array([gp + Vector2(0, -d), gp + Vector2(d, 0), gp + Vector2(0, d), gp + Vector2(-d, 0), gp + Vector2(0, -d)]), AMBER, 2.0)
			overlay.draw_string(mono, gp + Vector2(18, 5), "F", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, AMBER)
	# charge ring
	if P.charge_t > 0.25:
		var k: float = clamp((P.charge_t - 0.25) / (P.charge_need - 0.25), 0.0, 1.0)
		overlay.draw_arc(c, 32, -PI / 2, -PI / 2 + TAU * k, 48, Color.WHITE if k >= 1.0 else KI, 3.0)
	# scan markers
	if scan:
		for it in P.scan_candidates:
			var sp = _project(it.pos)
			if sp == null:
				continue
			var is_target: bool = it == P.scan_target
			var mc := CYAN if it.get("scanned", false) else AMBER
			if it.has("enemy"):
				mc = RED
			var h := 23.0 if is_target else 17.0
			if it.has("enemy"):
				overlay.draw_arc(sp, h, 0, TAU, 24, mc, 2.0 if is_target else 1.0)
				overlay.draw_circle(sp, 5, Color(mc, 0.4))
			else:
				overlay.draw_rect(Rect2(sp - Vector2(h, h), Vector2(h, h) * 2), mc, false, 2.0 if is_target else 1.0)
				overlay.draw_rect(Rect2(sp - Vector2(5, 5), Vector2(10, 10)), Color(mc, 0.4))


func update(dt: float) -> void:
	var P = G.player
	if P == null or not shown:
		return
	var hp: int = ceili(max(0.0, P.hp))
	hp_num.text = "%02d" % hp
	var frac: float = P.hp / P.max_hp
	var bar_w: float = 280.0 * (P.max_hp / 100.0) * 0.8 + 56.0
	hp_fill.get_parent().size.x = bar_w
	hp_fill.size.x = bar_w * frac
	ghost_hp = move_toward(ghost_hp, frac, dt * 0.5) if ghost_hp > frac else frac
	hp_ghost.size.x = bar_w * ghost_hp
	var low: bool = P.hp < 30.0
	var hcol := RED if low else CYAN
	hp_fill.color = hcol
	hp_num.add_theme_color_override("font_color", hcol)
	if low:
		hp_num.modulate.a = 0.65 + 0.35 * sin(Time.get_ticks_msec() * 0.008)
	else:
		hp_num.modulate.a = 1.0
	ki_fill.get_parent().size.x = 196.0 * P.max_ki / 100.0
	ki_fill.size.x = 196.0 * P.ki / 100.0
	threat_fill.size.x = 180.0 * G.enemies.threat_level(P.global_position)
	threat_fill.position.x = 180.0 - threat_fill.size.x
	mode_label.text = "S C A N   V I S O R" if P.scan_mode else "C O M B A T   V I S O R"
	mode_label.add_theme_color_override("font_color", AMBER if P.scan_mode else Color(CYAN, 0.55))
	if P.scan_mode and P.scan_progress > 0.0 and P.scan_target != null and not P.scan_target.get("scanned", false):
		scan_prog.visible = true
		scan_fill.size.x = 220.0 * P.scan_progress
	else:
		scan_prog.visible = false
	if boss_enemy != null:
		if not is_instance_valid(boss_enemy) or not boss_enemy.alive:
			boss(null)
		else:
			boss_fill.size.x = 520.0 * max(0.0, boss_enemy.hp / boss_enemy.max_hp)
	if msg_t > 0.0:
		msg_t -= dt
		if msg_t <= 0.0:
			create_tween().tween_property(msg_label, "modulate:a", 0.0, 0.6)
	if hint_t > 0.0:
		hint_t -= dt
		if hint_t <= 0.0:
			create_tween().tween_property(hint_label, "modulate:a", 0.0, 0.8)
	if area_t > 0.0:
		area_t -= dt
		if area_t <= 0.0:
			create_tween().tween_property(area_label, "modulate:a", 0.0, 2.5)
	hit_t = max(0.0, hit_t - dt)
	if ability_t > 0.0:
		ability_t -= dt
		if ability_t <= 0.0:
			create_tween().tween_property(ability_panel, "modulate:a", 0.0, 1.0).finished.connect(func(): ability_panel.visible = false)
	# mark rooms as visited for the map
	var L = G.level
	if L != null:
		var key: String = L.sector_id + "_rooms"
		if not G.progress.visited.has(key):
			G.progress.visited[key] = {}
		var ri := _room_index(L.map_rooms, P.global_position)
		if ri >= 0:
			G.progress.visited[key][str(ri)] = true
	if map_open:
		map_view.queue_redraw()
	damage_v = max(0.0, damage_v - dt * 1.8)
	overlay.queue_redraw()
	frame.queue_redraw()
