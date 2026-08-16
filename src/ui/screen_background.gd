class_name ScreenBackground
extends Control
## The backdrop full-screen menus are drawn on.

## Every menu uses this instead of its own [ColorRect], so the whole game changes together and no screen carries a colour of its own. The two stops of the gradient come from [UISkinData], and the node restyles itself when the theme is rebuilt.

@onready var _gradient: TextureRect = %Gradient

func _ready() -> void:
	_apply()
	UITheme.theme_changed.connect(_apply)

func _apply() -> void:
	var skin: UISkinData = UITheme.skin
	if skin == null:
		return
	var texture: GradientTexture2D = _gradient.texture as GradientTexture2D
	if texture == null or texture.gradient == null:
		push_warning("ScreenBackground: the Gradient node needs a GradientTexture2D.")
		return
# The texture is shared with the scene file, so it is copied before its colours are changed; otherwise every instance would edit the same one.
	var gradient: Gradient = texture.gradient.duplicate() as Gradient
	gradient.set_color(0, skin.screen_background)
	gradient.set_color(1, skin.screen_background_edge)
	var copy: GradientTexture2D = texture.duplicate() as GradientTexture2D
	copy.gradient = gradient
	_gradient.texture = copy
