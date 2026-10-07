import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:foon_design/foon_design.dart';
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
      appBar: FoonTopBar(
        logo: const AssetImage('assets/foonmed_logo_transparent.png'),
        semanticLabel: 'FoonMed — Contact Vibration Scan',
      ),
      body: Consumer<VibrationGridScanController>(
        builder: (context, controller, child) {
          return Padding(
            padding: const EdgeInsets.all(FoonSpacing.m),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusHeader(controller: controller),
                const SizedBox(height: FoonSpacing.tight),
                Expanded(child: _buildBody(context, controller)),
                const SizedBox(height: FoonSpacing.tight),
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
        return const FoonEmptyState(
          icon: Icons.stop_circle_outlined,
          title: 'Scan aborted',
          message: 'Partial data was discarded. Start a new scan when ready.',
        );
      case GridScanState.error:
        return FoonEmptyState(
          icon: Icons.error_outline,
          title: 'Scan failed',
          message: c.errorMessage ?? 'Unknown error',
        );
    }
  }

  Widget _buildActions(BuildContext context, VibrationGridScanController c) {
    switch (c.state) {
      case GridScanState.idle:
        return FoonCtaButton(
          label: 'START SCAN',
          onPressed: () => c.startScan(),
        );
      case GridScanState.awaitingBaseline:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoonCtaButton(
              label: 'CAPTURE BASELINE',
              onPressed: () => c.captureBaseline(),
            ),
            const SizedBox(height: FoonSpacing.s),
            _TextButton(label: 'Cancel', onPressed: () => c.abortScan()),
          ],
        );
      case GridScanState.awaitingPlacement:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FoonCtaButton(
              label: 'MEASURE CELL',
              onPressed: () => c.confirmPlacement(),
            ),
            const SizedBox(height: FoonSpacing.s),
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
            FoonCtaButton(
              label: _jsonCopied ? 'JSON COPIED' : 'COPY SCAN JSON',
              onPressed: () => _copyJson(context, c.lastScan!),
            ),
            const SizedBox(height: FoonSpacing.s),
            FoonCtaButton(label: 'NEW SCAN', onPressed: () => c.startScan()),
          ],
        );
      case GridScanState.aborted:
      case GridScanState.error:
        return FoonCtaButton(
          label: 'START OVER',
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
        const SizedBox(height: FoonSpacing.s),
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
        const SizedBox(height: FoonSpacing.tight),
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
          const SizedBox(height: FoonSpacing.m),
          Text(label),
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
          const SizedBox(height: FoonSpacing.tight),
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
          const SizedBox(height: FoonSpacing.s),
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
      mainAxisSpacing: FoonSpacing.xs,
      crossAxisSpacing: FoonSpacing.xs,
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

    // Grey empty cell ramping to Foon orange; opaque so the measured cells
    // never read lighter than the empty ones on the white page.
    Color cellColour(double t) =>
        Color.lerp(FoonColours.neutralLight, FoonColours.secondary, t)!;

    Color color;
    if (isCurrent) {
      color = FoonColours.secondary;
    } else if (visited && showValues && baseline > 0) {
      final normalized = value / baseline;
      // Ramp capped at 0.60 so dark value labels keep >= 9:1 contrast.
      final intensity = (normalized / 2).clamp(0.15, 0.60);
      color = cellColour(intensity);
    } else if (visited) {
      color = cellColour(0.45);
    } else {
      color = FoonColours.neutralLight;
    }

    Widget child;
    if (isCurrent) {
      child = const Icon(Icons.place, color: FoonColours.primary, size: 20);
    } else if (showValues && visited && baseline > 0) {
      child = Text(
        (value / baseline).toStringAsFixed(2),
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11,
          color: FoonColours.onSurface,
          fontWeight: FontWeight.w600,
        ),
      );
    } else if (visited) {
      child = Icon(
        Icons.check,
        size: 16,
        color: FoonColours.onSurface.withValues(alpha: 0.54),
      );
    } else {
      child = Text(
        '${row * controller.cols + col + 1}',
        style: const TextStyle(fontSize: 11, color: FoonColours.primary),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(FoonRadii.cell),
        border: isCurrent
            ? Border.all(color: FoonColours.primary, width: 2)
            : null,
      ),
      alignment: Alignment.center,
      child: child,
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
      style: TextButton.styleFrom(
        foregroundColor: FoonColours.onSurface,
        textStyle: FoonTextStyles.body,
      ),
      child: Text(label),
    );
  }
}
