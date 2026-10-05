extends RefCounted

const CUSTOM_LEGENDS := [144, 145, 146, 150, 151, 249, 250, 251] # Mew, Lugia, Ho-Oh, Celebi
const ARTICUNO := 144
const ZAPDOS := 145
const MOLTRES := 146
const MEWTWO := 150
const MEW := 151
const SUICUNE := 245
const ARTICUNO_LEVEL := 50
const ZAPDOS_LEVEL := 50
const MOLTRES_LEVEL := 50
const MEWTWO_LEVEL := 70
const MEW_LEVEL := 50
const ARTICUNO_ICE_PATH_B3F_CELL := Vector2i(8, 8) # initial placement test; adjust from phone test
const ZAPDOS_ROUTE_10_CELL := Vector2i(9, 10)
const MOLTRES_VICTORY_ROAD_CELL := Vector2i(5, 28)
const MEWTWO_ROUTE_4_CELL := Vector2i(29, 3) # initial placement test near Cerulean-side item ball
const MEW_RED_CELL := Vector2i(9, 10)
const ARTICUNO_STORY_TAG := &"legendary_roamers_articuno_story"
const ZAPDOS_STORY_TAG := &"legendary_roamers_zapdos_story"
const MOLTRES_STORY_TAG := &"legendary_roamers_moltres_story"
const MEWTWO_STORY_TAG := &"legendary_roamers_mewtwo_story"
const MEW_STORY_TAG := &"legendary_roamers_mew_story"
const TAG_PREFIX := "legendary_roamers_"
const KANTO_ONLY_ROAMERS := [151, 150, 144, 145, 146] # Mew, Articuno, Zapdos, Moltres

