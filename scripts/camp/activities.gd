extends RefCounted

const SCORE_GOAL := 1000
const FOOD_GOAL := 20
const TITLE := "ENS QUEDEM A ACAMPAR"
const SHAPES := [
	[Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)],
	[Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)],
	[Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)],
	[Vector2i(-1,0),Vector2i(0,0),Vector2i(1,0),Vector2i(1,1)],
]
const COLORS := [Color("e7ae65"), Color("75a493"), Color("c48476"), Color("8a83a7")]
var mode := ""
var clock := 0.0
var done := false
var failed := false
var score := 0
var turn := 0
var board := {}
var piece: Array[Vector2i] = []
var cell := Vector2i(3, 0)
var guesses := ""
var errors := 0
var puzzle := [1, 2, 0, 4, 5, 3]
var picked := -1
var falling: Array[Dictionary] = []
var player_lane := 2
var food := 0
var strikes := 0
const AGENDA_TOPICS := ["Acords", "Torns", "Materials", "Propostes"]
const AGENDA_ROUNDS := 3
const AGENDA_BEAT := 0.85
var agenda: Array[int] = []
var agenda_position := 0
var agenda_preview := true
var agenda_retry := false

func start(activity: String) -> void:
	mode = activity
	clock = 0
	done = false
	failed = false
	score = 0
	turn = 0
	board.clear()
	guesses = ""
	errors = 0
	puzzle = [1, 2, 0, 4, 5, 3]
	picked = -1
	falling.clear()
	agenda.clear()
	agenda_position = 0
	agenda_preview = true
	agenda_retry = false
	player_lane = 2
	food = 0
	strikes = 0
	if mode == "storage":
		spawn_piece()
	elif mode == "organization":
		for i in range(3):
			agenda.append(next_topic())

func next_topic() -> int:
	if agenda.is_empty():
		return randi_range(0, AGENDA_TOPICS.size() - 1)
	return (agenda.back() + randi_range(1, AGENDA_TOPICS.size() - 1)) % AGENDA_TOPICS.size()

func spawn_piece() -> void:
	cell = Vector2i(3, 0)
	piece.assign(SHAPES[turn % SHAPES.size()])
	if not fits(cell, piece):
		failed = true

func fits(origin: Vector2i, shape: Array[Vector2i]) -> bool:
	for offset in shape:
		var p := origin + offset
		if p.x < 0 or p.x >= 8 or p.y >= 12 or board.has(p):
			return false
	return true

func drop() -> void:
	if fits(cell + Vector2i.DOWN, piece):
		cell += Vector2i.DOWN
		return
	for offset in piece:
		var p := cell + offset
		if p.y < 0:
			failed = true
			return
		board[p] = turn % COLORS.size()
	var compacted := {}
	var destination := 11
	for y in range(11, -1, -1):
		var count := 0
		for x in range(8):
			count += int(board.has(Vector2i(x,y)))
		if count == 8:
			score += 100
			continue
		for x in range(8):
			if board.has(Vector2i(x,y)):
				compacted[Vector2i(x,destination)] = board[Vector2i(x,y)]
		destination -= 1
	board = compacted
	if score >= SCORE_GOAL:
		done = true
	else:
		turn += 1
		spawn_piece()

func tick(delta: float) -> void:
	if done or failed:
		return
	clock += delta
	match mode:
		"storage":
			if clock >= .65:
				clock -= .65
				drop()
		"catch":
			if clock >= .58:
				clock -= .58
				falling.append({"lane":randi_range(0,4),"y":0.0,"food":turn % 4 != 2,"icon":turn % 4})
				turn += 1
			for i in range(falling.size() - 1, -1, -1):
				falling[i].y += delta * .67
				if falling[i].y < 1.0:
					continue
				if falling[i].lane == player_lane:
					if falling[i].food: food += 1
					else: strikes += 1
				falling.remove_at(i)
			done = food >= FOOD_GOAL
			failed = strikes >= 3 and not done
		"organization":
			if agenda_retry and clock >= 1.0:
				agenda_retry = false
				agenda_preview = true
				clock = 0.0
			elif agenda_preview and not agenda_retry and clock >= agenda.size() * AGENDA_BEAT:
				agenda_preview = false
				clock = 0.0

