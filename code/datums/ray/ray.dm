#define RAY_CAST_DEFAULT_MAX_DISTANCE 50
#define RAY_CAST_STEP 0.01

/ray
	var/vector3/origin //the origin of the ray
	var/vector3/direction //direction of the ray

//use atom2vector3 for the origin, atoms2vector3 for the direction
/ray/New(var/vector3/p_origin, var/vector3/p_direction)
	origin = p_origin
	direction = p_direction.normalized()

/ray/proc/getPoint(var/distance)
	var/vector3/path = direction.times(distance)
	return origin.plus(path).floored()

/ray/proc/getFirstHit(var/max_distance = RAY_CAST_DEFAULT_MAX_DISTANCE)
	var/vector3/step = direction.times(RAY_CAST_STEP)
	var/vector3/pointer = new /vector3(0,0,0)
	while(pointer.euclidian_norm() < max_distance)
		pointer = pointer.plus(step)
		var/vector3/new_position = origin.plus(pointer).floored()
		if(!new_position.equals(origin.floored()))
			var/turf/T = locate(new_position.x, new_position.y, new_position.z)
			return new /rayCastHit(src, T, new_position.minus(origin).euclidian_norm())

/ray/proc/getAllHits(var/max_distance = RAY_CAST_DEFAULT_MAX_DISTANCE)
	var/vector3/step = direction.times(RAY_CAST_STEP)
	var/list/vector3/positions = list()
	var/vector3/pointer = new /vector3(0,0,0)
	while(pointer.euclidian_norm() < max_distance)
		pointer = pointer.plus(step)
		var/vector3/new_position = origin.plus(pointer).floored()
		var/exists = FALSE
		for(var/vector3/V in positions)
			if(V.equals(new_position))
				exists = TRUE
		if(!exists && !new_position.equals(origin.floored()))
			positions += new_position

	. = list()
	for(var/vector3/P in positions)
		var/turf/T = locate(P.x, P.y, P.z)
		. += new /rayCastHit(src, T, P.minus(origin).euclidian_norm())
