extends Node2D

# Low-resolution, shape-drawn prototype. All art is original placeholder pixel art.
const W := 480.0
const H := 270.0
const FLOOR_Y := 224.0
const PLAYER_SIZE := Vector2(12, 22)

var player := Vector2(76, FLOOR_Y - 18)
var velocity := Vector2.ZERO
var facing := 1.0
var xp := 0
var level := 1
var telekinesis_level := 1
var feeding_level := 1
var dash_level := 0
var flight_unlocked := false
var dash_unlocked := false
var flying := false
var dash_timer := 0.0
var dash_trail: Array[Dictionary] = []
var pulse_timer := 0.0
var status_text := "CONTAINMENT BREACH // FIND A WAY OUT"
var status_timer := 4.0
var subjects: Array[Dictionary] = []
var crates: Array[Dictionary] = []
var particles: Array[Dictionary] = []
var touch_move := Vector2.ZERO
var touch_buttons: Dictionary = {}
var feed_cooldown := 0.0
var tele_cooldown := 0.0
var mobile_button_rects: Dictionary = {}

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("08060d"))
	subjects = [
		{"pos": Vector2(182, FLOOR_Y - 8), "alive": true, "phase": 0.0},
		{"pos": Vector2(310, FLOOR_Y - 8), "alive": true, "phase": 1.8},
		{"pos": Vector2(412, FLOOR_Y - 8), "alive": true, "phase": 3.2},
	]
	crates = [
		{"pos": Vector2(232, FLOOR_Y - 13), "held": false, "offset": Vector2.ZERO},
		{"pos": Vector2(365, FLOOR_Y - 13), "held": false, "offset": Vector2.ZERO},
	]
	set_process(true)

func _process(delta: float) -> void:
	status_timer = maxf(0.0, status_timer - delta)
	feed_cooldown = maxf(0.0, feed_cooldown - delta)
	tele_cooldown = maxf(0.0, tele_cooldown - delta)
	pulse_timer = maxf(0.0, pulse_timer - delta)
	dash_timer = maxf(0.0, dash_timer - delta)
	var input_dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
	)
	if touch_move.length() > 0.1:
		input_dir = touch_move
	if input_dir.length() > 1.0:
		input_dir = input_dir.normalized()
	if absf(input_dir.x) > 0.05:
		facing = signf(input_dir.x)
	if dash_timer > 0.0:
		velocity = Vector2(facing * (245.0 + dash_level * 28.0), 0)
	else:
		var speed := 82.0 + (level - 1) * 5.0
		velocity.x = move_toward(velocity.x, input_dir.x * speed, 520.0 * delta)
		if flight_unlocked and (Input.is_action_pressed("move_up") or touch_buttons.get("FLY", false)):
			flying = true
			velocity.y = move_toward(velocity.y, -78.0, 260.0 * delta)
		elif flight_unlocked and Input.is_action_pressed("move_down"):
			flying = true
			velocity.y = move_toward(velocity.y, 78.0, 260.0 * delta)
		else:
			flying = false
			velocity.y = move_toward(velocity.y, 0.0, 500.0 * delta)
	player += velocity * delta
	player.x = clampf(player.x, 12.0, W - 12.0)
	player.y = clampf(player.y, 28.0, FLOOR_Y - 10.0) if not flying else clampf(player.y, 30.0, FLOOR_Y - 10.0)
	if not flying and dash_timer <= 0.0:
		player.y = FLOOR_Y - 18.0
	for trail in dash_trail:
		trail.life -= delta
	dash_trail = dash_trail.filter(func(t): return t.life > 0.0)
	for p in particles:
		p.pos += p.vel * delta
		p.life -= delta
	particles = particles.filter(func(p): return p.life > 0.0)
	for subject in subjects:
		subject.phase += delta
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ability_telekinesis"):
		use_telekinesis()
	elif event.is_action_pressed("ability_feed"):
		feed()
	elif event.is_action_pressed("ability_dash"):
		use_dash()
	elif event.is_action_pressed("upgrade_power"):
		upgrade()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		flight_unlocked = true
		set_status("FLIGHT UNLOCKED // HOLD UP OR TAP FLY")
	elif event is InputEventScreenTouch:
		_handle_touch(event.position, event.pressed)
	elif event is InputEventScreenDrag:
		_handle_drag(event.position)

