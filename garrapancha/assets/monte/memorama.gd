extends Node2D

const PANGOLIN := preload("res://assets/dialog/Pangolin-Regular.ttf")

# ── State machine ─────────────────────────────────────────────────────────────
enum GameState { SELECT, PLAYING, CHECKING }

# ── Layout constants ──────────────────────────────────────────────────────────
const CARD_GAP      := 10.0   # pixels between cards
const MAX_CARD_SIZE := 300.0  # maximum card side length
const GRID_X        := 30.0   # left edge of card area
const GRID_Y        := 425.0  # top edge of card area (below GameUI header)
const GRID_W        := 658.0  # usable width
const GRID_H        := 1035.0  # usable height

# ── Animation constants ───────────────────────────────────────────────────────
const FLIP_HALF_T  := 0.12  # seconds for each half of the flip animation
const CHECK_DELAY  := 0.70  # seconds to show two cards before checking match

# ── Card colours ──────────────────────────────────────────────────────────────
const COLOR_BACK    := Color(0.22, 0.48, 0.28, 1.0)  # card back (green)
const COLOR_FRONT   := Color(0.95, 0.91, 0.80, 1.0)  # card face (cream)
const COLOR_MATCHED := Color(0.42, 0.75, 0.42, 1.0)  # matched card face

# ── Runtime state ─────────────────────────────────────────────────────────────
var state         := GameState.SELECT
var current_level := 0

var card_nodes:    Array = []  # Control  – one per card
var card_pair_ids: Array = []  # int      – same id → matching pair
var card_flipped:  Array = []  # bool     – true when face-up
var card_matched:  Array = []  # bool     – true when permanently matched

var first_card   := -1
var matched_count := 0
var elapsed      := 0.0
var timer_running := false

# ── Scene references ──────────────────────────────────────────────────────────
@onready var level_panel:   Control = $UILayer/LevelPanel
@onready var game_ui:       Control = $UILayer/GameUI
@onready var cards_root:    Control = $UILayer/CardsRoot
@onready var win_panel:     Control = $UILayer/WinPanel
@onready var timer_label:   Label   = $UILayer/GameUI/TimerLabel
@onready var level_label:   Label   = $UILayer/GameUI/LevelLabel
@onready var win_time_lbl:  Label   = $UILayer/WinPanel/TimeLabel
@onready var next_lvl_btn:  Button  = $UILayer/WinPanel/NextLevelButton
@onready var game_back_btn: Button  = $UILayer/GameBackBtn
@onready var confirm_panel: Control = $UILayer/ConfirmPanel

var _confirm_action := ""


func _ready() -> void:
	if OS.has_feature("android") or OS.has_feature("ios"):
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_PORTRAIT)
	# Connect level-select buttons (with bound argument = level index)
	$UILayer/LevelPanel/Nivel1Btn.pressed.connect(_on_level_button_pressed.bind(0))
	$UILayer/LevelPanel/Nivel2Btn.pressed.connect(_on_level_button_pressed.bind(1))
	_show_level_panel()


func _process(delta: float) -> void:
	if timer_running:
		elapsed += delta
		timer_label.text = _fmt(elapsed)


# ── Navigation ────────────────────────────────────────────────────────────────

func _show_level_panel() -> void:
	state = GameState.SELECT
	timer_running = false
	_clear_cards()
	level_panel.show()
	game_ui.hide()
	cards_root.hide()
	win_panel.hide()
	game_back_btn.hide()
	confirm_panel.hide()


func _on_level_button_pressed(level: int) -> void:
	current_level = level
	_start_level()


func _on_game_back_pressed() -> void:
	_show_confirm("level_select")


func _on_next_level_pressed() -> void:
	current_level += 1
	_start_level()


func _on_back_button_pressed() -> void:
	_show_confirm("main_menu")


func _show_confirm(action: String) -> void:
	_confirm_action = action
	confirm_panel.show()


func _on_confirm_pressed() -> void:
	confirm_panel.hide()
	if _confirm_action == "main_menu":
		get_tree().change_scene_to_file("res://assets/monte_fondo.tscn")
	else:
		_show_level_panel()