func action(key: String) -> void:
	if key == "retry":
		start("puzzle" if mode == "catch" else mode)
		return
	if done or failed:
		return
	match mode:
		"storage":
			match key:
				"turn":
					var rotated: Array[Vector2i] = []
					for p in piece: rotated.append(Vector2i(-p.y,p.x))
					for shift in [0,-1,1,-2,2]:
						if fits(cell + Vector2i(shift,0), rotated):
							cell.x += shift
							piece = rotated
							break
				"drop":
					while fits(cell + Vector2i.DOWN, piece): cell += Vector2i.DOWN
					drop()
				"down": drop()
				"left", "right":
					var next := cell + (Vector2i.LEFT if key == "left" else Vector2i.RIGHT)
					if fits(next,piece): cell = next
		"communication":
			if key.length() != 1 or not key in "ABCDEFGHIJKLMNOPQRSTUVWXYZ" or key in guesses:
				return
			guesses += key
			if not key in TITLE: errors += 1
			done = masked_title() == TITLE
			failed = errors >= 7
		"puzzle":
			if not key.is_valid_int(): return
			var index := int(key)
			if index < 0 or index >= puzzle.size(): return
			if picked == -1:
				picked = index
				return
			var old: int = puzzle[picked]
			puzzle[picked] = puzzle[index]
			puzzle[index] = old
			picked = -1
			if puzzle == [0,1,2,3,4,5]:
				mode = "catch"
				clock = 0.0
		"catch":
			if key == "left": player_lane = maxi(0, player_lane - 1)
			elif key == "right": player_lane = mini(4, player_lane + 1)
			elif key.is_valid_int(): player_lane = clampi(int(key),0,4)
		"organization":
			if agenda_preview or agenda_retry or not key.is_valid_int():
				return
			var topic := int(key)
			if topic < 0 or topic >= AGENDA_TOPICS.size():
				return
			if topic != agenda[agenda_position]:
				agenda_position = 0
				agenda_retry = true
				clock = 0.0
				return
			agenda_position += 1
			if agenda_position == agenda.size():
				score += 1
				done = score == AGENDA_ROUNDS
				if not done:
					agenda.append(next_topic())
					agenda_position = 0
					agenda_preview = true
					clock = 0.0

func masked_title() -> String:
	var masked := ""
	for letter in TITLE:
		masked += letter if letter == " " or letter in guesses else "_"
	return masked

func key(code: int) -> void:
	if failed:
		if code == KEY_ENTER: action("retry")
		return
	if mode == "communication" and code >= KEY_A and code <= KEY_Z:
		action(String.chr(code))
	elif mode == "catch" and code >= KEY_1 and code <= KEY_5:
		action(str(code - KEY_1))
	elif mode in ["storage", "catch"]:
		match code:
			KEY_LEFT, KEY_A: action("left")
			KEY_RIGHT, KEY_D: action("right")
			KEY_UP, KEY_W: action("turn")
			KEY_DOWN, KEY_S: action("down")
			KEY_SPACE: action("drop")
	elif code >= KEY_1 and code <= KEY_6:
		action(str(code - KEY_1))