class Controller:
	extends RefCounted

	var host: Gen2ModHost
	var manifest: PokeModManifest
	var data: GameData
	var save = null
	var roaming: Array = []
	var roaming_maps: Array[Vector2i] = []
	var zapdos_unlocked := false
	var mewtwo_route_state := "initial" # initial, ran, lost

	func _init(p_host: Gen2ModHost, p_manifest: PokeModManifest) -> void:
		host = p_host
		manifest = p_manifest
		data = GameData.open(host.target_game())
		_build_roaming_maps()

	func enabled() -> bool:
		return bool(host.option(manifest.id, &"enabled"))

	func _build_roaming_maps() -> void:
		roaming_maps.clear()
		if data == null:
			return
		for raw in data.world_roaming_maps():
			if raw is Vector2i:
				var p: Vector2i = raw
				if p.x >= 0 and p.y >= 0 and p not in roaming_maps:
					roaming_maps.append(p)
			elif raw is Dictionary:
				var row: Dictionary = raw
				var g := int(row.get("map_group", row.get("group", -1)))
				var n := int(row.get("map_number", row.get("number", -1)))
				if g >= 0 and n >= 0:
					var p := Vector2i(g, n)
					if p not in roaming_maps:
						roaming_maps.append(p)
			elif raw is Array and raw.size() >= 2:
				var p := Vector2i(int(raw[0]), int(raw[1]))
				if p.x >= 0 and p.y >= 0 and p not in roaming_maps:
					roaming_maps.append(p)

	func save_created(p_save) -> void:
		host.write_save_data(manifest, p_save, {"version": 7, "roaming": [], "zapdos_unlocked": false, "mewtwo_route_state": "initial"})

	func save_activated(p_save) -> void:
		save = p_save
		roaming.clear()
		if save == null:
			return
		var stored = host.read_save_data(manifest, save)
		zapdos_unlocked = bool(stored.get("zapdos_unlocked", false)) if stored is Dictionary else false
		mewtwo_route_state = String(stored.get("mewtwo_route_state", "initial")) if stored is Dictionary else "initial"
		if stored is Dictionary:
			for raw in stored.get("roaming", []):
				if raw is Dictionary:
					roaming.append((raw as Dictionary).duplicate(true))

		# 0.1.5 TEST migration.
		# Crystal map constants: NEW_BARK group 24, ROUTE_29 map 3.
		var migrated := false
		if stored is Dictionary:
			migrated = bool(stored.get("migrated_lugia_to_route29_v015", false))
		if not migrated:
			for i in roaming.size():
				if int(roaming[i].get("species", 0)) == 249:
					roaming[i]["map_group"] = 24
					roaming[i]["map_number"] = 3
					break
			if save != null:
				host.write_save_data(manifest, save, {
					"version": 7,
					"roaming": roaming,
					"migrated_lugia_to_route29_v015": true,
					"zapdos_unlocked": zapdos_unlocked,
					"mewtwo_route_state": mewtwo_route_state
				})

	func save_deactivated() -> void:
		save = null
		roaming.clear()

	func persist() -> void:
		if save != null:
			host.write_save_data(manifest, save, {
				"version": 7,
				"roaming": roaming,
				"migrated_lugia_to_route29_v015": true,
				"zapdos_unlocked": zapdos_unlocked,
				"mewtwo_route_state": mewtwo_route_state
			})

	func unlock_zapdos() -> void:
		if zapdos_unlocked:
			return
		zapdos_unlocked = true
		persist()

	func set_mewtwo_route_state(state: String) -> void:
		mewtwo_route_state = state
		persist()

	func find_custom(species: int) -> int:
		for i in roaming.size():
			if int(roaming[i].get("species", 0)) == species:
				return i
		return -1

	func choose_map(species: int, from_map: Vector2i, first_spawn := false) -> Vector2i:
		var candidates: Array[Vector2i] = roaming_maps
		if species in KANTO_ONLY_ROAMERS:
			# IMPORTANT: these are the actual Crystal/PokéRecomp map IDs used by
			# world.current_map and by the proven v0.1.65 world actor. Do not derive
			# these through world_map_named() and do not filter the native Johto
			# roaming table: Gen-1 custom roamers have their own Kanto route pool.
			candidates = [
				Vector2i(13, 1), # ROUTE 1
				Vector2i(23, 1), # ROUTE 2
				Vector2i(14, 1), # ROUTE 3
				Vector2i(7, 12), # ROUTE 4
				Vector2i(25, 1), # ROUTE 5
				Vector2i(12, 1), # ROUTE 6
				Vector2i(21, 1), # ROUTE 7
				Vector2i(18, 1), # ROUTE 8
				Vector2i(7, 13), # ROUTE 9
				Vector2i(7, 14), # ROUTE 10 NORTH
				Vector2i(18, 3), # ROUTE 10 SOUTH
				Vector2i(12, 2), # ROUTE 11
				Vector2i(18, 2), # ROUTE 12
				Vector2i(17, 1), # ROUTE 13
				Vector2i(17, 2), # ROUTE 14
				Vector2i(17, 3), # ROUTE 15
				Vector2i(21, 2), # ROUTE 16
				Vector2i(21, 3), # ROUTE 17
				Vector2i(17, 4), # ROUTE 18
				Vector2i(6, 5),  # ROUTE 19
				Vector2i(6, 6),  # ROUTE 20
				Vector2i(6, 7),  # ROUTE 21
				Vector2i(23, 2), # ROUTE 22
				Vector2i(7, 15), # ROUTE 24
				Vector2i(7, 16), # ROUTE 25
				Vector2i(19, 1), # ROUTE 28
			]
		elif first_spawn and data != null:
			var route_29 = data.world_map_named(&"ROUTE_29")
			if route_29 != null:
				return Vector2i(route_29.group, route_29.number)
		if candidates.is_empty():
			return Vector2i(-1, -1)
		var index := posmod(species * 131 + from_map.x * 17 + from_map.y * 31, candidates.size())
		var chosen: Vector2i = candidates[index]
		if chosen == from_map and candidates.size() > 1:
			chosen = candidates[(index + 1) % candidates.size()]
		return chosen

	func start_custom_roaming(event: Dictionary) -> void:
		var species := int(event.get("species", 0))
		var here := Vector2i(int(event.get("map_group", -1)), int(event.get("map_number", -1)))
		var old_index := find_custom(species)
		var destination := choose_map(species, here, old_index < 0)
		if destination.x < 0:
			return

		var row := {
			"species": species,
			"level": int(event.get("level", 1)),
			"hp": maxi(1, int(event.get("hp", 0))),
			"dvs": int(event.get("dvs", 0)),
			"status": int(event.get("status", 0)),
			"map_group": destination.x,
			"map_number": destination.y,
		}
		var at := find_custom(species)
		if at >= 0:
			roaming[at] = row
		else:
			roaming.append(row)
		persist()

	func remove_custom(species: int) -> void:
		var at := find_custom(species)
		if at >= 0:
			roaming.remove_at(at)
			persist()

	func handle_suicune(event: Dictionary) -> void:
		if host.target_game() != &"crystal":
			return
		var progress := host.progress()
		if SUICUNE in progress.get(&"caught_species", []):
			return
		if not bool(progress.get(&"fought_suicune", false)):
			return
		for row in host.roamers():
			if int(row.get("species", 0)) == SUICUNE:
				return
		host.request_roamer(manifest.id, 2, SUICUNE, int(event.get("level", 40)))

	func on_battle_event(event: Dictionary) -> void:
		if not enabled():
			return
		if event.get("type") != Gen2Battle.ENDED:
			return
		if event.get("battle_kind") != &"wild":
			return

		var species := int(event.get("species", 0))
		var outcome: StringName = event.get("outcome", &"")
		var tag := String(event.get("tag", &""))

		# Mewtwo's Route 4 story battle has three deliberately different non-catch results.
		# RUN: stay on Route 4 and remember the retreat.
		# Player wipe: stay on Route 4 and remember Mewtwo's victory.
		# Mewtwo at 0 HP: only then does he become a Kanto roamer.
		if species == MEWTWO and tag == String(MEWTWO_STORY_TAG):
			if outcome == &"caught":
				set_mewtwo_route_state("initial")
				return
			var enemy_hp := int(event.get("hp", 1))
			if enemy_hp <= 0:
				set_mewtwo_route_state("initial")
				start_custom_roaming(event)
				return
			if outcome in [&"fled", &"run", &"escaped"]:
				set_mewtwo_route_state("ran")
			else:
				# Any non-catch, non-run result with Mewtwo still standing is the player losing.
				set_mewtwo_route_state("lost")
			return

		# A custom roamer was met again.
		if tag.begins_with(TAG_PREFIX) and tag != String(MEW_STORY_TAG) and tag != String(MOLTRES_STORY_TAG) and tag != String(ZAPDOS_STORY_TAG) and tag != String(ARTICUNO_STORY_TAG) and tag != String(MEWTWO_STORY_TAG):
			if outcome == &"caught":
				remove_custom(species)
			else:
				start_custom_roaming(event)
			return

		# Crystal's scripted Suicune can use the real empty third cartridge slot.
		if species == SUICUNE and outcome != &"caught":
			handle_suicune(event)
			return

		# Stationary Lugia / Ho-Oh / Celebi: a non-catch starts custom roaming.
		if species in CUSTOM_LEGENDS and outcome != &"caught":
			start_custom_roaming(event)

	func substitute_wild(context: Dictionary) -> Dictionary:
		if not enabled():
			return {}
		for row in roaming:
			if int(row.get("map_group", -1)) != int(context.get("map_group", -2)):
				continue
			if int(row.get("map_number", -1)) != int(context.get("map_number", -2)):
				continue
			# 0.1.6 TEST: 100% substitution once a normal wild encounter
			# has been selected on the custom roamer's exact stored map.
			var species := int(row.get("species", 0))
			return {
				"species": species,
				"level": int(row.get("level", 1)),
				"dvs": int(row.get("dvs", 0)),
				"hp": maxi(1, int(row.get("hp", 1))),
				"status": int(row.get("status", 0)),
				"tag": StringName(TAG_PREFIX + str(species)),
			}
		return {}

	func readable_map_name(group: int, number: int) -> String:
		# Complete Pokemon Crystal outdoor route map IDs (pret/pokecrystal map_constants.asm).
		# This covers every route that can appear in the roaming table, plus Kanto routes.
		var route_names := {
			"1:12": "ROUTE 38",
			"1:13": "ROUTE 39",
			"2:5": "ROUTE 42",
			"2:6": "ROUTE 44",
			"5:8": "ROUTE 45",
			"5:9": "ROUTE 46",
			"6:5": "ROUTE 19",
			"6:6": "ROUTE 20",
			"6:7": "ROUTE 21",
			"7:12": "ROUTE 4",
			"7:13": "ROUTE 9",
			"7:14": "ROUTE 10 NORTH",
			"7:15": "ROUTE 24",
			"7:16": "ROUTE 25",
			"8:6": "ROUTE 33",
			"9:5": "ROUTE 43",
			"10:1": "ROUTE 32",
			"10:2": "ROUTE 35",
			"10:3": "ROUTE 36",
			"10:4": "ROUTE 37",
			"11:1": "ROUTE 34",
			"12:1": "ROUTE 6",
			"12:2": "ROUTE 11",
			"13:1": "ROUTE 1",
			"14:1": "ROUTE 3",
			"16:1": "ROUTE 23",
			"17:1": "ROUTE 13",
			"17:2": "ROUTE 14",
			"17:3": "ROUTE 15",
			"17:4": "ROUTE 18",
			"18:1": "ROUTE 8",
			"18:2": "ROUTE 12",
			"18:3": "ROUTE 10 SOUTH",
			"19:1": "ROUTE 28",
			"21:1": "ROUTE 7",
			"21:2": "ROUTE 16",
			"21:3": "ROUTE 17",
			"22:1": "ROUTE 40",
			"22:2": "ROUTE 41",
			"23:1": "ROUTE 2",
			"23:2": "ROUTE 22",
			"24:1": "ROUTE 26",
			"24:2": "ROUTE 27",
			"24:3": "ROUTE 29",
			"25:1": "ROUTE 5",
			"26:1": "ROUTE 30",
			"26:2": "ROUTE 31",
		}
		var key := "%d:%d" % [group, number]
		return str(route_names.get(key, "MAP %s" % key))

	func page_rows() -> Array:
		var progress := host.progress()
		var beat_red_value = progress.get(&"beat_red", "<MISSING>")
		var caught := progress.get(&"caught_species", [])
		var rows: Array = [
			{"label": "BEAT RED", "detail": str(beat_red_value)},
			{"label": "MEW CAUGHT", "detail": str(MEW in caught)},
			{"label": "MEW ROAM", "detail": str(find_custom(MEW) >= 0)},
			{"label": "MAP TABLE", "detail": str(roaming_maps.size())},
			{"label": "ACTIVE", "detail": str(roaming.size())},
		]
		if roaming.is_empty():
			rows.append({"label": "CUSTOM", "detail": "NONE"})
			return rows
		for row in roaming:
			var species := int(row.get("species", 0))
			var mon_name := "#%03d" % species
			if data != null:
				var entry := data.species(species)
				if not entry.is_empty():
					mon_name = str(entry.get("name", mon_name))
			rows.append({
				"label": mon_name,
				"detail": "%s HP%d ST%d" % [
					readable_map_name(int(row.get("map_group", -1)), int(row.get("map_number", -1))),
					int(row.get("hp", 1)),
					int(row.get("status", 0))
				],
			})
		return rows


