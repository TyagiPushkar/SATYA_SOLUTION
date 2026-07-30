import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_text.dart';
import './main_screen.dart';
import '../../task/provider/task_provider.dart';

import '../../auth/provider/auth_provider.dart';
import '../../attendance/provider/punch_in_provider.dart';
import '../../attendance/provider/sync_provider.dart';
import '../../../core/providers/permission_provider.dart';
import '../../../core/models/permission_model.dart';