func draw(game: Control) -> void:
	var size := game.get_viewport_rect().size
	var scale := minf(1.0, minf((size.x - 24) / 760.0, (size.y - 24) / 520.0))
	game.draw_rect(Rect2(Vector2.ZERO,size), Color(0.04,0.10,0.08,.79))
	game.mini_scale = scale
	game.mini_rect = Rect2((size - Vector2(760,520) * scale) * .5, Vector2(760,520) * scale)
	game.draw_set_transform(game.mini_rect.position, 0, Vector2.ONE * scale)
	game.drawing_mini = true
	game.panel(Rect2(0,0,760,520))
	game.button(Rect2(698,12,46,42), "×", "commission_close")
	if failed:
		game.text(Vector2(38,92), "Vuelve a intentarlo", 30)
		game.text(Vector2(38,137), "Puedes reiniciar el minijuego.", 19)
		btn(game, Rect2(38,185,225,52), "Reintentar", "retry")
	else:
		match mode:
			"storage": draw_storage(game)
			"communication": draw_letters(game)
			"puzzle": draw_puzzle(game)
			"catch": draw_catch(game)
			"organization": draw_agenda(game)
	game.drawing_mini = false
	game.draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func btn(game: Control, rect: Rect2, label: String, value: String) -> void:
	game.button(rect,label,"activity:" + value)

func draw_storage(game: Control) -> void:
	game.text(Vector2(30,47), "Almacén · %d/%d puntos" % [score,SCORE_GOAL], 28)
	game.text(Vector2(30,77), "Completa diez filas. Cada fila vale 100 puntos.", 18)
	var origin := Vector2(44,96)
	for y in range(12):
		for x in range(8):
			var p := Vector2i(x,y)
			var r := Rect2(origin + Vector2(p)*31,Vector2(29,29))
			game.draw_rect(r, COLORS[board[p]] if board.has(p) else Color("31493f"))
	for offset in piece:
		if (cell+offset).y >= 0:
			game.draw_rect(Rect2(origin + Vector2(cell+offset)*31,Vector2(29,29)), COLORS[turn % COLORS.size()])
	btn(game,Rect2(346,122,160,50),"Izquierda","left")
	btn(game,Rect2(520,122,160,50),"Derecha","right")
	btn(game,Rect2(346,190,334,50),"Girar · ↑","turn")
	btn(game,Rect2(346,258,334,50),"Bajar · ↓","down")
	btn(game,Rect2(346,326,334,50),"Soltar · Espacio","drop")

func draw_letters(game: Control) -> void:
	game.text(Vector2(30,47), "Comunicación · El titular", 28)
	game.text(Vector2(30,88), "Descubre el acuerdo de la asamblea. Fallos: %d/7" % errors, 18)
	var shown := ""
	for letter in masked_title():
		shown += letter + " "
	game.text(Vector2(34,163), shown, 26)
	for i in range(26):
		var letter := String.chr(KEY_A+i)
		var r := Rect2(33+(i%9)*77,204+floori(i/9.0)*62,68,52)
		if letter in guesses:
			game.draw_rect(r, Color("46574c"))
			game.text(r.position+Vector2(23,34),letter,18,Color("b1b8aa"))
		else:
			btn(game,r,letter,letter)
	var support := [Vector2(66,485), Vector2(66,397), Vector2(151,397), Vector2(151,417)]
	for i in range(mini(errors,3)):
		game.draw_line(support[i],support[i+1],Color("f7dfaf"),3)
	if errors >= 4: game.draw_arc(Vector2(151,427),10,0,TAU,16,Color("f7dfaf"),3)
	if errors >= 5: game.draw_line(Vector2(151,437),Vector2(151,462),Color("f7dfaf"),3)
	if errors >= 6:
		game.draw_line(Vector2(151,445),Vector2(133,453),Color("f7dfaf"),3)
		game.draw_line(Vector2(151,445),Vector2(169,453),Color("f7dfaf"),3)

