import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/auth_provider.dart';
import '../main_screen.dart';
import 'login_screen.dart';

/// Tela inicial que decide para onde redirecionar o usuário:
/// - Se houver sessão válida → MainScreen (app normal)
/// - Se não houver sessão → LoginScreen
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late Future<UserProfile?> _initializationFuture;

  @override
  void initState() {
    super.initState();
    // Iniciamos o carregamento da sessão aqui
    final authProvider = context.read<AuthProvider>();
    _initializationFuture = authProvider.tryRestoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile?>(
      future: _initializationFuture,
      builder: (context, snapshot) {
        // Enquanto o Future está rodando, mostramos o conteúdo da Splash
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashContent();
        }

        // Quando o Future termina, decidimos para onde ir
        final profile = snapshot.data;
        
        // Usamos addPostFrameCallback para navegar após o build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (profile != null) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const MainScreen()),
            );
          } else {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        });

        // Enquanto o Navigator processa a transição, mantemos o conteúdo visual
        return const _SplashContent();
      },
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0099C6).withValues(alpha: 0.3),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.domain,
                size: 48,
                color: Color(0xFF4FC3F7),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Proteforms',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 40),
            const CircularProgressIndicator(
              color: Color(0xFF0099C6),
              strokeWidth: 2,
            ),
          ],
        ),
      ),
    );
  }
}
