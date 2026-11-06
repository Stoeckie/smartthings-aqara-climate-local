-- Aqara private cluster 0xFCC0, attribute 0x00F7: a list of (tag, Zigbee data type, value) records.
-- Tag 0x01 is the battery voltage in mV. Pure functions, no SmartThings libraries.
local M = {}

-- byte length per Zigbee data type id (fixed size types only)
local SIZE = {
  [0x10] = 1, [0x18] = 1, [0x20] = 1, [0x21] = 2, [0x22] = 3, [0x23] = 4, [0x24] = 5, [0x25] = 6, [0x26] = 7, [0x27] = 8,
  [0x28] = 1, [0x29] = 2, [0x2A] = 3, [0x2B] = 4, [0x2C] = 5, [0x2D] = 6, [0x2E] = 7, [0x2F] = 8, [0x39] = 4, [0x3A] = 8,
}
local SIGNED = { [0x28] = true, [0x29] = true, [0x2A] = true, [0x2B] = true }

--- Parse the records; returns { [tag] = number } (unknown types stop the parse).
function M.parse(s)
  local out, i = {}, 1
  while i + 1 <= #s do
    local tag, typ = s:byte(i, i + 1)
    local n = SIZE[typ]
    if not n or i + 1 + n > #s then break end
    local v
    if typ == 0x39 then
      v = string.unpack("<f", s, i + 2)
    elseif typ == 0x3A then
      v = string.unpack("<d", s, i + 2)
    elseif n <= 8 then
      v = string.unpack((SIGNED[typ] and "<i" or "<I") .. n, s, i + 2)
    end
    out[tag] = v
    i = i + 2 + n
  end
  return out
end

--- Battery percentage from a CR2032 / CR2450 voltage in mV (2.6 V empty, 3.0 V full, as the SmartThings drivers do).
function M.battery_percent(mv)
  mv = tonumber(mv)
  if not mv or mv <= 0 then return nil end
  local p = math.floor((mv - 2600) / 4 + 0.5)
  return math.max(0, math.min(100, p))
end

--- Pressure in kPa from the ZCL MeasuredValue (0.1 kPa units).
function M.pressure_kpa(measured)
  measured = tonumber(measured)
  if not measured then return nil end
  return math.floor(measured + 0.5) / 10
end

return M
