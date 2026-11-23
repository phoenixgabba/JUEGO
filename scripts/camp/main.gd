extends Control

const State = preload("res://scripts/camp/state.gd")
const World = preload("res://scripts/camp/world.gd")
const LICENSES = preload("res://scripts/manus/open_source_licenses.gd")
const COVER = preload("res://assets/acampada/cover.png")
const BODY = preload("res://assets/template/fonts/ui_regular.tres")
const BOLD = preload("res://assets/template/fonts/ui_bold.tres")
const TITLE = preload("res://assets/template/fonts/display/generic_title.tres")

var s: CampState = State.new()
var map_open := false
var world: CampWorld = World.new()
var screen := "title"
var paused := false
var confirm_new := false
var dialogue := false
var dialogue_speaker := ""
var dialogue_text := ""
var dialogue_next := ""
var choosing := false
var commission_open := false
var activity := preload("res://scripts/camp/activities.gd").new()
const COMMISSION_GAME := ["organization", "puzzle", "communication"]
var mini := false
var mini_piece := Vector2(240, 235)
var mini_success := 0
const LIFT_GOAL := 10.0
var mini_lift := 0.0
var mini_pegs := [false, false, false, false]
var mini_selected := 0
var dragging := false
var touch_directions := {}
var elapsed := 0.0
var evening_shade := 0.0
var save_timer := 0.0
var walking := false
var arrivals: Array = []
var toast := ""
var toast_time := 0.0
var clickables: Array = []
var world_rect := Rect2(0,0,1280,720)
var mini_rect := Rect2()
var mini_scale := 1.0
var drawing_mini := false
var portrait := false
var size_v := Vector2(1280, 720)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	set_process(true)
	set_process_input(true)
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	evening_shade = move_toward(evening_shade, s.light_level(), delta * 0.16)
	if toast_time > 0: toast_time -= delta
	if screen != "play" or paused or map_open:
		queue_redraw()
		return
	if mini:
		if s.build_stage == 0:
			var d := movement()
			mini_piece += d * delta * 250.0
			mini_piece.x = clampf(mini_piece.x, 105, 715)
			mini_piece.y = clampf(mini_piece.y, 125, 345)
		elif s.build_stage == 2:
			mini_lift = maxf(0.0, mini_lift - delta * 1.5)
	elif commission_open:
		activity.tick(delta)
		if activity.done: complete_activity()
	elif not dialogue:
		var dir := movement()
		walking = dir.length() > 0.05
		if walking:
			var movement_delta := dir * 88.0 * delta
			var steps := maxi(1, ceili(movement_delta.length() / 2.0))
			var step := movement_delta / steps
			for i in range(steps):
				var nx := s.player + Vector2(step.x, 0)
				if walkable(nx): s.player.x = nx.x
				var ny := s.player + Vector2(0, step.y)
				if walkable(ny): s.player.y = ny.y
		s.minutes += delta
		update_deliveries(delta)
		save_timer += delta
		if save_timer > 5:
			s.save_game()
			save_timer = 0
	queue_redraw()

func movement() -> Vector2:
	var d := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	for key in touch_directions:
		d += touch_directions[key]
	return d.normalized() if d.length() > 1.0 else d

func walkable(p: Vector2) -> bool:
	return World.walkable(p, s)

func update_deliveries(delta: float) -> void:
	if dialogue or mini or s.phase != "expansion":
		return
	if s.delivery not in ["leaving", "returning", "placing", "resident"]:
		return
	s.delivery_progress = minf(1.0, s.delivery_progress + delta / 1.6)
	if s.delivery == "resident":
		arrivals = [world.delivery_point(s, World.ENTRY_APPROACH, World.pitch_at(s, s.tents - 2) + Vector2(0, 8))]
	if s.delivery_progress < 1.0:
		return
	s.delivery_progress = 0.0
	match s.delivery:
		"leaving": s.delivery = "returning"
		"returning":
			s.delivery = "offer"
			announce("Ha vuelto una persona de la asamblea con su tienda.")
		"placing": install_tent(false)
		"resident": advance_expansion()
	s.save_game()

func install_tent(donated: bool) -> void:
	s.tents += 1
	s.capacity += 2
	keep_clear_of_new_shelters()
	if donated:
		s.people += 1
		s.phase = "expansion"
		s.delivery = "resident"
		s.delivery_progress = 0.0
		announce("La tienda donada está lista. Se acerca una persona para alojarse.")
	else:
		if s.tents > 6:
			s.people += 1
		advance_expansion()
	s.save_game()

func advance_expansion() -> void:
	arrivals.clear()
	s.phase = "expansion"
	s.delivery_progress = 0.0
	if s.tents < 6:
		s.delivery = "leaving"
		return
	if s.tents == 6 and s.material_boxes == 0:
		s.delivery = "unload"
		announce("Han traído cajas, mantas, agua y herramientas. Guárdalas en la primera tienda.")
		return
	if (s.commissions == 1 and s.tents >= World.KITCHEN_TENTS) or (s.commissions == 2 and s.tents >= World.COMMUNICATION_TENTS):
		s.phase = "commissions"
		s.delivery = ""
		announce("Ahora toca formar " + World.COMMISSION_NAMES[s.commissions] + ".")
		return
	s.delivery = "close" if s.tents >= World.DAY_ONE_TENTS else "offer"

