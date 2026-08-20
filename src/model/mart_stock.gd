class_name MartStock
## What a shop charges, item record + shop settings / event settings

## Sale price as a fraction of the buying price
## Used for items that do not have their own sell price
const SELL_FRACTION: float = 0.5


## Sets what [param item_id] costs from now on
## A price of `0` makes it unsellable
static func set_price(item_id: StringName, price: int) -> void:
	GameState.mart_prices[item_id] = maxi(price, 0)

## Sets what [param item_id] sells for
static func set_sell_price(item_id: StringName, price: int) -> void:
	GameState.mart_sell_prices[item_id] = maxi(price, 0)

## Forgets every override
static func clear() -> void:
	GameState.mart_prices.clear()
	GameState.mart_sell_prices.clear()

## What [param record] costs to buy
static func price_of(record: ItemData) -> int:
	if record == null:
		return 0
	if GameState.mart_prices.has(record.id):
		return int(GameState.mart_prices[record.id])
	return record.price

## What [param record] sells back for
static func sell_price_of(record: ItemData) -> int:
	if record == null:
		return 0
	if GameState.mart_sell_prices.has(record.id):
		return int(GameState.mart_sell_prices[record.id])
	if record.sell_price > 0:
		return record.sell_price
	return int(float(price_of(record)) * SELL_FRACTION)

## The two override tables written out for the save file
static func to_dict() -> Dictionary:
	return {
		"prices": _string_keys(GameState.mart_prices),
		"sell_prices": _string_keys(GameState.mart_sell_prices),
	}

static func from_dict(source: Dictionary) -> void:
	GameState.mart_prices = _stringname_keys(source.get("prices", {}))
	GameState.mart_sell_prices = _stringname_keys(source.get("sell_prices", {}))

static func _string_keys(table: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: StringName in table:
		result[String(key)] = int(table[key])
	return result

static func _stringname_keys(table: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in table:
		result[StringName(String(key))] = int(table[key])
	return result
