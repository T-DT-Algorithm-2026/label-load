# LabelLoad

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.6+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/ONNX%20Runtime-1.20-blue?style=for-the-badge" alt="ONNX">
  <img src="https://img.shields.io/badge/CUDA-GPU%20Accelerated-76B900?style=for-the-badge&logo=nvidia" alt="CUDA">
</div>

<p align="center">
  <b>🏷️ Enterprise-Grade Image Labeling Tool with AI Auto-Annotation</b>
</p>

<p align="center">
  <a href="./README_zh.md">🇨🇳 中文文档</a> •
  <a href="#highlights">Highlights</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a>
</p>

---

## Highlights

- **🤖 AI-Powered**: YOLOv8 detection and pose estimation with GPU/CPU auto-selection
- **⚡ High Performance**: Native C++ FFI inference engine (1300+ LOC), batch processing
- **🏗️ Clean Architecture**: 7 Providers, 36 Services, 40 Widgets, 100 unit tests
- **🌍 Bilingual**: Full Chinese/English internationalization (i18n)
- **📦 Docker Build**: One-command reproducible builds, no local dependencies

---

## Features

### Label Types

| Type | Description | YOLO Format |
|------|-------------|-------------|
| **BoundingBox** | Standard rectangle annotation | `class cx cy w h` |
| **BoxWithPoint** | Detection + pose keypoints | `class cx cy w h [kp_x kp_y v]...` |
| **Polygon** | Semantic segmentation masks | `class [x y]...` |

### AI Auto-Labeling

- **YOLOv8** object detection
- **YOLOv8-Pose** human pose estimation (17 keypoints COCO format)
- Automatic GPU detection and acceleration (CUDA)
- Append or overwrite modes for label merging
- Auto-infer on image navigation (optional)
- Tracks inferred images to avoid duplicate work

### Gadget Toolbox

| Tool | Description |
|------|-------------|
| **Batch Rename** | Sequential numbering of image files |
| **XYXY → XYWH** | Coordinate format conversion |
| **BBox Expand** | Proportionally expand bounding boxes |
| **Check & Fix** | Fix out-of-bounds boxes, remove duplicates |
| **Convert Labels** | Class ID remapping and filtering |
| **Delete Keypoints** | Strip keypoints, keep only bbox |
| **Add BBox from Points** | Calculate bbox from keypoint coordinates |

### Drawing & Editing

| Mode | Description |
|------|-------------|
| **Labeling Mode** | Draw new annotations (drag or two-click) |
| **Editing Mode** | Select, move, resize existing labels |
| **Polygon Mode** | Click to add vertices, close to complete |
| **Keypoint Mode** | Click to bind keypoints to labels |

### UI Features

- 🌓 Dark/Light theme with system detection
- ⌨️ Fully customizable keyboard shortcuts
- 🔍 Smooth zoom (0.05x - 20x) and pan with mouse
- ⚡ Undo/Redo history stack
- 💾 Auto-save on navigation (configurable)
- 🔆 Dark enhancement filter for low-light images

---

## Installation

### System Requirements

- **OS**: Ubuntu 22.04+ (GLib 2.72+)
- **Docker**: Required for building releases
- **GPU (Optional)**: CUDA 11.x + cuDNN 8.x for GPU inference

### Install from DEB Package

