extends RefCounted
class_name CampWorld

const MAP = preload("res://scripts/camp/plaza_geometry.gd")
const PLAZA = preload("res://assets/acampada/plaza.png")
const PLAYER = preload("res://assets/acampada/player.png")
const PATRICIA = preload("res://assets/acampada/alba.png")
const ALEJANDRO = preload("res://assets/acampada/joan.png")
const MARINA = preload("res://assets/acampada/mar.png")
const TARP = preload("res://assets/acampada/tarp.png")
const POLES = preload("res://assets/acampada/poles.png")
const PEGS = preload("res://assets/acampada/pegs.png")
const TABLE = preload("res://assets/acampada/table.png")
const TENT = preload("res://assets/acampada/tent.png")
const LAID = preload("res://assets/acampada/tent_laid.png")
const FRAMED = preload("res://assets/acampada/tent_poles.png")
const RAISED = preload("res://assets/acampada/tent_raised.png")
const FONT = preload("res://assets/template/fonts/ui_bold.tres")

const MEETING := Vector2(615, 428)
const SITE := Vector2(410, 392)
const ORGANIZATION := Vector2(625, 261)
const MATERIALS := {"lona": Vector2(235, 423), "varillas": Vector2(540, 435), "piquetas": Vector2(824, 391)}

# The illustrated plaza puts the fountain on the right. Rotate the satellite
# reference into that view, then compress depth to match the paving.
const CAMP_ORIGIN := Vector2(1025, 218)
const CAMP_EAST := Vector2(0, 0.93)
const CAMP_SOUTH := Vector2(-2.25, 0.19)
const DAY_ONE_TENTS := 25
const KITCHEN_TENTS := 12
const COMMUNICATION_TENTS := 19
const ENTRANCE := Vector2(650, 495)
const ENTRY_APPROACH := Vector2(650, 526)
const COMMUNICATION := Vector2(307, 407)
const KITCHEN := Vector2(540, 402)
const COMMISSION_POINTS := [ORGANIZATION, KITCHEN, COMMUNICATION]
const COMMISSION_NAMES := ["Organización", "Cocina", "Comunicación"]
const CROWD_TEXTURES := [PATRICIA, ALEJANDRO, MARINA, PLAYER]
const MAX_TENTS := 800
const TENT_GROUND := Vector2(9, 5)
const TENT_SIZE := Vector2(23, 21)
const TENT_OFFSET := Vector2(11.5, 17)
const CAMP_TINTS := [Color("e0c2a0"), Color("cad8bd"), Color("e1bfae"), Color.WHITE]
# Red boundary, traced in the supplied satellite crop.
const OCCUPIED_AREA := [
	Vector2(148,126), Vector2(150,117), Vector2(160,97), Vector2(177,91),
	Vector2(224,87), Vector2(245,81), Vector2(260,77), Vector2(270,81),
	Vector2(276,95), Vector2(282,126), Vector2(291,164), Vector2(301,195),
	Vector2(313,231), Vector2(322,259), Vector2(330,291), Vector2(325,307),
	Vector2(321,324), Vector2(295,337), Vector2(263,349), Vector2(231,362),
	Vector2(213,364), Vector2(201,359), Vector2(188,347), Vector2(179,333),
	Vector2(174,321), Vector2(172,309), Vector2(166,294), Vector2(165,269),
	Vector2(166,233), Vector2(160,208), Vector2(159,181), Vector2(160,149),
]

# Four lines drawn on the annotated plaza, from the northern pavement south.
const DAY_ONE_ROWS := [
	[Vector2(435, 323), Vector2(410, 392)],
	[Vector2(476, 318), Vector2(455, 392)],
	[Vector2(515, 318), Vector2(495, 392)],
	[Vector2(554, 318), Vector2(545, 385)],
]
static var day_one_pitches := make_day_one_pitches()

