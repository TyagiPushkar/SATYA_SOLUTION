import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mind_map/mind_map.dart';
import '../model/team_employee_model.dart';
import '../provider/team_provider.dart';

class MyTeamScreen extends ConsumerWidget {
  const MyTeamScreen({super.key});

  Widget _buildMindMapNode(TeamEmployee employee, [int depth = 0]) {
    final colors = [
      Colors.red.shade700,
      Colors.green.shade600,
      Colors.blue.shade700,
      Colors.orange.shade600,
      Colors.purple.shade600,
    ];
    final color = colors[depth % colors.length];

    final node = _SphereNode(employee, color);
    if (employee.team.isEmpty) {
      return node;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        node,
        MindMap(
          dotColor: Colors.transparent,
          dotRadius: 0,
          lineColor: Colors.blue.shade400,
          componentWith: 40,
          padding: const EdgeInsets.only(left: 0, right: 0),
          children: employee.team
              .map((e) => _buildMindMapNode(e, depth + 1))
              .toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final teamAsyncValue = ref.watch(teamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Team'),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(teamProvider),
            tooltip: 'Refresh Team',
          ),
        ],
        titleTextStyle: const TextStyle(
          color: Colors.black,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: teamAsyncValue.when(
        data: (rootEmployee) {
          return InteractiveViewer(
            constrained: false,
            boundaryMargin: const EdgeInsets.all(500),
            minScale: 0.1,
            maxScale: 3.0,
            child: Padding(
              padding: const EdgeInsets.all(60.0),
              child: RotatedBox(
                quarterTurns: 1, // Rotates the layout to be top-down vertical
                child: _buildMindMapNode(rootEmployee),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 12),
                Text(
                  error.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(teamProvider),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SphereNode extends StatelessWidget {
  final TeamEmployee employee;
  final Color color;

  const _SphereNode(this.employee, this.color);

  @override
  Widget build(BuildContext context) {
    final hasImage = employee.image != null && employee.image!.isNotEmpty;

    return RotatedBox(
      quarterTurns: 3, // Reverses the parent's rotation so text is upright
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            width: 60,
            height: 60,
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 25),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: hasImage
                  ? DecorationImage(
                      image: NetworkImage(employee.image!),
                      fit: BoxFit.cover,
                    )
                  : null,
              gradient: !hasImage
                  ? RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.9),
                        color,
                        color.withValues(alpha: 0.6),
                      ],
                      center: const Alignment(-0.3, -0.3),
                      radius: 0.8,
                    )
                  : null,
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  offset: Offset(2, 4),
                  blurRadius: 4,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: !hasImage
                ? Text(
                    employee.name.isNotEmpty
                        ? employee.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 22,
                      shadows: [
                        Shadow(
                          color: Colors.black54,
                          offset: Offset(1, 1),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          Positioned(
            bottom: 4,
            child: SizedBox(
              width: 90,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  employee.name,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
