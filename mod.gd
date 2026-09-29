extends RefCounted

const CUSTOM_LEGENDS := [249, 250, 251] # Lugia, Ho-Oh, Celebi
const SUICUNE := 245
const TAG_PREFIX := "legendary_roamers_"

class Controller:
	extends RefCounted

	var host: Gen2ModHost
	var manifest: PokeModManifest
	var data: GameData
	var save = null
	var roaming: Array = []
	var roaming_maps: Array[Vector2i] = []

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
		host.write_save_data(manifest, p_save, {"version": 3, "roaming": []})

	func save_activated(p_save) -> void:
		save = p_save
		roaming.clear()
		if save == null:
			return
		var stored = host.read_save_data(manifest, save)
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
					"version": 5,
					"roaming": roaming,
					"migrated_lugia_to_route29_v015": true
				})

	func save_deactivated() -> void:
		save = null
		roaming.clear()

	func persist() -> void:
		if save != null:
			host.write_save_data(manifest, save, {
				"version": 5,
				"roaming": roaming,
				"migrated_lugia_to_route29_v015": true
			})

	func find_custom(species: int) -> int:
		for i in roaming.size():
			if int(roaming[i].get("species", 0)) == species:
				return i
		return -1

	func choose_map(species: int, from_map: Vector2i, first_spawn := false) -> Vector2i:
		if first_spawn and data != null:
			var route_29 = data.world_map_named(&"ROUTE_29")
			if route_29 != null:
				return Vector2i(route_29.group, route_29.number)
		if roaming_maps.is_empty():
			return Vector2i(-1, -1)
		var index := posmod(species * 131 + from_map.x * 17 + from_map.y * 31, roaming_maps.size())
		var chosen: Vector2i = roaming_maps[index]
		if chosen == from_map and roaming_maps.size() > 1:
			chosen = roaming_maps[(index + 1) % roaming_maps.size()]
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

		# A custom roamer was met again.
		if tag.begins_with(TAG_PREFIX):
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
		return str(route_names.get(key, key))

	func page_rows() -> Array:
		var rows: Array = [
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
	var _outbox: Array = []
	var cached_grass := PackedVector2Array()
	var cached_allowed := {}

	func _init(p_controller, p_data: GameData) -> void:
		controller = p_controller
		data = p_data
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
		_outbox.clear()
		battle_queued_species = 0
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
		if cached_grass.is_empty():
			return
		for species in CUSTOM_LEGENDS:
			var cell: Vector2i = legend_cells.get(species, Vector2i(-1, -1))
			if cell.x < 0:
				continue
			if world.player_cell == cell:
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
				"solid": false,
			})
		return result

	func interact(cell: Vector2i, _facing: int) -> bool:
		if world == null or controller == null or not controller.enabled():
			return false
		for species in CUSTOM_LEGENDS:
			if legend_cells.get(species, Vector2i(-1, -1)) == cell:
				_queue_battle(species)
				return true
		return false

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
