import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:livekit_client/livekit_client.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // On Android devices (especially Xiaomi/MIUI), hardware AEC/NS on VOICE_COMMUNICATION
  // causes AudioRecord HAL status -38 / StartRecording twice native aborts (SIGABRT).
  // Initializing via LiveKitClient with bypassVoiceProcessing: true uses MediaRecorder.AudioSource.MIC
  // with software APM instead of failing platform effects.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    try {
      await LiveKitClient.initialize(
        bypassVoiceProcessing: true,
      );
    } catch (e) {
      debugPrint('[NexRonda] LiveKitClient init warning: $e');
    }
  }

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
