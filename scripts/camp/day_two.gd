extends RefCounted

const NAMES := ["Redes", "Seguridad", "Convivencia", "Punto sanitario", "Accesibilidad"]
const POINTS := [Vector2(575,410), Vector2(710,450), Vector2(795,429), Vector2(375,455), Vector2(810,395)]
const MEDIA_POINTS := [Vector2(575,410), Vector2(540,430), Vector2(650,454)]
const MEDIA := ["Retrato de Patricia", "Vídeo de Cocina", "Foto de las llegadas"]
const KINDS := ["redes", "seguridad", "convivencia", "sanitario", "accesibilidad"]
const OBJECTS := ["Lona", "Manta", "Agua", "Linterna", "Cuerda", "Piqueta"]
const MAZE := ["#######","#.....#","#.###.#","#...#.#","###.#.#","#...#.#","#.###.#","#.....#","#######"]

var mode := ""
var done := false
var score := 0
var clock := 0.0
var targets: Array = []
var cards: Array = []
var revealed: Array = []
var matched: Array = []
var npc := Vector2i(1,1)
var tweezers := Vector2.ZERO
var holding := -2
var grabbed := false
var notice := ""

func start(kind: String) -> void:
	mode = kind
	done = false
	score = 0
	clock = 0.0
	revealed.clear()
	matched.clear()
	cards = [0,1,2,3,4,5,0,1,2,3,4,5]
	cards.shuffle()
	npc = Vector2i(1,1)
	holding = -2
	grabbed = false
	notice = ""
	refresh_targets()

func refresh_targets() -> void:
	targets = ["Agitador", "Mayor", "Menor", "—", "—", "—"]
	targets.shuffle()

func tick(delta: float) -> void:
	clock += delta
	if mode == "seguridad" and clock >= 1.8:
		refresh_targets()
		clock = 0
	if mode == "convivencia" and revealed.size() == 2 and clock >= 0.85:
		revealed.clear()

func key(code: int) -> void:
	match code:
		KEY_UP, KEY_W: action("up")
		KEY_DOWN, KEY_S: action("down")
		KEY_LEFT, KEY_A: action("left")
		KEY_RIGHT, KEY_D: action("right")
		KEY_ENTER, KEY_SPACE: action("publish")

func action(value: String) -> void:
	if done: return
	match mode:
		"redes":
			done = value == "publish"
		"seguridad":
			if not value.is_valid_int(): return
			var target = targets[int(value)]
			if target == "Agitador":
				score += 1
				notice = "Aviso enviado al equipo."
				refresh_targets()
				clock = 0
			elif target != "—":
				notice = "Deja paso a las personas mayores y menores."
				score = maxi(0, score - 1)
				refresh_targets()
				clock = 0
			done = score >= 15
		"convivencia":
			if not value.is_valid_int() or revealed.size() >= 2: return
			var index := int(value)
			if index in matched or index in revealed: return
			revealed.append(index)
			if revealed.size() == 2:
				if cards[revealed[0]] == cards[revealed[1]]:
					matched.append_array(revealed)
					revealed.clear()
					done = matched.size() == cards.size()
				clock = 0
		"accesibilidad":
			var directions := {"up":Vector2i.UP, "down":Vector2i.DOWN, "left":Vector2i.LEFT, "right":Vector2i.RIGHT}
			if not directions.has(value): return
			var step: Vector2i = npc + directions[value]
			if MAZE[step.y][step.x] == "#":
				notice = "Paso bloqueado."
				return
			npc = step
			notice = ""
			done = npc == Vector2i(5,7)

func first_aid_piece() -> Vector2:
	return Vector2(92, 230 + (score % 3) * 62)

func pointer(pos: Vector2, index: int, phase: String) -> void:
	if mode != "sanitario" or done: return
	if phase == "down" and holding == -2 and pos.distance_to(first_aid_piece()) < 29:
		holding = index
		tweezers = pos
		grabbed = true
	elif index == holding:
		tweezers = pos
		if not Rect2(55,195,315,195).has_point(pos):
			grabbed = false
			notice = "Has rozado el borde. Vuelve a intentarlo."
		if phase in ["up", "cancel"]:
			if phase == "up" and grabbed and Rect2(307,200,62,187).has_point(pos):
				score += 1
				notice = "Material retirado."
				done = score == 3
			holding = -2
			grabbed = false

