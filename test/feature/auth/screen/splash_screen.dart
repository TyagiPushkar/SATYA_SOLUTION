import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_loader.dart';
import '../provider/auth_provider.dart';
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});
  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }
  Future<void> _checkAuth() async {
    await Future.delayed(Duration(seconds: 2)); // Artificial delay for splash
    final isAuthenticated = await ref.read(splashProvider.future);
    if (!mounted) return;

    if (isAuthenticated) {
      context.go('/home');
    } else {
      context.go('/login');
    }
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: AppLoader(color: AppColors.white),
      ),
    );
  }
}
