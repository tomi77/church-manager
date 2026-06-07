extends GutTest

const ProvinceNodeScene := preload("res://scenes/ui/map/ProvinceNode.tscn")

func _make_province_with_pressure(id: String, owner: String, foreign_pressure: Dictionary) -> Province:
    var p := Province.new()
    p.id = id
    p.owner = owner
    p.display_name = id
    p.position = Vector2(100, 100)
    p.pressure = foreign_pressure
    return p

func _instance(prov: Province) -> ProvinceNode:
    var pn: ProvinceNode = ProvinceNodeScene.instantiate()
    add_child_autofree(pn)
    await get_tree().process_frame
    pn.set_province(prov)
    return pn

func test_no_tint_when_max_foreign_pressure_below_60():
    var p := _make_province_with_pressure("test", "islam", {"chr_wschodnie": 50.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "none")

func test_subtle_tint_when_foreign_pressure_61_to_85():
    var p := _make_province_with_pressure("test", "islam", {"chr_wschodnie": 75.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "subtle")

func test_alert_pulse_when_foreign_pressure_over_85():
    var p := _make_province_with_pressure("test", "islam", {"chr_wschodnie": 90.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "alert")

func test_owner_pressure_ignored_for_tint():
    var p := _make_province_with_pressure("test", "islam", {"islam": 95.0})
    var pn := await _instance(p)
    assert_eq(pn.pressure_alert_state(), "none")
