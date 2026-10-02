# foonmed — Contact-Vibration Biomechanical Scanner

A Flutter app that turns an ordinary smartphone into a contact-vibration scanner. It drives the phone's haptic vibration motor against a surface, measures the mechanical response with the 3-axis accelerometer, and builds a **biomechanical heatmap** over a user-guided grid scan. Each completed scan is exported as a JSON document containing a raw RMS matrix and a normalized flat feature vector — the ML pipeline contract for downstream **medical models** (e.g., edema/sprain detection, biomechanical profiling).

## How it works

Airborne acoustic sensing fails at the skin interface because of the huge acoustic impedance mismatch between air and tissue (~400 Rayls vs ~1,500,000 Rayls — ~99.9% of the energy reflects). Direct mechanical contact avoids this entirely:

```
┌──────────────────────────────────────────────────────┐
│                    SMARTPHONE                        │
│                                                      │
│  [ Haptic motor ] ──► sustained vibration ──► skin    │
│                                              │       │
│  [ 3-axis accelerometer ] ◄── mechanical response     │
└──────────────────────────────────────────────────────┘
```

1. **Mechanical coupling** — the vibration motor transmits waves directly through the device chassis into the contact surface (hand, tissue, or material).
2. **Load modulation** — sub-surface features (bone, fluid pockets, stiffness changes, structural cracks) modulate how the device vibrates.
3. **Signal acquisition** — the accelerometer measures the resulting damping; stronger/weaker transmission appears as per-cell RMS energy.

Dividing each cell by a free-air baseline yields a normalized heatmap of relative mechanical coupling across the grid.

## Scan workflow

The state machine (`idle → awaitingBaseline → awaitingPlacement → settling → capturing → processing → completed`) walks the user through a row-major scan (top-left → bottom-right):

1. **START SCAN** — verifies a vibration motor is available.
2. **CAPTURE BASELINE** — the phone is held freely in the air; one vibration burst establishes `baseline_air_rms`.
3. **Per cell (5×5 = 25 cells)** — the UI highlights the next cell. The user places the phone, then taps **PHONE PLACED — MEASURE CELL**. Explicit per-cell confirmation prevents motion-artifact corruption. **Retake last** and **Abort** are always available.
4. **SCAN COMPLETE** — shows the normalized heatmap, baseline, scan id, the feature vector, and **COPY SCAN JSON** for hand-off to the ML pipeline.

## Signal processing

Per cell (`lib/services/grid_signal_processor.dart`):

| Phase | Value |
|---|---|
| Cell settle (placement stabilization) | 200 ms |
| Pre-roll before firing the motor | 50 ms |
| Vibration burst | 500 ms |
| Motor warmup samples discarded | first 150 ms |
| Minimum usable samples | 10 |

For each axis *k* ∈ {x, y, z}, gravity/DC offset is removed and the RMS is computed over the settled window:

```
rms_k = sqrt( Σ (a_k − mean(a_k))² / N )
contact_rms = sqrt( rms_x² + rms_y² + rms_z² )
```

Normalization for ML input:

```
normalized[i][j] = contact_rms[i][j] / baseline_air_rms
flat_feature_vector = row-major flatten of normalized   (25 values)
```

Sampling runs at the fastest rate the sensor allows (`HIGH_SAMPLING_RATE_SENSORS`). Motors run at 110–200 Hz while IMUs sample at ≤100 Hz, so the recorded signal is an aliased beat envelope rather than the raw waveform — RMS energy of that envelope is the robust proxy for mechanical damping.

## Exported JSON (ML contract)

Produced by `ContactGridScan.toJson()`:

```json
{
  "scan_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "timestamp": "2026-10-02T21:44:00Z",
  "target_type": "hand_palmar",
  "grid_dimensions": { "rows": 5, "cols": 5 },
  "scan_direction": "top_left_to_bottom_right",
  "baseline_air_rms": 0.446,
  "capture": {
    "settle_ms": 200,
    "vibrate_ms": 500,
    "warmup_discard_ms": 150,
    "pre_roll_ms": 50,
    "min_samples_per_cell": 10
  },
  "sensor": { "axis_mode": "vector_norm" },
  "device": {
    "platform": "android",
    "model": "Pixel 8 Pro",
    "app_version": "1.0.0+1"
  },
  "data_matrix": [
    [1.240, 1.150, 2.450, 2.100, 1.050],
    [1.300, 1.420, 2.800, 2.300, 1.120],
    [1.180, 1.250, 2.100, 1.950, 1.080],
    [1.100, 1.150, 1.650, 1.500, 1.020],
    [0.950, 1.050, 1.400, 1.250, 0.980]
  ],
  "cell_stats": [
    [
      { "rms_x": 0.71, "rms_y": 0.65, "rms_z": 0.84,
        "contact_rms": 1.24, "samples": 38, "sample_rate_hz": 99.4 },
      "… 4 more cells in row …"
    ],
    "… 4 more rows …"
  ],
  "flat_feature_vector": [0.257, 0.238, 0.508, 0.435, 0.217, 0.269, "… 19 more …"]
}
```

- `data_matrix` — raw per-cell `contact_rms` in physical units (m/s²), the source of truth.
- `cell_stats` — per-axis RMS, sample count, and measured sample rate for QA/feature engineering.
- `flat_feature_vector` — baseline-normalized, row-major, fixed length (rows × cols): the model input tensor.

## Repository structure

```text
lib/
├── main.dart                                  # ContactScanApp entry point
├── controllers/
│   └── vibration_grid_scan_controller.dart    # Scan state machine & capture orchestration
├── models/
│   ├── accel_sample.dart                      # Timestamped accelerometer sample
│   └── contact_grid_scan.dart                 # JSON schema, normalization, flat vector
├── services/
│   ├── accelerometer_source.dart              # sensors_plus stream adapter
│   ├── vibrator_port.dart                     # Vibrator abstraction (Android/iOS)
│   ├── grid_signal_processor.dart             # Pure math: DC removal, RMS, normalization
│   └── scan_provenance.dart                   # Platform/model/app-version metadata
└── ui/
    └── scan_screen.dart                       # Grid UI, prompts, heatmap, JSON export

test/
├── grid_signal_processor_test.dart            # RMS/normalization math
├── contact_grid_scan_test.dart                # JSON schema round-trip
└── vibration_grid_scan_controller_test.dart   # State-machine behavior (fakes)

ios/Runner/AppDelegate.swift                   # CHHapticEngine method channel (unbuilt — see below)
```

## Platform notes

- **Android (primary):** requires `android.permission.VIBRATE` and `android.permission.HIGH_SAMPLING_RATE_SENSORS` (declared in `AndroidManifest.xml`). The latter is mandatory — without it the OS rejects `samplingPeriod = 0` and the sensor stream silently returns nothing.
- **iOS:** sustained vibration is not supported by the `vibration` package, so `AppDelegate.swift` registers a `foonmed/vibrator` channel backed by `CHHapticEngine` continuous events (start/stop/isSupported). This code path is written but **not yet built or tested** — no Xcode toolchain on the development machine.
- **Emulators:** the virtual accelerometer emits perfectly constant values, so real RMS energy is zero. End-to-end emulator testing works by injecting a synthetic signal with `adb emu sensor set acceleration 0:9.78:<v>` in a loop. Emulators also report `hasVibrator() == false` even when a vibrator HAL exists — `PlatformVibrator` therefore assumes Android support and verifies iOS via the native channel.

## Getting started

Prerequisites: Flutter SDK (Dart ≥ 3.12), an Android device or emulator.

```bash
flutter pub get
flutter test          # 24 tests: math, JSON schema, state machine
flutter run -d <device_id>
```

Build a release-grade APK:

```bash
flutter build apk --release
```

## Status

- Full scan flow validated end-to-end on an emulator (baseline → 25 cells → completed JSON).
- Real-device validation of vibration coupling, signal quality, and aliasing behavior is still required before any clinical/ML use.
- iOS haptic path needs a build on a machine with Xcode.
- Downstream: feed `flat_feature_vector` (plus `data_matrix`/`cell_stats` for richer features) into the medical ML pipeline; the schema above is the ingestion contract.