func complete_activity() -> void:
	commission_open = false
	if activity.mode == "storage":
		s.material_boxes = 4
		s.phase = "commissions"
		s.delivery = ""
		keep_clear_of_new_shelters()
		s.save_game()
		open_dialog("MATERIAL COMÚN", "Almacén organizado. Vamos al punto de reunión para formar Organización.")
	else:
		form_commission()

func form_commission() -> void:
	const NOTES := [
		"Los seis referentes nos reunimos aquí para coordinar turnos y recoger acuerdos. Este será nuestro punto fijo. La carpa la montaremos más adelante.",
		"Ya tenemos mesa y comida en Cocina. Sigamos recibiendo tiendas antes de preparar el primer comunicado.",
		"Publicamos el acuerdo de la asamblea desde este punto. Quedan las últimas tiendas antes de cerrar el día."
	]
	var index := s.commissions
	s.commissions += 1
	if s.commissions == 2:
		keep_clear_of_new_shelters()
	advance_expansion()
	s.save_game()
	open_dialog(World.COMMISSION_NAMES[index].to_upper(), NOTES[index])

func keep_clear_of_new_shelters() -> void:
	if walkable(s.player):
		return
	for direction in [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]:
		var nearby: Vector2 = s.player + direction * 36.0
		if walkable(nearby):
			s.player = nearby
			return
	s.player = World.ENTRANCE

func start_game(resume: bool) -> void:
	s = State.new()
	if resume and s.load_game():
		if not walkable(s.player): s.player = World.ENTRANCE
		arrivals = []
	else:
		s.reset_save()
		s.save_game()
		arrivals = []
	evening_shade = s.light_level()
	screen = "play"
	map_open = false
	paused = false
	mini = false
	commission_open = false
	dialogue = false
	if not resume:
		open_dialog("LA PLAZA, DÍA 1", "Hay unas veinte personas en la plaza. Acércate a Patricia, Alejandro y Marina para preparar la primera asamblea.", "")
	else:
		announce("Partida recuperada. La plaza te estaba esperando.")

func announce(text: String) -> void:
	toast = text
	toast_time = 4.0

func open_dialog(speaker: String, text: String, next: String = "") -> void:
	dialogue = true
	dialogue_speaker = speaker
	dialogue_text = text
	dialogue_next = next
	choosing = next == "assembly_choice"
	walking = false

func close_dialog() -> void:
	if choosing: return
	var next := dialogue_next
	dialogue = false
	dialogue_next = ""
	if next == "show_end": screen = "result"

func choose_assembly(option: int) -> void:
	if not choosing: return
	choosing = false
	s.choice = "cuidados" if option == 0 else "materiales"
	if option == 0:
		s.wellbeing += 10
		s.respect += 20
	else:
		s.cash += 8
		s.respect += 15
	s.phase = "materials"
	s.save_game()
	open_dialog("ASAMBLEA", "Acordamos quedarnos y acampar. La primera tienda será común y servirá para guardar material. Busquemos lona, varillas y piquetas.", "")

func interact() -> void:
	if screen != "play": return
	if paused or commission_open: return
	if dialogue:
		if not choosing: close_dialog()
		return
	if mini:
		mini_action()
		return
	if s.phase == "meeting" and s.player.distance_to(World.MEETING) < 100:
		open_dialog("PRIMERA ASAMBLEA", "Patricia: Nos hemos juntado espontáneamente. ¿Y si nos quedamos a acampar? Empezamos con una tienda común. ¿Qué priorizamos al arrancar?", "assembly_choice")
		return
	if s.phase == "materials":
		var nearest := ""
		var dist := 75.0
		for key in World.MATERIALS:
			var d: float = s.player.distance_to(World.MATERIALS[key])
			if not s.collected[key] and d < dist:
				dist = d
				nearest = str(key)
		if nearest != "":
			s.collected[nearest] = true
			s.respect += 5
			s.energy = maxi(0, s.energy - 2)
			announce("Recogido: " + nearest + ".")
			if s.all_collected():
				s.phase = "build"
				open_dialog("ALEJANDRO", "¡Todo listo! Ven al espacio marcado en la zona B y montemos la tienda paso a paso.", "")
			s.save_game()
			return
	if s.phase == "build" and s.player.distance_to(World.camp_build_point(s)) < (100.0 if s.tents == 0 else 26.0):
		mini = true
		mini_piece = Vector2(240, 235)
		mini_success = 0
		mini_lift = 0.0
		mini_pegs = [false, false, false, false]
		mini_selected = 0
		return
	if s.phase == "commissions" and s.player.distance_to(World.COMMISSION_POINTS[s.commissions]) < 38:
		commission_open = true
		activity.start(COMMISSION_GAME[s.commissions])
		return
	if s.phase == "expansion" and interact_with_delivery():
		return
	var nearest_npc := ""
	var distance := 88.0
	for n in ["Patricia", "Alejandro", "Marina"]:
		var d := s.player.distance_to(world.npc_pos(n, s, elapsed))
		if d < distance:
			distance = d
			nearest_npc = n
	if nearest_npc != "":
		talk_to(nearest_npc)
	else:
		announce("Acércate a una persona o a un objeto marcado para interactuar.")