func draw(game: Control) -> void:
	var size: Vector2 = game.size_v
	var layout := Vector2(420, 620)
	var scale := minf((size.x - 24) / layout.x, (size.y - 24) / layout.y)
	if not game.mobile_layout: scale = minf(scale, 1.2)
	game.draw_rect(Rect2(Vector2.ZERO,size), Color(0.04,0.10,0.08,0.8))
	game.mini_scale = scale
	game.mini_rect = Rect2((size - layout * scale) * 0.5, layout * scale)
	game.draw_set_transform(game.mini_rect.position, 0.0, Vector2.ONE * scale)
	game.drawing_mini = true
	game.panel(Rect2(Vector2.ZERO,layout))
	game.button(Rect2(350,12,52,50), "×", "commission_close")
	game.text(Vector2(20,47), NAMES[KINDS.find(mode)], 29)
	match mode:
		"redes":
			game.paragraph(Vector2(20,99), "Cuenta de Instagram simulada: @acampadavalencia. Revisa y publica las tres piezas que has capturado.", 380, 21)
			for i in range(MEDIA.size()):
				game.panel(Rect2(22,205+i*78,376,62), Color("36594b"))
				game.text(Vector2(39,244+i*78), MEDIA[i], 23)
			btn(game,Rect2(22,484,376,66),"Publicar y abrir Redes","publish")
		"seguridad":
			game.paragraph(Vector2(20,99), "Señala a los agitadores neonazis para avisar al equipo. Deja pasar a mayores y menores.", 380, 21)
			for i in range(targets.size()):
				btn(game,Rect2(20+(i%2)*194,210+floori(i/2.0)*91,184,78),targets[i],str(i))
			game.text(Vector2(20,523),"Avisos correctos: %d/15" % score, 23)
		"convivencia":
			game.paragraph(Vector2(20,99), "Encuentra las parejas de material compartido para acordar cómo organizarlo.", 380, 21)
			for i in range(cards.size()):
				btn(game,Rect2(18+(i%3)*130,180+floori(i/3.0)*94,124,83),OBJECTS[cards[i]] if i in revealed or i in matched else "?",str(i))
		"sanitario":
			game.paragraph(Vector2(20,99), "Mantén pulsado para cerrar las pinzas. Arrastra cada pieza a la bandeja y suelta dentro, sin rozar el borde.", 380, 21)
			game.draw_rect(Rect2(55,195,315,195), Color("805552"))
			game.draw_rect(Rect2(307,200,62,187), Color("62866d"))
			var piece := tweezers if grabbed else first_aid_piece()
			game.draw_circle(piece, 14, Color("eecda3"))
			if holding != -2:
				game.draw_line(tweezers + Vector2(24,-35),tweezers,Color("dedfd5"),7)
				game.draw_line(tweezers + Vector2(-21,-35),tweezers,Color("dedfd5"),7)
			game.text(Vector2(35,450), "Piezas retiradas: %d/3" % score, 24)
		"accesibilidad":
			game.paragraph(Vector2(20,94), "Acompaña a la persona hasta la tienda por un camino sin obstáculos." if notice.is_empty() else "Paso bloqueado. Busca otra ruta.", 380, 20)
			for y in range(MAZE.size()):
				for x in range(MAZE[y].length()):
					var r := Rect2(63+x*42,151+y*42,40,40)
					var color := Color("465457") if MAZE[y][x] == "#" else Color("e3d5ac")
					game.draw_rect(r,color)
					if Vector2i(x,y) == Vector2i(5,7): game.text(r.position + Vector2(9,28),"T",23,Color("355e4c"),true)
					if Vector2i(x,y) == npc: game.draw_circle(r.get_center(),13,Color("286c78"))
			for i in range(4):
				btn(game,Rect2(18+i*98,545,90,58),["←","↑","↓","→"][i],["left","up","down","right"][i])
	if not notice.is_empty() and mode != "accesibilidad":
		game.paragraph(Vector2(20,570.0),notice,380,17,Color("f8d688"))
	game.drawing_mini = false
	game.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func btn(game: Control, rect: Rect2, label: String, value: String) -> void:
	game.button(rect,label,"activity:" + value)
