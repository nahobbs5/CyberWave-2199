extends SceneTree
## Scratch probe for the Vale da Lua build (temporary).
func _initialize() -> void:
	_go.call_deferred()
func _go() -> void:
	create_timer(200.0).timeout.connect(func() -> void: quit(2))
	var t0 := Time.get_ticks_msec()
	var track := (load("res://scenes/tracks/vale_da_lua.tscn") as PackedScene).instantiate() as TrackCircuit
	root.add_child(track)
	print("build ms ", Time.get_ticks_msec() - t0, " length ", track.length)
	var s := track.get_node("Scenery") as ValeDaLuaScenery
	print("crossings ", s.river_crossings, " depths ", s.crossing_depths, " falls ", s.waterfalls, " drop ", s.river_drop)
	print("boulders ", s.boulder_count(), " free ", s.boulder_origins.size())
	var on_road := 0
	for i in s.boulder_origins.size():
		if s.edge_distance(s.boulder_origins[i]) < s.boulder_radii[i] * 0.5:
			on_road += 1
	print("boulders on road ", on_road)
	var zones := track.find_children("*", "RecoveryZone", true, false)
	print("zones ", zones.size(), " boxes ", zones[0].get_child_count() if zones.size() > 0 else 0)
	var bad := 0
	var d := 0.0
	while d < track.length:
		for lat in [-6.5, 0.0, 6.5]:
			if zones.size() > 0 and (zones[0] as RecoveryZone).has_point(track.get_safe_transform(d, lat, 0.6).origin):
				bad += 1
		d += 2.0
	print("road samples in water zone ", bad, " signs ", track.get_node("_GenCornerSigns").get_child_count(), " open ", track.open_edges)
	quit()