# 0.1.14 interaction test.
# Lugia is drawn only on its stored roaming map, on a reachable grass cell.
# The actor is solid; pressing A toward it queues a tagged wild battle.
# The existing battle-ended handler then catches/removes or re-roams it.
class VisibleLegendsActor extends RefCounted:
	var world: Gen2WorldAPI = null
	var controller = null
	var data: GameData = null
	var legend_cells := {}
	var move_clocks := {}
	var move_indices := {}
	var battle_queued_species := 0
	var power_plant_officer_facing := Gen2WorldSprite.FACING_DOWN
	var power_plant_officer_cell := Vector2i(7, 14)
	var power_surge_state := 0
	var power_surge_emote_frames := 0
	var power_surge_target := Vector2i(-1, -1)
	var power_surge_hide_emote := false
	var _outbox: Array = []
	var cached_grass := PackedVector2Array()
	var cached_allowed := {}
	var silver_cave_room_3 = null
	var victory_road = null
	var route_10_north = null
	var route_4 = null
	var ice_path_b3f = null
	var power_plant = null
	var mew_story_queued := false
	var moltres_story_queued := false
	var mewtwo_story_queued := false
	var articuno_story_queued := false
	var zapdos_story_queued := false

	func _init(p_controller, p_data: GameData) -> void:
		controller = p_controller
		data = p_data
		if data != null:
			silver_cave_room_3 = data.world_map_named(&"SILVER_CAVE_ROOM_3")
		victory_road = data.world_map_named(&"VICTORY_ROAD")
		route_10_north = data.world_map_named(&"ROUTE_10_NORTH")
		route_4 = data.world_map_named(&"ROUTE_4")
		ice_path_b3f = data.world_map_named(&"ICE_PATH_B3F")
		power_plant = data.world_map_named(&"POWER_PLANT")
		for species in CUSTOM_LEGENDS:
			legend_cells[species] = Vector2i(-1, -1)
			move_clocks[species] = 0
			move_indices[species] = 0

	func _delay(species: int) -> int:
		return 60 if species == 251 else 180

	func _active_row(species: int) -> Dictionary:
		if controller == null:
			return {}
		var at: int = controller.find_custom(species)
		if at < 0:
			return {}
		return controller.roaming[at]

	func _on_power_plant() -> bool:
		if world == null or world.current_map == null or power_plant == null:
			return false
		return int(world.current_map.group) == int(power_plant.group) \
			and int(world.current_map.number) == int(power_plant.number)

	func _on_route_10_north() -> bool:
		if world == null or world.current_map == null or route_10_north == null:
			return false
		return int(world.current_map.group) == int(route_10_north.group) \
			and int(world.current_map.number) == int(route_10_north.number)

	func _on_route_4() -> bool:
		if world == null or world.current_map == null or route_4 == null:
			return false
		return int(world.current_map.group) == int(route_4.group) \
			and int(world.current_map.number) == int(route_4.number)

	func _show_mewtwo() -> bool:
		if controller == null or not controller.enabled() or not _on_route_4():
			return false
		# Mewtwo is post-Red content. PokéRecomp 0.1.72 repairs beat_red in
		# older saves when they are loaded, so the official progress flag is safe.
		if not bool(controller.host.progress().get(&"beat_red", false)):
			return false
		if controller.find_custom(MEWTWO) >= 0:
			return false
		return MEWTWO not in controller.host.progress().get(&"caught_species", [])

	func _queue_mewtwo_dialogue() -> void:
		if mewtwo_story_queued:
			return
		mewtwo_story_queued = true
		if controller.mewtwo_route_state == "ran":
			_outbox.append({
				"kind": &"text",
				"text": ["You have returned.", "Last time, you fled\nfrom our battle.", "Have you found your\ncourage?"],
				"tag": &"mewtwo_returned_after_run",
			})
			return
		if controller.mewtwo_route_state == "lost":
			_outbox.append({
				"kind": &"text",
				"text": ["So... you have\nreturned again.", "Last time, I proved\nyou were not ready.", "Are you certain you\nwish to suffer\nanother defeat?"],
				"tag": &"mewtwo_returned_after_loss",
			})
			return
		_outbox.append({
			"kind": &"text",
			"text": [
				"I was created by humans.",
				"They sought to create\nthe most powerful\nPOKéMON.",
				"To them, I was never\na living being.",
				"I was an experiment.\nA weapon.",
				"I escaped from those\nwho created me and\ncame to this place.",
				"They say the LEGENDARY\nPOKéMON MEW is the\nstrongest of all.",
				"Those who say that...\nhave never met me.",
				"Three years ago,\na TRAINER entered\nthis cave.",
				"He challenged me.",
				"Our battle shook the\ncavern to its core.",
				"The cave collapsed...\nand has remained\nsealed ever since.",
				"Yet you have come\nseeking me as well.",
				"Tell me...",
			],
			"tag": &"mewtwo_story_intro",
		})

	func _queue_mewtwo_roamer_dialogue() -> void:
		if mewtwo_story_queued:
			return
		mewtwo_story_queued = true
		_outbox.append({
			"kind": &"text",
			"text": ["You found me.", "Last time, you\ndefeated me.", "But make no mistake.", "This time...\nI will defeat you."],
			"tag": &"mewtwo_roamer_rematch",
		})

	func _queue_mewtwo_battle() -> void:
		_outbox.append({"kind": &"cry", "species": MEWTWO})
		_outbox.append({"kind": &"battle", "species": MEWTWO, "level": MEWTWO_LEVEL, "tag": MEWTWO_STORY_TAG})

	func _on_ice_path_b3f() -> bool:
		if world == null or world.current_map == null or ice_path_b3f == null:
			return false
		return int(world.current_map.group) == int(ice_path_b3f.group) \
			and int(world.current_map.number) == int(ice_path_b3f.number)

	func _show_articuno() -> bool:
		if controller == null or not controller.enabled() or not _on_ice_path_b3f():
			return false
		if controller.find_custom(ARTICUNO) >= 0:
			return false
		return ARTICUNO not in controller.host.progress().get(&"caught_species", [])

	func _queue_articuno_battle() -> void:
		if articuno_story_queued:
			return
		articuno_story_queued = true
		_outbox.append({"kind": &"cry", "species": ARTICUNO})
		_outbox.append({"kind": &"battle", "species": ARTICUNO, "level": ARTICUNO_LEVEL, "tag": ARTICUNO_STORY_TAG})

	func _show_zapdos() -> bool:
		if controller == null or not controller.enabled() or not _on_route_10_north():
			return false
		if not controller.zapdos_unlocked:
			return false
		if controller.find_custom(ZAPDOS) >= 0:
			return false
		return ZAPDOS not in controller.host.progress().get(&"caught_species", [])

	func _queue_zapdos_battle() -> void:
		if zapdos_story_queued:
			return
		zapdos_story_queued = true
		_outbox.append({"kind": &"cry", "species": ZAPDOS})
		_outbox.append({"kind": &"battle", "species": ZAPDOS, "level": ZAPDOS_LEVEL, "tag": ZAPDOS_STORY_TAG})

	func _on_victory_road() -> bool:
		if world == null or world.current_map == null or victory_road == null:
			return false
		return int(world.current_map.group) == int(victory_road.group) \
			and int(world.current_map.number) == int(victory_road.number)

	func _show_moltres() -> bool:
		if controller == null or not controller.enabled() or not _on_victory_road():
			return false
		if controller.find_custom(MOLTRES) >= 0:
			return false
		return MOLTRES not in controller.host.progress().get(&"caught_species", [])

	func _queue_moltres_battle() -> void:
		if moltres_story_queued:
			return
		moltres_story_queued = true
		_outbox.append({"kind": &"cry", "species": MOLTRES})
		_outbox.append({
			"kind": &"battle",
			"species": MOLTRES,
			"level": MOLTRES_LEVEL,
			"tag": MOLTRES_STORY_TAG,
		})

	func _on_silver_cave_room_3() -> bool:
		if world == null or world.current_map == null or silver_cave_room_3 == null:
			return false
		return int(world.current_map.group) == int(silver_cave_room_3.group) \
			and int(world.current_map.number) == int(silver_cave_room_3.number)

	func _show_test_mew() -> bool:
		if controller == null or not controller.enabled() or not _on_silver_cave_room_3():
			return false
		if not controller.host.progress().get(&"beat_red", false):
			return false
		if controller.find_custom(MEW) >= 0:
			return false
		return MEW not in controller.host.progress().get(&"caught_species", [])

	func _queue_mew_battle() -> void:
		if mew_story_queued:
			return
		mew_story_queued = true
		_outbox.append({
			"kind": &"text",
			"text": "MEW...",
		})
		_outbox.append({"kind": &"cry", "species": MEW})
		_outbox.append({
			"kind": &"battle",
			"species": MEW,
			"level": MEW_LEVEL,
			"tag": MEW_STORY_TAG,
		})

	func _eligible_grass() -> PackedVector2Array:
		if world == null:
			return PackedVector2Array()
		var eligible: Dictionary = world.visible_encounter_cells()
		return eligible.get(Gen2WorldEncounter.METHOD_GRASS, PackedVector2Array())

	func _place_species(species: int, grass: PackedVector2Array) -> void:
		legend_cells[species] = Vector2i(-1, -1)
		var row := _active_row(species)
		if row.is_empty() or world == null or world.current_map == null:
			return
		if int(row.get("map_group", -1)) != int(world.current_map.group) \
			or int(row.get("map_number", -1)) != int(world.current_map.number):
			return
		var player := world.player_cell
		var best_distance := 2147483647
		for raw in grass:
			var cell := Vector2i(roundi(raw.x), roundi(raw.y))
			if cell == player:
				continue
			var used := false
			for other in CUSTOM_LEGENDS:
				if other != species and legend_cells.get(other, Vector2i(-1, -1)) == cell:
					used = true
					break
			if used:
				continue
			var distance := absi(cell.x - player.x) + absi(cell.y - player.y)
			if distance < best_distance:
				best_distance = distance
				legend_cells[species] = cell

	func set_world(next_world: Gen2WorldAPI) -> void:
		world = next_world
		power_plant_officer_facing = Gen2WorldSprite.FACING_DOWN
		power_plant_officer_cell = Vector2i(7, 14)
		power_surge_state = 0
		power_surge_emote_frames = 0
		power_surge_target = Vector2i(-1, -1)
		_outbox.clear()
		battle_queued_species = 0
		mew_story_queued = false
		moltres_story_queued = false
		mewtwo_story_queued = false
		articuno_story_queued = false
		zapdos_story_queued = false
		for species in CUSTOM_LEGENDS:
			legend_cells[species] = Vector2i(-1, -1)
			move_clocks[species] = 0
		cached_grass = PackedVector2Array()
		cached_allowed.clear()
		if world == null or controller == null or not controller.enabled():
			return
		cached_grass = _eligible_grass()
		if cached_grass.is_empty():
			return
		for raw in cached_grass:
			cached_allowed[Vector2i(roundi(raw.x), roundi(raw.y))] = true
		for species in CUSTOM_LEGENDS:
			_place_species(species, cached_grass)

	func _queue_battle(species: int) -> void:
		if battle_queued_species != 0 or controller == null:
			return
		var row := _active_row(species)
		if row.is_empty():
			return
		battle_queued_species = species
		_outbox.append({"kind": &"cry", "species": species})
		_outbox.append({
			"kind": &"battle",
			"species": species,
			"level": int(row.get("level", 1)),
			"dvs": int(row.get("dvs", 0)),
			"hp": maxi(1, int(row.get("hp", 1))),
			"status": int(row.get("status", 0)),
			"tag": StringName(TAG_PREFIX + str(species)),
		})

	func advance_frame() -> void:
		if world == null or controller == null or not controller.enabled() or battle_queued_species != 0:
			return
		# TEMP TEST GATE: replace beat_red with the real generator-restored condition later.
		if _on_power_plant() and power_surge_state == 0 and controller.host.progress().get(&"beat_red", false):
			var p := world.player_cell
			# Temporary Beat Red trigger: exactly the two tiles to the LEFT of the officer.
			# Officer home = (7,14), active tiles = (6,14) and (5,14).
			var officer_delta := p - Vector2i(7, 14)
			if p == Vector2i(6, 14) or p == Vector2i(5, 14):
				power_surge_state = 1
				power_surge_emote_frames = 0
				power_surge_hide_emote = false
				power_surge_target = p
				if absi(officer_delta.x) >= absi(officer_delta.y):
					power_plant_officer_facing = Gen2WorldSprite.FACING_RIGHT if officer_delta.x > 0 else Gen2WorldSprite.FACING_LEFT
				else:
					power_plant_officer_facing = Gen2WorldSprite.FACING_DOWN if officer_delta.y > 0 else Gen2WorldSprite.FACING_UP
		if power_surge_state == 1 and not power_surge_hide_emote and power_surge_emote_frames == 0:
			# v51 behaviour: immediately hand control to a blocking text request.
			# State 1 remains active so the real ! is still shown.
			power_surge_emote_frames = -1
			_outbox.append({
				"kind": &"text",
				"text": "HEY! WAIT!",
				"tag": &"power_surge_hey",
			})
		if cached_grass.is_empty():
			return
		for species in CUSTOM_LEGENDS:
			var cell: Vector2i = legend_cells.get(species, Vector2i(-1, -1))
			if cell.x < 0:
				continue
			if world.player_cell == cell and species != MEWTWO:
				_queue_battle(species)
				return
			move_clocks[species] = int(move_clocks.get(species, 0)) + 1
			if int(move_clocks[species]) < _delay(species):
				continue
			move_clocks[species] = 0
			var dirs := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP]
			var base_index := int(move_indices.get(species, 0))
			for n in range(4):
				var idx := (base_index + n) % 4
				var next: Vector2i = cell + dirs[idx]
				if not cached_allowed.has(next) or next == world.player_cell:
					continue
				var occupied_by_legend := false
				for other in CUSTOM_LEGENDS:
					if other != species and legend_cells.get(other, Vector2i(-1, -1)) == next:
						occupied_by_legend = true
						break
				if occupied_by_legend:
					continue
				legend_cells[species] = next
				move_indices[species] = (idx + 1) % 4
				break

	func sprites() -> Array:
		if world == null or controller == null or data == null or not controller.enabled():
			return []
		var result: Array = []
		for species in CUSTOM_LEGENDS:
			var cell: Vector2i = legend_cells.get(species, Vector2i(-1, -1))
			if cell.x < 0:
				continue
			var row := _active_row(species)
			if row.is_empty() or world.current_map == null:
				continue
			if int(row.get("map_group", -1)) != int(world.current_map.group) \
				or int(row.get("map_number", -1)) != int(world.current_map.number):
				continue
			var icon = data.mon_menu_icon(species)
			if icon == null:
				continue
			result.append({
				"icon": icon,
				"facing": Gen2WorldSprite.FACING_DOWN,
				"position_cells": Vector2(cell),
				"solid": species == MEWTWO,
			})
		# API54 isolation test: exact same sprite contract as working Kabuto.
		if _on_power_plant():
			var officer_row := {
				"id": &"power_plant_officer",
				"sprite": 0x43,
				"colors": data.overworld_sprite_palette(2, Gen2WorldPalette.TIME_DAY),
				"facing": power_plant_officer_facing,
				"position_cells": power_plant_officer_cell,
				"solid": true,
			}
			if power_surge_state == 1 and not power_surge_hide_emote:
				officer_row["emote"] = Gen2WorldActors.EMOTE_SHOCK
			result.append(officer_row)
		if _show_mewtwo():
			var mewtwo_icon = data.mon_menu_icon(MEWTWO)
			if mewtwo_icon != null:
				result.append({"icon": mewtwo_icon, "facing": Gen2WorldSprite.FACING_DOWN, "position_cells": Vector2(MEWTWO_ROUTE_4_CELL), "solid": true})
		if _show_articuno():
			var articuno_icon = data.mon_menu_icon(ARTICUNO)
			if articuno_icon != null:
				result.append({"icon": articuno_icon, "facing": Gen2WorldSprite.FACING_DOWN, "position_cells": Vector2(ARTICUNO_ICE_PATH_B3F_CELL), "solid": true})
		if _show_zapdos():
			var zapdos_icon = data.mon_menu_icon(ZAPDOS)
			if zapdos_icon != null:
				result.append({"icon": zapdos_icon, "facing": Gen2WorldSprite.FACING_DOWN, "position_cells": Vector2(ZAPDOS_ROUTE_10_CELL), "solid": true})
		if _show_moltres():
			var moltres_icon = data.mon_menu_icon(MOLTRES)
			if moltres_icon != null:
				result.append({
					"icon": moltres_icon,
					"facing": Gen2WorldSprite.FACING_DOWN,
					"position_cells": Vector2(MOLTRES_VICTORY_ROAD_CELL),
					"solid": true,
				})
		if _show_test_mew():
			var mew_icon = data.mon_menu_icon(MEW)
			if mew_icon != null:
				result.append({
					"icon": mew_icon,
					"facing": Gen2WorldSprite.FACING_DOWN,
					"position_cells": Vector2(MEW_RED_CELL),
					"solid": true,
				})
		return result

	func interact(cell: Vector2i, _facing: int) -> bool:
		if world == null or controller == null or not controller.enabled():
			return false
		if cell == power_plant_officer_cell and _on_power_plant() and power_surge_state == 0:
			var delta := world.player_cell - cell
			if delta == Vector2i.LEFT:
				power_plant_officer_facing = Gen2WorldSprite.FACING_LEFT
			elif delta == Vector2i.RIGHT:
				power_plant_officer_facing = Gen2WorldSprite.FACING_RIGHT
			elif delta == Vector2i.UP:
				power_plant_officer_facing = Gen2WorldSprite.FACING_UP
			else:
				power_plant_officer_facing = Gen2WorldSprite.FACING_DOWN
			var machine_part_found = int(controller.host.inventory().get(0x80, 0)) > 0
			if machine_part_found == true:
				_outbox.append({
					"kind": &"text",
					"text": ["Wait a minute!!\nIs that the MACHINE\nPART that was stolen?", "You should talk to\nthe MANAGER so we\ncan get the GENERATOR\nback online!"],
					"tag": &"power_plant_officer_found_machine_part",
				})
			else:
				_outbox.append({
					"kind": &"text",
					"text": ["The POWER PLANT\nalways attracted\nELECTRIC-type\nPOKéMON…", "It must be the\nstrong magnetic\nfield around here."],
					"tag": &"power_plant_officer_before_machine_part",
				})
			return true
		if cell == MEWTWO_ROUTE_4_CELL and _show_mewtwo():
			_queue_mewtwo_dialogue()
			return true
		if cell == ARTICUNO_ICE_PATH_B3F_CELL and _show_articuno():
			_queue_articuno_battle()
			return true
		if cell == ZAPDOS_ROUTE_10_CELL and _show_zapdos():
			_queue_zapdos_battle()
			return true
		if cell == MOLTRES_VICTORY_ROAD_CELL and _show_moltres():
			_queue_moltres_battle()
			return true
		if cell == MEW_RED_CELL and _show_test_mew():
			_queue_mew_battle()
			return true
		for species in CUSTOM_LEGENDS:
			if legend_cells.get(species, Vector2i(-1, -1)) == cell:
				if species == MEWTWO:
					_queue_mewtwo_roamer_dialogue()
				else:
					_queue_battle(species)
				return true
		return false

	func _queue_officer_step(direction: Vector2i, tag: StringName) -> void:
		_outbox.append({
			"kind": &"step",
			"id": &"power_plant_officer",
			"direction": direction,
			"tag": tag,
		})

	func _walk_officer_toward_player() -> void:
		var p := world.player_cell
		power_surge_target = p
		var delta := p - power_plant_officer_cell
		if absi(delta.x) + absi(delta.y) <= 1:
			power_surge_state = 4
			_outbox.append({
				"kind": &"text",
				"text": ["What happened back there?", "After you switched the\nGENERATOR back on,\nwe had a huge\npower surge!", "It must be coming\nfrom outside!"],
				"tag": &"power_surge_explain",
			})
			return
		if absi(delta.x) >= absi(delta.y):
			_queue_officer_step(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT, &"power_surge_approach")
		else:
			_queue_officer_step(Vector2i.DOWN if delta.y > 0 else Vector2i.UP, &"power_surge_approach")

	func _walk_officer_home() -> void:
		var home := Vector2i(7, 14)
		if power_plant_officer_cell == home:
			power_plant_officer_facing = Gen2WorldSprite.FACING_DOWN
			power_surge_hide_emote = false
			power_surge_state = 6
			return
		var delta := home - power_plant_officer_cell
		if delta.x != 0:
			_queue_officer_step(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT, &"power_surge_return")
		else:
			_queue_officer_step(Vector2i.DOWN if delta.y > 0 else Vector2i.UP, &"power_surge_return")

	func request_completed(result: Dictionary) -> void:
		if not bool(result.get("ok", false)):
			return
		var tag = result.get("tag", &"")
		if tag == &"mewtwo_returned_after_run":
			_outbox.append({"kind": &"yes_no", "text": "Are you prepared to\nface me again?", "tag": &"mewtwo_return_choice"})
		elif tag == &"mewtwo_returned_after_loss":
			_outbox.append({"kind": &"yes_no", "text": "Will you challenge me\nagain?", "tag": &"mewtwo_return_choice"})
		elif tag == &"mewtwo_return_choice":
			if bool(result.get("accepted", false)):
				_outbox.append({"kind": &"text", "text": ["Then prove it.", "This time...\ndo not fail."], "tag": &"mewtwo_story_ready"})
			else:
				_outbox.append({"kind": &"text", "text": "Then you are still\nnot ready.", "tag": &"mewtwo_story_declined"})
		elif tag == &"mewtwo_roamer_rematch":
			_queue_battle(MEWTWO)
		elif tag == &"mewtwo_story_intro":
			_outbox.append({
				"kind": &"yes_no",
				"text": "Are you prepared to\nface the strongest\nPOKéMON?",
				"tag": &"mewtwo_story_choice",
			})
		elif tag == &"mewtwo_story_choice":
			if bool(result.get("accepted", false)):
				_outbox.append({
					"kind": &"text",
					"text": ["Very well.", "Show me the strength\nthat brought you here.", "Do not disappoint me."],
					"tag": &"mewtwo_story_ready",
				})
			else:
				_outbox.append({
					"kind": &"text",
					"text": ["Then leave.", "Return when you are\nprepared."],
					"tag": &"mewtwo_story_declined",
				})
		elif tag == &"mewtwo_story_declined":
			mewtwo_story_queued = false
		elif tag == &"mewtwo_story_ready":
			# The dialogue sequence is finished once the battle is queued.
			# Clear this guard now so a RUN/player loss can talk to the
			# stationary Route 4 Mewtwo again immediately after battle.
			_queue_mewtwo_battle()
			mewtwo_story_queued = false
		elif tag == &"power_surge_hey":
			power_surge_state = 3
			_walk_officer_toward_player()
		elif tag == &"power_surge_approach":
			power_plant_officer_cell = Vector2i(result.get("cell", power_plant_officer_cell))
			power_plant_officer_facing = int(result.get("facing", power_plant_officer_facing))
			_walk_officer_toward_player()
		elif tag == &"power_surge_explain":
			# The surge conversation is the story gate for Zapdos.
			controller.unlock_zapdos()
			# Experimental: reuse the same surge/cutscene state during the walk home,
			# but suppress the visible exclamation mark.
			power_surge_state = 1
			power_surge_hide_emote = true
			_walk_officer_home()
		elif tag == &"power_surge_return":
			power_plant_officer_cell = Vector2i(result.get("cell", power_plant_officer_cell))
			power_plant_officer_facing = int(result.get("facing", power_plant_officer_facing))
			_walk_officer_home()

	func take_requests() -> Array:
		var requests := _outbox.duplicate()
		_outbox.clear()
		return requests

func register(host: Gen2ModHost, manifest: PokeModManifest) -> void:
	var controller := Controller.new(host, manifest)
	# One registered world actor owns all custom legendary sprites.
	# This follows the documented one-actor registration pattern and avoids
	# multiple registrations under the same mod id.
	host.register_world_actor(manifest.id, VisibleLegendsActor.new(controller, controller.data))

	host.register_option(manifest.id, {
		"key": "enabled",
		"label": "LEGENDARY ROAMERS",
		"values": [false, true],
		"labels": ["OFF", "ON"],
		"default": true,
	})

	host.register_save_lifecycle(manifest, controller)
	host.register_wild_substitute(manifest.id, controller)
	host.subscribe(Gen2ModHost.CHANNEL_BATTLE, manifest.id, controller.on_battle_event)

	# Official API page + START-menu pattern from docs/MODS.md.
	host.register_page(manifest.id, {
		"title": "ROAM DEBUG",
		"rows": controller.page_rows,
	})
	host.register_menu_entry(Gen2ModHost.MENU_START, manifest.id, {
		"label": "ROAM DEBUG",
		"action": Gen2ModHost.START_ACTION_OPEN_MOD_PAGE,
		"page": manifest.id,
	})
