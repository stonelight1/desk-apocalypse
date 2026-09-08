extends CharacterBody2D

signal died(enemy: Node2D)

const DATA_LOADER = preload("res://scripts/core/data_loader.gd")
const DAMAGE_POPUP_SCENE: PackedScene = preload("res://scenes/ui/damage_popup.tscn")
const DATA_PATH: String = "res://data/enemies/zombie_basic_01.json"
const ANIMATION_DATA_PATH: String = "res://UI/Assets/Characters/Zombie/Basic/Config/animation_data.json"
const ANIMATION_TEXTURE_PATHS := {
	"idle": "res://UI/Assets/Characters/Zombie/Basic/Animations/idle.png",
	"walk": "res://UI/Assets/Characters/Zombie/Basic/Animations/walk.png",
	"attack": "res://UI/Assets/Characters/Zombie/Basic/Animations/attack.png",
	"hit": "res://UI/Assets/Characters/Zombie/Basic/Animations/hit.png",
	"death": "res://UI/Assets/Characters/Zombie/Basic/Animations/death.png",
}
const MIN_ATTACK_RANGE: float = 1.0
const ATTACK_ANIMATION_DURATION: float = 0.625
const HIT_ANIMATION_DURATION: float = 0.3
const DEATH_ANIMATION_DURATION: float = 0.75
const MIN_SEPARATION: float = 64.0
const SEPARATION_SPEED: float = 80.0

@export var max_hp: int = 100
@export var attack_damage: int = 10
@export var move_speed: float = 40.0
@export var attack_range: float = 40.0
@export var attack_interval: float = 2.0
@export var target_path: NodePath = NodePath("../Player")

var hp: int
var target: Node2D
var current_state: String = "chase"
var attack_cooldown: float = 0.0
var animation_timer: float = 0.0
var hit_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_setup_animations()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var data := DATA_LOADER.load_json(DATA_PATH)
	max_hp = int(data.get("hp", max_hp))
	attack_damage = int(data.get("attack", attack_damage))
	move_speed = float(data.get("speed", move_speed))
	attack_range = float(data.get("attack_range", attack_range))
	attack_interval = float(data.get("attack_interval", attack_interval))
	hp = max_hp
	target = get_node_or_null(target_path) as Node2D
	_play_animation("walk")

func _physics_process(delta: float) -> void:
	if current_state == "dead":
		velocity = Vector2.ZERO
		return

	if not is_instance_valid(target):
		target = get_node_or_null(target_path) as Node2D

	if not is_instance_valid(target):
		velocity = Vector2.ZERO
		return

	attack_cooldown = maxf(attack_cooldown - delta, 0.0)
	animation_timer = maxf(animation_timer - delta, 0.0)
	hit_timer = maxf(hit_timer - delta, 0.0)
	if hit_timer > 0.0:
		_play_animation("hit")
	elif animation_timer > 0.0:
		_play_animation("attack")

	var horizontal_distance := target.global_position.x - global_position.x
	# 攻击/受击演出期间锁定位置，避免丧尸边攻击边滑动。
	if hit_timer > 0.0 or animation_timer > 0.0:
		velocity = Vector2.ZERO
		sprite.flip_h = horizontal_distance > 0.0
		return

	if abs(horizontal_distance) <= maxf(attack_range, MIN_ATTACK_RANGE):
		current_state = "idle"
		velocity = Vector2.ZERO
		if hit_timer <= 0.0 and animation_timer <= 0.0:
			_play_animation("idle")
		if attack_cooldown == 0.0 and target.has_method("take_damage"):
			animation_timer = ATTACK_ANIMATION_DURATION
			_play_animation("attack")
			target.take_damage(attack_damage)
			attack_cooldown = attack_interval
	else:
		current_state = "chase"
		var chase_speed: float = sign(horizontal_distance) * move_speed
		velocity = Vector2(chase_speed + _get_separation_velocity(), 0.0)
		# The supplied zombie art faces left by default, so flip when moving right.
		sprite.flip_h = horizontal_distance > 0.0
		if hit_timer <= 0.0 and animation_timer <= 0.0:
			_play_animation("walk")
		move_and_slide()

