extends CanvasLayer

@onready var health_feedback: Control = $HealthFeedback
@onready var health_bar: ProgressBar = $HealthFeedback/HealthBar
@onready var health_value: Label = $HealthFeedback/Value

var player: Node2D

func _ready() -> void:
    player = get_node_or_null("../Player") as Node2D
    if not is_instance_valid(player):
        health_feedback.visible = false
        return
    if not player.health_changed.is_connected(_on_player_health_changed):
        player.health_changed.connect(_on_player_health_changed)
    _on_player_health_changed(player.hp, player.max_hp)
    _update_health_position()

func _process(_delta: float) -> void:
    if not is_instance_valid(player):
        health_feedback.visible = false
        return
    _update_health_position()

func _on_player_health_changed(current: int, maximum: int) -> void:
    health_bar.max_value = maxi(maximum, 1)
    health_bar.value = clampi(current, 0, maxi(maximum, 1))
    health_value.text = "%d/%d" % [current, maximum]
    health_feedback.visible = true

func _update_health_position() -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var feedback_size := health_feedback.size
    var max_x := maxf(viewport_size.x - feedback_size.x - 8.0, 8.0)
    var max_y := maxf(viewport_size.y - feedback_size.y - 8.0, 8.0)
    var x := clampf(player.global_position.x - feedback_size.x * 0.5, 8.0, max_x)
    var y := clampf(player.global_position.y - 120.0, 8.0, max_y)
    health_feedback.position = Vector2(x, y)