func draw_puzzle(game: Control) -> void:
	game.text(Vector2(30,47), "Cocina · Monta la mesa", 28)
	game.text(Vector2(30,84), "Toca dos piezas para intercambiarlas y completar la mesa.", 18)
	var table: Texture2D = preload("res://assets/acampada/table.png")
	for i in range(6):
		var p: int = puzzle[i]
		var r := Rect2(134+(i%3)*162,112+floori(i/3.0)*157,151,143)
		game.draw_rect(r, Color("6a7860"))
		game.draw_texture_rect_region(table,r,Rect2((p%3)*85,floori(p/3.0)*128,85,128))
		game.draw_rect(r,Color("f3d691") if picked == i else Color("ab9a72"),false,3)
		game.clickables.append({"rect":game.mini_hit(r),"id":"activity:" + str(i)})

func draw_catch(game: Control) -> void:
	game.text(Vector2(30,47), "Cocina · Alimentos %d/%d" % [food,FOOD_GOAL], 28)
	game.text(Vector2(30,81), "Recoge comida y esquiva herramientas. Golpes: %d/3" % strikes, 18)
	for i in range(5):
		game.draw_rect(Rect2(40+i*137,104,126,313), Color("3a5346"))
		btn(game,Rect2(40+i*137,450,126,44),str(i+1),str(i))
	for item in falling:
		var p := Vector2(104+item.lane*137,124+item.y*263)
		match int(item.icon):
			0:
				game.draw_rect(Rect2(p-Vector2(18,9),Vector2(36,17)), Color("be8045"))
				for cut in [-9,0,9]: game.draw_line(p+Vector2(cut,-7),p+Vector2(cut-4,3),Color("f5cd83"),2)
			1:
				game.draw_circle(p+Vector2(-6,1),10,Color("ce5847"))
				game.draw_circle(p+Vector2(6,1),10,Color("ce5847"))
				game.draw_line(p+Vector2(0,-5),p+Vector2(5,-15),Color("92b871"),4)
			2:
				game.draw_line(p+Vector2(-12,12),p+Vector2(9,-10),Color("babdb8"),7)
				game.draw_arc(p+Vector2(9,-10),8,0.15,4.65,10,Color("babdb8"),4)
			3:
				game.draw_circle(p+Vector2(0,-4),13,Color("699f4a"))
				game.draw_rect(Rect2(p+Vector2(-3,4),Vector2(7,12)),Color("abd075"))
		game.text(p+Vector2(-53,30),["Pan","Fruta","Llave","Verdura"][item.icon],15,Color("fff1cf"),true,106,HORIZONTAL_ALIGNMENT_CENTER)
	game.draw_rect(Rect2(76+player_lane*137,394,57,17),Color("f2c97a"))

func draw_agenda(game: Control) -> void:
	game.text(Vector2(30,47), "Organización · Orden del día", 28)
	game.text(Vector2(30,85), "Ronda %d/%d" % [mini(score + 1, AGENDA_ROUNDS), AGENDA_ROUNDS], 19)
	var active := -1
	var instruction := "Reproduce el orden con las tarjetas o las teclas 1–4."
	if agenda_retry:
		instruction = "Se ha cruzado un tema. Vuelve a mirar el orden."
	elif agenda_preview:
		instruction = "Fíjate en el orden en que se iluminan los temas."
		if fmod(clock, AGENDA_BEAT) < .62:
			active = agenda[mini(floori(clock / AGENDA_BEAT), agenda.size() - 1)]
	game.text(Vector2(30,131), instruction, 20)
	for i in range(agenda.size()):
		game.draw_circle(Vector2(310 + i * 34,187), 9, COLORS[i % COLORS.size()] if i < agenda_position else Color("52665a"))
	for i in range(AGENDA_TOPICS.size()):
		var r := Rect2(95 + (i % 2) * 293, 231 + floori(i / 2.0) * 111, 277, 87)
		var label := "%d · %s" % [i + 1, AGENDA_TOPICS[i]]
		if agenda_preview or agenda_retry:
			game.draw_rect(r, COLORS[i] if active == i else Color("3f5649"))
			game.text(r.position + Vector2(0,52), label, 22, Color("fff4d7"), true, r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			btn(game, r, label, str(i))