Download from [Releases](https://github.com/T-DT-Algorithm-2026/label-load/releases) and replace `<version>` with the release version:

```bash
# CPU version (~18MB, no CUDA required)
sudo apt install label-load_<version>_amd64.deb

# GPU version (~120MB, requires CUDA Toolkit installed)
sudo apt install label-load_<version>_gpu_amd64.deb
```

### Build from Source (Docker)

```bash
git clone https://github.com/T-DT-Algorithm-2026/label-load.git
cd label-load/label_load

# Build CPU release (default)
./packaging/build_docker.sh --cpu

# Build GPU release
./packaging/build_docker.sh --gpu

# Override ONNX Runtime version
./packaging/build_docker.sh --cpu --ort-version 1.23.0

# Output: build/release/label-load_*.deb
```

### Local Development

```bash
# Install Flutter 3.6+
# https://docs.flutter.dev/get-started/install/linux

cd label_load
./run.sh debug      # Build debug version
./run.sh run        # Run debug version
```

---

## Quick Start

### 1. Create a Project

1. Click the **+** button in bottom-right
2. Enter project name and description
3. Select **Image Directory** (where your images are)
4. Select **Label Directory** (where .txt labels will be saved)
5. Add label categories with names and colors

### 2. Start Labeling

1. Click a project card to open the labeling interface
2. Press `W` to toggle between **Labeling Mode** and **Editing Mode**
3. In Labeling Mode:
   - **Drag** or **two-click** to draw bounding boxes
   - Press `C` to cycle through label classes
4. Press `A`/`D` to navigate between images
5. Labels auto-save when navigating (configurable)

### 3. AI Auto-Labeling

1. Open project settings (gear icon)
2. Configure AI model:
   - Select ONNX model file (.onnx)
   - Choose model type (YOLO / YOLO-Pose)
   - Adjust confidence and NMS thresholds
3. Press `R` to run inference on current image
4. Use batch inference for entire dataset

---

## Keyboard Shortcuts

All shortcuts are customizable via **Settings → Key Bindings**.

### Navigation

| Action | Default Key |
|--------|-------------|
| Previous Image | `A` |
| Next Image | `D` |
| Previous Label | `Q` |
| Next Label | `E` |

### Editing

| Action | Default Key |
|--------|-------------|
| Toggle Mode (Label/Edit) | `W` |
| Next Class | `C` |
| Delete Selected | `Delete` or `Backspace` |
| Save Labels | `S` |
| Undo | `Ctrl+Z` |
| Redo | `Ctrl+Shift+Z` |
| Cancel Operation | `Escape` |

### AI & View

| Action | Default Key |
|--------|-------------|
| AI Inference | `R` |
| Toggle Dark Enhancement | `X` |
| Toggle Keypoint Visibility | `V` |
| Cycle Keypoint Binding | `` ` `` (backtick) |

### Mouse

| Action | Mouse |
|--------|-------|
| Create/Draw | Left Click |
| Delete | Right Click |
| Pan Canvas | Middle Click Drag |
| Zoom | Scroll Wheel |

---

## Architecture

```
label_load/
├── lib/                        # Flutter source (95 files)
│   ├── models/                 # Data models (Label, Project, Config)
│   ├── providers/              # State management (7 Providers)
│   │   ├── project_provider.dart
│   │   ├── canvas_provider.dart
│   │   ├── keybindings_provider.dart
│   │   └── settings_provider.dart
│   ├── services/               # Business logic (36 files)
│   │   ├── inference/          # AI inference orchestration
│   │   ├── gadgets/            # Batch processing tools
│   │   └── labels/             # Label I/O and history
│   └── widgets/                # UI components (40 files)
│       ├── canvas/             # Image canvas and painters
│       └── dialogs/            # Settings, AI config, gadgets
├── onnx_inference/             # Native FFI plugin
│   └── src/                    # C++ inference engine (1300+ LOC)
├── test/                       # Unit tests (100 files)
├── integration_test/           # Integration tests (13 flows)
└── packaging/                  # Docker build scripts
    ├── Dockerfile.build        # Build environment
    └── build_docker.sh         # Unified build script
```

---

## Development Commands

```bash
# Help and version
./run.sh help              # Show all commands
./run.sh version           # Show version info

# Development
./run.sh clean             # Clean build artifacts
./run.sh debug             # Build debug version
./run.sh run               # Run debug version

# Release workflow
./run.sh release           # Build release version
./run.sh deb               # Package DEB (default: CPU)
./run.sh deb --gpu         # Package GPU DEB (~120MB)
./run.sh deb --cpu         # Package CPU DEB (~18MB)

# Testing
./run.sh test              # Run all tests
./run.sh test --unit       # Unit tests only
./run.sh test --int        # Integration tests only
./run.sh test --native     # C++ tests
./run.sh test --coverage   # Generate coverage report

# Code quality
./run.sh analyze           # Static analysis
./run.sh format            # Format check
```

---

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please ensure:
- All tests pass (`./run.sh test`)
- Code is formatted (`./run.sh format`)
- No analyzer warnings (`./run.sh analyze`)

---

## License

MIT License - see [LICENSE](LICENSE)

---

<div align="center">
  <sub>Built with ❤️ using Flutter and ONNX Runtime</sub>
</div>
