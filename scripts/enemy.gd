extends CharacterBody2D

const EnemyStateMachine = preload("res://scripts/state/enemy_state_machine.gd")

const State = EnemyStateMachine.State

@export var stats_path: String = "res://data/monster.json"
@export var monster_id: String = "zombie_basic"

var max_hp: int = 0
var current_hp: int = 0
var atk: int = 0
var def: int = 0
var move_speed := 45.0
var attack_range := 70.0
var enemy_attack_interval := 1.5
var _attack_timer := 0.0
var alive := false
var state = State.IDLE
var _battle_manager: Node
var _player: Node2D
var _state_machine: RefCounted

@onready var hp_bar: ProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_state_machine = EnemyStateMachine.new()
	_state_machine.state_changed.connect(_on_state_changed)
	_play_state_animation(State.IDLE)
	_load_stats()
	_battle_manager = get_parent().get_node_or_null("BattleManager")
	var player_node = get_parent().get_node_or_null("Player")
	if player_node is Node2D:
		_player = player_node
	if alive and _battle_manager != null and _battle_manager.has_method("register_enemy"):
		_battle_manager.register_enemy(self)

func _physics_process(_delta: float) -> void:
	if not alive or state == State.DEAD or state == State.HIT:
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(_player):
		var player_node = get_parent().get_node_or_null("Player")
		if player_node is Node2D:
			_player = player_node
	if not _is_player_alive():
		_transition_to(State.IDLE)
		velocity = Vector2.ZERO
		_attack_timer = 0.0
		return

	_update_facing()
	var distance := global_position.distance_to(_player.global_position)
	if distance > attack_range:
		_transition_to(State.CHASE)
		velocity = global_position.direction_to(_player.global_position) * move_speed
		_attack_timer = 0.0
		move_and_slide()
		return

	_transition_to(State.ATTACK)
	velocity = Vector2.ZERO
	_attack_timer -= _delta
	if _attack_timer <= 0.0:
		_attack()
		_attack_timer = enemy_attack_interval

func is_alive() -> bool:
	return alive

func take_damage(value: float) -> void:
	if not alive:
		return

	_transition_to(State.HIT)
	current_hp = max(current_hp - int(value), 0)
	_update_debug_hp()
	print("Enemy HP: %d / %d" % [current_hp, max_hp])
	if current_hp <= 0:
		alive = false
		velocity = Vector2.ZERO
		$CollisionShape2D.set_deferred("disabled", true)
		_transition_to(State.DEAD)
		if _battle_manager != null and _battle_manager.has_method("notify_enemy_death"):
			_battle_manager.notify_enemy_death(self)
		elif _battle_manager != null and _battle_manager.has_method("unregister_enemy"):
			_battle_manager.unregister_enemy(self)
		print("Enemy DEAD")
		await animated_sprite.animation_finished
		if is_inside_tree():
			queue_free()
	else:
		await animated_sprite.animation_finished
		if alive and state == State.HIT:
			_transition_to(State.IDLE)

func _exit_tree() -> void:
	if _battle_manager != null and _battle_manager.has_method("unregister_enemy"):
		_battle_manager.unregister_enemy(self)

func _load_stats() -> void:
	var file = FileAccess.open(stats_path, FileAccess.READ)
	if file == null:
		push_error("Enemy stats file not found: %s" % stats_path)
		return

	var data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_ARRAY:
		push_error("Enemy stats must be a JSON array: %s" % stats_path)
		return

	for monster in data:
		if typeof(monster) == TYPE_DICTIONARY and monster.get("id") == monster_id:
			max_hp = int(monster.get("hp", 0))
			current_hp = max_hp
			atk = int(monster.get("atk", 0))
			def = int(monster.get("def", 0))
			move_speed = float(monster.get("move_speed", move_speed))
			attack_range = float(monster.get("attack_range", attack_range))
			enemy_attack_interval = float(monster.get("attack_interval", enemy_attack_interval))
			alive = max_hp > 0
			_update_debug_hp()
			return

	push_error("Enemy stats not found for id: %s" % monster_id)

func _update_debug_hp() -> void:
	if not is_instance_valid(hp_bar) or not is_instance_valid(hp_label):
		return
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_label.text = "%d / %d" % [current_hp, max_hp]

func _transition_to(next_state: int) -> void:
	_state_machine.transition_to(next_state)
	state = _state_machine.current_state

func _on_state_changed(_previous_state: int, current_state: int) -> void:
	state = current_state
	_play_state_animation(current_state)

func _attack() -> void:
	if not _is_player_alive() or not _player.has_method("take_damage"):
		return

	_update_facing()
	animated_sprite.play(&"zombie_attack")
	print("%s attacks Player" % name)
	print("Enemy Damage: %d" % atk)
	_player.call("take_damage", atk)

func _is_player_alive() -> bool:
	return is_instance_valid(_player) and _player.has_method("is_alive") and _player.is_alive()

func _update_facing() -> void:
	# The source artwork faces left by default; flip only when the player is right.
	animated_sprite.flip_h = _player.global_position.x > global_position.x

func _play_state_animation(current_state: int) -> void:
	if not is_instance_valid(animated_sprite):
		return

	match current_state:
		State.IDLE:
			animated_sprite.play(&"zombie_idle")
		State.CHASE:
			animated_sprite.play(&"zombie_walk")
		State.ATTACK:
			animated_sprite.play(&"zombie_attack")
		State.HIT:
			animated_sprite.play(&"zombie_hit")
		State.DEAD:
			animated_sprite.play(&"zombie_death")
