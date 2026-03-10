import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/chat_list_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppTheme.primaryDark,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const ChatViewerApp());
}

class ChatViewerApp extends StatelessWidget {
  const ChatViewerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Viewer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.whatsAppTheme(),
      home: const ChatListScreen(),
    );
  }
}
