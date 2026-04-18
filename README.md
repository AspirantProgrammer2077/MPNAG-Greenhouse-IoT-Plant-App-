🌱 MPNAG Greenhouse (IoT Plant App)

MPNAG Greenhouse is a smart IoT-based plant monitoring and control system that connects to an ESP32 via Bluetooth. The application tracks real-time environmental data such as temperature, humidity, and soil moisture, allowing users to monitor plant conditions directly from their mobile device.

Take note: This application only works for Android Devices API 35+ since some of the packages are not compatible to flutter_bluetooth_serial package and
I have to change it from flutter_bluetooth_serial into flutter_blue_plus.

🚀 Features
- 📡 Bluetooth connectivity (ESP32)
- 🌡️ Real-time monitoring (temperature, humidity, soil moisture)
- ⚙️ Automatic scheduling based on sensor data
- 🎮 Manual control for user-defined actions
- 📱 Simple and user-friendly interface

🛠️ Tech Stack
- Flutter (Mobile App)
- ESP32 (Microcontroller)
- Bluetooth Communication
- Sensors (Soil Moisture, Temperature, Humidity)

📌 How It Works
The ESP32 collects data from connected sensors and sends it to the mobile app via Bluetooth. Users can:
- Monitor plant conditions in real time
- Set automatic schedules for watering or actions
- Manually control devices when needed

🎯 Purpose
This project aims to improve plant care efficiency, reduce manual effort, and promote smart agriculture using IoT technology.

