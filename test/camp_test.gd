extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	if not value:
		push_error("FAIL: " + label)
		quit(1)
		assert(value, label)

func run() -> void:
	var main = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(main)
	await process_frame
	main.start_game(false)
	main.close_dialog()
	check(main.s.phase == "talk", "inicio en plaza casi vacía")
	var y_before: float = main.s.player.y
	Input.action_press("move_up")
	main._process(0.2)
	Input.action_release("move_up")
	check(main.s.player.y < y_before, "movimiento por teclado")
	var x_before: float = main.s.player.x
	main.clickables = [{"rect":Rect2(0,0,100,100), "id":"dir", "dir":Vector2.RIGHT}]
	main.pointer_down(Vector2(50,50), 0)
	main._process(0.2)
	main.pointer_up(Vector2(50,50), 0)
	check(main.s.player.x > x_before and main.touch_directions.is_empty(), "movimiento táctil y liberación")
	for n in ["Patricia", "Alejandro", "Marina"]:
		main.s.player = main.world.npc_pos(n, main.s, main.elapsed) + Vector2(0, 50)
		main.interact()
		check(main.s.talked[n], "conversación con " + n)
		main.close_dialog()
	check(main.s.phase == "meeting", "reunión tras conocer a las tres personas")
	main.s.player = main.world.MEETING + Vector2(0,60)
	main.interact()
	check(main.choosing, "la asamblea ofrece decisión")
	main.choose_assembly(0)
	main.close_dialog()
	check(main.s.phase == "materials" and main.s.choice == "cuidados", "acuerdo cambia estado")
	for k in ["lona", "varillas", "piquetas"]:
		main.s.player = main.world.MATERIALS[k] + Vector2(0,30)
		main.interact()
		check(main.s.collected[k], "recogida de " + k)
		if main.dialogue: main.close_dialog()
	check(main.s.phase == "build", "materiales desbloquean montaje")
	main.s.player = main.world.SITE + Vector2(0,75)
	main.interact()
	check(main.mini and main.s.build_stage == 0, "inicia montaje")
	main.mini_rect = Rect2(0,0,820,500)
	main.pointer_down(Vector2(240,235), 7)
	var drag := InputEventScreenDrag.new()
	drag.position = Vector2(560,235)
	main._input(drag)
	main.pointer_up(Vector2(560,235), 7)
	check(main.s.build_stage == 1 and not main.mini, "lona arrastrada y extendida")
	main.close_dialog(); main.interact()
	main.elapsed = 0
	main.mini_action(); main.mini_action()
	check(main.s.build_stage == 2, "varillas encajadas con precisión")
	main.close_dialog(); main.interact()
	main.action_held = true
	main._process(2.1)
	check(main.s.build_stage == 3, "estructura levantada al mantener")
	main.close_dialog(); main.interact()
	for i in range(4):
		main.mini_selected = i
		main.mini_action()
	check(main.s.tents == 1 and main.s.capacity == 0, "primera tienda de material")
	check(main.walkable(main.s.player), "el jugador no queda dentro de la tienda")
	main.close_dialog()
	for i in range(5):
		check(main.s.delivery == "leaving", "participante sale a por su tienda")
		main.update_deliveries(2.0)
		main.update_deliveries(2.0)
		check(main.s.delivery == "offer", "participante vuelve")
		main.s.player = CampWorld.ENTRANCE
		main.interact()
		main.close_dialog()
		main.s.player = CampWorld.next_pitch(main.s) + Vector2(0, 10)
		main.interact()
		main.update_deliveries(2.0)
	check(main.s.tents == 6 and main.s.people == 20 and main.s.delivery == "unload", "cinco tiendas propias")
	main.s.player = CampWorld.SITE + Vector2(0, 12)
	main.interact()
	check(main.commission_open and main.activity.mode == "storage", "almacén abre bloques")
	await process_frame
	await process_frame
	var activity = main.activity
	for y in [10,11]:
		for x in [0,1,2,5,6,7]:
			activity.board[Vector2i(x,y)] = 0
	activity.score = 800
	activity.key(KEY_SPACE)
	check(activity.score == 1000 and activity.done, "el almacén termina en 1000 puntos")
	main._process(0.01)
	main.close_dialog()
	var donations := 0
	while main.s.tents < CampWorld.DAY_ONE_TENTS:
		if main.s.phase == "commissions":
			var commission: int = main.s.commissions
			check(main.s.tents == [6, 12, 19][commission], "comisión intercalada con llegadas")
			check(main.s.daylight() == "TARDE", "la tarde avanza por hitos")
			await play_commission(main, activity, commission)
			continue
		main.s.player = CampWorld.ENTRANCE
		main.interact()
		main.close_dialog()
		main.s.player = CampWorld.next_pitch(main.s) + Vector2(0, 10)
		if main.s.phase == "build":
			for step in range(4):
				main.interact()
				check(main.mini and main.s.build_stage == step, "minijuego de donación")
				main.complete_build_stage()
				main.close_dialog()
			check(main.s.delivery == "resident", "llega alguien para ocupar la tienda")
			main.update_deliveries(1.0)
			check(main.arrivals.size() == 1, "residente visible")
			main.update_deliveries(1.0)
			donations += 1
		else:
			main.interact()
			main.update_deliveries(2.0)
	check(donations > 0 and main.s.tents == 25 and main.s.capacity == 48 and main.s.commissions == 3 and main.s.daylight() == "NOCHE", "25 tiendas y almacén sin plazas")
	main.s.player = CampWorld.ORGANIZATION
	main.interact()
	main.close_dialog()
	check(main.screen == "result", "pantalla de final de día")
	var loaded := CampState.new()
	check(loaded.load_game() and loaded.phase == "finished" and loaded.tents == 25 and loaded.commissions == 3, "guardado y recuperación")
	loaded.reset_save()
	print("[acampada-tests] PASS: asamblea, almacén, cinco tiendas propias, tres comisiones, donaciones, 25 tiendas y guardado")
	quit(0)

func play_commission(main: Control, activity, i: int) -> void:
	main.s.player = CampWorld.COMMISSION_POINTS[i]
	main.interact()
	check(main.commission_open, "actividad de comisión")
	await process_frame
	await process_frame
	match i:
		0:
			for round_index in range(3):
				activity.tick(5.0)
				var sequence: Array = activity.agenda.duplicate()
				check(sequence.size() == 3 + round_index, "secuencia de Organización")
				for topic in sequence:
					activity.action(str(topic))
		2:
			activity.key(KEY_Z)
			check(activity.errors == 1, "una letra errónea cuenta un fallo")
			for letter in activity.TITLE:
				if letter != " ": activity.action(letter)
		1:
			for slot in [0,2,1,2,3,5,4,5]:
				activity.action(str(slot))
			check(activity.mode == "catch" and not activity.done, "puzzle abre la recogida")
			await process_frame
			await process_frame
			activity.falling.append({"lane":0,"y":0.99,"food":false,"icon":2})
			activity.tick(0.04)
			check(activity.strikes == 0, "herramienta esquivada")
			for n in range(20):
				activity.falling.append({"lane":2,"y":0.99,"food":true,"icon":0})
				activity.tick(0.04)
			check(activity.food == 20, "20 alimentos")
	check(activity.done, "actividad completada")
	main._process(0.01)
	main.close_dialog()
