"""Pressure trend over 3 hours, classes, storm alert and the ScaledValue conversion."""
from run_lua import runtime, req

H = 3600


def test_classes_and_alert():
    t = req(runtime(), "pressure_trend")
    assert t.trend(0.3) == b"steady" and t.trend(-0.4) == b"steady"
    assert t.trend(1.0) == b"risingSlowly" and t.trend(-1.5) == b"fallingSlowly"
    assert t.trend(2.0) == b"rising" and t.trend(-3.5) == b"falling"
    assert t.trend(-3.6) == b"fallingQuickly" and t.trend(6.0) == b"risingQuickly"
    assert t.trend(-6.1) == b"fallingVeryRapidly" and t.trend(None) is None
    assert t.alert(-3.6, 3.6) == b"storm" and t.alert(-3.5, 3.6) == b"clear" and t.alert(-5, 6) == b"clear"


def test_history_and_change():
    lua = runtime()
    t = req(lua, "pressure_trend")
    lst = lua.table()
    now = 1_000_000
    # one sample every 30 min, falling 1 hPa per hour
    for i in range(9):
        lst = t.add(lst, now + i * 1800, 1020.0 - i * 0.5)
    end = now + 8 * 1800
    assert t.change(lst, end) == -3.0                       # 3 h back: 1021.5 -> 1018.0 is -3.0 at 1 hPa/h
    # too little history: nothing
    short = t.add(t.add(lua.table(), now, 1020.0), now + 2 * H, 1019.0)
    assert t.change(short, now + 2 * H) is None
    # samples within 10 min replace the last value, older than 4 h are dropped, survives encode/decode
    lst2 = t.add(t.add(lua.table(), now, 1020.0), now + 300, 1020.4)
    assert len(lst2) == 1 and lst2[1].v == 1020.4
    enc = t.encode(lst)
    back = t.decode(enc)
    assert len(back) == len(lst) and t.change(back, end) == -3.0
    pruned = t.add(back, end + 2 * H, 1017.0)
    assert all(end + 2 * H - x.t <= 4 * H for x in pruned.values())


def test_scaled_value():
    t = req(runtime(), "aqara_tlv")
    assert t.scaled_kpa(10234, -1) == 102.34 and t.scaled_kpa(10234, None) == 102.34
    assert t.scaled_kpa(50, -1) is None
