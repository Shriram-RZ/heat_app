import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'home_page.dart';
import 'overlays/alarm_message.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  initializeNotifications();
  runApp(const MyApp());
}


Future<void> initializeNotifications() async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  const initializationSettingsAndroid = AndroidInitializationSettings('app_icon');
  const initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AlarmMessage(), // This launches the overlay UI
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomePage(),
    );
  }
}
