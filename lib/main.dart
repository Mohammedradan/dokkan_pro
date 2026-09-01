import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'db/database.dart';
import 'screens/home_shell.dart';
import 'screens/pin_screen.dart';
import 'services/notification_service.dart';
import 'state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  final db = AppDatabase();
  await db.database; // إنشاء قاعدة البيانات
  final state = AppState(db);
  await state.init();
  // إعادة جدولة التنبيه اليومي (إن كان مفعلاً) بمحتوى محدث
  await NotificationService.instance.rescheduleFrom(state);
  runApp(DokkanApp(state: state));
}

class DokkanApp extends StatelessWidget {
  final AppState state;

  const DokkanApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      // قراءة إعداد المظهر تحت الـ Provider ليعاد بناء MaterialApp عند تغييره
      child: Builder(
        builder: (context) {
          final appState = context.watch<AppState>();
          final themeMode = switch (appState.themeMode) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          };
          return MaterialApp(
            title: 'دكاني',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              useMaterial3: true,
              colorScheme:
                  ColorScheme.fromSeed(seedColor: const Color(0xFF00897B)),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
              ),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF00897B),
                brightness: Brightness.dark,
              ),
              appBarTheme: const AppBarTheme(
                centerTitle: true,
              ),
              inputDecorationTheme: const InputDecorationTheme(
                border: OutlineInputBorder(),
              ),
            ),
            themeMode: themeMode,
            locale: const Locale('ar'),
            supportedLocales: const [Locale('ar')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const PinGate(child: HomeShell()),
          );
        },
      ),
    );
  }
}
