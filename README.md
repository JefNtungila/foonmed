Here is the production-ready **`README.md`** tailored to your project’s architecture, physical principles, and machine learning pipeline requirements.

---

# Contact-Vibration Biomechanical & NDT Grid Scanner

A mobile sensing platform that converts off-the-shelf smartphone hardware into a high-density, sub-surface mechanical scanner. By combining **contact vibration actuation** ($100\text{--}200\text{ Hz}$) with **3-axis inertial acceleration sensing**, the app maps sub-surface mechanical impedance, viscoelastic damping, and structural discontinuities up to a $1\text{--}2\text{ cm}$ depth.

The software guides users through a row-major grid scan (e.g., $5 \times 5$ or $8 \times 8$), exporting a normalized $N \times M$ matrix designed for machine learning (ML) ingestion (biometric profiling, edema/sprain assessment, and Non-Destructive Testing).

---

## 🔬 How It Works (Physical Principles)

Airborne acoustic sonar ($>20\text{ kHz}$) suffers from a **$99.9\%$ energy reflection penalty** at the air-skin interface due to extreme acoustic impedance mismatch ($Z_{\text{air}} \approx 400\text{ Rayls}$ vs. $Z_{\text{tissue}} \approx 1,500,000\text{ Rayls}$).

Direct contact mechanical vibration circumvents this barrier entirely:

```
┌─────────────────────────────────────────────────────────────┐
│                       SMARTPHONE DEVICE                     │
│                                                             │
│  [ Haptic Motor (LRA/ERM) ] ──► Sustained Wave (100–200 Hz) │
│                                         │                   │
│                                         ▼                   │
│                              [ Target Surface / Skin ]      │
│                                         │                   │
│                                         ▼                   │
│  [ 3-Axis Accelerometer ]   ◄── Mechanical Response         │
└─────────────────────────────────────────────────────────────┘

```

1. **Mechanical Coupling:** The vibrating haptic motor transmits shear/compressional waves directly into the tissue or material.
2. **Load Modulation:** Sub-surface structural features (dense bone, swollen fluid pockets, muscle mass, or material cracks) modulate the device's vibration profile.
3. **Signal Acquisition:** The accelerometer measures the mechanical damping and resonant shifts.

---

## 📊 Signal Processing Pipeline

For each cell in the $N \times M$ grid scan sequence:

1. **Cell Settle Phase ($150\text{ ms}$):** Allows hand placement stabilization.
2. **Transient Rejection ($150\text{ ms}$):** Discards initial haptic motor spin-up noise.
3. **Steady-State Sampling ($350\text{ ms}$):** Captures raw 3-axis accelerometer samples $\vec{a}(t) = [a_x(t), a_y(t), a_z(t)]^T$.
4. **DC Offset Removal:** Subtracts gravitational bias from each axis:

$$\tilde{a}_k(t) = a_k(t) - \bar{a}_k \quad \text{for } k \in \{x, y, z\}$$


5. **3D Vector Magnitude Norm:** Computes orientation-robust per-sample magnitude:

$$\Vert{}\tilde{a}(t)\Vert{} = \sqrt{\tilde{a}_x(t)^2 + \tilde{a}_y(t)^2 + \tilde{a}_z(t)^2}$$


6. **RMS Energy Computation:** Calculates the Root Mean Square energy scalar over $N$ steady-state samples:

$$\text{RMS}_{\text{3D}} = \sqrt{\frac{1}{N} \sum_{i=1}^{N} \Vert{}\tilde{a}_i\Vert{}^2}$$



---

## 🕹️ User Scan Workflow

Scans follow a standardized **row-major acquisition sequence** (Top-Left $(0,0)$ to Bottom-Right $(R-1, C-1)$):

```text
  [ (0,0) Top-Left ]  ──►  (0,1)  ──►  (0,2)  ──►  (0,3)
                                                     │
  (1,3)  ◄──  (1,2)  ◄──  (1,1)  ◄──  (1,0)  ◄───────┘
  │
  └──► [ Next Row... ] ──► [ (R-1, C-1) Bottom-Right ]

```