func _handle_touch(pos: Vector2, pressed: bool) -> void:
	var p := get_global_transform_with_canvas().affine_inverse() * pos
	if not pressed:
		touch_move = Vector2.ZERO
		touch_buttons.clear()
		return
	for key in mobile_button_rects:
		if mobile_button_rects[key].has_point(p):
			match key:
				"TK": use_telekinesis()
				"FEED": feed()
				"DASH": use_dash()
				"UP": upgrade()
				"FLY":
					flight_unlocked = true
					touch_buttons["FLY"] = true
			return
		if p.x < 105 and p.y > 175:
			touch_move = Vector2(signf(p.x - 52), 0)

func _handle_drag(pos: Vector2) -> void:
	var p := get_global_transform_with_canvas().affine_inverse() * pos
	if p.x < 105 and p.y > 175:
		touch_move = Vector2(signf(p.x - 52), 0)

func use_telekinesis() -> void:
	if tele_cooldown > 0.0:
		return
	tele_cooldown = 0.65
	pulse_timer = 0.22
	var target_found := false
	for crate in crates:
		if absf(crate.pos.x - player.x) < 92.0 and absf(crate.pos.y - player.y) < 60.0:
			crate.held = not crate.held
			crate.offset = Vector2(facing * 28.0, -30.0) if crate.held else Vector2.ZERO
			if crate.held:
				set_status("TELEKINESIS // OBJECT LIFTED")
			else:
				crate.pos.x += facing * 35.0
				set_status("TELEKINESIS // OBJECT THROWN")
				_spawn_particles(crate.pos, Color("b56cff"), 10)
			target_found = true
			break
	if not target_found:
		set_status("TELEKINESIS // NO OBJECT IN RANGE")

func feed() -> void:
	if feed_cooldown > 0.0:
		return
	var best = null
	var best_dist := 48.0
	for subject in subjects:
		if not subject.alive:
			continue
		var d: float = player.distance_to(subject.pos)
		if d < best_dist:
			best = subject
			best_dist = d
	if best == null:
		set_status("FEEDING // MOVE CLOSER TO A SUBJECT")
		return
	best.alive = false
	feed_cooldown = 0.5
	var gained := 25 + feeding_level * 5
	xp += gained
	_spawn_particles(best.pos, Color("d51f3b"), 18)
	set_status("FED // +%d EVOLUTION XP // VITALITY RESTORED" % gained)
	if xp >= level * 60:
		level += 1
		telekinesis_level += 1
		if level >= 2:
			flight_unlocked = true
		if level >= 3:
			dash_unlocked = true
		set_status("EVOLUTION %d // THE MONSTER STIRS" % level)

func use_dash() -> void:
	if not dash_unlocked:
		set_status("VAMPIRIC DASH // LOCKED — FEED TO EVOLVE")
		return
	if dash_timer > 0.0:
		return
	dash_timer = 0.18
	for i in range(7):
		dash_trail.append({"pos": player - Vector2(facing * i * 8.0, 0), "life": 0.22 + i * 0.018, "max_life": 0.35})
	_spawn_particles(player, Color("ff173f"), 8)
	set_status("VAMPIRIC DASH // BLOOD-RED AFTERIMAGE")

func upgrade() -> void:
	var cost := level * 35
	if xp < cost:
		set_status("EVOLUTION // NEED %d MORE XP" % (cost - xp))
		return
	xp -= cost
	telekinesis_level += 1
	feeding_level += 1
	if dash_unlocked:
		dash_level += 1
	level += 1
	_spawn_particles(player, Color("c77bff"), 20)
	set_status("POWER SURGE // FORM MUTATING // LEVEL %d" % level)

