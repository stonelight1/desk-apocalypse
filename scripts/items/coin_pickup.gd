extends Area2D

const PICKUP_DISTANCE: float = 54.0
const BOB_HEIGHT: float = 4.0
const BOB_SPEED: float = 3.0

@export var value: int = 1

var _base_y: float
var _time: float = 0.0
var _player: Node2D

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    _base_y = position.y
    _player = get_node_or_null("../Player") as Node2D

func _process(delta: float) -> void:
    _time += delta
    sprite.position.y = sin(_time * BOB_SPEED) * BOB_HEIGHT
    if not is_instance_valid(_player):
        _player = get_node_or_null("../Player") as Node2D
    if is_instance_valid(_player) and global_position.distance_to(_player.global_position) <= PICKUP_DISTANCE:
        collect()

func collect() -> void:
    GameManager.add_coin(value)
    queue_free()
