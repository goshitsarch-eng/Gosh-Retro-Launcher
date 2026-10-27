class_name IconRegistry
extends RefCounted
## Built-in 32x32 icon catalog + icon-string resolver (port of utils/icons.ts: BUILTIN_ICONS and getIconSrc).
## PLACEHOLDER — implemented by the platform agent. Shell-specific catalogs (wfw/, win95/) live with the shells.


## [{id, name}] in picker order.
static func builtin_list() -> Array:
	return []


static func builtin_texture(_id: String) -> Texture2D:
	return null


static func default_item_texture() -> Texture2D:
	return null


## Resolves an `icon` string (builtin id, legacy name, data: URL, http URL, file path) to a texture.
## Never returns null: falls back to default_item_texture(). Port of getIconSrc semantics.
static func resolve(_icon: String) -> Texture2D:
	return default_item_texture()