func _spawn_particles(origin: Vector2, color: Color, count: int) -> void:
	for i in range(count):
		var angle := randf() * TAU
		var speed := randf_range(12.0, 58.0)
		particles.append({"pos": origin, "vel": Vector2(cos(angle), sin(angle)) * speed, "life": randf_range(0.2, 0.65), "max_life": 0.65, "color": color})

func set_status(message: String) -> void:
	status_text = message
	status_timer = 2.6

func _draw() -> void:
	_draw_background()
	_draw_room()
	_draw_subjects()
	_draw_crates()
	_draw_particles()
	_draw_dash_trail()
	_draw_player()
	_draw_hud()
	_draw_touch_controls()

func _draw_background() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("08060d"))
	for x in range(0, 480, 16):
		draw_line(Vector2(x, 0), Vector2(x, FLOOR_Y), Color("15101d"), 1.0)
	for y in range(12, 225, 16):
		draw_line(Vector2(0, y), Vector2(W, y), Color("15101d"), 1.0)
	# Distant industrial silhouettes
	draw_rect(Rect2(18, 42, 64, 68), Color("100c18"))
	draw_rect(Rect2(26, 52, 18, 36), Color("251323"))
	draw_rect(Rect2(92, 30, 22, 80), Color("100c18"))
	draw_rect(Rect2(400, 35, 48, 70), Color("100c18"))
	for x in [30, 54, 420, 438]:
		draw_rect(Rect2(x, 57, 5, 2), Color("74233b"))

func _draw_room() -> void:
	draw_rect(Rect2(0, FLOOR_Y, W, H - FLOOR_Y), Color("211b28"))
	draw_rect(Rect2(0, FLOOR_Y, W, 4), Color("514054"))
	for x in range(0, 480, 24):
		draw_rect(Rect2(x, FLOOR_Y + 8, 22, 2), Color("302738"))
	# Flickering warning lamps and pipes
	var lamp := Color("9d1836") if int(Time.get_ticks_msec() / 450) % 3 != 0 else Color("481329")
	draw_rect(Rect2(145, 18, 38, 5), lamp)
	draw_rect(Rect2(145, 24, 38, 1), Color("3c172b"))
	draw_rect(Rect2(275, 16, 5, 30), Color("443247"))
	draw_rect(Rect2(275, 43, 18, 4), Color("443247"))
	# Drain and blood stains
	draw_rect(Rect2(62, FLOOR_Y + 12, 34, 8), Color("17121d"))
	draw_rect(Rect2(69, FLOOR_Y + 15, 20, 2), Color("08070b"))
	draw_rect(Rect2(340, FLOOR_Y + 7, 16, 3), Color("4b1428"))
	draw_rect(Rect2(348, FLOOR_Y + 10, 9, 2), Color("4b1428"))

func _draw_subjects() -> void:
	for subject in subjects:
		if not subject.alive:
			# A dark pool remains where the subject fell.
			draw_rect(Rect2(subject.pos.x - 10, FLOOR_Y - 2, 20, 3), Color("541329"))
			continue
		var bob := sin(subject.phase * 2.0) * 1.0
		var p: Vector2 = subject.pos + Vector2(0, bob)
		draw_rect(Rect2(p.x - 5, p.y - 20, 10, 8), Color("b7a9ae"))
		draw_rect(Rect2(p.x - 6, p.y - 12, 12, 12), Color("687080"))
		draw_rect(Rect2(p.x - 4, p.y - 1, 3, 9), Color("4d4858"))
		draw_rect(Rect2(p.x + 1, p.y - 1, 3, 9), Color("4d4858"))
		draw_rect(Rect2(p.x - 3, p.y - 18, 2, 2), Color("9d203b"))
		draw_rect(Rect2(p.x + 1, p.y - 18, 2, 2), Color("9d203b"))