func interact_with_delivery() -> bool:
	match s.delivery:
		"offer":
			if s.player.distance_to(World.ENTRANCE) > 42: return false
			if s.tents < 6 or s.tents % 3 != 0:
				s.delivery = "assign"
				open_dialog("LLEGADA", "He traído mi propia tienda. Acércate a uno de los huecos marcados y usa Acción para indicarme dónde montarla.")
			else:
				s.delivery = "donation"
				s.build_stage = 0
				s.phase = "build"
				open_dialog("DONACIÓN", "Traemos una tienda para quien la necesite. Móntala en el sitio marcado.")
		"assign":
			if not World.assign_pitch(s): return false
			s.delivery = "placing"
			s.delivery_progress = 0.0
		"unload":
			if s.player.distance_to(World.SITE) > 30: return false
			activity.start("storage")
			commission_open = true
		"close":
			if s.player.distance_to(World.ORGANIZATION) > 38: return false
			s.phase = "finished"
			s.delivery = ""
			open_dialog("CIERRE DEL DÍA", "Terminamos el día con 25 tiendas y tres comisiones. Mañana seguimos.", "show_end")
		_: return false
	s.save_game()
	return true

func talk_to(n: String) -> void:
	if s.phase == "talk" and not s.talked[n]:
		s.talked[n] = true
		s.respect += 10
		var lines := {
			"Patricia": "Soy Patricia. Una plaza no se ocupa solo con tiendas: se llena de escucha. ¿Te quedas para la primera asamblea?",
			"Alejandro": "Soy Alejandro. Hay materiales por aquí y sé montar tiendas. Primero decidamos cómo hacerlo entre todas.",
			"Marina": "Soy Marina. Podemos construir un lugar donde cada persona tenga voz. Nos reunimos en el centro cuando estemos listas."
		}
		if s.all_talked(): s.phase = "meeting"
		s.save_game()
		open_dialog(n.to_upper(), lines[n], "")
	else:
		var line := "La plaza es de quienes la cuidan. Seguimos juntas."
		if s.phase == "meeting": line = "Nos vemos en el círculo del centro para decidir juntas."
		if s.phase == "materials": line = "Busca los materiales brillantes. Cada pieza cuenta."
		if s.phase == "build": line = "Te ayudamos desde aquí. La lona, las varillas y las piquetas van por turnos."
		if s.phase == "expansion": line = "La primera tienda es para el material común. Las demás darán cobijo."
		if s.phase in ["commissions", "finished"]: line = "Nos reunimos en Organización, delante del Ayuntamiento."
		open_dialog(n.to_upper(), line, "")

func mini_action() -> void:
	match s.build_stage:
		0:
			if mini_piece.distance_to(Vector2(560,235)) < 55: complete_build_stage()
			else: announce("Mueve la lona hasta el círculo dorado.")
		1:
			var needle := (sin(elapsed * 2.9) + 1.0) / 2.0
			if needle >= 0.30 and needle <= 0.70:
				mini_success += 1
				if mini_success >= 2: complete_build_stage()
				else: announce("¡Una varilla encajada! Falta otra.")
			else: announce("Casi: espera a que el indicador entre en la franja verde.")
		2:
			mini_lift += 1.0
			if mini_lift >= LIFT_GOAL: complete_build_stage()
		3:
			mini_pegs[mini_selected] = true
			if not mini_pegs.has(false): complete_build_stage()
			else:
				for i in range(4):
					if not mini_pegs[i]:
						mini_selected = i
						break

func complete_build_stage() -> void:
	if not mini: return
	s.build_stage += 1
	s.energy = maxi(0, s.energy - 5)
	s.respect += 12
	mini = false
	dragging = false
	if s.build_stage == 4:
		if s.tents == 0:
			s.tents = 1
			advance_expansion()
			if s.player.distance_to(World.SITE) < 9:
				s.player = World.clear_spot(World.SITE + Vector2(0, 15), s)
			open_dialog("ALEJANDRO", "Ya tenemos un sitio para guardar material. Cinco personas de la asamblea van a buscar sus tiendas.")
		else:
			install_tent(true)
	else:
		var lines := ["La lona ya está extendida sobre el suelo.", "Las varillas quedan ensambladas sobre la lona.", "La estructura está levantada; solo falta asegurarla."]
		open_dialog("MONTAJE", lines[s.build_stage - 1] + " Acércate de nuevo para continuar.", "")
	s.save_game()

func objective() -> String:
	match s.phase:
		"talk": return "Conoce a Patricia, Alejandro y Marina  ·  %d/3" % [int(s.talked.Patricia) + int(s.talked.Alejandro) + int(s.talked.Marina)]
		"meeting": return "Ve al círculo central y participa en la primera asamblea."
		"materials": return "Recoge lona, varillas y piquetas  ·  %d/3" % s.resources()
		"build": return "Monta la tienda marcada · paso %d/4 · %d/25 tiendas" % [s.build_stage + 1, s.tents]
		"commissions": return "Forma %s (%d/3)" % [World.COMMISSION_NAMES[s.commissions], s.commissions]
		"expansion":
			var instruction: String = {
				"leaving":"Deja que vaya a buscar su tienda", "returning":"Espera a que vuelva con su tienda",
				"offer":"Habla con quien acaba de llegar", "assign":"Indica dónde montar la tienda",
				"placing":"La persona está montando su tienda", "resident":"Recibe a la persona que ocupará la tienda",
				"unload":"Guarda el material en la primera tienda", "close":"Cierra el día en Organización",
			}.get(s.delivery, "")
			return "%s · %d/%d tiendas" % [instruction, s.tents, World.DAY_ONE_TENTS]
		"finished": return "Día 1 cerrado · 25 tiendas y 3 comisiones"
	return "Explora la plaza."

