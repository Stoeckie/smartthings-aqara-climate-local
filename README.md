# Aqara Climate Sensor (local) for SmartThings

SmartThings Edge driver for the Aqara temperature and humidity sensors that also measure air pressure. It runs on your hub over Zigbee, with no cloud involved.

| Model | Zigbee model |
|---|---|
| Aqara Temperature and Humidity Sensor T1 | lumi.sensor_ht.agl02 |
| Aqara Temperature and Humidity Sensor (WSDCGQ11LM) | lumi.weather |

## What you get
* Temperature and humidity, with the standard offset settings
* Air pressure (`atmosphericPressureMeasurement`, kPa)
* Battery as a percentage: 2.6 V is empty and 3.0 V is full. It is read from the Aqara report the sensor sends about once an hour.
* Refresh
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