func _draw_crates() -> void:
	for crate in crates:
		var p: Vector2 = crate.pos + crate.offset if crate.held else crate.pos
		if crate.held:
			draw_rect(Rect2(p.x - 20, p.y - 20, 40, 40), Color(0.58, 0.28, 0.9, 0.12))
		draw_rect(Rect2(p.x - 12, p.y - 13, 24, 24), Color("4a3c50"))
		draw_rect(Rect2(p.x - 10, p.y - 11, 20, 20), Color("6a536e"))
		draw_rect(Rect2(p.x - 8, p.y - 9, 16, 2), Color("9c78a5"))
		draw_rect(Rect2(p.x - 2, p.y - 9, 3, 18), Color("3a2b44"))
		if crate.held:
			draw_rect(Rect2(p.x - 15, p.y - 16, 30, 30), Color(0.68, 0.3, 1.0, 0.12), false, 1.0)

func _draw_player() -> void:
	var p := player
	var evolved := level >= 2
	var monstrous := level >= 4
	# Shadow and a restrained supernatural aura
	draw_rect(Rect2(p.x - 10, FLOOR_Y - 2, 20, 3), Color("030207"))
	if level >= 2 or pulse_timer > 0.0:
		draw_rect(Rect2(p.x - 13 - level, p.y - 17 - level, 26 + level * 2, 25 + level * 2), Color(0.48, 0.08, 0.2, 0.11))
	# Bat-like shoulder silhouette grows with evolution
	if evolved:
		draw_rect(Rect2(p.x - 11, p.y - 13, 5, 8), Color("1a101e"))
		draw_rect(Rect2(p.x + 6, p.y - 13, 5, 8), Color("1a101e"))
	if monstrous:
		draw_rect(Rect2(p.x - 13, p.y - 17, 5, 10), Color("1a101e"))
		draw_rect(Rect2(p.x + 8, p.y - 17, 5, 10), Color("1a101e"))
	# Body, head, coat: deliberately chunky pixel blocks
	var body_color := Color("28202f") if level < 3 else Color("351421")
	draw_rect(Rect2(p.x - 6, p.y - 12, 12, 13), body_color)
	draw_rect(Rect2(p.x - 5, p.y - 11, 3, 11), Color("4a263c"))
	draw_rect(Rect2(p.x - 5, p.y - 20, 10, 9), Color("b7a0a6") if level < 3 else Color("88717f"))
	draw_rect(Rect2(p.x - 6, p.y - 22, 12, 4), Color("19111f"))
	# Hair grows into horn-like points at later evolution
	if monstrous:
		draw_rect(Rect2(p.x - 6, p.y - 26, 3, 5), Color("20101f"))
		draw_rect(Rect2(p.x + 3, p.y - 26, 3, 5), Color("20101f"))	
	var eye_color := Color("ef314f") if level >= 2 else Color("7b253e")
	draw_rect(Rect2(p.x + facing * 2, p.y - 17, 2, 2), eye_color)
	if level >= 3:
		draw_rect(Rect2(p.x - 8, p.y - 5, 2, 7), Color("bd2948"))
		draw_rect(Rect2(p.x + 6, p.y - 5, 2, 7), Color("bd2948"))
	# Arms and legs animate in blocky steps
	var step := int(Time.get_ticks_msec() / 100) % 2 if absf(velocity.x) > 5 else 0
	draw_rect(Rect2(p.x - 8, p.y - 11, 3, 9), Color("82717f"))
	draw_rect(Rect2(p.x + 5, p.y - 11, 3, 9), Color("82717f"))
	draw_rect(Rect2(p.x - 5, p.y + 1, 4, 8 + step), Color("18121e"))
	draw_rect(Rect2(p.x + 1, p.y + 1, 4, 8 - step), Color("18121e"))
	if flying:
		draw_rect(Rect2(p.x - 13, p.y - 3, 5, 2), Color("8c2143"))
		draw_rect(Rect2(p.x + 8, p.y - 3, 5, 2), Color("8c2143"))

func _draw_dash_trail() -> void:
	for t in dash_trail:
		var alpha: float = clampf(t.life / t.max_life, 0.0, 1.0)
		draw_rect(Rect2(t.pos.x - 7, t.pos.y - 19, 14, 21), Color(1.0, 0.04, 0.18, alpha * 0.42))
		draw_rect(Rect2(t.pos.x - 4, t.pos.y - 17, 8, 15), Color(1.0, 0.16, 0.28, alpha * 0.34))