func _draw() -> void:
	size_v = get_viewport_rect().size
	portrait = size_v.y > size_v.x * 1.15
	clickables.clear()
	draw_rect(Rect2(Vector2.ZERO,size_v), Color("e5dcc3"), true)
	if screen == "title":
		draw_title()
		return
	var wy := maxf(0.0, (size_v.y - size_v.x * 0.5625) * 0.30)
	var zoom := 2.1 if portrait else 2.25
	var world_width := size_v.x * zoom
	var world_height := world_width * 0.5625
	var camera_x := clampf(size_v.x * 0.5 - s.player.x / 1280.0 * world_width, size_v.x - world_width, 0.0)
	if world_height > size_v.y:
		wy = clampf(size_v.y * 0.55 - s.player.y / 720.0 * world_height, size_v.y - world_height, 0.0)
	world_rect = Rect2(camera_x, wy, world_width, world_height)
	world.draw(self, s, world_rect, elapsed, walking, arrivals)
	draw_rect(world_rect, Color(0.12, 0.16, 0.34, evening_shade))
	if map_open:
		draw_camp_map()
		return
	draw_hud()
	if screen == "play":
		if not mini and not dialogue and not paused and not commission_open: draw_touch_controls()
		if toast_time > 0 and not dialogue and not mini: draw_toast()
		if commission_open:
			clickables.clear()
			activity.draw(self)
		if mini:
			clickables.clear()
			draw_minigame()
		if dialogue:
			clickables.clear()
			draw_dialog()
		if paused:
			clickables.clear()
			draw_pause()
	elif screen == "result":
		clickables.clear()
		draw_result()

func panel(r: Rect2, fill: Color = Color("203d35"), border: Color = Color("eed29b")) -> void:
	draw_rect(r.grow(4), Color(0.11,0.17,0.15,0.32), true)
	draw_rect(r, fill, true)
	draw_rect(r, border, false, 2)

func text(pos: Vector2, value: String, font_size: int, color: Color = Color("fff5df"), bold: bool = false, width: float = -1, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(BOLD if bold else BODY, pos, value, align, width, font_size, color)

func wrap_lines(value: String, font: Font, font_size: int, width: float) -> Array:
	var lines: Array = []
	var line := ""
	for word in value.split(" "):
		var candidate := word if line == "" else line + " " + word
		if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > width and line != "":
			lines.append(line)
			line = word
		else: line = candidate
	if line != "": lines.append(line)
	return lines

func paragraph(p: Vector2, value: String, width: float, font_size: int, color: Color = Color("fff5df"), line_height: float = 1.35) -> void:
	var y := p.y
	for line in wrap_lines(value, BODY, font_size, width):
		text(Vector2(p.x,y), line, font_size, color)
		y += font_size * line_height

func button(r: Rect2, label: String, id: String, highlight: bool = false) -> void:
	var col := Color("f0bc66") if highlight else Color("36594b")
	draw_rect(r, col, true)
	draw_rect(r, Color("f7daa0"), false, 2)
	var fs := 22 if drawing_mini or not portrait else 36
	text(Vector2(r.position.x, r.position.y + r.size.y * 0.63), label, fs, Color("27392f") if highlight else Color("fff5df"), true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
	clickables.append({"rect":mini_hit(r) if drawing_mini else r, "id":id})

func mini_hit(r: Rect2) -> Rect2:
	return Rect2(mini_rect.position + r.position * mini_scale, r.size * mini_scale)

func draw_title() -> void:
	draw_texture_rect(COVER, Rect2(Vector2.ZERO,size_v), false)
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.10,0.18,0.15,0.30), true)
	var w := minf(590, size_v.x - 56)
	var x := 42.0 if not portrait else (size_v.x - w) / 2
	var y := 72.0 if not portrait else size_v.y * 0.16
	panel(Rect2(x,y,w,520), Color(0.10,0.20,0.17,0.92))
	text(Vector2(x+30,y+45), "UN JUEGO DE PLAZA Y COMUNIDAD", 15, Color("f1c873"), true)
	draw_string(TITLE, Vector2(x+27,y+120), "ACAMPADA", HORIZONTAL_ALIGNMENT_LEFT, w-40, 53, Color("fff2d7"))
	draw_string(TITLE, Vector2(x+27,y+177), "VALÈNCIA", HORIZONTAL_ALIGNMENT_LEFT, w-40, 53, Color("f5bf6d"))
	paragraph(Vector2(x+32,y+220), "Un primer día para escucharnos, levantar refugio y hacer sitio a quienes llegan.", w-64, 22)
	var has_save := FileAccess.file_exists(State.SAVE_PATH)
	button(Rect2(x+32,y+300,w-64,54), "CONTINUAR PARTIDA" if has_save else "EMPEZAR EL DÍA 1", "continue" if has_save else "start", true)
	if has_save: button(Rect2(x+32,y+366,w-64,45), "NUEVA PARTIDA", "new")
	text(Vector2(x+34,y+448), "WASD / flechas para caminar   ·   E para interactuar", 16, Color("d4e0cb"))
	text(Vector2(x+34,y+476), "En móvil: cruceta y botón de acción", 16, Color("d4e0cb"))
	text(Vector2(x+34,y+503), "Licencias de código abierto", 14, Color("eecb89"))
	clickables.append({"rect":Rect2(x+30,y+482,240,32),"id":"licenses"})
	if confirm_new:
		draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.10,0.08,0.75), true)
		var r := Rect2(size_v.x/2-260,size_v.y/2-135,520,270)
		panel(r, Color("f8edce"), Color("29453a"))
		text(r.position+Vector2(25,48), "¿Empezar de nuevo?", 27, Color("29453a"), true)
		paragraph(r.position+Vector2(25,88), "Se borrará la partida guardada en este dispositivo.", 470, 18, Color("405446"))
		clickables.clear()
		button(Rect2(r.position+Vector2(25,140),Vector2(470,45)), "SÍ, NUEVA PARTIDA", "confirm_new", true)
		button(Rect2(r.position+Vector2(25,200),Vector2(470,45)), "CANCELAR", "cancel_new")

