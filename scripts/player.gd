extends CharacterBody2D

const DamageCalculator = preload("res://scripts/combat/damage_calculator.gd")
const PlayerStateMachine = preload("res://scripts/state/player_state_machine.gd")

const State = PlayerStateMachine.State

@export var stats_path: String = "res://data/player.json"
@export var weapon_path: String = "res://data/weapon.json"
@export var weapon_id: String = "baseball_bat"
@export var battle_manager_path: NodePath = NodePath("../BattleManager")
@export var target_refresh_interval: float = 0.5

var state = State.IDLE
var target: Node2D
var max_hp := 0
var current_hp := 0
var atk := 0
var def := 0
var crit_rate := 0.0
var crit_damage := 1.0
var move_speed := 0.0
var attack_range := 0.0
var attack_multiplier := 1.0
var attack_speed := 1.0
var attack_interval := 0.0
var _battle_manager: Node
var _state_machine: RefCounted
var _target_refresh_timer := 0.0
var _attack_timer := 0.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_state_machine = PlayerStateMachine.new()
	_state_machine.state_changed.connect(_on_state_changed)
	_play_state_animation(State.IDLE)
	_load_stats()
	_load_weapon()
	_battle_manager = get_node_or_null(battle_manager_path)

func _physics_process(_delta: float) -> void:
	if state == State.DEAD or state == State.HIT:
		velocity = Vector2.ZERO
		return

	_target_refresh_timer -= _delta
	if _target_refresh_timer <= 0.0 or not _is_target_alive():
		_target_refresh_timer = target_refresh_interval
		var next_target = _get_nearest_enemy()
		if not is_instance_valid(target) or next_target != target:
			_attack_timer = 0.0
			target = next_target
			if is_instance_valid(target):
				_update_facing(target.global_position)

	if not _is_target_alive():
		_transition_to(State.IDLE)
		velocity = Vector2.ZERO
		_attack_timer = 0.0
		return

	_update_facing(target.global_position)
	var distance := global_position.distance_to(target.global_position)
	if distance > attack_range:
		_transition_to(State.MOVE)
		velocity = global_position.direction_to(target.global_position) * move_speed
		_attack_timer = 0.0
		move_and_slide()
		return

	_transition_to(State.ATTACK)
	velocity = Vector2.ZERO
	_attack_timer -= _delta
	if _attack_timer <= 0.0:
		_attack()
		_attack_timer = attack_interval

func set_target(new_target: Node2D) -> void:
	if new_target != target:
		_attack_timer = 0.0
	target = new_target
	if is_instance_valid(target):
		_update_facing(target.global_position)

func _transition_to(next_state: int) -> void:
	_state_machine.transition_to(next_state)
	state = _state_machine.current_state

func _on_state_changed(_previous_state: int, current_state: int) -> void:
	state = current_state
	_play_state_animation(current_state)

func _play_state_animation(current_state: int) -> void:
	if not is_instance_valid(animated_sprite):
		return

	match current_state:
		State.IDLE:
			animated_sprite.play(&"player_idle")
		State.MOVE:
			animated_sprite.play(&"player_walk")
		State.ATTACK:
			animated_sprite.play(&"player_attack")
		State.HIT:
			animated_sprite.play(&"player_hit")
		State.DEAD:
			animated_sprite.play(&"player_death")

func _attack() -> void:
	if not _is_target_alive() or not target.has_method("take_damage"):
		return

	_update_facing(target.global_position)
	animated_sprite.play(&"player_attack")
	var enemy_def := int(target.get("def"))
	var damage: Dictionary = DamageCalculator.calculate(
		atk,
		attack_multiplier,
		crit_rate,
		crit_damage,
		enemy_def
	)
	print("Player attacks %s" % target.name)
	print("Raw Damage: %d" % roundi(damage["raw_damage"]))
	if damage["critical"]:
		print("CRITICAL")
	print("Enemy DEF: %d" % enemy_def)
	print("Final Damage: %d" % damage["final_damage"])
	target.call("take_damage", damage["final_damage"])

func take_damage(value: float) -> void:
	if not is_alive():
		return

	_transition_to(State.HIT)
	current_hp = max(current_hp - int(value), 0)
	print("Player HP: %d / %d" % [current_hp, max_hp])
	if current_hp <= 0:
		velocity = Vector2.ZERO
		target = null
		_transition_to(State.DEAD)
		print("Player DEAD")
		return

	await animated_sprite.animation_finished
	if is_alive() and state == State.HIT:
		_transition_to(State.IDLE)

func is_alive() -> bool:
	return current_hp > 0 and state != State.DEAD

func _update_facing(target_position: Vector2) -> void:
	# The source artwork faces left by default; flip only when the target is right.
	animated_sprite.flip_h = target_position.x > global_position.x

func _get_nearest_enemy() -> Node2D:
	if _battle_manager == null or not _battle_manager.has_method("get_nearest_enemy"):
		return null

	var nearest = _battle_manager.get_nearest_enemy(global_position)
	if nearest is Node2D:
		return nearest
	return null

func _is_target_alive() -> bool:
	if not is_instance_valid(target):
		return false
	if target.has_method("is_alive"):
		return target.is_alive()
	return true

func _load_stats() -> void:
	var file = FileAccess.open(stats_path, FileAccess.READ)
	if file == null:
		push_error("Player stats file not found: %s" % stats_path)
		return

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_error("Player stats must be a JSON object: %s" % stats_path)
		return

	max_hp = int(data.get("hp", 0))
	current_hp = max_hp
	atk = int(data.get("atk", 0))
	def = int(data.get("def", 0))
	crit_rate = float(data.get("crit_rate", 0.0))
	crit_damage = float(data.get("crit_damage", 1.0))
	move_speed = float(data.get("move_speed", 0.0))
	attack_range = float(data.get("attack_range", 0.0))

func _load_weapon() -> void:
	var file = FileAccess.open(weapon_path, FileAccess.READ)
	if file == null:
		push_error("Weapon data file not found: %s" % weapon_path)
		return

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		push_error("Weapon data must be a JSON array: %s" % weapon_path)
		return

	for weapon in data:
		if typeof(weapon) == TYPE_DICTIONARY and weapon.get("id") == weapon_id:
			attack_multiplier = float(weapon.get("attack_multiplier", 0.0))
			attack_speed = float(weapon.get("attack_speed", 0.0))
			if attack_speed <= 0.0:
				push_error("Weapon attack_speed must be greater than zero: %s" % weapon_id)
				return
			attack_interval = 1.0 / attack_speed
			return

	push_error("Weapon data not found for id: %s" % weapon_id)
