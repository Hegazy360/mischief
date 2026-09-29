## NavGraph — portal graph of the house; Dijkstra paths with per-mover tick costs (TECH §3.3).
##
## Rooms are 1-D segments on a floor. Links: doorways (always open, shared x, free to cross), doors
## (open/close ticks per mover) and the stairs (traversal ticks per mover, foot ↔ head). `path()`
## returns a NavPath whose legs change room at their start (see NavPath).
class_name NavGraph
extends RefCounted

var house: HouseDef = null
## Per room: bitmask of rooms joined to it by a doorway (squeak hearing).
var doorway_adj: PackedInt32Array = PackedInt32Array()


## Build from a HouseDef.
static func build(h: HouseDef) -> NavGraph:
	var g := NavGraph.new()
	g.house = h
	g.doorway_adj.resize(h.rooms.size())
	for i in h.rooms.size():
		g.doorway_adj[i] = 0
	for l in h.links:
		if l.kind == LinkDef.DOORWAY and l.a_idx >= 0 and l.b_idx >= 0:
			g.doorway_adj[l.a_idx] |= 1 << l.b_idx
			g.doorway_adj[l.b_idx] |= 1 << l.a_idx
	return g


## Base speed (sub-px per tick) of a mover (SimConst.MOVER_*).
static func mover_speed(mover: int) -> int:
	match mover:
		SimConst.MOVER_HUSH_RUN:
			return SimConst.HUSH_RUN
		SimConst.MOVER_B_WALK:
			return SimConst.B_WALK
		SimConst.MOVER_B_CHASE:
			return SimConst.B_CHASE
		_:
			return SimConst.HUSH_TIPTOE


static func _is_hush(mover: int) -> bool:
	return mover == SimConst.MOVER_HUSH_WALK or mover == SimConst.MOVER_HUSH_RUN


func _link_ticks(l: LinkDef, mover: int) -> int:
	if l.kind == LinkDef.DOORWAY:
		return 0
	return l.hush_ticks if _is_hush(mover) else l.bellows_ticks


