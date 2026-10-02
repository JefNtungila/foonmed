import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../controllers/vibration_grid_scan_controller.dart';
import '../models/contact_grid_scan.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  GridScanState? _previousState;
  bool _jsonCopied = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<VibrationGridScanController>().state;
    if (_previousState != null &&
        _previousState != state &&
        (state == GridScanState.awaitingPlacement ||
            state == GridScanState.awaitingBaseline)) {
      HapticFeedback.selectionClick();
    }
    _previousState = state;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contact Vibration Scan'),
      ),
      body: Consumer<VibrationGridScanController>(
        builder: (context, controller, child) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusHeader(controller: controller),
                const SizedBox(height: 12),
                Expanded(child: _buildBody(context, controller)),
                const SizedBox(height: 12),
                _buildActions(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, VibrationGridScanController c) {
    switch (c.state) {
      case GridScanState.idle:
        return _IdleView(controller: c);
      case GridScanState.awaitingBaseline:
        return _BaselinePromptView(controller: c);
      case GridScanState.baselineCapturing:
        return const _BusyView(label: 'Measuring baseline in free air…');
      case GridScanState.awaitingPlacement:
        return _PlacementView(controller: c);
      case GridScanState.settling:
        return const _BusyView(label: 'Settling…');
      case GridScanState.capturing:
        return _BusyView(label: 'Measuring cell ${c.cellIndex + 1} of ${c.totalCells}…');
      case GridScanState.processing:
        return const _BusyView(label: 'Processing…');
      case GridScanState.completed:
        return _ResultsView(controller: c);
      case GridScanState.aborted:
        return const _MessageView(
          icon: Icons.stop_circle_outlined,
          title: 'Scan aborted',
          message: 'Partial data was discarded. Start a new scan when ready.',
        );
      case GridScanState.error:
        return _MessageView(
          icon: Icons.error_outline,
          title: 'Scan failed',
          message: c.errorMessage ?? 'Unknown error',
        );
    }
  }

  Widget _buildActions(BuildContext context, VibrationGridScanController c) {
    switch (c.state) {
      case GridScanState.idle:
        return _PrimaryButton(
          label: 'START SCAN',
          color: Colors.green,
          onPressed: () => c.startScan(),
        );
      case GridScanState.awaitingBaseline:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrimaryButton(
              label: 'CAPTURE BASELINE',
              color: Colors.blue,
              onPressed: () => c.captureBaseline(),
            ),
            const SizedBox(height: 8),
            _TextButton(label: 'Cancel', onPressed: () => c.abortScan()),
          ],
        );
      case GridScanState.awaitingPlacement:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrimaryButton(
              label: 'PHONE PLACED — MEASURE CELL',
              color: Colors.blue,
              onPressed: () => c.confirmPlacement(),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _TextButton(
                    label: 'Retake last',
                    onPressed: c.canRetakeLastCell ? () => c.retakeLastCell() : null,
                  ),
                ),
                Expanded(
                  child: _TextButton(
                    label: 'Abort',
                    onPressed: () => c.abortScan(),
                  ),
                ),
              ],
            ),
          ],
        );
      case GridScanState.baselineCapturing:
      case GridScanState.settling:
      case GridScanState.capturing:
      case GridScanState.processing:
        return _TextButton(label: 'Abort', onPressed: () => c.abortScan());
      case GridScanState.completed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PrimaryButton(
              label: _jsonCopied ? 'JSON COPIED' : 'COPY SCAN JSON',
              color: Colors.blue,
              onPressed: () => _copyJson(context, c.lastScan!),
            ),
            const SizedBox(height: 8),
            _PrimaryButton(
              label: 'NEW SCAN',
              color: Colors.green,
              onPressed: () => c.startScan(),
            ),
          ],
        );
      case GridScanState.aborted:
      case GridScanState.error:
        return _PrimaryButton(
          label: 'START OVER',
          color: Colors.green,
          onPressed: () => c.startScan(),
        );
    }
  }

  Future<void> _copyJson(BuildContext context, ContactGridScan scan) async {
    await Clipboard.setData(ClipboardData(text: scan.toJsonString()));
    if (!context.mounted) return;
    setState(() => _jsonCopied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Scan JSON copied to clipboard')),
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _jsonCopied = false);
  }
}

class _StatusHeader extends StatelessWidget {
  final VibrationGridScanController controller;

  const _StatusHeader({required this.controller});