func draw_hud() -> void:
	if portrait:
		panel(Rect2(16,16,size_v.x-32,150), Color(0.11,0.22,0.19,0.95))
		text(Vector2(42,62), "ACAMPADA VALÈNCIA · " + s.daylight(), 31, Color("fff2d7"), true)
		text(Vector2(42,111), "DÍA 1  ·  VIDA %d   ENERGÍA %d   RESPETO %d" % [s.health,s.energy,s.respect], 25, Color("f3ce89"), true)
		text(Vector2(42,148), "CAJA %d €   ·   RECURSOS %d   ·   BIENESTAR %d   ·   PERSONAS %d" % [s.cash,s.resources(),s.wellbeing,s.people], 21)
		var oy := minf(world_rect.end.y + 24, size_v.y * 0.58)
		panel(Rect2(22,oy,size_v.x-44,140), Color(0.13,0.25,0.20,0.96))
		text(Vector2(48,oy+42), "AHORA EN LA PLAZA", 23, Color("f2c66f"), true)
		paragraph(Vector2(48,oy+83), objective(), size_v.x-100, 27)
		draw_portrait_diary(oy + 164)
		button(Rect2(size_v.x-160,22,125,55), "PAUSA", "pause")
	else:
		panel(Rect2(14,14,size_v.x-28,62), Color(0.10,0.20,0.17,0.95))
		text(Vector2(32,40), "ACAMPADA", 19, Color("f6ce80"), true)
		text(Vector2(32,62), "DÍA 1 · %s · %02d:00" % [s.daylight(), s.clock_hour()], 13, Color("fff3d9"), true)
		text(Vector2(225,51), "VIDA %d    ENERGÍA %d    RESPETO %d    CAJA %d €    RECURSOS %d    BIENESTAR %d    PERSONAS %d" % [s.health,s.energy,s.respect,s.cash,s.resources(),s.wellbeing,s.people], 16, Color("fff6e2"), true)
		button(Rect2(size_v.x-105,23,76,42), "Ⅱ", "pause")
		panel(Rect2(size_v.x-327,94,305,94), Color(0.12,0.23,0.19,0.91))
		text(Vector2(size_v.x-309,121), "AHORA EN LA PLAZA", 13, Color("eac379"), true)
		paragraph(Vector2(size_v.x-309,145), objective(), 268, 16)

func draw_portrait_diary(y: float) -> void:
	var available := size_v.y - y - 420.0
	if available < 300: return
	var h := minf(available, 590.0)
	var x := 22.0
	panel(Rect2(x,y,size_v.x-44,h), Color("f9f0da"), Color("91a78b"))
	text(Vector2(x+26,y+42), "DIARIO DE LA PLAZA", 29, Color("b26743"), true)
	var order := ["talk", "meeting", "materials", "build", "commissions", "expansion", "finished"]
	var index := order.find(s.phase)
	var labels := ["Conocer a las primeras personas", "Celebrar la primera asamblea", "Reunir los materiales", "Levantar y asegurar la tienda", "Formar tres comisiones", "Montar 25 tiendas y cerrar el día"]
	var row := minf(67.0, (h-92)/6.0)
	for i in range(6):
		var yy := y+82+i*row
		var done := index > i
		draw_circle(Vector2(x+42,yy-8), 12, Color("6c9d70") if done else Color("d8c9a7"))
		if done: text(Vector2(x+33,yy-2), "+", 18, Color("ffffff"), true)
		text(Vector2(x+70,yy), labels[i], 29, Color("344d3d") if done else Color("7d8975"), done)
	if h > 500:
		text(Vector2(x+26,y+h-27), "Cruceta para caminar · ACCIÓN cerca de personas y objetos", 23, Color("748873"))

func toggle_map() -> void:
	map_open = not map_open
	touch_directions.clear()
	clickables.clear()
	queue_redraw()