static func make_day_one_pitches() -> PackedVector2Array:
	var pitches := PackedVector2Array()
	for i in range(6):
		var fraction := float(i) / 5.0
		for row_index in range(DAY_ONE_ROWS.size()):
			var row: Array = DAY_ONE_ROWS[row_index]
			var end: Vector2 = SITE.lerp(row[0], 1.0 / 6.0) if row_index == 0 else row[1]
			pitches.append(row[0].lerp(end, fraction))
	return pitches

static var camp_pitches := make_pitches()

static func make_pitches() -> PackedVector2Array:
	var boundary := PackedVector2Array()
	for point in OCCUPIED_AREA:
		boundary.append(CAMP_ORIGIN + CAMP_EAST * point.x + CAMP_SOUTH * point.y)
	var blocks: Array[Vector2] = []
	# Leave crossing routes between blocks and a clearing at the first tent
	# and at the Organization table.
	for row in range(36):
		for column in range(65):
			if row % 8 == 7 or column % 10 == 9:
				continue
			var position := Vector2(210 + 10 * column, 365 + 6 * row)
			if position.distance_to(SITE) < 36 or position.distance_to(MEETING) < 28 or position.distance_to(ENTRANCE) < 20:
				continue
			if position.distance_to(ORGANIZATION) < 30 or position.distance_to(COMMUNICATION) < 30 or position.distance_to(KITCHEN) < 34:
				continue
			var fits := true
			for corner in [Vector2(-5,-3), Vector2(5,-3), Vector2(5,3), Vector2(-5,3)]:
				if not Geometry2D.is_point_in_polygon(position + corner, boundary) or not MAP.walkable(position + corner):
					fits = false
					break
			if fits:
				blocks.append(position)
	# Spread occupied pitches across the available area while preserving
	# the cross aisles, then expand outward from the original site.
	var selected: Array[Vector2] = []
	for i in range(mini(MAX_TENTS - 1, blocks.size())):
		selected.append(blocks[floori(float(i) * blocks.size() / (MAX_TENTS - 1))])
	selected.sort_custom(func(a: Vector2, b: Vector2): return a.distance_squared_to(SITE) < b.distance_squared_to(SITE))
	return PackedVector2Array(selected)

static func pitch_count(s: CampState) -> int:
	return maxi(0, s.tents - 1)

static func next_pitch(s: CampState) -> Vector2:
	return pitch_at(s, s.tents - 1)

static func pitch_at(s: CampState, index: int) -> Vector2:
	return day_one_pitches[int(s.pitch_swaps.get(str(index), index))]

static func assign_pitch(s: CampState) -> bool:
	var first := s.tents - 1
	var best := -1
	var distance := 16.0
	for i in range(first, mini(first + 3, DAY_ONE_TENTS - 1)):
		var d := s.player.distance_to(pitch_at(s, i))
		if d < distance:
			best = i
			distance = d
	if best < 0:
		return false
	var previous := int(s.pitch_swaps.get(str(first), first))
	s.pitch_swaps[str(first)] = int(s.pitch_swaps.get(str(best), best))
	s.pitch_swaps[str(best)] = previous
	return true

var route_key := ""
var route := Curve2D.new()

func delivery_point(s: CampState, start: Vector2, end: Vector2) -> Vector2:
	var key := "%s:%s:%s:%s" % [s.delivery, s.tents, start, end]
	if route_key != key:
		route_key = key
		route.clear_points()
		var grid := AStarGrid2D.new()
		grid.region = Rect2i(36, 60, 190, 84)
		grid.cell_size = Vector2(4, 4)
		grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
		grid.update()
		for y in range(grid.region.position.y, grid.region.end.y):
			for x in range(grid.region.position.x, grid.region.end.x):
				var id := Vector2i(x, y)
				grid.set_point_solid(id, not walkable(Vector2(id) * 4.0, s))
		var origin := nearby_grid_point(grid, start)
		var to := nearby_grid_point(grid, end)
		if grid.is_in_boundsv(origin) and grid.is_in_boundsv(to):
			for point in grid.get_point_path(origin, to):
				route.add_point(point)
	return route.sample_baked(route.get_baked_length() * s.delivery_progress) if route.point_count > 0 else start

