"""Aqara TLV report, battery and pressure conversion."""
import struct
from run_lua import runtime, req


def test_parse_real_report():
    lua = runtime()
    t = req(lua, "aqara_tlv")
    # tag 1: battery 2985 mV (uint16), tag 5: uint16, tag 0x64: int16 temperature, tag 0x0a: uint16, tag 0x66: int32 pressure
    raw = (bytes([0x01, 0x21]) + struct.pack("<H", 2985) + bytes([0x05, 0x21]) + struct.pack("<H", 12)
           + bytes([0x64, 0x29]) + struct.pack("<h", -125) + bytes([0x0a, 0x21]) + struct.pack("<H", 0)
           + bytes([0x66, 0x2B]) + struct.pack("<i", 102340) + bytes([0x08, 0x39]) + struct.pack("<f", 1.5))
    rec = t.parse(raw)
    assert rec[1] == 2985 and rec[5] == 12 and rec[0x64] == -125 and rec[0x66] == 102340 and rec[8] == 1.5
    # unknown type stops parsing without error
    assert t.parse(bytes([0x01, 0x21, 0x10, 0x0b, 0x02, 0x99, 0x00]))[1] == 2832


def test_battery_and_pressure():
    lua = runtime()
    t = req(lua, "aqara_tlv")
    assert t.battery_percent(3000) == 100 and t.battery_percent(2600) == 0
    assert t.battery_percent(2900) == 75 and t.battery_percent(3200) == 100 and t.battery_percent(2400) == 0
    assert t.battery_percent(0) is None
    assert t.pressure_kpa(1023) == 102.3
