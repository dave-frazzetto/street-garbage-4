class_name PerkDeck
extends RefCounted
## Deals weighted hands of distinct, currently available perks.

var _pool: Array[Perk] = []
var _rng: RandomNumberGenerator


func _init(perks: Array[Perk], rng: RandomNumberGenerator = null) -> void:
	_pool = perks.duplicate()
	_rng = rng if rng != null else RandomNumberGenerator.new()
	if rng == null:
		_rng.randomize()


func draw_hand(ctx: PerkContext, count: int) -> Array[Perk]:
	var candidates: Array[Perk] = []
	var weights: Array[float] = []
	for perk: Perk in _pool:
		if perk != null and perk.is_available(ctx):
			var w: float = perk.weight * _rarity_weight(ctx.run.config, perk.rarity)
			if w > 0.0:
				candidates.append(perk)
				weights.append(w)
	var hand: Array[Perk] = []
	while hand.size() < count and not candidates.is_empty():
		var index: int = _pick_weighted(weights)
		hand.append(candidates[index])
		candidates.remove_at(index)
		weights.remove_at(index)
	return hand


func _pick_weighted(weights: Array[float]) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var roll: float = _rng.randf() * total
	for i: int in weights.size():
		roll -= weights[i]
		if roll <= 0.0:
			return i
	return weights.size() - 1


static func _rarity_weight(config: RunConfig, rarity: Perk.Rarity) -> float:
	return config.rare_weight if rarity == Perk.Rarity.RARE else config.common_weight
