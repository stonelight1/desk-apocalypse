extends CharacterBody2D

enum State {
    IDLE,
    WALK,
    ATTACK,
    HIT,
    DEATH
}

const SPEED: float = 55.0
const BATTLE_AREA_LEFT: float = 128.0
const BATTLE_AREA_RIGHT: float = 1152.0
const BATTLE_AREA_TOP: float = 430.0
const BATTLE_AREA_BOTTOM: float = 560.0
const PATROL_LEFT: float = 760.0
const PATROL_RIGHT: float = 960.0
const DATA_LOADER = preload("res://scripts/core/data_loader.gd")
const DAMAGE_POPUP_SCENE: PackedScene = preload("res://scenes/ui/damage_popup.tscn")
const HIT_EFFECT_TEXTURE: Texture2D = preload("res://UI/Assets/Effects/melee_hit_01.png")
const WEAPON_DATA_PATH: String = "res://data/weapons/baseball_bat.json"
const ANIMATION_DATA_PATH: String = "res://UI/Assets/Characters/Player/Config/animation_data.json"
const ANIMATION_TEXTURE_PATHS := {
    "idle": "res://UI/Assets/Characters/Player/Animations/idle.png",
    "walk": "res://UI/Assets/Characters/Player/Animations/walk.png",
    "attack": "res://UI/Assets/Characters/Player/Animations/attack.png",
    "hit": "res://UI/Assets/Characters/Player/Animations/hit.png",
    "death": "res://UI/Assets/Characters/Player/Animations/death.png",
}
const ATTACK_RANGE: float = 60.0
const ATTACK_ANIMATION_DURATION: float = 0.625
const ATTACK_HIT_DELAY: float = 0.25
const HIT_ANIMATION_DURATION: float = 0.3
const RESPAWN_DELAY: float = 3.0

signal health_changed(current: int, maximum: int)

@export var max_hp: int = 100

var current_state: State = State.WALK
var direction: float = 1.0
var hp: int
var attack_damage: int = 10
var attack_interval: float = 1.0
var attack_cooldown: float = 0.5
var attack_count: int = 0
var last_target_name: String = ""
var last_attack_damage: int = 0
var animation_timer: float = 0.0
var hit_timer: float = 0.0
var spawn_position: Vector2
var pending_target: Node2D
var pending_damage: int = 0
var pending_attack_timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_effect: Sprite2D = $AttackEffect
@onready var game_manager: Node = get_node("/root/GameManager")

func _ready() -> void:
    _setup_animations()
    sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    attack_effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    var weapon_data := DATA_LOADER.load_json(WEAPON_DATA_PATH)
    attack_damage = int(weapon_data.get("attack", attack_damage))
    attack_interval = float(weapon_data.get("attack_speed", attack_interval))
    hp = max_hp
    spawn_position = global_position
    direction = -1.0
    current_state = State.IDLE
    attack_effect.visible = false
    _clamp_to_battle_area()
    _play_animation("idle")

func _physics_process(delta: float) -> void:
    if current_state == State.DEATH:
        velocity = Vector2.ZERO
        return

    attack_cooldown = maxf(attack_cooldown - delta, 0.0)
    animation_timer = maxf(animation_timer - delta, 0.0)
    hit_timer = maxf(hit_timer - delta, 0.0)
    if is_instance_valid(pending_target):
        pending_attack_timer = maxf(pending_attack_timer - delta, 0.0)
        if pending_attack_timer == 0.0:
            _resolve_pending_attack()
    if hit_timer > 0.0:
        current_state = State.HIT
    elif animation_timer > 0.0:
        current_state = State.ATTACK
    else:
        current_state = State.IDLE
        _play_animation("idle")

    # 攻击/受击演出期间锁定位置，避免出现边挥棒边后退的视觉错误。
    if hit_timer > 0.0 or animation_timer > 0.0:
        velocity = Vector2.ZERO
        sprite.flip_h = direction > 0.0
        _clamp_to_battle_area()
        return

    # 玩家保持在右侧战斗位，不主动追击左侧丧尸；丧尸负责接近玩家。
    var attack_target := _find_nearest_enemy(ATTACK_RANGE)
    if is_instance_valid(attack_target):
        var horizontal_distance := attack_target.global_position.x - global_position.x
        velocity = Vector2.ZERO
        if horizontal_distance != 0.0:
            direction = 1.0 if horizontal_distance > 0.0 else -1.0
    else:
        velocity = Vector2(direction * SPEED, 0.0)
        if global_position.x <= PATROL_LEFT and direction < 0.0:
            direction = 1.0
        elif global_position.x >= PATROL_RIGHT and direction > 0.0:
            direction = -1.0
        current_state = State.WALK
        _play_animation("walk")

    move_and_slide()
    _clamp_to_battle_area()
    # The supplied character art faces left by default, so flip only while moving right.
    sprite.flip_h = direction > 0.0
    if is_instance_valid(attack_target) and attack_cooldown == 0.0:
        _auto_attack()
        attack_cooldown = attack_interval

