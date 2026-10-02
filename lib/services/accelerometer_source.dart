import 'package:sensors_plus/sensors_plus.dart';

import '../models/accel_sample.dart';

abstract class AccelerometerSource {
  Stream<AccelSample> sampleStream();
}

class SensorPlusAccelerometerSource implements AccelerometerSource {
  const SensorPlusAccelerometerSource();

  @override
  Stream<AccelSample> sampleStream() {
    return accelerometerEventStream(samplingPeriod: SensorInterval.fastestInterval)
        .map(
      (event) => AccelSample(
        x: event.x,
        y: event.y,
        z: event.z,
        timestamp: event.timestamp,
      ),
    );
  }
}
