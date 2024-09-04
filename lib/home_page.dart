import 'package:alarm_app/notification_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart' as local_notifications;
import 'package:flutter_overlay_window/flutter_overlay_window.dart' as overlay_window;
import 'package:thermal/thermal.dart';
import 'package:vibration/vibration.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:restart_app/restart_app.dart'; // Import the restart_app package

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _isOverlayActive = false;
  bool _isNotificationEnabled = false;
  double _batteryTemperature = 0.0;
  Battery _battery = Battery();
  BatteryState _batteryState = BatteryState.charging;
  int _batteryLevel = 0;
  final double _temperatureThreshold = 37;

  @override
  void initState() {
    super.initState();
    startForegroundService();
    _monitorBatteryTemperature();
    _getBatteryState();
    _getBatteryLevel();
  }

  Future<void> startForegroundService() async {
    await FlutterForegroundTask.startService(
      notificationTitle: 'Blast Beam',
      notificationText: 'Monitoring battery temperature in the background.',
    );
  }

  Future<void> stopForegroundService() async {
    await FlutterForegroundTask.stopService();
  }

  Future<void> showLocalNotification({
    required double temperature,
  }) async {
    const androidPlatformChannelSpecifics = local_notifications.AndroidNotificationDetails(
      'temperature_alert_channel',
      'Temperature Alerts',
      importance: local_notifications.Importance.high,
      priority: local_notifications.Priority.high,
      showWhen: false,
    );

    const platformChannelSpecifics = local_notifications.NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    try {
      await NotificationService.flutterLocalNotificationsPlugin.show(
        0,
        'Temperature Alert',
        'Battery temperature is ${temperature.toStringAsFixed(2)}°C',
        platformChannelSpecifics,
        payload: 'Temperature alert',
      );
    } catch (e) {
      print('Error showing notification: $e');
    }
  }

  void _monitorBatteryTemperature() {
    Thermal().onBatteryTemperatureChanged.listen((temperature) async {
      setState(() {
        _batteryTemperature = temperature;
      });

      if (_isNotificationEnabled && temperature > _temperatureThreshold) {
        await showLocalNotification(temperature: temperature);
      }

      if (temperature > _temperatureThreshold && !_isOverlayActive) {
        _showAlarmOverlay();
        _triggerVibration();
      } else if (temperature <= _temperatureThreshold && _isOverlayActive) {
        _closeAlarmOverlay();
        _stopVibration();
      }
    });
  }

  Future<void> _triggerVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.vibrate(pattern: [500, 1000, 500, 1000]);
    }
  }

  Future<void> _stopVibration() async {
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.cancel();
    }
  }

  Future<void> _toggleOverlay(bool value) async {
    if (value) {
      final hasPermission = await overlay_window.FlutterOverlayWindow.isPermissionGranted();
      if (!hasPermission) {
        await overlay_window.FlutterOverlayWindow.requestPermission();
      }
    } else {
      _closeAlarmOverlay();
    }

    setState(() {
      _isOverlayActive = value;
    });
  }

  Future<void> _showAlarmOverlay() async {
    final isOverlayActive = await overlay_window.FlutterOverlayWindow.isActive();

    if (!isOverlayActive) {
      await overlay_window.FlutterOverlayWindow.showOverlay(
        enableDrag: false,
        overlayTitle: "Temperature Alert",
        overlayContent: "Battery temperature: ${_batteryTemperature.toStringAsFixed(2)}°C\n\nTap 'Close' to dismiss.",
        alignment: overlay_window.OverlayAlignment.center,
        visibility: overlay_window.NotificationVisibility.visibilityPublic,
      );

      setState(() {
        _isOverlayActive = true;
      });
    }
  }

  Future<void> _closeAlarmOverlay() async {
    await overlay_window.FlutterOverlayWindow.closeOverlay();
    setState(() {
      _isOverlayActive = false;
    });
  }

  Future<void> _getBatteryState() async {
    _battery.onBatteryStateChanged.listen((BatteryState state) {
      setState(() {
        _batteryState = state;
      });
    });
  }

  Future<void> _getBatteryLevel() async {
    final level = await _battery.batteryLevel;
    setState(() {
      _batteryLevel = level;
    });
  }

  @override
  void dispose() {
    stopForegroundService();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Blast Beam'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // First Row: Radial Gauge with Gradient Background
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple.shade200, Colors.purple.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: SfRadialGauge(
                  axes: <RadialAxis>[
                    RadialAxis(
                      minimum: 0,
                      maximum: 50,
                      ranges: <GaugeRange>[
                        GaugeRange(startValue: 0, endValue: 35, color: Colors.green),
                        GaugeRange(startValue: 35, endValue: 40, color: Colors.orange),
                        GaugeRange(startValue: 40, endValue: 50, color: Colors.red),
                      ],
                      pointers: <GaugePointer>[
                        NeedlePointer(value: _batteryTemperature),
                      ],
                      annotations: <GaugeAnnotation>[
                        GaugeAnnotation(
                          widget: Text(
                            '${_batteryTemperature.toStringAsFixed(2)}°C',
                            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
                          ),
                          angle: 90,
                          positionFactor: 0.5,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Second Row: Battery Level and Battery State in Separate Boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue.shade200, Colors.blue.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            Icons.battery_std,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Battery Level',
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            '$_batteryLevel%',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blueGrey.shade200, Colors.blueGrey.shade400],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Icon(
                            _batteryState == BatteryState.charging
                                ? Icons.battery_charging_full
                                : Icons.battery_std,
                            size: 40,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Battery State',
                            style: const TextStyle(color: Colors.white, fontSize: 18),
                          ),
                          Text(
                            _batteryState == BatteryState.charging
                                ? 'Charging'
                                : 'Normal',
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Third Row: Box for Show Overlay with Switch
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color.fromARGB(255, 143, 244, 219), const Color.fromARGB(255, 150, 248, 230)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Show Overlay:',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 10),
                    Switch(
                      value: _isOverlayActive,
                      onChanged: (value) {
                        setState(() {
                          _isOverlayActive = value;
                          _toggleOverlay(_isOverlayActive);
                        });
                      },
                      activeColor: const Color.fromARGB(255, 123, 215, 255),
                      inactiveThumbColor: Colors.grey,
                      inactiveTrackColor: Colors.grey.shade300,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _isOverlayActive ? 'Overlay is Active' : 'Overlay is Inactive',
                style: TextStyle(fontSize: 16, color: _isOverlayActive ? Colors.green : Colors.red),
              ),
              const SizedBox(height: 20),
              // Reload Button
              ElevatedButton(
                onPressed: () {
                  Restart.restartApp(); // Restart the app
                },
                child: const Text('Reload App'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
