extends Node2D

@onready var amount_label: Label = $Amount

func _ready() -> void:
    z_index = 30
    var tween := create_tween().set_parallel(true)
    tween.tween_property(self, "position:y", position.y - 34.0, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
    tween.tween_property(self, "modulate:a", 0.0, 0.55).set_delay(0.12)
    tween.chain().tween_callback(queue_free)

func setup(value: int, color: Color) -> void:
    amount_label.text = str(value)
    amount_label.modulate = color
