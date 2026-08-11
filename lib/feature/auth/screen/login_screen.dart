import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/app_textfield.dart';
import '../provider/auth_provider.dart';
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
  void _submit() {
    if (_formKey.currentState!.validate()) {
      ref.read(loginProvider.notifier).login(
        _emailController.text,
        _passwordController.text,
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<void>>(loginProvider, (previous, next) {
      next.when(
        data: (_) {
          if (previous?.isLoading == true) {
            context.go('/home');
          }
        },
        error: (error, stackTrace) {
          AppSnackbar.show(context, error.toString(), isError: true);
        },
        loading: () {},
      );
    });
    final loginState = ref.watch(loginProvider);
    final obscurePassword = ref.watch(loginPasswordVisibilityProvider);
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: AppColors.loginBackgroundNew,
      body: Stack(
        children: [ 
          Positioned(
            top: -size.width * 0.3,
            right: -size.width * 0.2,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -size.width * 0.2,
            left: -size.width * 0.1,
            child: Container(
              width: size.width * 0.6,
              height: size.width * 0.6,
              decoration: BoxDecoration(
                color: AppColors.primaryOrange.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppSizeBox.h(20),
                      AppText(
                        'Login here',
                        color: AppColors.primary,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                      AppSizeBox.h(24),
                      AppText(
                        "Welcome back you've\nbeen missed!",
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        textAlign: TextAlign.center,
                        color: AppColors.black,
                      ),
                      AppSizeBox.h(60),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            AppTextField(
                              controller: _emailController,
                              hint: 'Email',
                              fillColor: AppColors.white,
                              borderColor: AppColors.primary,
                              validator: Validators.email,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            AppSizeBox.h(24),
                            AppTextField(
                              controller: _passwordController,
                              hint: 'Password',
                              fillColor: AppColors.white,
                              borderColor: AppColors.primary,
                              obscureText: obscurePassword,
                              validator: Validators.password,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: AppColors.grey,
                                ),
                                onPressed: () {
                                  ref.read(loginPasswordVisibilityProvider.notifier).state = !obscurePassword;
                                },
                              ),
                            ),
                            AppSizeBox.h(16),
                            Align(
                              alignment: Alignment.centerRight,
                              child: AppText(
                                'Forgot your password?',
                                color: AppColors.primaryOrange,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            AppSizeBox.h(40),
                            AppButton(
                              text: 'Sign in',
                              color: AppColors.primary,
                              isLoading: loginState.isLoading,
                              onTap: _submit,
                            ),
                          ],
                        ),
                      ),
                      AppSizeBox.h(60),
                      AppText(
                        'Or continue with',
                        color: AppColors.primaryOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      AppSizeBox.h(20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton(Icons.g_mobiledata, size: 36),
                          AppSizeBox.w(16),
                          _buildSocialButton(Icons.facebook),
                          AppSizeBox.w(16),
                          _buildSocialButton(Icons.apple),
                        ],
                      ),
                      AppSizeBox.h(40),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildSocialButton(IconData icon, {double size = 24}) {
    return Container(
      width: 50,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(icon, color: AppColors.black, size: size),
      ),
    );
  }
}
