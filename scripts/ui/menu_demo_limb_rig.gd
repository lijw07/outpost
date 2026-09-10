extends RefCounted
## Two-segment pixel limbs. The elbow bends instead of stretching a straight line.
const INK := Color("14211f")

static func joints(shoulder: Vector2, hand: Vector2, bend: float) -> PackedVector2Array:
	var delta := hand-shoulder
	var distance := clampf(delta.length(),0.1,23.8)
	var direction := delta.normalized() if delta.length_squared() > 0.01 else Vector2.DOWN
	var wrist := shoulder+direction*distance
	var along := clampf((13.0*13.0-11.0*11.0+distance*distance)/(2*distance),0,13)
	var midpoint := shoulder+direction*along
	var height := sqrt(maxf(0,13.0*13.0-along*along))
	var elbow := midpoint+direction.orthogonal()*height*bend
	return PackedVector2Array([shoulder,elbow,wrist])

static func draw_arm(canvas: Node2D, points: PackedVector2Array, sleeve: Color, skin: Color, undead: bool) -> void:
	# Work at the same two-world-unit pixel density as the body silhouette.
	var shoulder := (points[0]*0.5).round()
	var elbow := (points[1]*0.5).round()
	var wrist := (points[2]*0.5).round()
	var cuff := elbow.lerp(wrist,0.45).round()
	for color_width in [[INK,4.0],[sleeve.darkened(0.22),2.0]]:
		var color: Color = color_width[0]
		var width: float = color_width[1]
		canvas.draw_line(shoulder,elbow,color,width,false)
		canvas.draw_line(elbow,cuff,color,width,false)
		canvas.draw_circle(elbow,width*0.5,color)
		canvas.draw_circle(shoulder,width*0.5,color)
	canvas.draw_line(shoulder,elbow,sleeve,1,false)
	canvas.draw_line(cuff,wrist,INK,3,false)
	canvas.draw_line(cuff,wrist,skin.darkened(0.15),1,false)
	canvas.draw_rect(Rect2(wrist-Vector2(1,1),Vector2(3,3)),INK)
	canvas.draw_rect(Rect2(wrist,Vector2(2,2)),skin)
	if undead:
		var forward := (wrist-elbow).normalized()
		canvas.draw_line(wrist,wrist+forward*2,skin,1,false)
