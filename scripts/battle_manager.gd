extends Node

signal enemy_died(enemy: Node2D)

const EnemyScene = preload("res://scenes/Enemy.tscn")

@export var max_enemy_count: int = 3
@export var respawn_delay: float = 2.0
@export var spawn_points_path: NodePath = NodePath("../BattleArea/EnemySpawnPoints")

var _enemies: Array[Node2D] = []
var _spawn_points: Array[Node2D] = []
var _spawn_points_root: Node
var _next_spawn_index := 0
var _next_enemy_id := 4

func _ready() -> void:
	call_deferred("_initialize_spawn_points")

func _initialize_spawn_points() -> void:
	_spawn_points_root = get_node_or_null(spawn_points_path)
	if _spawn_points_root == null:
		push_error("Enemy spawn points node not found: %s" % spawn_points_path)
		return

	for child in _spawn_points_root.get_children():
		if child is Node2D:
			_spawn_points.append(child)

	if _spawn_points.is_empty():
		push_error("No enemy spawn points configured")
		return

	_ensure_enemy_count()

func register_enemy(enemy: Node2D) -> void:
	if is_instance_valid(enemy) and not _enemies.has(enemy):
		_enemies.append(enemy)

func unregister_enemy(enemy: Node2D) -> void:
	_enemies.erase(enemy)

func notify_enemy_death(enemy: Node2D) -> void:
	unregister_enemy(enemy)
	enemy_died.emit(enemy)
	get_tree().create_timer(respawn_delay).timeout.connect(_spawn_enemy)

func get_nearest_enemy(player_position: Vector2) -> Node2D:
	_cleanup_enemies()
	var nearest_enemy: Node2D
	var nearest_distance_squared: float = INF

	for enemy in _enemies:
		if not is_instance_valid(enemy):
			continue
		if not enemy.has_method("is_alive") or not enemy.is_alive():
			continue

		var distance_squared := player_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest_enemy = enemy

	return nearest_enemy

func _ensure_enemy_count() -> void:
	_cleanup_enemies()
	while _enemies.size() < max_enemy_count:
		_spawn_enemy()

func _spawn_enemy() -> void:
	_cleanup_enemies()
	if _enemies.size() >= max_enemy_count:
		return
	if _spawn_points.is_empty():
		return

	var spawn_point := _get_available_spawn_point()
	if spawn_point == null:
		return
	var enemy := EnemyScene.instantiate()
	enemy.name = "Enemy_%02d" % _next_enemy_id
	_next_enemy_id += 1
	get_parent().add_child(enemy)
	enemy.global_position = spawn_point.global_position

func _get_available_spawn_point() -> Node2D:
	for offset in _spawn_points.size():
		var index := (_next_spawn_index + offset) % _spawn_points.size()
		var spawn_point := _spawn_points[index]
		var occupied := false
		for enemy in _enemies:
			if is_instance_valid(enemy) and enemy.global_position.distance_squared_to(spawn_point.global_position) < 1.0:
				occupied = true
				break
		if not occupied:
			_next_spawn_index = (index + 1) % _spawn_points.size()
			return spawn_point

	return null

func _cleanup_enemies() -> void:
	for enemy in _enemies.duplicate():
		if not is_instance_valid(enemy):
			_enemies.erase(enemy)
