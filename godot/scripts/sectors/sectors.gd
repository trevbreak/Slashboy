class_name Sectors
extends RefCounted
## Sector registry.

const TOTAL_ITEMS := 12   # energy tanks + ki shards hidden across the game
const NAMES := {"s1": "RING C", "s2": "UNDERCITY", "s3": "FOUNDRY", "s4": "ARCHIVES", "s5": "BLOOM HEART"}


static func make(id: String) -> Level:
	match id:
		"s1": return Sector1.new()
		"s2": return Sector2.new()
		"s3": return Sector3.new()
		"s4": return Sector4.new()
		"s5": return Sector5.new()
	push_error("unknown sector " + id)
	return Sector1.new()
