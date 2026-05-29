import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'screens/main_tab.dart';
import 'screens/onboarding.dart';
import 'state/pet_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  await petStore.load();
  runApp(const PetTimesApp());
}

class PetTimesApp extends StatelessWidget {
  const PetTimesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PET TIMES',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      locale: const Locale('ko'),
      supportedLocales: const [Locale('ko'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      home: AnimatedBuilder(
        animation: petStore,
        builder: (_, _) =>
            petStore.hasPet ? const MainTabScreen() : const OnboardingScreen(),
      ),
    );
  }
}
