extends Node2D

const ZOMBIE_SCENE: PackedScene = preload("res://scenes/enemy/zombie_basic.tscn")
# 参考图的挂机构图是“主角在右、丧尸从左侧接近”，避免开局右侧出现敌人。
const ZOMBIE_SPAWN_POINTS := [Vector2(240, 500), Vector2(400, 500), Vector2(560, 500)]
const ZOMBIE_RESPAWN_DELAY: float = 3.0

var zombie_serial: int = 0
var game_manager: Node

func _ready() -> void:
    print("Desk Apocalypse V0.1 started")
    game_manager = get_node("/root/GameManager")
    if not game_manager.load_game():
        game_manager.reset_run()
    for index in ZOMBIE_SPAWN_POINTS.size():
        _spawn_zombie(index)

func _spawn_zombie(spawn_point_index: int) -> void:
    if spawn_point_index < 0 or spawn_point_index >= ZOMBIE_SPAWN_POINTS.size():
        return
    zombie_serial += 1
    var zombie := ZOMBIE_SCENE.instantiate()
    zombie.name = "Zombie%02d" % zombie_serial
    zombie.position = ZOMBIE_SPAWN_POINTS[spawn_point_index]
    zombie.set_meta("spawn_point_index", spawn_point_index)
    zombie.died.connect(_on_zombie_died)
    add_child(zombie)

func _on_zombie_died(enemy: Node2D) -> void:
    game_manager.add_experience(10)
    var spawn_point_index := int(enemy.get_meta("spawn_point_index", -1))
    if spawn_point_index >= 0:
        get_tree().create_timer(ZOMBIE_RESPAWN_DELAY).timeout.connect(_respawn_zombie.bind(spawn_point_index))

func _respawn_zombie(spawn_point_index: int) -> void:
    if is_inside_tree():
        _spawn_zombie(spawn_point_index)

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        game_manager.save_game()
        get_tree().quit()