func draw_camp_map() -> void:
	draw_rect(Rect2(Vector2.ZERO, size_v), Color(0.04,0.09,0.07,0.94))
	var width := minf(size_v.x - 44, (size_v.y - 205) * 16.0 / 9.0)
	var start := Vector2((size_v.x - width) / 2.0, 70)
	var scale := width / 1280.0
	var map_rect := Rect2(start, Vector2(width,720 * scale))
	text(start + Vector2(0,-22), "Mapa · %d/%d tiendas" % [s.tents, World.DAY_ONE_TENTS], 20)
	button(Rect2(map_rect.end.x - 118,10,118,44), "Cerrar", "map")
	draw_texture_rect(World.PLAZA, map_rect, false)
	for i in range(World.pitch_count(s)):
		var point := start + World.pitch_at(s,i) * scale
		draw_circle(point, 3.0, Color("b0db96"))
	var points := world.map_locations(s, elapsed)
	var offset_counts := {}
	for i in range(points.size()):
		var item := points[i]
		var point: Vector2 = start + item.pos * scale
		var count: int = offset_counts.get(point,0)
		offset_counts[point] = count + 1
		if count > 0: point.x += count * 22
		var color := Color("f5c172") if item.kind == "goal" else (Color("a3d58b") if item.kind == "built" else Color("8bd5ed"))
		draw_circle(point,11,Color("172723"))
		draw_arc(point,11,0,TAU,26,color,2)
		text(point + Vector2(-11,5),str(i+1),13,color,true,22,HORIZONTAL_ALIGNMENT_CENTER)
		var columns := 2 if width < 680 else 3
		var column_width := width / columns
		var label_pos := map_rect.end - Vector2(width,0) + Vector2(i % columns * column_width, 27 + floori(float(i) / columns) * 25)
		text(label_pos,"%d  %s" % [i+1,item.label],16,color,true,column_width)

func draw_touch_controls() -> void:
	var y := size_v.y - (210 if portrait else 105)
	var x := 205.0 if portrait else 106.0
	var step := 92.0 if portrait else 50.0
	var radius := 50.0 if portrait else 29.0
	var dirs := [{"v":Vector2.LEFT,"p":Vector2(x-step,y),"icon":"‹"}, {"v":Vector2.RIGHT,"p":Vector2(x+step,y),"icon":"›"}, {"v":Vector2.UP,"p":Vector2(x,y-step),"icon":"^"}, {"v":Vector2.DOWN,"p":Vector2(x,y+step),"icon":"v"}]
	for d in dirs:
		draw_circle(d.p, radius, Color(0.10,0.21,0.18,0.72))
		draw_arc(d.p, radius, 0, TAU, 30, Color(0.98,0.89,0.69,0.65), 2)
		text(d.p + Vector2(-radius, radius*0.38), d.icon, 42 if portrait else 28, Color("fff5dc"), true, radius*2, HORIZONTAL_ALIGNMENT_CENTER)
		clickables.append({"rect":Rect2(d.p-Vector2(radius,radius),Vector2(radius*2,radius*2)),"id":"dir","dir":d.v})
	var ap := Vector2(size_v.x-(135 if portrait else 78), y)
	var ar := 75.0 if portrait else 47.0
	draw_circle(ap, ar, Color("efbe6b"))
	draw_arc(ap, ar, 0, TAU, 40, Color("fff2ce"), 3)
	text(ap+Vector2(-ar,8), "ACCIÓN", 21 if portrait else 14, Color("263d32"), true, ar*2, HORIZONTAL_ALIGNMENT_CENTER)
	clickables.append({"rect":Rect2(ap-Vector2(ar,ar),Vector2(ar*2,ar*2)),"id":"action"})
	var map_radius := ar * 0.68
	var map_pos := ap - Vector2(0, ar + map_radius + 13)
	draw_circle(map_pos, map_radius, Color("36594b"))
	draw_arc(map_pos, map_radius, 0, TAU, 36, Color("fff2ce"), 2)
	text(map_pos + Vector2(-map_radius, 5), "MAPA", 18 if portrait else 12, Color("fff5df"), true, map_radius * 2, HORIZONTAL_ALIGNMENT_CENTER)
	clickables.append({"rect":Rect2(map_pos - Vector2.ONE * map_radius,Vector2.ONE * map_radius * 2), "id":"map"})
	if not portrait: text(Vector2(224,size_v.y-21), "CAMINAR: WASD / FLECHAS    ·    INTERACTUAR: E   ·   MAPA: M", 13, Color("fff5df"), true)

func draw_toast() -> void:
	var y := minf(world_rect.end.y - 68, size_v.y - 95) if not portrait else size_v.y * 0.72
	var w := 690.0 if not portrait else 1100.0
	panel(Rect2((size_v.x-w)/2,y,w,44 if not portrait else 65), Color(0.12,0.24,0.19,0.94))
	text(Vector2((size_v.x-w)/2+12,y+(29 if not portrait else 43)), toast, 16 if not portrait else 24, Color("fff4d7"), true, w-24, HORIZONTAL_ALIGNMENT_CENTER)

func draw_dialog() -> void:
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.05,0.11,0.09,0.42), true)
	var w := 890.0 if not portrait else 1120.0
	var h := 196.0 if not portrait else (560.0 if choosing else 400.0)
	var x := (size_v.x-w)/2
	var y := size_v.y-h-45 if not portrait else maxf(20, size_v.y-h-105)
	var r := Rect2(x,y,w,h)
	panel(r, Color("f8edce"), Color("243d33"))
	text(Vector2(x+25,y+37), dialogue_speaker, 18 if not portrait else 34, Color("b65c3e"), true)
	paragraph(Vector2(x+25,y+72), dialogue_text, w-50, 20 if not portrait else 35, Color("273f35"))
	if choosing:
		if portrait:
			button(Rect2(x+24,y+h-225,w-48,90), "1 · Cuidar a las personas", "choice0", true)
			button(Rect2(x+24,y+h-115,w-48,90), "2 · Reunir recursos", "choice1")
		else:
			var by := y+h-62
			button(Rect2(x+24,by,(w-60)/2,45), "1 · Cuidar a las personas", "choice0", true)
			button(Rect2(x+36+(w-60)/2,by,(w-60)/2,45), "2 · Reunir recursos", "choice1")

	else:
		text(Vector2(x+25,y+h-22), "E / ESPACIO  ·  CONTINUAR", 14 if not portrait else 29, Color("6b7d69"), true)
		clickables.append({"rect":r,"id":"dialog"})