## Shortest path in ticks for `mover` from (room, x) to (room, x); x in sub-px. `room_mask` limits the
## rooms passed through (bit per room idx; the start and goal rooms are always allowed); -1 = all.
## `speed` > 0 overrides the mover's walking speed for the costs. Returns a NavPath (`ok` false and
## no legs when unreachable).
func path(from_room: int, from_x: int, to_room: int, to_x: int, mover: int, room_mask: int = -1, speed: int = -1) -> NavPath:
	var p := NavPath.new()
	var sp := speed if speed > 0 else mover_speed(mover)
	p.speed = sp
	p.x = from_x
	p.room = from_room
	if from_room < 0 or to_room < 0 or from_room >= house.rooms.size() or to_room >= house.rooms.size():
		p.ok = false
		return p
	if from_room == to_room:
		p.add_leg(to_room, to_x, NavPath.WALK, Fx.div_ceil(absi(to_x - from_x), sp))
		return p
	var nl := house.links.size()
	var nn := nl * 2
	# node n = link*2 + side (0 = standing on the a side, 1 = on the b side)
	var dist := PackedInt32Array()
	var prev := PackedInt32Array()
	var done := PackedByteArray()
	dist.resize(nn)
	prev.resize(nn)
	done.resize(nn)
	const INF := 1 << 30
	for i in nn:
		dist[i] = INF
		prev[i] = -2
		done[i] = 0
	# seed: walk from the start to every link end in the start room
	for li in house.room_links[from_room]:
		var l := house.links[li]
		if l.kind < 0 or l.a_idx < 0 or l.b_idx < 0:
			continue
		var side := 0 if l.a_idx == from_room else 1
		var node := li * 2 + side
		var c := Fx.div_ceil(absi(l.x_in(from_room) - from_x), sp)
		if c < dist[node]:
			dist[node] = c
			prev[node] = -1
	var best_goal := INF
	var best_goal_node := -1
	while true:
		var u := -1
		var ud := INF
		for i in nn:
			if done[i] == 0 and dist[i] < ud:
				ud = dist[i]
				u = i
		if u < 0 or ud >= best_goal:
			break
		done[u] = 1
		var li := u >> 1
		var side := u & 1
		var l := house.links[li]
		var here := l.a_idx if side == 0 else l.b_idx
		var hx := l.x_in(here)
		if here == to_room:
			var gc := ud + Fx.div_ceil(absi(to_x - hx), sp)
			if gc < best_goal:
				best_goal = gc
				best_goal_node = u
		# cross this link
		var there := l.b_idx if side == 0 else l.a_idx
		if there == to_room or there == from_room or _allowed(room_mask, there):
			var v := li * 2 + (1 - side)
			var cv := ud + _link_ticks(l, mover)
			if cv < dist[v]:
				dist[v] = cv
				prev[v] = u
		# walk to other links in the same room
		for lj in house.room_links[here]:
			if lj == li:
				continue
			var m := house.links[lj]
			if m.kind < 0 or m.a_idx < 0 or m.b_idx < 0:
				continue
			var s2 := 0 if m.a_idx == here else 1
			var w := lj * 2 + s2
			var cw := ud + Fx.div_ceil(absi(m.x_in(here) - hx), sp)
			if cw < dist[w]:
				dist[w] = cw
				prev[w] = u
	if best_goal_node < 0:
		p.ok = false
		return p
	# backtrack the node chain
	var chain := PackedInt32Array()
	var cur := best_goal_node
	while cur >= 0:
		chain.append(cur)
		cur = prev[cur]
	chain.reverse()
	# legs: the chain alternates "arrive at link end" nodes; a node whose predecessor is the other end
	# of the same link is a crossing.
	var cur_room := from_room
	var cx := from_x
	for ci in chain.size():
		var node := chain[ci]
		var li := node >> 1
		var side := node & 1
		var l := house.links[li]
		var here := l.a_idx if side == 0 else l.b_idx
		var hx := l.x_in(here)
		var crossed := ci > 0 and (chain[ci - 1] >> 1) == li
		if crossed:
			match l.kind:
				LinkDef.DOORWAY:
					p.add_leg(here, hx, NavPath.WALK, 0, li)
				LinkDef.DOOR:
					p.add_leg(here, hx, NavPath.DOOR, maxi(1, _link_ticks(l, mover)), li)
				LinkDef.STAIRS:
					p.add_leg(here, hx, NavPath.STAIRS, maxi(1, _link_ticks(l, mover)), li)
			cur_room = here
			cx = hx
		else:
			p.add_leg(cur_room, hx, NavPath.WALK, Fx.div_ceil(absi(hx - cx), sp))
			cx = hx
	p.add_leg(to_room, to_x, NavPath.WALK, Fx.div_ceil(absi(to_x - cx), sp))
	return p


static func _allowed(mask: int, r: int) -> bool:
	return mask == -1 or (mask & (1 << r)) != 0


## Path cost in ticks (-1 unreachable).
func cost(from_room: int, from_x: int, to_room: int, to_x: int, mover: int, room_mask: int = -1) -> int:
	var p := path(from_room, from_x, to_room, to_x, mover, room_mask)
	return p.remaining_ticks() if p.ok else -1


## True when `a` and `b` are the same room or joined by a doorway.
func doorway_joined(a: int, b: int) -> bool:
	if a < 0 or b < 0:
		return false
	return a == b or (doorway_adj[a] & (1 << b)) != 0


## Walking distance in sub-px between two points on the same floor (-1 across floors).
func floor_distance(room_a: int, x_a: int, room_b: int, x_b: int) -> int:
	if room_a < 0 or room_b < 0:
		return -1
	if house.rooms[room_a].floor != house.rooms[room_b].floor:
		return -1
	return absi(x_a - x_b)


## The doorway link idx of `room` that lies ahead of x in direction `facing` within `near` sub-px, -1 if none.
func doorway_ahead(room: int, x: int, facing: int, near: int) -> int:
	if room < 0:
		return -1
	for li in house.room_links[room]:
		var l := house.links[li]
		if l.kind != LinkDef.DOORWAY:
			continue
		var d := (l.x_sub - x) * facing
		if d >= 0 and d <= near:
			return li
	return -1
