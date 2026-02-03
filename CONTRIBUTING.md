# Contributing to LabelLoad

Thank you for your interest in contributing to LabelLoad! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [License Agreement](#license-agreement)
- [How to Contribute](#how-to-contribute)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Style Guidelines](#style-guidelines)
- [CI/CD Pipeline](#cicd-pipeline)

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md). Be respectful and constructive in all interactions. We welcome contributors of all experience levels.

## License Agreement

By contributing to LabelLoad, you agree that your contributions will be licensed under the [MIT License](LICENSE).

### Developer Certificate of Origin (DCO)

All contributions to this project must be accompanied by a Developer Certificate of Origin (DCO) sign-off. This is a lightweight way for contributors to certify that they have the right to submit their contribution under the project's license.

When you submit a pull request, you must check the DCO checkbox in the PR template, confirming that:

1. The contribution was created by you and you have the right to submit it
2. The contribution is provided under the project license
3. You understand that this contribution is public and a record of it is maintained

For more information, see the [Developer Certificate of Origin](https://developercertificate.org/).

## How to Contribute

### 🐛 Reporting Bugs

Found a bug? Please [open an issue](../../issues/new?template=bug_report.yml) with:

- Clear description of the problem
- Steps to reproduce
- Expected vs actual behavior
- System information (OS, app version, CPU/GPU package)

### ✨ Suggesting Features

Have an idea? [Request a feature](../../issues/new?template=feature_request.yml) and tell us:

- What problem it would solve
- Your proposed solution
- How important it is to your workflow

### 🔧 Contributing Code

1. Check existing issues or create one to discuss your idea
2. Fork the repository
3. Create a feature branch
4. Make your changes
5. Submit a pull request

## Getting Started

### Prerequisites

- **Flutter SDK** 3.6+
- **Linux** development environment (Ubuntu 22.04+ recommended)
- **ONNX Runtime** 1.23.0 (for AI features)
- **Docker** (for release builds)

### Fork and Clone

```bash
# Fork the repository on GitHub, then:
git clone https://github.com/YOUR_USERNAME/label-load.git
cd label-load/label_load
```

## Development Setup

### 1. Install Dependencies

```bash
# Install Flutter dependencies
flutter pub get

# Install ONNX Runtime (for AI inference)
ORT_VERSION="1.23.0"
wget "https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/onnxruntime-linux-x64-${ORT_VERSION}.tgz"
tar -xzf "onnxruntime-linux-x64-${ORT_VERSION}.tgz"
sudo cp onnxruntime-linux-x64-${ORT_VERSION}/lib/*.so* /usr/local/lib/
sudo cp -r onnxruntime-linux-x64-${ORT_VERSION}/include/* /usr/local/include/
sudo ldconfig
```

### 2. Build and Run

```bash
./run.sh debug    # Build debug version
./run.sh run      # Run the application
```

### 3. Verify Setup

```bash
./run.sh test --unit    # Run unit tests
./run.sh analyze        # Static analysis
```

## Making Changes

### Branch Naming

Use descriptive branch names:

- `feature/add-polygon-tool` - New features
- `fix/canvas-zoom-issue` - Bug fixes
- `docs/update-readme` - Documentation
- `refactor/simplify-provider` - Code refactoring

### Commit Messages

Follow conventional commit format:

```
type(scope): description

[optional body]
```

Types: `feat`, `fix`, `docs`, `style`, `refactor`, `test`, `chore`

Examples:
```
feat(canvas): add polygon drawing mode
fix(inference): handle model loading timeout
docs(readme): update installation instructions
```

## Testing

### Run All Tests

```bash
./run.sh test              # All tests
./run.sh test --unit       # Unit tests only
./run.sh test --int        # Integration tests only
./run.sh test --coverage   # Generate coverage report
```

### Test Structure

```
test/
├── models/           # Data model tests
├── providers/        # State management tests
├── services/         # Business logic tests
├── widgets/          # Widget tests
└── helpers/          # Test utilities

integration_test/
├── flows/            # Integration test flows
│   ├── app_smoke_test.dart
│   ├── ai_inference_flow_test.dart
│   ├── project_creation_flow_test.dart
│   └── ...           # 13 flow tests total
└── helpers/          # Integration test utilities
```

### Writing Tests

- Place tests in the corresponding `test/` subdirectory
- Use descriptive test names
- Test edge cases and error conditions
- Mock external dependencies

```dart
void main() {
  group('Label', () {
    test('should parse YOLO format correctly', () {
      final label = Label.fromYoloLine('0 0.5 0.5 0.1 0.1', (id) => 'class$id');
      expect(label.id, equals(0));
      expect(label.x, closeTo(0.5, 0.001));
    });
  });
}
```

## Submitting Changes

### Before Submitting

1. **Format code**: `./run.sh format`
2. **Run analysis**: `./run.sh analyze`
3. **Run tests**: `./run.sh test`
4. **Update documentation** if needed

### Pull Request Process

1. Create a pull request from your fork
2. Fill out the PR template
3. Wait for CI checks to pass
4. Address review feedback
5. Squash commits if requested

### PR Checklist

- [ ] Code is formatted (`./run.sh format`)
- [ ] No analyzer warnings (`./run.sh analyze`)
- [ ] All tests pass (`./run.sh test`)
- [ ] Documentation updated (if applicable)
- [ ] Commit messages follow convention

## Style Guidelines

### Dart Style

Follow the [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines:

- Use `lowerCamelCase` for variables and functions
- Use `UpperCamelCase` for classes and types
- Prefer `final` for local variables
- Add documentation comments to public APIs

### File Organization

```dart
// 1. Imports (grouped and sorted)
import 'dart:async';
import 'package:flutter/material.dart';
import '../models/label.dart';

// 2. Part directives (if any)
part 'widget_mixin.dart';

// 3. Class documentation
/// Brief description.
///
/// Detailed description if needed.
class MyWidget extends StatefulWidget {
  // 4. Fields
  final String title;
  
  // 5. Constructor
  const MyWidget({super.key, required this.title});
  
  // 6. Methods
  @override
  State<MyWidget> createState() => _MyWidgetState();
}
```

### Comments

- Use `///` for documentation comments
- Use `//` for implementation notes
- Write comments in English

### Error Handling

- Use `AppError` for domain errors
- Report unexpected errors via `ErrorReporter`
- Provide user-friendly error messages

## CI/CD Pipeline

All pull requests are automatically checked by our CI pipeline:

### Automated Checks

| Check | Command | Description |
|-------|---------|-------------|
| 🔍 Format | `./run.sh format` | Dart code formatting |
| 📊 Analyze | `./run.sh analyze` | Static analysis |
| 🧪 Unit Tests | `./run.sh test --unit` | Unit tests with coverage |
| 🔧 Native Tests | `./run.sh test --native` | C++ tests |
| 🖥️ Integration | `./run.sh test --int` | Integration tests |
| 📦 Build | `./run.sh release` | Build verification |

### Release Process

Releases are automated via GitHub Actions:

1. Create and push a version tag: `git tag v1.0.6 && git push --tags`
2. CI automatically builds CPU and GPU DEB packages
3. Packages are uploaded to GitHub Releases

Manual releases can also be triggered from the Actions tab.

## Questions?

- 💬 [Open a Discussion](../../discussions) for questions
- 🐛 [Report an Issue](../../issues/new/choose) for bugs
- 📖 Check the [README](README.md) for documentation

---

Thank you for contributing! 🎉
