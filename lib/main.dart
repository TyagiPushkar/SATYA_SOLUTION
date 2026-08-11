import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app.dart';
import 'feature/attendance/service/background_location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await BackgroundLocationService.initializeService();
  } catch (_) {}
  runApp(const ProviderScope(child: MyApp()));
}