func nearby_grid_point(grid: AStarGrid2D, point: Vector2) -> Vector2i:
	var cell := Vector2i((point / 4.0).round())
	for radius in range(7):
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				var id := cell + Vector2i(x,y)
				if grid.is_in_boundsv(id) and not grid.is_point_solid(id):
					return id
	return Vector2i(-1,-1)

static func walkable(p: Vector2, s: CampState) -> bool:
	if not MAP.walkable(p) or pitch_blocks(p, s):
		return false
	if s.tents > 0 and Rect2(SITE - TENT_GROUND, TENT_GROUND * 2).has_point(p):
		return false
	if s.commissions >= 2:
		if Rect2(KITCHEN - Vector2(7,4), Vector2(16,7)).has_point(p):
			return false
		if Rect2(KITCHEN + Vector2(8,-1), Vector2(20,7)).has_point(p):
			return false
	if s.material_boxes > 0 and Rect2(SITE + Vector2(6,-3), Vector2(27,7)).has_point(p):
		return false
	return true

static func clear_spot(p: Vector2, s: CampState) -> Vector2:
	if walkable(p, s):
		return p
	for distance in range(4, 45, 4):
		for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
			var nearby: Vector2 = p + direction * distance
			if walkable(nearby, s):
				return nearby
	return ENTRANCE

static func pitch_blocks(p: Vector2, s: CampState) -> bool:
	for i in range(pitch_count(s)):
		if Rect2(pitch_at(s, i) - TENT_GROUND, TENT_GROUND * 2.0).has_point(p):
			return true
	return false

func draw_pitch(c: Control, p: Vector2, index: int) -> void:
	c.draw_texture_rect(TENT, Rect2(p - TENT_OFFSET, TENT_SIZE), false, CAMP_TINTS[index % CAMP_TINTS.size()])

func npc_pos(n: String, s: CampState, t: float) -> Vector2:
	if s.phase in ["commissions", "expansion", "finished"]:
		return clear_spot(ORGANIZATION + Vector2(-22 + ["Patricia", "Alejandro", "Marina"].find(n) * 22, -14), s)
	var p := Vector2.ZERO
	match n:
		"Patricia": p = Vector2(585, 480)
		"Alejandro": p = Vector2(435, 398)
		"Marina": p = Vector2(755, 407)
	if s.phase == "meeting":
		match n:
			"Patricia": p = Vector2(575, 423)
			"Alejandro": p = Vector2(628, 394)
			"Marina": p = Vector2(687, 423)
	elif s.phase == "build":
		match n:
			"Patricia": p = Vector2(480, 438)
			"Alejandro": p = Vector2(300, 427)
			"Marina": p = Vector2(690, 470)
	# Small walking routines keep the plaza alive without changing logical navigation.
	if s.phase == "materials":
		var shift := 0.0
		match n:
			"Patricia": shift = 0.4
			"Alejandro": shift = 2.1
			"Marina": shift = 4.0
		p += Vector2(sin(t * 0.42 + shift) * 18.0, cos(t * 0.35 + shift) * 7.0)
	return clear_spot(p,s)

func crowd_position(i: int, s: CampState) -> Vector2:
	var center := MEETING if s.phase == "meeting" else Vector2(440 + (i % 5) * 67, 390 + floori(i / 5.0) * 36)
	var pos := center + Vector2.from_angle(i * TAU / 17.0) * (32.0 + float(i % 3) * 9.0)
	if s.phase in ["commissions", "expansion", "finished", "build"]:
		if i < 3: pos = ORGANIZATION + Vector2(-20 + i * 20, 15)
		elif i < 7: pos = COMMUNICATION + Vector2(-27 + (i - 3) * 18, 12)
		elif i < 10: pos = KITCHEN + Vector2(-21 + (i - 7) * 18, 17)
	return clear_spot(pos, s)

