import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/schedule/presentation/app_shell.dart';
import 'app_theme.dart';
import 'providers.dart';

class RsueScheduleApp extends ConsumerWidget {
  const RsueScheduleApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(appControllerProvider);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Расписание РГЭУ',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: controller.themeMode,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const AppShell(),
    );
  }
}
