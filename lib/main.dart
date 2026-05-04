import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/database/database_helper.dart';

import 'services/auth_provider.dart';
import 'services/configuracao_provider.dart';
import 'services/obras_provider.dart';
import 'services/relatorios_provider.dart';
import 'services/responsaveis_provider.dart';
import 'services/checklist_provider.dart';
import 'services/sync_provider.dart';

import 'screens/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR', null);

  // Inicializa Supabase
  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  // Inicializa banco de dados local (SQLite) com migrations
  final dbHelper = DatabaseHelper.instance;
  await dbHelper.database;

  runApp(const ProteformsApp());
}

class ProteformsApp extends StatelessWidget {
  const ProteformsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseHelper>(create: (_) => DatabaseHelper.instance),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => ConfiguracaoProvider()),
        ChangeNotifierProvider(create: (_) => ObrasProvider()),
        ChangeNotifierProvider(create: (_) => RelatoriosProvider()),
        ChangeNotifierProvider(create: (_) => ResponsaveisProvider()),
        ChangeNotifierProvider(create: (_) => ChecklistProvider()),
      ],
      child: MaterialApp(
        title: 'Proteforms RTI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('pt', 'BR'),
        ],
        home: const SplashScreen(),
      ),
    );
  }
}