func draw(c: Control, s: CampState, rect: Rect2, t: float, walking: bool, arrival_positions: Array) -> void:
	var v := rect.size / Vector2(1280, 720)
	c.draw_set_transform(rect.position, 0.0, v)
	c.draw_texture_rect(PLAZA, Rect2(0, 0, 1280, 720), false)
	# Light zone markers are labels, not buildings: the sketch depicts a future camp.
	zone(c, Vector2(230, 347), "B")
	zone(c, Vector2(825, 345), "A")
	zone(c, Vector2(202, 557), "C")
	zone(c, Vector2(200, 625), "E")
	zone(c, Vector2(741, 590), "D")
	zone(c, Vector2(884, 465), "H · PLAZA 15M")
	if s.phase == "meeting":
		marker(c, MEETING, "ASAMBLEA", t)
	if s.phase == "materials":
		for k in MATERIALS:
			if not s.collected[k]:
				var texture: Texture2D = TARP if k == "lona" else (POLES if k == "varillas" else PEGS)
				var p: Vector2 = MATERIALS[k]
				c.draw_circle(p, 8, Color(1.0, 0.85, 0.43, 0.25))
				c.draw_texture_rect(texture, Rect2(p - Vector2(6, 10), Vector2(12, 12)), false)
				c.draw_string(FONT, p + Vector2(-34, -12), str(k).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 68, 8, Color("263e39"))
	if s.phase == "build":
		marker(c, camp_build_point(s), "MONTAR", t)
	if s.tents > 0:
		zone(c, SITE + Vector2(-28, 8), "MATERIAL")
	if s.phase == "build" and s.build_stage > 0:
		var tex: Texture2D = LAID
		if s.build_stage == 2: tex = FRAMED
		if s.build_stage == 3: tex = RAISED
		if s.build_stage >= 4: tex = TENT
		c.draw_texture_rect(tex, Rect2(camp_build_point(s) - TENT_OFFSET, TENT_SIZE), false)
	if s.phase == "commissions":
		marker(c, COMMISSION_POINTS[s.commissions], COMMISSION_NAMES[s.commissions].to_upper(), t)
	if s.phase == "expansion":
		if s.delivery == "assign":
			marker(c, next_pitch(s), "ELIGE SITIO", t)
			for i in range(s.tents - 1, mini(s.tents + 2, DAY_ONE_TENTS - 1)):
				var pitch := pitch_at(s, i)
				c.draw_rect(Rect2(pitch - TENT_GROUND, TENT_GROUND * 2.0), Color("ffed9c"), false, 1.0)
		elif s.delivery == "offer":
			marker(c, ENTRANCE, "LLEGADA", t)
		elif s.delivery == "unload":
			marker(c, SITE, "GUARDAR MATERIAL", t)
		elif s.delivery == "close":
			marker(c, ORGANIZATION, "CIERRE DEL DÍA", t)
	for i in range(s.commissions):
		zone(c, COMMISSION_POINTS[i] + Vector2(-27, 12), COMMISSION_NAMES[i].to_upper())
	# Characters are ordered by their feet, so overlapping still feels spatial.
	var actors: Array = MAP.scenery.duplicate()
	actors.append_array([
		{"name":"Patricia", "pos":npc_pos("Patricia", s, t), "tex":PATRICIA},
		{"name":"Alejandro", "pos":npc_pos("Alejandro", s, t), "tex":ALEJANDRO},
		{"name":"Marina", "pos":npc_pos("Marina", s, t), "tex":MARINA},
		{"name":"Tú", "pos":s.player, "tex":PLAYER, "walking":walking}
	])
	if s.tents > 0:
		actors.append({"pos":SITE,"pitch":0})
	if s.commissions >= 2:
		actors.append({"pos":KITCHEN, "table":true})
		for i in range(3):
			actors.append({"pos":KITCHEN + Vector2(11 + i * 7, 2), "box":true})
	for i in range(mini(s.material_boxes, 4)):
		actors.append({"pos":SITE + Vector2(8 + i * 7, 0), "box":true})
	var carriers := s.phase == "expansion" and s.delivery in ["leaving", "returning", "offer", "assign", "placing"]
	for i in range(17):
		if carriers and s.tents <= 5 and i == s.tents - 1:
			continue
		actors.append({"pos":crowd_position(i,s), "tex":CROWD_TEXTURES[i % 4], "name":""})
	if carriers:
		var pos := ENTRANCE
		match s.delivery:
			"leaving": pos = delivery_point(s, crowd_position(s.tents - 1, s), ENTRANCE)
			"returning": pos = delivery_point(s, ENTRY_APPROACH, ENTRANCE)
			"placing": pos = delivery_point(s, ENTRANCE, next_pitch(s))
		actors.append({"pos":pos, "tex":CROWD_TEXTURES[(s.tents - 1) % 4], "name":"Con tienda" if s.delivery in ["assign", "placing"] else "Llegada", "walking":s.delivery in ["leaving", "returning", "placing"]})
	for i in range(arrival_positions.size()):
		actors.append({"name":"", "pos":arrival_positions[i], "tex":CROWD_TEXTURES[i % 4]})
	for i in range(pitch_count(s)):
		actors.append({"pos": pitch_at(s, i), "pitch": i})
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for a in actors:
		if a.has("cutout"):
			MAP.draw_cutout(c, PLAZA, a.cutout)
			continue
		if a.has("box"):
			box(c, a.pos)
			continue
		if a.has("table"):
			c.draw_texture_rect(TABLE, Rect2(a.pos - Vector2(8, 13), Vector2(16, 16)), false)
			continue
		if a.has("pitch"):
			draw_pitch(c, a.pos, a.pitch)
			continue
		actor(c, a.tex, a.pos, str(a.name), t, bool(a.get("walking", s.phase not in ["talk", "meeting"])))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func camp_build_point(s: CampState) -> Vector2:
	return SITE if s.tents == 0 else next_pitch(s)