func _auto_attack() -> void:
    var target := _find_nearest_enemy(ATTACK_RANGE)
    if not is_instance_valid(target):
        return

    current_state = State.ATTACK
    animation_timer = ATTACK_ANIMATION_DURATION
    _play_animation("attack")
    _show_attack_effect()
    last_attack_damage = attack_damage + game_manager.weapon_bonus_damage
    pending_target = target
    pending_damage = last_attack_damage
    pending_attack_timer = ATTACK_HIT_DELAY
    last_target_name = target.name

func _resolve_pending_attack() -> void:
    var target := pending_target
    pending_target = null
    if not is_instance_valid(target) or not target.has_method("take_damage"):
        return
    _spawn_hit_effect(target)
    target.take_damage(pending_damage)
    attack_count += 1

func _show_attack_effect() -> void:
    attack_effect.visible = true
    attack_effect.modulate.a = 1.0
    attack_effect.scale = Vector2.ONE * 0.09
    attack_effect.flip_h = direction > 0.0
    attack_effect.position = Vector2(-58.0 if direction < 0.0 else 58.0, -72.0)
    var tween := attack_effect.create_tween()
    tween.tween_property(attack_effect, "modulate:a", 0.0, 0.24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_callback(_hide_attack_effect)

func _hide_attack_effect() -> void:
    attack_effect.visible = false

func _spawn_hit_effect(target: Node2D) -> void:
    var effect := Sprite2D.new()
    effect.texture = HIT_EFFECT_TEXTURE
    effect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    effect.z_index = 30
    effect.scale = Vector2.ONE * 0.07
    get_tree().current_scene.add_child(effect)
    effect.global_position = target.global_position + Vector2(0.0, -62.0)
    var tween := effect.create_tween().set_parallel(true)
    tween.tween_property(effect, "scale", Vector2.ONE * 0.1, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(effect, "modulate:a", 0.0, 0.24).set_delay(0.04)
    tween.chain().tween_callback(effect.queue_free)

func _find_nearest_enemy(max_distance: float = INF) -> Node2D:
    var nearest: Node2D
    var nearest_distance := INF
    for candidate in get_tree().get_nodes_in_group("enemies"):
        if not is_instance_valid(candidate) or not candidate.has_method("take_damage"):
            continue
        var distance := global_position.distance_to(candidate.global_position)
        if distance <= max_distance and distance < nearest_distance:
            nearest_distance = distance
            nearest = candidate as Node2D
    return nearest

func _clamp_to_battle_area() -> void:
    var clamped_x := clampf(global_position.x, BATTLE_AREA_LEFT, BATTLE_AREA_RIGHT)
    var clamped_y := clampf(global_position.y, BATTLE_AREA_TOP, BATTLE_AREA_BOTTOM)
    if global_position.x != clamped_x or global_position.y != clamped_y:
        global_position = Vector2(clamped_x, clamped_y)
    if clamped_x <= BATTLE_AREA_LEFT:
        direction = 1.0
    elif clamped_x >= BATTLE_AREA_RIGHT:
        direction = -1.0

func take_damage(value: int) -> void:
    if current_state == State.DEATH:
        return
    hp = maxi(hp - value, 0)
    health_changed.emit(hp, max_hp)
    _spawn_damage_popup(value, Color("#ff716d"))
    if hp == 0:
        current_state = State.DEATH
        velocity = Vector2.ZERO
        collision_layer = 0
        collision_mask = 0
        _play_animation("death")
        get_tree().create_timer(RESPAWN_DELAY).timeout.connect(_respawn)
    else:
        current_state = State.HIT
        hit_timer = HIT_ANIMATION_DURATION
        _play_animation("hit")

func _respawn() -> void:
    if not is_inside_tree():
        return
    global_position = spawn_position
    hp = max_hp
    collision_layer = 2
    collision_mask = 1
    direction = 1.0
    attack_cooldown = attack_interval
    animation_timer = 0.0
    hit_timer = 0.0
    pending_target = null
    pending_attack_timer = 0.0
    current_state = State.WALK
    health_changed.emit(hp, max_hp)
    _play_animation("walk")

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
        push_warning("Player animation texture missing: %s" % texture_path)
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
