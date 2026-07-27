import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_sizebox.dart';
import '../../../core/widgets/app_text.dart';
import '../../auth/provider/auth_provider.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: 300,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gradientPurple,
                        AppColors.gradientPink,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                ),
                Column(
                  children: [
                    AppSizeBox.h(120),
                    Stack(
                      clipBehavior: Clip.none,
                      alignment: Alignment.topCenter,
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 24),
                          padding: EdgeInsets.only(top: 60, bottom: 20),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.grey.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AppText(
                                    'Janet Walker',
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  AppSizeBox.w(4),
                                  AppText(
                                    '( 24 Y )',
                                    fontSize: 12,
                                    color: AppColors.grey.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              AppSizeBox.h(8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance,
                                    size: 14,
                                    color: AppColors.grey.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                  AppSizeBox.w(4),
                                  AppText(
                                    'Stanford University',
                                    fontSize: 14,
                                    color: AppColors.grey.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              AppSizeBox.h(24),
                              Divider(
                                color: AppColors.grey.withValues(alpha: 0.2),
                              ),
                              AppSizeBox.h(16),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatItem(Icons.access_time, '5 Min'),
                                  _buildStatItem(
                                    Icons.chat_bubble_outline,
                                    'Message',
                                  ),
                                  _buildStatItem(
                                    Icons.location_on_outlined,
                                    'Location',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          top: -45,
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 45,
                              backgroundImage: NetworkImage(
                                'https://i.pravatar.cc/150?img=5',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: EdgeInsets.all(24.0),
                      child: AppText(
                        "I'm a cool girl and I like to study science. lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do",
                        fontSize: 14,
                        color: AppColors.grey.withValues(alpha: 0.9),
                        textAlign: TextAlign.center,
                        maxLines: 3,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SliverFillRemaining(
            hasScrollBody: false,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.0),
                  child: AppButton(
                    text: 'Logout',
                    color: AppColors.primary,
                    onTap: () async {
                      await ref.read(loginProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ),
                AppSizeBox.h(32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.grey.withValues(alpha: 0.7), size: 24),
        AppSizeBox.h(8),
        AppText(
          label,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.black.withValues(alpha: 0.7),
        ),
      ],
    );
  }
}
