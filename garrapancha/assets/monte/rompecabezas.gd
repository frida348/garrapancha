extends Node2D

@export var puzzle_image_path: String = "res://assets/monte/puzzle_image.png"
@export var columns: int = 3
@export var rows: int = 3
@export var snap_threshold: float = 70.0

const PUZZLE_CENTER  := Vector2(359.0, 410.0)
const MAX_PUZZLE_W   := 680.0
const MAX_PUZZLE_H   := 660.0
const SCATTER_Y_MIN  := 800.0
const SCATTER_Y_MAX  := 1480.0
const SCREEN_MARGIN  := 14.0
const BUMP_RATIO     := 0.28   # tab height as fraction of piece side
const BUMP_START     := 0.28   # tab starts at 28% of edge
const BUMP_END       := 0.72   # tab ends at 72% of edge
const BUMP_STEPS     := 20     # polygon steps per edge

# Piece dimensions
var piece_w: float        # width in image pixels
var piece_h: float        # height in image pixels
var display_scale: float  # image → screen scale
var piece_dw: float       # piece screen width
var piece_dh: float       # piece screen height

# Connectors: 1 = tab out, -1 = blank in
# h_conn[row][col] = right side of piece (col, row)
# v_conn[row][col] = bottom side of piece (col, row)
var h_conn: Array = []
var v_conn: Array = []

# Per-piece data (indexed the same as pieces[])
var pieces:       Array = []  # Node2D
var piece_polys:  Array = []  # PackedVector2Array  (display-space, for hit test)
var piece_targets: Array = [] # Vector2
var piece_placed: Array = []  # bool

var dragging_idx: int = -1
var drag_offset:  Vector2 = Vector2.ZERO
var elapsed:      float = 0.0
var timer_running: bool = false
var placed_count: int = 0

@onready var puzzle_root:     Node2D  = $PuzzleRoot
@onready var board_outline:   Node2D  = $PuzzleRoot/BoardOutline
@onready var timer_label:     Label   = $UILayer/TimerLabel
@onready var win_panel:       Control = $UILayer/WinPanel
@onready var win_time_label:  Label   = $UILayer/WinPanel/TimeLabel
@onready var no_image_label:  Label   = $UILayer/NoImageLabel


func _ready() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	win_panel.hide()
	no_image_label.hide()
	if ResourceLoader.exists(puzzle_image_path):
		_create_puzzle(load(puzzle_image_path) as Texture2D)
		timer_running = true
	else:
		no_image_label.show()


func _process(delta: float) -> void:
	if timer_running:
		elapsed += delta
		timer_label.text = _format_time(elapsed)


# ── Input (mouse + touch) ────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not win_panel.visible:
				_pick(event.position)
		else:
			_drop()

	elif event is InputEventMouseMotion and dragging_idx >= 0:
		pieces[dragging_idx].position = event.position + drag_offset
		get_viewport().set_input_as_handled()

	elif event is InputEventScreenTouch:
		if event.pressed:
			if not win_panel.visible:
				_pick(event.position)
		else:
			_drop()

	elif event is InputEventScreenDrag and dragging_idx >= 0:
		pieces[dragging_idx].position = event.position + drag_offset
		get_viewport().set_input_as_handled()


# ── Puzzle construction ──────────────────────────────────────────────────────

func _create_puzzle(texture: Texture2D) -> void:
	var tw := float(texture.get_width())
	var th := float(texture.get_height())
	display_scale = minf(MAX_PUZZLE_W / tw, MAX_PUZZLE_H / th)
	piece_w  = tw / columns
	piece_h  = th / rows
	piece_dw = piece_w * display_scale
	piece_dh = piece_h * display_scale

	# Random connectors
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for row in range(rows):
		h_conn.append([])
		for _col in range(columns - 1):
			h_conn[row].append(1 if rng.randf() > 0.5 else -1)
	for _row in range(rows - 1):
		v_conn.append([])
		for _col in range(columns):
			v_conn[_row].append(1 if rng.randf() > 0.5 else -1)

	var board_origin := PUZZLE_CENTER - Vector2(piece_dw * columns, piece_dh * rows) * 0.5

	# Slot outlines
	var slot_pos: Array = []
	for row in range(rows):
		for col in range(columns):
			slot_pos.append(board_origin + Vector2(col * piece_dw, row * piece_dh))
	board_outline.setup(slot_pos, Vector2(piece_dw, piece_dh))

	var scatter := _scatter_positions(columns * rows)
	var idx := 0
	for row in range(rows):
		for col in range(columns):
			var sides   := _sides(col, row)
			var polygon := _make_polygon(sides)
			var uv      := _make_uv(polygon, col, row)
			var piece   := _make_piece_node(texture, polygon, uv, scatter[idx], idx)
			piece.set_meta("piece_idx", idx)
			puzzle_root.add_child(piece)
			pieces.append(piece)
			piece_polys.append(polygon)
			piece_targets.append(board_origin + Vector2(col * piece_dw, row * piece_dh))
			piece_placed.append(false)
			idx += 1


func _sides(col: int, row: int) -> Dictionary:
	return {
		"top":    0 if row == 0            else -v_conn[row - 1][col],
		"right":  0 if col == columns - 1  else  h_conn[row][col],
		"bottom": 0 if row == rows - 1     else  v_conn[row][col],
		"left":   0 if col == 0            else -h_conn[row][col - 1],
	}


# ── Polygon / UV generation ──────────────────────────────────────────────────

