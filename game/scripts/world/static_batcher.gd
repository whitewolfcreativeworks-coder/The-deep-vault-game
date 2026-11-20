extends Object
class_name StaticBatcher
## Draw calls are what slow a tablet down the most: a forest has hundreds of copies
## of the same trees, rocks, fences and barrels, and each copy costs its own draw
## call. Once a level is built, this gathers identical imported props that sit in
## the same patch of ground (a 40 m grid, so patches off-screen are still skipped)
## into one MultiMesh each: one draw call per patch instead of one per prop.
##
## Only plain, still scenery is touched: imported meshes (from .gltf/.glb) with no
## script anywhere between them and the level, no animation player, not on a
## moving body, and visible. Anything made in code (gates, bridges that crumble,
## doors...) or alive (monsters, chests, NPCs...) is left exactly as it was. The
## originals are hidden, not deleted, so any script holding one still works.

const CELL := 40.0
const MIN_COUNT := 4

static func batch(root: Node3D) -> Dictionary:
	var groups := {}
	var baked := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if not _batchable(mi, root):
			continue
		var mesh := _mesh_for(mi, baked)
		if mesh == null:
			continue
		var p := mi.global_position
		# props that fade out with distance batch in small patches, so they still
		# disappear at about the right distance (the range applies to the patch)
		var cell := CELL if mi.visibility_range_end <= 0.0 else 14.0
		var key := "%d|%d|%d|%d|%d|%s|%s|%s|%s|%d|%d" % [mesh.get_instance_id(), mi.material_override.get_instance_id() if mi.material_override else 0,
			mi.material_overlay.get_instance_id() if mi.material_overlay else 0, mi.cast_shadow, mi.layers,
			str(snappedf(mi.visibility_range_begin, 0.1)), str(snappedf(mi.visibility_range_end, 0.1)), str(snappedf(mi.transparency, 0.01)),
			str(mi.visibility_range_fade_mode), floori(p.x / cell), floori(p.z / cell)]
		if not groups.has(key):
			groups[key] = [mesh, []]
		(groups[key][1] as Array).append(mi)
	var inv := root.global_transform.affine_inverse()
	var made := 0
	var replaced := 0
	for key in groups:
		var list: Array = groups[key][1]
		if list.size() < MIN_COUNT:
			continue
		var first: MeshInstance3D = list[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = groups[key][0]
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, inv * (list[i] as MeshInstance3D).global_transform)
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Batch"
		mmi.multimesh = mm
		mmi.material_override = first.material_override
		mmi.cast_shadow = first.cast_shadow
		mmi.layers = first.layers
		mmi.material_overlay = first.material_overlay
		mmi.transparency = first.transparency
		mmi.visibility_range_begin = first.visibility_range_begin
		mmi.visibility_range_begin_margin = first.visibility_range_begin_margin
		mmi.visibility_range_end = first.visibility_range_end
		mmi.visibility_range_end_margin = first.visibility_range_end_margin
		mmi.visibility_range_fade_mode = first.visibility_range_fade_mode
		root.add_child(mmi)
		for m in list:
			(m as MeshInstance3D).visible = false
		made += 1
		replaced += list.size()
	return {"batches": made, "meshes": replaced}

## Small things far away are a few pixels each but still cost a draw call each
## (a mushroom's spots, a chicken's beak, a goblin's earring). Give every mesh a
## draw distance by its size: under 0.6 m: 40 m, under 2 m: 65 m, under 5 m:
## 110 m; bigger things (trees, walls, portals, beacons) are always drawn. Meshes
## that already have their own draw distance, and anything in the "far_visible"
## group, are left alone.
static func cull_small(root: Node, only_under := false) -> int:
	var n := 0
	for g in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		if gi.visibility_range_end > 0.0 or gi.is_in_group("far_visible") or gi is MultiMeshInstance3D:
			continue
		var r := draw_distance(gi)
		if r > 0.0:
			gi.visibility_range_end = r
			gi.visibility_range_end_margin = 3.0
			n += 1
	return n

