import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import '../../auth/provider/auth_provider.dart';
import '../provider/punch_in_provider.dart';

Future<void> showPunchInRequiredDialog(
  BuildContext context,
  WidgetRef ref, {
  String? message,
  VoidCallback? onSuccess,
}) async {
  final user = ref.read(currentUserProvider).value;
  final empId = user?.id ?? 7;

  return showDialog(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Consumer(
        builder: (context, ref, child) {
          final punchState = ref.watch(punchInProvider);

          if (punchState.isPunchedIn == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (Navigator.of(dialogContext).canPop()) {
                Navigator.of(dialogContext).pop();
                onSuccess?.call();
              }
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.fingerprint_rounded,
                      size: 38,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppText(
                    'Punch In Required',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message ??
                        'You have not punched in today. Please punch in to start your work day.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: ElevatedButton(
                      onPressed: punchState.isLoading
                          ? null
                          : () async {
                              final resultMsg = await ref
                                  .read(punchInProvider.notifier)
                                  .togglePunchIn(empId: empId);
                              if (resultMsg != null && context.mounted) {
                                final isError =
                                    resultMsg.startsWith('ERROR:');
                                final displayMsg = isError
                                    ? resultMsg.replaceFirst('ERROR:', '').trim()
                                    : resultMsg;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        Icon(
                                          isError
                                              ? Icons.error_outline
                                              : Icons.check_circle_outline,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            displayMsg,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    backgroundColor:
                                        isError ? AppColors.red : Colors.green,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: punchState.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.touch_app_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Punch In',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(punchPromptDismissedProvider.notifier)
                          .dismiss();
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(
                      'Close & Continue',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
