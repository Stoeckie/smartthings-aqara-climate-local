# Aqara Climate Sensor (local) for SmartThings

SmartThings Edge driver for the Aqara temperature and humidity sensors that also measure air pressure. It runs on your hub over Zigbee, with no cloud involved.

| Model | Zigbee model |
|---|---|
| Aqara Temperature and Humidity Sensor T1 | lumi.sensor_ht.agl02 |
| Aqara Temperature and Humidity Sensor (WSDCGQ11LM) | lumi.weather |

## What you get
* Temperature and humidity, with the standard offset settings. The sensor itself only reports after a change of 0.5 °C or 6 %; the driver also takes the exact values (0.1 °C, 0.1 %) from the hourly Aqara report
* Air pressure (`atmosphericPressureMeasurement`, kPa), from the pressure reports and the hourly Aqara report
* Air pressure in 0.1 hPa steps: the T1 also sends a scaled value next to the whole hPa value, the driver uses that one
* Pressure trend (`silvervalley08660.pressureTrend`), for routines and storm alerts:
  * **Change in 3 hours** in hPa
  * **Trend** in the classes of the marine forecasts: steady (below 0.5 hPa), slowly (0.5 to 1.5), rising or falling (1.6 to 3.5), quickly (3.6 to 6.0), very rapidly (above 6.0)
  * **Storm alert**: storm when the pressure falls at least the set amount in 3 hours (setting, default 3.6 hPa, "falling quickly")
  * The trend starts after 2.5 hours of readings and survives a hub restart
* Battery as a percentage: 2.6 V is empty and 3.0 V is full. It is read from the Aqara report the sensor sends about once an hour (exact to the mV). The 0.1 V steps of the standard battery report are only used when that report is missing.
* Refresh
* A value only goes to the hub when it changed; after a driver start every value is sent once so the app catches up
* Everything works in routines

## Why
* **Official SmartThings driver:** it shows no pressure, and gives battery only as normal, warning or critical.
* **Community drivers:** some of them have no pressure in their profile, so every pressure report from these sensors ends in an error in the hub log.

## Install
1. Enroll your hub: https://bestow-regional.api.smartthings.com/invite/qWjBdybRNG2y (Stoeckie Edge Drivers) and install **Aqara Climate Sensor (local)**.
2. Choose how to add the sensor:
   * **New sensor:** Add device, Scan nearby, then hold the button on the sensor for 5 s.
   * **Sensor you already have:** switch the driver in the app (device, menu, Driver, Select different driver), or with the CLI: `smartthings edge:drivers:switch <device-id> --driver <driver-id>`. The device keeps its name, room and routines.

The sensors sleep, so new values come with the next report: on a change, and otherwise every few minutes. Battery comes about once an hour.

## License
Apache 2.0, see LICENSE. Not affiliated with Aqara.
