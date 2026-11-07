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


def test_real_t1_report():
    """Report captured from a T1 on a hub (7-11-2026): battery 2957 mV, 16.38 C, 78.59 %, 1023 hPa."""
    lua = runtime()
    t = req(lua, "aqara_tlv")
    raw = bytes.fromhex("01218d0b032810042 1a84305210d000624050000000008211d010a21a4790c2001642966066529b31e6629ff03".replace(" ", ""))
    rec = t.parse(raw)
    assert rec[1] == 2957 and rec[0x64] == 1638 and rec[0x65] == 7859 and rec[0x66] == 1023
    assert t.pressure_kpa(rec[0x66]) == 102.3 and t.battery_percent(rec[1]) == 89
    assert t.temperature_c(rec[0x64]) == 16.4 and t.humidity_pct(rec[0x65]) == 78.6
    assert t.temperature_c(-126) == -1.3 and t.humidity_pct(None) is None and t.temperature_c(9000) is None