  @override
  Widget build(BuildContext context) {
    final state = controller.state;
    final statusLabel = switch (state) {
      GridScanState.idle => 'READY',
      GridScanState.awaitingBaseline => 'STEP 1 OF 2 — BASELINE',
      GridScanState.baselineCapturing => 'MEASURING BASELINE',
      GridScanState.awaitingPlacement =>
        'STEP 2 OF 2 — CELL ${controller.cellIndex + 1} / ${controller.totalCells}',
      GridScanState.settling => 'SETTLING',
      GridScanState.capturing => 'MEASURING',
      GridScanState.processing => 'PROCESSING',
      GridScanState.completed => 'SCAN COMPLETE',
      GridScanState.aborted => 'ABORTED',
      GridScanState.error => 'ERROR',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          statusLabel,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: state == GridScanState.completed ? 1.0 : controller.progress,
          minHeight: 6,
        ),
      ],
    );
  }
}

class _IdleView extends StatelessWidget {
  final VibrationGridScanController controller;

  const _IdleView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Contact vibration scan of the palmar hand.\n\n'
        '1. Capture a free-air vibration baseline.\n'
        '2. Place the phone on each highlighted grid cell '
        '(${controller.rows}×${controller.cols}, top-left to bottom-right) '
        'and tap when placed.\n\n'
        'The actuator vibrates for ${controller.vibrateMs} ms per cell while the '
        'accelerometer records contact energy.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

class _BaselinePromptView extends StatelessWidget {
  final VibrationGridScanController controller;

  const _BaselinePromptView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Hold the phone freely in the air, away from your hand or any surface.\n\n'
        'Tap CAPTURE BASELINE to record the free-air reference vibration.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PlacementView extends StatelessWidget {
  final VibrationGridScanController controller;

  const _PlacementView({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Place the phone firmly on the highlighted cell '
          '(row ${controller.currentRow + 1}, col ${controller.currentCol + 1}), '
          'then tap MEASURE.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: _GridMatrix(controller: controller, showValues: false),
            ),
          ),
        ),
      ],
    );
  }
}

class _BusyView extends StatelessWidget {
  final String label;

  const _BusyView({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(label),
        ],
      ),
    );
  }
}

class _MessageView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _MessageView({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ResultsView extends StatelessWidget {
  final VibrationGridScanController controller;

  const _ResultsView({required this.controller});

  @override
  Widget build(BuildContext context) {
    final scan = controller.lastScan!;
    final flat = scan.flatFeatureVector;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: _GridMatrix(controller: controller, showValues: true),
          ),
          const SizedBox(height: 12),
          Text(
            'Baseline (air): ${scan.baselineAirRms.toStringAsFixed(3)} m/s² RMS',
            textAlign: TextAlign.center,
          ),
          Text(
            'Grid: ${scan.gridDimensions.rows}×${scan.gridDimensions.cols} · '
            'scan ${scan.scanId.substring(0, 8)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            title: const Text('Normalized feature vector'),
            children: [
              Text(
                '[',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(
                flat.map((v) => v.toStringAsFixed(3)).join(', '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Text(']', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridMatrix extends StatelessWidget {
  final VibrationGridScanController controller;
  final bool showValues;

  const _GridMatrix({required this.controller, required this.showValues});

  @override
  Widget build(BuildContext context) {
    final rows = controller.rows;
    final cols = controller.cols;
    final isComplete = controller.state == GridScanState.completed;
    final baseline = controller.baselineAirRms;

    return GridView.count(
      crossAxisCount: cols,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: [
        for (var r = 0; r < rows; r++)
          for (var c = 0; c < cols; c++)
            _buildCell(context, r, c, isComplete, baseline),
      ],
    );
  }

  Widget _buildCell(
    BuildContext context,
    int row,
    int col,
    bool isComplete,
    double baseline,
  ) {
    final isCurrent = row == controller.currentRow &&
        col == controller.currentCol &&
        controller.state == GridScanState.awaitingPlacement;
    final value = controller.cellValue(row, col) ?? 0.0;
    final visited = isComplete ||
        (controller.cellIndex > row * controller.cols + col &&
            controller.state != GridScanState.idle);

    Color color;
    if (isCurrent) {
      color = Colors.blue.shade400;
    } else if (visited && showValues && baseline > 0) {
      final normalized = value / baseline;
      final intensity = (normalized / 2).clamp(0.15, 1.0);
      color = Colors.green.withValues(alpha: intensity);
    } else if (visited) {
      color = Colors.green.shade300;
    } else {
      color = Colors.grey.shade300;
    }

    Widget child;
    if (isCurrent) {
      child = const Icon(Icons.place, color: Colors.white, size: 20);
    } else if (showValues && visited && baseline > 0) {
      child = Text(
        (value / baseline).toStringAsFixed(2),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.black,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (visited) {
      child = const Icon(Icons.check, size: 16, color: Colors.black54);
    } else {
      child = Text(
        '${row * controller.cols + col + 1}',
        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: isCurrent
            ? Border.all(color: Colors.blue.shade900, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 15),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      child: Text(label, style: const TextStyle(fontSize: 16)),
    );
  }
}

class _TextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _TextButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