func _on_reject_pressed() -> void:
	confirm_panel.hide()


# ── Level setup ───────────────────────────────────────────────────────────────

func _start_level() -> void:
	_clear_cards()
	elapsed       = 0.0
	matched_count = 0
	first_card    = -1
	state         = GameState.PLAYING

	level_panel.hide()
	win_panel.hide()
	game_ui.show()
	cards_root.show()
	game_back_btn.show()

	level_label.text = MemoramaData.LEVEL_TITLES[current_level]

	var cfg: Array  = MemoramaData.LEVEL_SIZES[current_level]
	var cols: int   = cfg[0]
	var rows: int   = cfg[1]
	var n_pairs: int = int(cols * rows * 0.5)
	var raw: Array  = MemoramaData.LEVEL_CONTENT[current_level]

	# Build the deck: each entry is [card_a, card_b]; shuffle both slots.
	var deck: Array = []
	for i in range(n_pairs):
		var entry = raw[i] if i < raw.size() else null
		var card_a: Dictionary
		var card_b: Dictionary
		if entry is Array and entry.size() >= 2:
			card_a = entry[0]
			card_b = entry[1]
		elif entry is Dictionary:
			card_a = entry
			card_b = entry
		else:
			card_a = {"type": "text", "value": "?"}
			card_b = {"type": "text", "value": "?"}
		deck.append({"data": card_a, "pair_id": i})
		deck.append({"data": card_b, "pair_id": i})
	deck.shuffle()

	var card_size := _card_size(cols, rows)
	var total_w   := cols * card_size.x + (cols - 1) * CARD_GAP
	var total_h   := rows * card_size.y + (rows - 1) * CARD_GAP
	var origin    := Vector2(
		GRID_X + (GRID_W - total_w) * 0.5,
		GRID_Y + (GRID_H - total_h) * 0.5
	)

	for row in range(rows):
		for col in range(cols):
			var i    := row * cols + col
			var pos  := origin + Vector2(col * (card_size.x + CARD_GAP), row * (card_size.y + CARD_GAP))
			var card := _make_card(deck[i], i, pos, card_size)
			cards_root.add_child(card)
			card_nodes.append(card)
			card_pair_ids.append(deck[i].pair_id)
			card_flipped.append(false)
			card_matched.append(false)

	timer_running = true


func _clear_cards() -> void:
	for c in card_nodes:
		if is_instance_valid(c):
			c.queue_free()
	card_nodes.clear()
	card_pair_ids.clear()
	card_flipped.clear()
	card_matched.clear()


func _card_size(cols: int, rows: int) -> Vector2:
	var w := minf((GRID_W - CARD_GAP * (cols - 1)) / cols, MAX_CARD_SIZE)
	var h := minf((GRID_H - CARD_GAP * (rows - 1)) / rows, MAX_CARD_SIZE)
	return Vector2(w, h)


# ── Card factory ──────────────────────────────────────────────────────────────

func _make_card(entry: Dictionary, idx: int, pos: Vector2, sz: Vector2) -> Control:
	var card := Control.new()
	card.size          = sz
	card.position      = pos
	card.pivot_offset  = sz * 0.5
	card.mouse_filter  = Control.MOUSE_FILTER_STOP
	card.clip_contents = true

	var short_side := minf(sz.x, sz.y)

	# ── Back side ─────────────────────────────────────────────────────────────
	var back_bg := ColorRect.new()
	back_bg.size         = sz
	back_bg.color        = COLOR_BACK
	back_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(back_bg)

	var q_lbl := Label.new()
	q_lbl.size         = sz
	q_lbl.text         = "?"
	q_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	q_lbl.add_theme_font_override("font", PANGOLIN)
	q_lbl.add_theme_font_size_override("font_size", int(short_side * 0.52))
	q_lbl.modulate     = Color(1, 1, 1, 0.60)
	q_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(q_lbl)

	# ── Front side (hidden initially) ────────────────────────────────────────
	var front_bg := ColorRect.new()
	front_bg.size         = sz
	front_bg.color        = COLOR_FRONT
	front_bg.visible      = false
	front_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(front_bg)

	var data: Dictionary = entry.data
	var front_content: Control

	if data.type == "image" and ResourceLoader.exists(data.value):
		var tex := TextureRect.new()
		tex.size         = sz
		tex.texture      = load(data.value)
		tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.visible      = false
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(tex)
		front_content = tex
	else:
		var lbl := Label.new()
		lbl.size         = sz
		lbl.text         = data.value
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_override("font", PANGOLIN)
		lbl.add_theme_font_size_override("font_size", int(short_side * 0.26))
		lbl.visible      = false
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(lbl)
		front_content = lbl

	# Store references in metadata for quick access during animations.
	card.set_meta("back_bg",       back_bg)
	card.set_meta("q_lbl",         q_lbl)
	card.set_meta("front_bg",      front_bg)
	card.set_meta("front_content", front_content)

	card.gui_input.connect(_on_card_gui_input.bind(idx))
	return card