func _make_polygon(sides: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var bx  := piece_dw * BUMP_RATIO   # tab depth for vertical edges
	var by  := piece_dh * BUMP_RATIO   # tab depth for horizontal edges
	var p_tl := Vector2(0,       0)
	var p_tr := Vector2(piece_dw, 0)
	var p_br := Vector2(piece_dw, piece_dh)
	var p_bl := Vector2(0,       piece_dh)

	pts.append(p_tl)
	_add_bump(pts, p_tl, p_tr, Vector2(0, -1), by * sides.top)
	pts.append(p_tr)
	_add_bump(pts, p_tr, p_br, Vector2(1,  0), bx * sides.right)
	pts.append(p_br)
	_add_bump(pts, p_br, p_bl, Vector2(0,  1), by * sides.bottom)
	pts.append(p_bl)
	_add_bump(pts, p_bl, p_tl, Vector2(-1, 0), bx * sides.left)
	return pts


func _add_bump(pts: PackedVector2Array,
               p1: Vector2, p2: Vector2,
               normal: Vector2, bump_size: float) -> void:
	# Inserts intermediate polygon points between p1 and p2.
	# bump_size > 0 → tab; bump_size < 0 → blank; 0 → flat (no extra points).
	if bump_size == 0.0:
		return
	for i in range(1, BUMP_STEPS):
		var t   := float(i) / BUMP_STEPS
		var pos := p1.lerp(p2, t)
		if t >= BUMP_START and t <= BUMP_END:
			var bt := (t - BUMP_START) / (BUMP_END - BUMP_START)
			pos += normal * sin(bt * PI) * bump_size
		pts.append(pos)


func _make_uv(polygon: PackedVector2Array, col: int, row: int) -> PackedVector2Array:
	# UV in texture-pixel space so the correct image region shows through each piece,
	# including the tab areas that visually overlap adjacent cells.
	var uvs := PackedVector2Array()
	for pt in polygon:
		uvs.append(Vector2(
			col * piece_w + pt.x / display_scale,
			row * piece_h + pt.y / display_scale
		))
	return uvs


func _make_piece_node(texture: Texture2D, polygon: PackedVector2Array,
                      uv: PackedVector2Array, pos: Vector2, _idx: int) -> Node2D:
	# Drop shadow
	var shadow := Polygon2D.new()
	shadow.polygon = polygon
	shadow.color   = Color(0.0, 0.0, 0.0, 0.22)
	shadow.position = Vector2(4, 4)

	# Textured polygon
	var poly := Polygon2D.new()
	poly.texture     = texture
	poly.polygon     = polygon
	poly.uv          = uv
	poly.antialiased = true

	# Border
	var border_pts := PackedVector2Array(polygon)
	border_pts.append(polygon[0])
	var border := Line2D.new()
	border.points        = border_pts
	border.default_color = Color(0.0, 0.0, 0.0, 0.5)
	border.width         = 2.0
	poly.add_child(border)

	var piece := Node2D.new()
	piece.position = pos
	piece.add_child(shadow)
	piece.add_child(poly)
	return piece


# ── Pick / Drop ──────────────────────────────────────────────────────────────

func _scatter_positions(count: int) -> Array:
	var rng  := RandomNumberGenerator.new()
	rng.randomize()
	var max_x := maxf(SCREEN_MARGIN, 718.0 - piece_dw - SCREEN_MARGIN)
	var max_y := maxf(SCATTER_Y_MIN, SCATTER_Y_MAX - piece_dh)
	var out: Array = []
	for _i in range(count):
		out.append(Vector2(
			rng.randf_range(SCREEN_MARGIN, max_x),
			rng.randf_range(SCATTER_Y_MIN, max_y)
		))
	return out


func _pick(mouse: Vector2) -> void:
	# Iterate children in reverse draw order so the topmost piece is picked first.
	for i in range(puzzle_root.get_child_count() - 1, -1, -1):
		var child: Node = puzzle_root.get_child(i)
		if not child.has_meta("piece_idx"):
			continue
		var idx: int = child.get_meta("piece_idx")
		if piece_placed[idx]:
			continue
		# Hit test using the jigsaw polygon shape.
		var local: Vector2 = mouse - child.position
		if Geometry2D.is_point_in_polygon(local, piece_polys[idx]):
			dragging_idx = idx
			drag_offset  = child.position - mouse
			puzzle_root.move_child(child, puzzle_root.get_child_count() - 1)
			get_viewport().set_input_as_handled()
			return


func _drop() -> void:
	if dragging_idx < 0:
		return
	var piece: Node2D   = pieces[dragging_idx]
	var target: Vector2 = piece_targets[dragging_idx]
	if piece.position.distance_to(target) <= snap_threshold:
		piece.position = target
		piece_placed[dragging_idx] = true
		_snap_effect(piece)
		placed_count += 1
		if placed_count == columns * rows:
			_on_win()
	dragging_idx = -1


func _snap_effect(piece: Node2D) -> void:
	var tw := create_tween()
	tw.tween_property(piece, "scale", Vector2(1.06, 1.06), 0.07)
	tw.tween_property(piece, "scale", Vector2(1.0,  1.0),  0.07)


# ── Win / UI ─────────────────────────────────────────────────────────────────

func _on_win() -> void:
	timer_running = false
	win_time_label.text = "Tiempo: " + _format_time(elapsed)
	win_panel.show()


func _format_time(s: float) -> String:
	var m  := floori(s / 60.0)
	var sc := floori(fmod(s, 60.0))
	var cs := floori(fmod(s, 1.0) * 100.0)
	return "%02d:%02d.%02d" % [m, sc, cs]


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://assets/monte_fondo.tscn")