static func draw_distance(gi: GeometryInstance3D) -> float:
	if gi is Label3D and (gi as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED:
		return 0.0          # floating markers ("!" over a quest giver, names) are meant to be seen from afar
	var flame := gi is CPUParticles3D or gi is GPUParticles3D
	var ab := gi.get_aabb()
	var sc := gi.global_transform.basis.get_scale() if gi.is_inside_tree() else Vector3.ONE
	var e := maxf(ab.size.x * absf(sc.x), maxf(ab.size.y * absf(sc.y), ab.size.z * absf(sc.z)))
	if e <= 0.0:
		return 0.0
	if flame and e < 5.0:
		return 70.0          # torch flames and the like: a little further
	if e < 0.6:
		return 40.0
	if e < 2.0:
		return 65.0
	if e < 5.0:
		return 110.0
	return 0.0

## The mesh to draw: the prop's own, or a copy with its per-surface material
## overrides baked in (shared by every prop with the same overrides).
static func _mesh_for(mi: MeshInstance3D, baked: Dictionary) -> Mesh:
	var mesh := mi.mesh
	var over: Array = []
	var any := false
	for i in mi.get_surface_override_material_count():
		var m := mi.get_surface_override_material(i)
		over.append(m)
		if m != null:
			any = true
	if not any:
		return mesh
	if not mesh is ArrayMesh:
		return null
	var k := str(mesh.get_instance_id()) + ":" + ",".join(over.map(func(m: Variant) -> String: return str(m.get_instance_id()) if m else "-"))
	if not baked.has(k):
		var copy := (mesh as ArrayMesh).duplicate() as ArrayMesh
		for i in over.size():
			if over[i] != null and i < copy.get_surface_count():
				copy.surface_set_material(i, over[i])
		baked[k] = copy
	return baked[k]

static func _batchable(mi: MeshInstance3D, root: Node3D) -> bool:
	if mi.mesh == null or not mi.is_visible_in_tree() or mi.get_script() != null or mi.skin != null:
		return false
	var path := String(mi.mesh.resource_path)
	if not path.begins_with("res://assets/") or not path.contains("::"):
		return false          # made in code: might be animated by its level
	if mi.is_in_group("no_batch"):
		return false
	var n: Node = mi.get_parent()
	while n != null and n != root:
		if n.get_script() != null or n.is_in_group("no_batch"):
			return false
		if n is CharacterBody3D or n is RigidBody3D or n is AnimatableBody3D or n is Area3D or n is Skeleton3D or n is BoneAttachment3D:
			return false
		for c in n.get_children():
			if c is AnimationPlayer or c is AnimationTree:
				return false
		n = n.get_parent()
	return n == root

## (for the tests: why meshes weren't batched)
static func reasons(root: Node3D) -> Dictionary:
	var out := {}
	var paths := {}
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var r := "ok"
		if mi.mesh == null: r = "no mesh"
		elif not mi.is_visible_in_tree(): r = "hidden"
		elif mi.get_script() != null: r = "script"
		elif mi.skin != null: r = "skin"
		elif not String(mi.mesh.resource_path).begins_with("res://assets/") or not String(mi.mesh.resource_path).contains("::"): r = "code-made mesh"
		else:
			var nn: Node = mi.get_parent()
			while nn != null and nn != root:
				if nn.get_script() != null:
					r = "scripted ancestor " + String(nn.get_script().resource_path.get_file()); break
				if nn is CharacterBody3D or nn is RigidBody3D or nn is AnimatableBody3D or nn is Area3D or nn is Skeleton3D or nn is BoneAttachment3D:
					r = "body " + nn.get_class(); break
				var anim := false
				for c in nn.get_children():
					if c is AnimationPlayer or c is AnimationTree:
						anim = true
				if anim:
					r = "animated"; break
				nn = nn.get_parent()
		out[r] = int(out.get(r, 0)) + 1
		if r == "code-made mesh":
			var anc := ""
			var nn2: Node = mi.get_parent()
			var depth := 0
			while nn2 != null and nn2 != root and depth < 6:
				if nn2.get_script() != null:
					anc = nn2.get_script().resource_path.get_file()
				nn2 = nn2.get_parent(); depth += 1
			var mk := "%s mat:%s anc:%s" % [mi.mesh.get_class(), "override" if mi.material_override else ("surf" if mi.get_surface_override_material_count() > 0 and mi.get_surface_override_material(0) else "mesh"), anc]
			paths[mk] = int(paths.get(mk, 0)) + 1
	out["sample_paths"] = paths
	return out
