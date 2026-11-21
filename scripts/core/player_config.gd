class_name PlayerConfig extends RefCounted
## What one human player picked on the selection screen.

var source: InputSource
var control_mode := 0  # Game.ControlMode
var color_index := 0
var driver: DriverDef
var kart: KartDef

func color() -> Color:
	return Game.PLAYER_COLORS[color_index % Game.PLAYER_COLORS.size()]
