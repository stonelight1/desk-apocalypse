extends Sprite2D

func _ready() -> void:
    var viewport := get_viewport()
    if not viewport.size_changed.is_connected(_fit_to_viewport):
        viewport.size_changed.connect(_fit_to_viewport)
    _fit_to_viewport()

func _fit_to_viewport() -> void:
    if texture == null:
        return
    var viewport_size := get_viewport_rect().size
    var texture_size := texture.get_size()
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or texture_size.x <= 0.0 or texture_size.y <= 0.0:
        return
    position = viewport_size * 0.5
    var cover_scale := maxf(viewport_size.x / texture_size.x, viewport_size.y / texture_size.y)
    scale = Vector2.ONE * cover_scale