func _get_separation_velocity() -> float:
	var own_slot := int(get_meta("spawn_point_index", -1))
	if own_slot < 0:
		return 0.0

	var separation := 0.0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other) or other.current_state == "dead":
			continue
		var other_slot := int(other.get_meta("spawn_point_index", -1))
		if other_slot < 0 or other_slot == own_slot:
			continue
		var horizontal_gap: float = global_position.x - other.global_position.x
		if own_slot < other_slot:
			# 较小序号代表队列更靠左，不能穿过后面的敌人。
			if horizontal_gap > -MIN_SEPARATION:
				separation -= SEPARATION_SPEED * clampf((MIN_SEPARATION + horizontal_gap) / MIN_SEPARATION, 0.0, 1.0)
		else:
			# 较大序号代表队列更靠右，不能穿过前面的敌人。
			if horizontal_gap < MIN_SEPARATION:
				separation += SEPARATION_SPEED * clampf((MIN_SEPARATION - horizontal_gap) / MIN_SEPARATION, 0.0, 1.0)
	return separation

func take_damage(value: int) -> void:
	if current_state == "dead":
		return
	hp = maxi(hp - value, 0)
	_spawn_damage_popup(value, Color("#ffb16d"))
	if hp == 0:
		die()
	else:
		current_state = "hit"
		hit_timer = HIT_ANIMATION_DURATION
		_play_animation("hit")

func die() -> void:
	if current_state == "dead":
		return
	current_state = "dead"
	remove_from_group("enemies")
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	_play_animation("death")
	died.emit(self)
	get_tree().create_timer(DEATH_ANIMATION_DURATION).timeout.connect(queue_free)

func _spawn_damage_popup(value: int, color: Color) -> void:
	var popup := DAMAGE_POPUP_SCENE.instantiate()
	popup.position = global_position + Vector2(0.0, -92.0)
	get_tree().current_scene.add_child(popup)
	popup.setup(value, color)

func _setup_animations() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	var config_data := DATA_LOADER.load_json(ANIMATION_DATA_PATH)
	var animation_config: Dictionary = config_data.get("animations", {})
	for animation_name in ANIMATION_TEXTURE_PATHS:
		var fallback_frames := 1
		var fallback_fps := 6.0
		var fallback_loop: bool = animation_name in ["idle", "walk"]
		var spec: Dictionary = animation_config.get(animation_name, {})
		var frame_count := maxi(int(spec.get("frames", fallback_frames)), 1)
		var fps := maxf(float(spec.get("fps", fallback_fps)), 1.0)
		var loop := bool(spec.get("loop", fallback_loop))
		var rects: Array = spec.get("rects", [])
		_add_sheet_animation(frames, animation_name, ANIMATION_TEXTURE_PATHS[animation_name], frame_count, fps, loop, rects)
	sprite.sprite_frames = frames

func _add_sheet_animation(frames: SpriteFrames, animation_name: String, texture_path: String, frame_count: int, fps: float, loop: bool, rects: Array = []) -> void:
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("Zombie animation texture missing: %s" % texture_path)
		return
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	frames.set_animation_loop(animation_name, loop)
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.filter_clip = true
		if rects.size() == frame_count and rects[index] is Array and rects[index].size() == 4:
			var values: Array = rects[index]
			atlas.region = Rect2(float(values[0]), float(values[1]), float(values[2]), float(values[3]))
		else:
			var frame_width := texture.get_width() / float(frame_count)
			atlas.region = Rect2(frame_width * index, 0.0, frame_width, texture.get_height())
		frames.add_frame(animation_name, atlas)

func _play_animation(animation_name: String) -> void:
	if sprite.animation != StringName(animation_name):
		sprite.play(animation_name)