* **Baseline Calibration:** A initial $1.0\text{ sec}$ free-air vibration scan establishes `baseline_air_rms` ($\text{RMS}_{\text{air}}$).
* **Manual Step Advancement:** The state machine (`awaitingPlacement`) requires explicit user confirmation (UI tap or volume key) per cell before firing the vibration pulse. This prevents motion artifact corruption.

---

## 📁 Repository Structure

```text
lib/
├── models/
│   └── contact_grid_scan.dart        # JSON schema, matrix serialization, flat vector export
├── controllers/
│   └── vibration_grid_scan_controller.dart # State machine (idle, baseline, awaitingPlacement, capturing, done)
├── services/
│   ├── vibration_grid_scan_service.dart # Platform motor & IMU sensor lifecycle orchestrator
│   └── grid_signal_processor.dart    # Pure math functions (DC removal, 3D norm, RMS, normalization)
└── ui/
    └── scan_grid_overlay.dart        # Interactive row-major grid UI overlay

```

---

## 💾 Exported Data Schema (ML Pipeline Contract)

Completed scans yield a JSON-serializable payload containing metadata, raw $\text{RMS}_{\text{3D}}$ physical units ($\text{m/s}^2$), and a flattened 1D feature vector for model input:

```json
{
  "scan_id": "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d",
  "timestamp": "2026-10-02T21:44:00Z",
  "device_info": {
    "platform": "android",
    "model": "Pixel 8 Pro",
    "sensor_sample_rate_hz": 100.0
  },
  "grid_dimensions": { "rows": 5, "cols": 5 },
  "scan_direction": "top_left_to_bottom_right",
  "baseline_air_rms": 4.821,
  "data_matrix": [
    [1.240, 1.150, 2.450, 2.100, 1.050],
    [1.300, 1.420, 2.800, 2.300, 1.120],
    [1.180, 1.250, 2.100, 1.950, 1.080],
    [1.100, 1.150, 1.650, 1.500, 1.020],
    [0.950, 1.050, 1.400, 1.250, 0.980]
  ],
  "normalized_matrix": [
    [0.257, 0.238, 0.508, 0.435, 0.217],
    [0.269, 0.294, 0.580, 0.477, 0.232],
    [0.244, 0.259, 0.435, 0.404, 0.224],
    [0.228, 0.238, 0.342, 0.311, 0.211],
    [0.197, 0.217, 0.290, 0.259, 0.203]
  ],
  "flat_feature_vector": [1.240, 1.150, 2.450, 2.100, 1.050, 1.300, 1.420]
}

```

---

## 🛠️ Hardware & Platform Notes

* **Primary Platform:** Android. Requires `android.permission.VIBRATE` in `AndroidManifest.xml`.
* **iOS Compatibility:** iOS restricts continuous vibration duration through `AudioServices` and throttles continuous haptics via `CHHapticEngine`. iOS runtime fallback throws an `UnsupportedPlatformException` unless compiled with the audio-speaker transducer mode.
* **Sensor Sampling Rates:** Standard smartphone IMUs sample between $50\text{--}100\text{ Hz}$. Because vibration motors operate at $110\text{--}200\text{ Hz}$, aliasing occurs above the Nyquist limit. The recorded signal represents a load-modulated beat envelope rather than a pure waveform; however, the relative RMS energy metric remains a robust proxy for mechanical damping.

---

## 🚀 Getting Started

### Prerequisites

* Flutter SDK $\ge 3.19.0$
* Android device (Android 10+ recommended for precise haptic motor control)

### Setup

1. Clone the repository and install dependencies:
```bash
flutter pub get

```


2. Run unit tests on the pure mathematical processor:
```bash
flutter test test/grid_signal_processor_test.dart

```


3. Target an attached Android device:
```bash
flutter run -d <android_device_id>

```



---

## 📄 License

Distributed under the MIT License. See `LICENSE` for more information.