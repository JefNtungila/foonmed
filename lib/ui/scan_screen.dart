
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/scan_controller.dart';
import '../models/scan_data.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acoustic Scan'),
      ),
      body: Consumer<ScanController>(builder: (context, scanController, child) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Scan State: ${scanController.state.name.toUpperCase()}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 20),
              if (scanController.errorMessage != null)
                Text(
                  'Error: ${scanController.errorMessage}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: scanController.state == ScanState.scanning
                    ? null
                    : () => scanController.startScan(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text('START SCAN', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: scanController.state == ScanState.idle ||
                        scanController.state == ScanState.processing
                    ? null
                    : () => scanController.stopScan(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('STOP SCAN', style: TextStyle(fontSize: 18)),
              ),
              const SizedBox(height: 30),
              if (scanController.lastScanData != null)
                Expanded(
                  child: SingleChildScrollView(
                    child: Card(
                      elevation: 4,
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last Scan Data:',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            _buildScanDetail(context, 'Audio Path:', scanController.lastScanData!.audioFilePath),
                            _buildScanDetail(context, 'Duration:', '${scanController.lastScanData!.metadata.totalDurationMs} ms'),
                            _buildScanDetail(context, 'Spatial Log Entries:', '${scanController.lastScanData!.spatialTimeLog.length}'),
                            ExpansionTile(
                              title: const Text('Mathematical Representation'),
                              children: [
                                _buildScanDetail(context, 'Spectrum Matrix Size:', '${scanController.lastScanData!.mathematicalRepresentation.spectrumMatrix.length} x ${scanController.lastScanData!.mathematicalRepresentation.spectrumMatrix.isNotEmpty ? scanController.lastScanData!.mathematicalRepresentation.spectrumMatrix.first.length : 0}'),
                                _buildScanDetail(context, 'Energy Profile Size:', '${scanController.lastScanData!.mathematicalRepresentation.energyProfile.length}'),
                                // You might want to display more detailed spectrum data here, e.g., in a chart or truncated form
                              ],
                            ),
                            ExpansionTile(
                              title: const Text('Spatial Time Log (first 5 entries)'),
                              children: [
                                ...scanController.lastScanData!.spatialTimeLog.take(5).map((entry) => Text('  T: ${entry.timestampMs}ms, R: ${entry.row}, C: ${entry.column}')).toList(),
                                if (scanController.lastScanData!.spatialTimeLog.length > 5) const Text('  ...'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildScanDetail(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
