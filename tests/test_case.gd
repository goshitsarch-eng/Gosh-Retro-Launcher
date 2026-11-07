class_name TestCase
extends RefCounted
## Minimal xUnit-style base (GUT is not vendored). Subclasses define test_* methods.

var failures: Array[String] = []
var _current := ""


func expect(cond: bool, message: String = "expectation failed") -> void:
	if not cond:
		failures.append("%s: %s" % [_current, message])


func expect_eq(actual: Variant, expected: Variant, message: String = "") -> void:
	if not Jsonx.equal(actual, expected):
		failures.append("%s: %s\n    expected: %s\n    actual:   %s" % [
			_current, message, Jsonx.canon(expected), Jsonx.canon(actual)])


func expect_near(actual: float, expected: float, eps: float = 0.0001, message: String = "") -> void:
	if absf(actual - expected) > eps:
		failures.append("%s: %s expected %s got %s" % [_current, message, expected, actual])


func expect_null(value: Variant, message: String = "") -> void:
	if value != null:
		failures.append("%s: %s expected null, got %s" % [_current, message, str(value)])