func draw_pause() -> void:
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.10,0.08,0.75), true)
	var r := Rect2(size_v.x/2-260, size_v.y/2-195, 520, 390)
	panel(r)
	text(r.position+Vector2(30,54), "EN PAUSA", 34, Color("f1c578"), true)
	paragraph(r.position+Vector2(30,94), "Tu progreso se guarda automáticamente en este dispositivo.", 455, 20)
	button(Rect2(r.position+Vector2(30,140),Vector2(460,52)), "CONTINUAR", "unpause", true)
	button(Rect2(r.position+Vector2(30,208),Vector2(460,52)), "VOLVER AL INICIO", "title")
	button(Rect2(r.position+Vector2(30,276),Vector2(460,52)), "LICENCIAS", "licenses")

func draw_result() -> void:
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.11,0.08,0.78), true)
	var r := Rect2(size_v.x/2-355, size_v.y/2-235, 710, 470)
	panel(r, Color("f8edce"), Color("233f34"))
	text(r.position+Vector2(36,50), "LA PLAZA YA NO ESTÁ VACÍA", 17, Color("b45f40"), true)
	text(r.position+Vector2(36,102), "Día 1 completado", 38, Color("263e32"), true)
	paragraph(r.position+Vector2(36,153), "Hay 25 tiendas, incluida la de material común. Organización y Comunicación tienen puntos de reunión y Cocina ya cuenta con una mesa y cajas de comida.", 635, 21, Color("314a3c"))
	text(r.position+Vector2(36,264), "RESPETO %d    ·    PERSONAS %d    ·    ALOJAMIENTO %d" % [s.respect,s.people,s.capacity], 18, Color("63745b"), true)
	button(Rect2(r.position+Vector2(36,302),Vector2(638,55)), "SEGUIR EXPLORANDO", "explore", true)
	button(Rect2(r.position+Vector2(36,375),Vector2(638,45)), "VOLVER AL INICIO", "title")

