-- SmartThings Edge driver: Aqara temperature, humidity and pressure sensors (T1 lumi.sensor_ht.agl02 and
-- WSDCGQ11LM lumi.weather). Temperature and humidity use the SmartThings defaults (with the offset settings),
-- pressure and the battery percentage come from the reports these sensors send.
local capabilities = require "st.capabilities"
local ZigbeeDriver = require "st.zigbee"
local defaults = require "st.zigbee.defaults"
local clusters = require "st.zigbee.zcl.clusters"
local cluster_base = require "st.zigbee.cluster_base"
local data_types = require "st.zigbee.data_types"
local log = require "log"
local tlv = require "aqara_tlv"
local ptrend = require "pressure_trend"

local BUILD = "2026-11-08a"
local PRIVATE_CLUSTER = 0xFCC0
local PRIVATE_ATTR_MODE = 0x0009
local PRIVATE_ATTR_REPORT = 0x00F7
local MFG_CODE = 0x115F

local Temperature = clusters.TemperatureMeasurement
local Humidity = clusters.RelativeHumidity
local Pressure = clusters.PressureMeasurement
local Power = clusters.PowerConfiguration
local TREND_ID = "silvervalley08660.pressureTrend"

local function emit_battery(device, mv, source)
  local pct = tlv.battery_percent(mv)
  if not pct then return end
  device:emit_event(capabilities.battery.battery(pct))
  if device:get_field("last_mv") ~= mv then
    device:set_field("last_mv", mv)
    log.info(string.format("[aqara] %s: battery %d mV = %d%% (%s)", device.label, mv, pct, source))
  end
end

-- pressure plus the change over the last 3 hours (trend and storm alert, for routines)
local function emit_pressure(device, kpa, precise)
  if not (kpa and kpa > 30 and kpa < 120) then return end
  local now = os.time()
  if precise then device:set_field("scaled_at", now)
  -- whole hPa (MeasuredValue, hourly report) only when the sensor sends no 0.1 hPa ScaledValue
  elseif now - (device:get_field("scaled_at") or 0) < 2 * 3600 then return end
  device:emit_event(capabilities.atmosphericPressureMeasurement.atmosphericPressure({ value = kpa, unit = "kPa" }))
  local list = ptrend.add(ptrend.decode(device:get_field("p_hist")), now, kpa * 10)
  device:set_field("p_hist", ptrend.encode(list), { persist = true })
  local dv = ptrend.change(list, now)
  if dv == nil then return end
  local drop = tonumber((device.preferences or {}).stormDrop) or 3.6
  pcall(function()
    local Trend = capabilities[TREND_ID]
    device:emit_event(Trend.change({ value = dv, unit = "hPa" }))
    device:emit_event(Trend.trend(ptrend.trend(dv)))
    device:emit_event(Trend.alert(ptrend.alert(dv, drop)))
  end)
  if device:get_field("last_trend") ~= ptrend.trend(dv) then
    device:set_field("last_trend", ptrend.trend(dv))
    log.info(string.format("[aqara] %s: pressure %.1f hPa, %+.1f hPa in 3 h (%s)", device.label, kpa * 10, dv, ptrend.trend(dv)))
  end
end

local function pressure_handler(_driver, device, value, _zb_rx)
  emit_pressure(device, tlv.pressure_kpa(value.value))
end

-- the T1 sends ScaledValue (0.1 hPa with Scale -1) in the same report as MeasuredValue (whole hPa)
local function scale_handler(_driver, device, value, _zb_rx)
  local s = tonumber(value.value)
  if s then device:set_field("p_scale", s, { persist = true }) end
end

local function scaled_handler(_driver, device, value, _zb_rx)
  emit_pressure(device, tlv.scaled_kpa(value.value, device:get_field("p_scale")), true)
end

local function voltage_handler(_driver, device, value, _zb_rx)
  -- the power cluster only has 0.1 V steps; the Aqara report is exact, so use this only without recent Aqara reports
  if os.time() - (device:get_field("aqara_report_at") or 0) < 3 * 3600 then return end
  emit_battery(device, (tonumber(value.value) or 0) * 100, "power cluster")
end

local function private_handler(_driver, device, value, _zb_rx)
  local raw = value and value.value
  if type(raw) ~= "string" then return end
  local rec = tlv.parse(raw)
  if rec[0x01] then
    device:set_field("aqara_report_at", os.time())
    emit_battery(device, rec[0x01], "Aqara report")
  end
  -- the same hourly report carries exact temperature (0.01 C) and humidity (0.01 %); the normal reports only come
  -- after a change of 0.5 C or 6 %, so these keep the values precise
  local c, rh = tlv.temperature_c(rec[0x64]), tlv.humidity_pct(rec[0x65])
  if c then device:emit_event(capabilities.temperatureMeasurement.temperature({ value = c, unit = "C" })) end
  if rh then device:emit_event(capabilities.relativeHumidityMeasurement.humidity(rh)) end
  -- and the pressure in hPa (tag 0x66); the sensor rarely sends a separate pressure report
  emit_pressure(device, rec[0x66] and tlv.pressure_kpa(rec[0x66]))
end

local function refresh(_driver, device)
  device:send(Temperature.attributes.MeasuredValue:read(device))
  device:send(Humidity.attributes.MeasuredValue:read(device))
  device:send(Pressure.attributes.MeasuredValue:read(device))
  device:send(Power.attributes.BatteryVoltage:read(device))
end

local function added(driver, device)
  -- ask the sensor for its Aqara reports (battery); the official SmartThings driver does the same
  device:send(cluster_base.write_manufacturer_specific_attribute(device, PRIVATE_CLUSTER, PRIVATE_ATTR_MODE, MFG_CODE,
    data_types.Uint8, 1))
  refresh(driver, device)
end

local function init(_driver, device)
  log.info(string.format("[aqara] %s: driver build %s", device.label, BUILD))
end

local template = {
  supported_capabilities = {
    capabilities.temperatureMeasurement,
    capabilities.relativeHumidityMeasurement,
    capabilities.battery,
    capabilities.refresh,
  },
  zigbee_handlers = {
    attr = {
      [Pressure.ID] = { [0x0000] = pressure_handler, [0x0014] = scale_handler, [0x0010] = scaled_handler },
      [Power.ID] = { [Power.attributes.BatteryVoltage.ID] = voltage_handler },
      [PRIVATE_CLUSTER] = { [PRIVATE_ATTR_REPORT] = private_handler },
    },
  },
  capability_handlers = {
    [capabilities.refresh.ID] = { [capabilities.refresh.commands.refresh.NAME] = refresh },
  },
  lifecycle_handlers = { added = added, init = init, doConfigure = function(d, dev) dev:configure(); added(d, dev) end },
  health_check = false,
}

defaults.register_for_default_handlers(template, template.supported_capabilities)
local driver = ZigbeeDriver("aqara-climate-local", template)
log.info("[aqara] Aqara Climate Sensor (local) driver starting, build " .. BUILD)
driver:run()