func _draw_particles() -> void:
	for p in particles:
		var alpha: float = clampf(p.life / p.max_life, 0.0, 1.0)
		var c: Color = p.color
		c.a = alpha
		draw_rect(Rect2(p.pos.x, p.pos.y, 2, 2), c)

func _draw_hud() -> void:
	# Header panel
	draw_rect(Rect2(6, 6, 220, 49), Color(0.035, 0.025, 0.05, 0.94))
	draw_rect(Rect2(6, 6, 2, 49), Color("b52d50"))
	draw_string(ThemeDB.fallback_font, Vector2(14, 18), "NIGHTBLOOD // SUBJECT 07", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e7d8e8"))
	draw_string(ThemeDB.fallback_font, Vector2(14, 31), "EVOLUTION %02d   XP %03d" % [level, xp], HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("e45b75"))
	draw_string(ThemeDB.fallback_font, Vector2(14, 44), "TK %d  FEED %d  DASH %d" % [telekinesis_level, feeding_level, dash_level], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("b5a5bf"))
	# Progression bar
	draw_rect(Rect2(236, 9, 110, 7), Color("291b2c"))
	draw_rect(Rect2(237, 10, minf(108.0, float(xp % (level * 60)) / float(level * 60) * 108.0), 5), Color("a52243"))
	draw_string(ThemeDB.fallback_font, Vector2(236, 27), "EVOLUTION THRESHOLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 7, Color("b9a7bc"))
	draw_string(ThemeDB.fallback_font, Vector2(236, 40), "FLIGHT: %s" % ("ONLINE" if flight_unlocked else "LOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("c2a6d4"))
	draw_string(ThemeDB.fallback_font, Vector2(236, 51), "DASH: %s" % ("ONLINE" if dash_unlocked else "LOCKED"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("e45b75"))
	if status_timer > 0.0:
		var width := minf(330.0, status_text.length() * 5.0 + 18.0)
		draw_rect(Rect2((W - width) / 2, 66, width, 16), Color(0.025, 0.015, 0.035, 0.88))
		draw_string(ThemeDB.fallback_font, Vector2((W - width) / 2 + 8, 77), status_text, HORIZONTAL_ALIGNMENT_LEFT, width - 10, 7, Color("f0dbe7"))
	# Desktop hints
	draw_string(ThemeDB.fallback_font, Vector2(8, 263), "A/D MOVE   SPACE TELEKINESIS   F FEED   SHIFT DASH   E UPGRADE   F1 FLIGHT", HORIZONTAL_ALIGNMENT_LEFT, 465, 7, Color("87788f"))

func _draw_touch_controls() -> void:
	mobile_button_rects.clear()
	var buttons := [
		{"key":"TK", "label":"TK", "rect":Rect2(346, 190, 28, 28)},
		{"key":"FEED", "label":"FEED", "rect":Rect2(380, 190, 38, 28)},
		{"key":"DASH", "label":"DASH", "rect":Rect2(424, 190, 42, 28)},
		{"key":"UP", "label":"EVOLVE", "rect":Rect2(382, 224, 48, 26)},
		{"key":"FLY", "label":"FLY", "rect":Rect2(334, 224, 42, 26)},
	]
	for b in buttons:
		var r: Rect2 = b.rect
		mobile_button_rects[b.key] = r
		draw_rect(r, Color(0.12, 0.07, 0.15, 0.78))
		draw_rect(r, Color("74405f"), false, 1.0)
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x + 4, r.position.y + 17), b.label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 8, 8, Color("e8d8e8"))
	# Left/right mobile movement pads
	draw_rect(Rect2(10, 204, 38, 38), Color(0.12, 0.07, 0.15, 0.7))
	draw_rect(Rect2(53, 204, 38, 38), Color(0.12, 0.07, 0.15, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(20, 228), "<", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8d8e8"))
	draw_string(ThemeDB.fallback_font, Vector2(65, 228), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("e8d8e8"))
