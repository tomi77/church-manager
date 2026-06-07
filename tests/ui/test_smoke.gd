extends GutTest

func test_ui_test_dir_is_discovered():
	# Smoke test — jeśli runner ten plik podniósł, to katalog tests/ui/ jest discoverable
	assert_true(true, "tests/ui/ jest discoverable przez GUT")