func box(c: Control, pos: Vector2) -> void:
	c.draw_rect(Rect2(pos - Vector2(3, 4), Vector2(6, 5)), Color("9a7244"))
	c.draw_line(pos - Vector2(3, 3), pos + Vector2(3, -3), Color("d0aa71"))

func zone(c: Control, pos: Vector2, text: String) -> void:
	var width := 28.0 if text.length() == 1 else 128.0
	c.draw_rect(Rect2(pos.x, pos.y, width, 23), Color(0.14, 0.22, 0.19, 0.67), true)
	c.draw_string(FONT, pos + Vector2(7, 16), text, HORIZONTAL_ALIGNMENT_LEFT, width - 8, 11, Color("fff1ce"))

func marker(c: Control, pos: Vector2, text: String, t: float) -> void:
	var r := 9.0 + sin(t * 3.0)
	c.draw_arc(pos, r, 0, TAU, 32, Color("ffed9c"), 1.0)
	c.draw_circle(pos, 1.5, Color("fff5cb"))
	c.draw_rect(Rect2(pos.x - 49, pos.y - 29, 98, 13), Color("213c35"), true)
	c.draw_string(FONT, pos + Vector2(-47, -19), text, HORIZONTAL_ALIGNMENT_CENTER, 94, 9, Color("fff0bb"))

func actor(c: Control, tex: Texture2D, pos: Vector2, name: String, t: float, walking: bool) -> void:
	c.draw_circle(pos, 4, Color(0.16, 0.14, 0.10, 0.27))
	var bob := sin(t * 9.0 + pos.x) * 0.5 if walking else sin(t * 1.7 + pos.x) * 0.15
	c.draw_texture_rect(tex, Rect2(pos + Vector2(-5, -16 + bob), Vector2(10, 17)), false)
	if name.is_empty(): return
	var text_width := ceilf(FONT.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9).x)
	var label_width := text_width + 12.0
	c.draw_rect(Rect2(pos + Vector2(-label_width / 2.0, -32 + bob), Vector2(label_width, 13)), Color(0.11, 0.19, 0.17, 0.83))
	c.draw_string(FONT, pos + Vector2(-text_width / 2.0, -22 + bob), name, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("fff9e8"))
