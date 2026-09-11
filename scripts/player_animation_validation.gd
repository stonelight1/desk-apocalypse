extends CharacterBody2D

## V0.3 Player-only animation validation controller.
## This script intentionally has no combat, weapon, enemy, AI, stats, or loot logic.

const MOVE_SPEED: float = 220.0
const MIN_X: float = 120.0
const MAX_X: float = 1160.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var locked_animation: StringName = &""
var is_dead: bool = false

func _ready() -> void:
	animated_sprite.scale = Vector2.ONE * 0.3
	animated_sprite.position = Vector2(0.0, -58.0)
	animated_sprite.offset = Vector2.ZERO
	animated_sprite.centered = true
	animated_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	animated_sprite.animation_finished.connect(_on_animation_finished)
	animated_sprite.play(&"Idle")

func _physics_process(_delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		return

	if locked_animation != &"":
		velocity = Vector2.ZERO
		return

	var move_input: float = 0.0
	if Input.is_physical_key_pressed(KEY_A):
		move_input -= 1.0
	if Input.is_physical_key_pressed(KEY_D):
		move_input += 1.0

	velocity = Vector2(move_input * MOVE_SPEED, 0.0)
	if move_input != 0.0:
		# The supplied art faces left by default; flip only when moving right.
		animated_sprite.flip_h = move_input > 0.0
		_play_loop(&"Walk")
	else:
		_play_loop(&"Idle")

	move_and_slide()
	position.x = clampf(position.x, MIN_X, MAX_X)

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.physical_keycode == KEY_K:
		_play_death()
	elif key_event.physical_keycode == KEY_J:
		_play_one_shot(&"Attack")
	elif key_event.physical_keycode == KEY_H:
		_play_one_shot(&"Hit")

func _play_loop(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name or not animated_sprite.is_playing():
		animated_sprite.play(animation_name)

func _play_one_shot(animation_name: StringName) -> void:
	if is_dead or locked_animation != &"":
		return

	locked_animation = animation_name
	velocity = Vector2.ZERO
	animated_sprite.play(animation_name)
	print("[Player V0.3] one-shot: ", animation_name)

func _play_death() -> void:
	if is_dead:
		return

	is_dead = true
	locked_animation = &"Death"
	velocity = Vector2.ZERO
	animated_sprite.play(&"Death")
	print("[Player V0.3] one-shot: Death")

func _on_animation_finished() -> void:
	if animated_sprite.animation == &"Death":
		# Keep the final Death frame visible for inspection.
		animated_sprite.pause()
		return

	if animated_sprite.animation == locked_animation:
		locked_animation = &""
		print("[Player V0.3] return to locomotion")