func draw_minigame() -> void:
	draw_rect(Rect2(Vector2.ZERO,size_v), Color(0.04,0.10,0.08,0.75), true)
	mini_scale = minf(1.4 if portrait else 1.0, minf((size_v.x - 20.0) / 820.0, (size_v.y - 20.0) / 500.0))
	var y := (size_v.y - 500.0 * mini_scale) / 2.0
	mini_rect = Rect2((size_v.x-820*mini_scale)/2,y,820*mini_scale,500*mini_scale)
	draw_set_transform(mini_rect.position, 0.0, Vector2.ONE * mini_scale)
	drawing_mini = true
	var p := Vector2.ZERO
	panel(Rect2(0,0,820,500), Color("f8edce"), Color("29453a"))
	var names := ["1. EXTIENDE LA LONA", "2. ENSAMBLA LAS VARILLAS", "3. LEVANTA LA ESTRUCTURA", "4. ASEGURA LAS PIQUETAS"]
	text(p+Vector2(28,42), names[s.build_stage], 25, Color("2a4839"), true)
	button(Rect2(p+Vector2(720,12),Vector2(75,44)), "X", "mini_close")
	if s.build_stage == 0:
		paragraph(p+Vector2(28,76), "Arrastra la lona al círculo. En PC: flechas y E.", 750, 22, Color("405446"))
		draw_circle(p+Vector2(560,235), 75, Color(0.91,0.73,0.36,0.24))
		draw_arc(p+Vector2(560,235), 70, 0, TAU, 40, Color("be8e3e"), 4)
		draw_texture_rect(World.TARP, Rect2(p+mini_piece-Vector2(55,55),Vector2(110,110)), false)
		text(p+Vector2(450,355), "DESTINO", 15, Color("927339"), true, 220, HORIZONTAL_ALIGNMENT_CENTER)
		button(Rect2(p+Vector2(290,406),Vector2(240,50)), "COLOCAR · E", "mini_action", true)
	elif s.build_stage == 1:
		paragraph(p+Vector2(28,76), "Dos varillas: pulsa cuando el indicador esté en verde.", 750, 22, Color("405446"))
		draw_texture_rect(World.FRAMED, Rect2(p+Vector2(320,105),Vector2(180,150)), false)
		draw_rect(Rect2(p+Vector2(130,285),Vector2(560,30)), Color("cdbf9e"), true)
		draw_rect(Rect2(p+Vector2(298,285),Vector2(224,30)), Color("77a878"), true)
		var needle := (sin(elapsed*2.9)+1.0)/2.0
		draw_rect(Rect2(p+Vector2(130+needle*560-5,275),Vector2(10,50)), Color("be5d40"), true)
		text(p+Vector2(0,355), "ENCAJADAS %d / 2" % mini_success, 18, Color("345445"), true, 820, HORIZONTAL_ALIGNMENT_CENTER)
		button(Rect2(p+Vector2(290,406),Vector2(240,50)), "ENCAJAR · E", "mini_action", true)
	elif s.build_stage == 2:
		paragraph(p+Vector2(28,76), "Pulsa E o el botón repetidamente para levantar la tienda. La barra baja si paras.", 750, 22, Color("405446"))
		draw_texture_rect(World.RAISED, Rect2(p+Vector2(310,100),Vector2(200,180)), false)
		draw_rect(Rect2(p+Vector2(145,305),Vector2(530,24)), Color("cabd9c"), true)
		draw_rect(Rect2(p+Vector2(145,305),Vector2(530*clampf(mini_lift/LIFT_GOAL,0,1),24)), Color("64a276"), true)
		button(Rect2(p+Vector2(265,386),Vector2(290,65)), "PULSA RÁPIDO · E", "mini_action", true)
	else:
		paragraph(p+Vector2(28,76), "Toca las cuatro piquetas. En PC: flechas y E.", 750, 22, Color("405446"))
		draw_texture_rect(World.RAISED, Rect2(p+Vector2(292,112),Vector2(236,220)), false)
		var pts := [Vector2(250,160),Vector2(570,160),Vector2(250,327),Vector2(570,327)]
		for i in range(4):
			var pt: Vector2 = p+pts[i]
			draw_circle(pt, 25, Color("68a577") if mini_pegs[i] else Color("e9b15f"))
			draw_arc(pt, 29 if i == mini_selected else 25, 0, TAU, 28, Color("354f3d"), 3)
			text(pt+Vector2(-20,7), "OK" if mini_pegs[i] else str(i+1), 20, Color("263e32"), true, 40, HORIZONTAL_ALIGNMENT_CENTER)
			clickables.append({"rect":mini_hit(Rect2(pt-Vector2(35,35),Vector2(70,70))),"id":"peg%d" % i})
		button(Rect2(p+Vector2(290,406),Vector2(240,50)), "ASEGURAR · E", "mini_action", true)
	if toast_time > 0: text(p+Vector2(28,390), toast, 15, Color("a05739"), true)
	text(p+Vector2(28,478), "ESC: CERRAR Y CONTINUAR DESPUÉS", 13, Color("657b69"), true)
	drawing_mini = false
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if commission_open:
			if event.keycode == KEY_ESCAPE:
				commission_open = false
			else:
				activity.key(event.keycode)
			return
		if event.keycode == KEY_M and screen == "play" and not mini and not dialogue and not paused:
			toggle_map()
			return
		if map_open:
			if event.keycode == KEY_ESCAPE: toggle_map()
			return
		if event.keycode == KEY_ESCAPE:
			if mini: mini = false
			elif dialogue: pass
			elif screen == "play": paused = not paused
			return
		if choosing and event.keycode in [KEY_1,KEY_KP_1]: choose_assembly(0); return
		if choosing and event.keycode in [KEY_2,KEY_KP_2]: choose_assembly(1); return
		if mini and s.build_stage == 3 and event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN,KEY_A,KEY_D,KEY_W,KEY_S]:
			mini_selected = (mini_selected + 1) % 4
			return
		if event.keycode in [KEY_E,KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]:
			if screen == "title" and not confirm_new: start_game(FileAccess.file_exists(State.SAVE_PATH))
			elif screen == "result": screen = "play"
			else: interact()
			return
	if event is InputEventScreenTouch:
		if event.pressed: pointer_down(event.position, event.index)
		else: pointer_up(event.position, event.index)
	elif event is InputEventScreenDrag:
		if dragging and mini and s.build_stage == 0: mini_piece = (event.position - mini_rect.position) / mini_scale
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: pointer_down(event.position, -1)
		else: pointer_up(event.position, -1)
	elif event is InputEventMouseMotion and dragging and mini and s.build_stage == 0:
		mini_piece = (event.position - mini_rect.position) / mini_scale

func pointer_down(pos: Vector2, index: int) -> void:
	if mini and s.build_stage == 0 and pos.distance_to(mini_rect.position+mini_piece*mini_scale) < 75*mini_scale:
		dragging = true
		return
	for entry in clickables:
		if entry.rect.has_point(pos):
			var id: String = entry.id
			if commission_open:
				if id == "commission_close": commission_open = false
				elif id.begins_with("activity:"): activity.action(id.trim_prefix("activity:"))
				return
			match id:
				"start": start_game(false)
				"continue": start_game(true)
				"new": confirm_new = true
				"confirm_new": confirm_new = false; start_game(false)
				"cancel_new": confirm_new = false
				"licenses": LICENSES.open(self)
				"pause": paused = true; s.save_game()
				"unpause": paused = false
				"title": paused = false; screen = "title"; s.save_game()
				"explore": screen = "play"
				"dialog": close_dialog()
				"choice0": choose_assembly(0)
				"choice1": choose_assembly(1)
				"dir": touch_directions[index] = entry.dir
				"action": interact()
				"map": toggle_map()
				"mini_action": mini_action()
				"mini_close": mini = false
				_:
					if id.begins_with("peg"):
						mini_selected = int(id.substr(3))
						mini_action()
			return

func pointer_up(_pos: Vector2, index: int) -> void:
	touch_directions.erase(index)
	if dragging:
		dragging = false
		if mini and s.build_stage == 0 and mini_piece.distance_to(Vector2(560,235)) < 65: complete_build_stage()
