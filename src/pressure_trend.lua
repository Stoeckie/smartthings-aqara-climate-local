-- Pressure trend over the last 3 hours, in the classes of the marine forecasts (change in hPa in 3 hours):
-- steady below 0.5 (the sensor has 0.1 hPa steps), slowly 0.5 to 1.5, normal 1.6 to 3.5, quickly 3.6 to 6.0,
-- very rapidly above 6.0. Samples are kept as a string "time:hPa;..." so they survive a hub restart.
local M = {}

M.WINDOW = 3 * 3600      -- the change is given per 3 hours
M.MIN_SPAN = 2.5 * 3600  -- at least this much history before a trend is given
M.KEEP = 4 * 3600        -- history kept
M.GAP = 10 * 60          -- samples closer together than this replace the previous one

function M.decode(s)
  local out = {}
  for t, v in tostring(s or ""):gmatch("(%d+):([%d%.]+)") do out[#out + 1] = { t = tonumber(t), v = tonumber(v) } end
  return out
end

function M.encode(list)
  local parts = {}
  for _, x in ipairs(list) do parts[#parts + 1] = string.format("%d:%.1f", x.t, x.v) end
  return table.concat(parts, ";")
end

-- add a sample (hPa) at time now; returns the new list
function M.add(list, now, hpa)
  local out = {}
  for _, x in ipairs(list) do
    if now - x.t <= M.KEEP and x.t <= now then out[#out + 1] = x end
  end
  local last = out[#out]
  if last and now - last.t < M.GAP then out[#out] = { t = last.t, v = hpa } -- keep the time, newest value
  else out[#out + 1] = { t = now, v = hpa } end
  return out
end

-- change in hPa per 3 hours, or nil when there is not enough history
function M.change(list, now)
  local cur = list[#list]
  if not cur then return nil end
  local base, best
  for _, x in ipairs(list) do
    local age = now - x.t
    if age >= M.MIN_SPAN then
      local d = math.abs(age - M.WINDOW)
      if not best or d < best then best, base = d, x end
    end
  end
  if not base or cur.t <= base.t then return nil end
  local dv = (cur.v - base.v) * M.WINDOW / (cur.t - base.t)
  local r = math.floor(math.abs(dv) * 10 + 0.5) / 10
  return dv < 0 and -r or r
end

function M.trend(dv)
  if dv == nil then return nil end
  local a = math.abs(dv)
  if a < 0.5 then return "steady" end
  local dir = dv > 0 and "rising" or "falling"
  if a <= 1.5 then return dir .. "Slowly" end
  if a <= 3.5 then return dir end
  if a <= 6.0 then return dir .. "Quickly" end
  return dir .. "VeryRapidly"
end

-- "storm" when the pressure dropped at least `drop` hPa in 3 hours
function M.alert(dv, drop)
  if dv == nil then return nil end
  return (dv <= -(drop or 3.6)) and "storm" or "clear"
end

return M
