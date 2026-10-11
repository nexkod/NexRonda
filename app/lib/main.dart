import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/intercom_service.dart';
import 'screens/home_screen.dart';
import 'widgets/assistive_floating_overlay.dart';

@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AssistiveFloatingOverlay(),
    ),
  );
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => IntercomService()),
      ],
      child: const NexRondaApp(),
    ),
  );
}

class NexRondaApp extends StatelessWidget {
  const NexRondaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NexRonda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF10B981),
          brightness: Brightness.dark,
          primary: const Color(0xFF10B981),
          surface: const Color(0xFF1E293B),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