# ── Input & flip logic ────────────────────────────────────────────────────────

func _on_card_gui_input(event: InputEvent, idx: int) -> void:
	if state != GameState.PLAYING:
		return
	if card_flipped[idx] or card_matched[idx]:
		return
	var clicked: bool = \
		(event is InputEventMouseButton and event.pressed
		 and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if not clicked:
		return
	_flip_card(idx)


func _flip_card(idx: int) -> void:
	card_flipped[idx] = true
	_animate_flip(card_nodes[idx], true)

	if first_card == -1:
		first_card = idx
		return

	# Second card flipped: lock input and check after delay.
	var second := idx
	var first  := first_card
	first_card  = -1
	state = GameState.CHECKING

	await get_tree().create_timer(CHECK_DELAY).timeout
	if not is_instance_valid(self):
		return
	_check_match(first, second)


func _animate_flip(card: Control, to_front: bool) -> void:
	var back_bg:       ColorRect = card.get_meta("back_bg")
	var q_lbl:         Label     = card.get_meta("q_lbl")
	var front_bg:      ColorRect = card.get_meta("front_bg")
	var front_content: Control   = card.get_meta("front_content")

	var tw := create_tween()
	tw.tween_property(card, "scale:x", 0.0, FLIP_HALF_T)
	tw.tween_callback(func():
		back_bg.visible       = not to_front
		q_lbl.visible         = not to_front
		front_bg.visible      = to_front
		front_content.visible = to_front
	)
	tw.tween_property(card, "scale:x", 1.0, FLIP_HALF_T)


func _check_match(a: int, b: int) -> void:
	if card_pair_ids[a] == card_pair_ids[b]:
		# ✓ Pair matched
		card_matched[a] = true
		card_matched[b] = true
		_mark_matched(a)
		_mark_matched(b)
		matched_count += 1
		state = GameState.PLAYING
		if matched_count * 2 == card_nodes.size():
			_on_win()
	else:
		# ✗ No match — flip both back
		_animate_flip(card_nodes[a], false)
		_animate_flip(card_nodes[b], false)
		await get_tree().create_timer(FLIP_HALF_T * 2 + 0.05).timeout
		if not is_instance_valid(self):
			return
		card_flipped[a] = false
		card_flipped[b] = false
		state = GameState.PLAYING


func _mark_matched(idx: int) -> void:
	var front_bg: ColorRect = card_nodes[idx].get_meta("front_bg")
	var tw := create_tween()
	tw.tween_property(front_bg, "color", COLOR_MATCHED, 0.30)


# ── Win ───────────────────────────────────────────────────────────────────────

func _on_win() -> void:
	timer_running = false
	win_time_lbl.text    = "Tiempo: " + _fmt(elapsed)
	next_lvl_btn.visible = current_level < MemoramaData.LEVEL_SIZES.size() - 1
	game_ui.hide()
	cards_root.hide()
	win_panel.show()
	game_back_btn.hide()


# ── Helpers ───────────────────────────────────────────────────────────────────

func _fmt(s: float) -> String:
	var m  := floori(s / 60.0)
	var sc := floori(fmod(s, 60.0))
	var cs := floori(fmod(s, 1.0) * 100.0)
	return "%02d:%02d.%02d" % [m, sc, cs]
