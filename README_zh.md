# LabelLoad

<div align="center">
  <img src="https://img.shields.io/badge/Flutter-3.6+-02569B?style=for-the-badge&logo=flutter" alt="Flutter">
  <img src="https://img.shields.io/badge/Platform-Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License">
  <img src="https://img.shields.io/badge/ONNX%20Runtime-1.20-blue?style=for-the-badge" alt="ONNX">
  <img src="https://img.shields.io/badge/CUDA-GPU%20加速-76B900?style=for-the-badge&logo=nvidia" alt="CUDA">
</div>

<p align="center">
  <b>🏷️ 企业级图像标注工具，支持 AI 自动标注</b>
</p>

<p align="center">
  <a href="./README.md">🇬🇧 English</a> •
  <a href="#亮点">亮点</a> •
  <a href="#安装">安装</a> •
  <a href="#快速开始">快速开始</a>
</p>

---

## 亮点

- **🤖 AI 驱动**: YOLOv8 检测和姿态估计，GPU/CPU 自动选择
- **⚡ 高性能**: 原生 C++ FFI 推理引擎 (1300+ 行代码)，支持批量处理
- **🏗️ 清晰架构**: 7 个 Provider、36 个 Service、40 个 Widget，100 个单元测试
- **🌍 双语支持**: 完整的中英文国际化 (i18n)
- **📦 Docker 构建**: 一键构建，无需本地依赖

---

## 功能特性

### 标签类型

| 类型 | 描述 | YOLO 格式 |
|------|------|-----------|
| **边界框 (Box)** | 标准矩形标注 | `class cx cy w h` |
| **框+关键点 (BoxWithPoint)** | 检测 + 姿态关键点 | `class cx cy w h [kp_x kp_y v]...` |
| **多边形 (Polygon)** | 语义分割掩码 | `class [x y]...` |

### AI 自动标注

- **YOLOv8** 目标检测
- **YOLOv8-Pose** 人体姿态估计 (17 关键点 COCO 格式)
- 自动检测 GPU 并加速 (CUDA)
- 追加/覆盖两种标签合并模式
- 切换图片时可自动推理 (可配置)
- 记录已推理图片，避免重复工作

### 工具箱 (Gadgets)

| 工具 | 功能 |
|------|------|
| **批量重命名** | 按序号重命名图片文件 |
| **XYXY → XYWH** | 坐标格式转换 |
| **边框扩展** | 按比例扩展边界框 |
| **检查修复** | 修复越界框、移除重复标签 |
| **格式转换** | 类别 ID 重映射和过滤 |
| **删除关键点** | 剥离关键点，仅保留边界框 |
| **从点生成框** | 根据关键点坐标计算边界框 |

### 绘制与编辑

| 模式 | 描述 |
|------|------|
| **标注模式** | 绘制新标注（拖动或两点点击） |
| **编辑模式** | 选择、移动、调整现有标注 |
| **多边形模式** | 点击添加顶点，闭合完成 |
| **关键点模式** | 点击将关键点绑定到标签 |

### 界面特性

- 🌓 深色/浅色主题，跟随系统
- ⌨️ 完全可自定义的快捷键
- 🔍 平滑缩放 (0.05x - 20x) 和鼠标平移
- ⚡ 撤销/重做历史栈
- 💾 导航时自动保存 (可配置)
- 🔆 暗部增强滤镜，适用于低光照图片

---

## 安装

### 系统要求

- **操作系统**: Ubuntu 22.04+ (GLib 2.72+)
- **Docker**: 构建发布版本时需要
- **GPU (可选)**: CUDA 11.x + cuDNN 8.x 用于 GPU 推理

### 从 DEB 包安装

从 [Releases](https://github.com/T-DT-Algorithm-2026/label-load/releases) 下载，并将 `<version>` 替换为发布版本号：

```bash
# CPU 版本 (~18MB，无需 CUDA)
sudo apt install label-load_<version>_amd64.deb

# GPU 版本 (~120MB，需预装 CUDA Toolkit)
sudo apt install label-load_<version>_gpu_amd64.deb
```

### 从源码构建 (Docker)

```bash
git clone https://github.com/T-DT-Algorithm-2026/label-load.git
cd label-load/label_load

# 构建 CPU 发布版 (默认)
./packaging/build_docker.sh --cpu

# 构建 GPU 发布版
./packaging/build_docker.sh --gpu

# 输出: build/release/label-load_*.deb
```

### 本地开发

```bash
# 安装 Flutter 3.6+
# https://docs.flutter.dev/get-started/install/linux

cd label_load
./run.sh debug      # 构建调试版本
./run.sh run        # 运行调试版本
```

---

## 快速开始

### 1. 创建项目

1. 点击右下角 **+** 按钮
2. 输入项目名称和描述
3. 选择 **图片目录** (图片所在位置)
4. 选择 **标签目录** (.txt 标签保存位置)
5. 添加标签类别，设置名称和颜色

### 2. 开始标注

1. 点击项目卡片进入标注界面
2. 按 `W` 切换 **标注模式** 和 **编辑模式**
3. 在标注模式下：
   - **拖动** 或 **两点点击** 绘制边界框
   - 按 `C` 切换类别
4. 按 `A`/`D` 切换图片
5. 切换图片时自动保存标签 (可配置)

### 3. AI 自动标注

1. 打开项目设置 (齿轮图标)
2. 配置 AI 模型：
   - 选择 ONNX 模型文件 (.onnx)
   - 选择模型类型 (YOLO / YOLO-Pose)
   - 调整置信度和 NMS 阈值
3. 按 `R` 对当前图片执行推理
4. 使用批量推理处理整个数据集

---

## 快捷键

所有快捷键可在 **设置 → 快捷键** 中自定义。

### 导航

| 操作 | 默认按键 |
|------|----------|
| 上一张图片 | `A` |
| 下一张图片 | `D` |
| 上一个标签 | `Q` |
| 下一个标签 | `E` |

### 编辑

| 操作 | 默认按键 |
|------|----------|
| 切换模式 (标注/编辑) | `W` |
| 下一个类别 | `C` |
| 删除选中 | `Delete` 或 `Backspace` |
| 保存标签 | `S` |
| 撤销 | `Ctrl+Z` |
| 重做 | `Ctrl+Shift+Z` |
| 取消操作 | `Escape` |

### AI 与视图

| 操作 | 默认按键 |
|------|----------|
| AI 推理 | `R` |
| 切换暗部增强 | `X` |
| 切换关键点可见性 | `V` |
| 循环切换关键点绑定 | `` ` `` (反引号) |

### 鼠标

| 操作 | 鼠标 |
|------|------|
| 创建/绘制 | 左键 |
| 删除 | 右键 |
| 平移画布 | 中键拖动 |
| 缩放 | 滚轮 |

---

## 架构

```
label_load/
├── lib/                        # Flutter 源码 (95 文件)
│   ├── models/                 # 数据模型 (Label, Project, Config)
│   ├── providers/              # 状态管理 (7 个 Provider)
│   │   ├── project_provider.dart
│   │   ├── canvas_provider.dart
│   │   ├── keybindings_provider.dart
│   │   └── settings_provider.dart
│   ├── services/               # 业务逻辑 (36 文件)
│   │   ├── inference/          # AI 推理编排
│   │   ├── gadgets/            # 批处理工具
│   │   └── labels/             # 标签 I/O 和历史
│   └── widgets/                # UI 组件 (40 文件)
│       ├── canvas/             # 图像画布和绘制器
│       └── dialogs/            # 设置、AI 配置、工具箱
├── onnx_inference/             # 原生 FFI 插件
│   └── src/                    # C++ 推理引擎 (1300+ 行代码)
├── test/                       # 单元测试 (100 文件)
├── integration_test/           # 集成测试 (13 个流程)
└── packaging/                  # Docker 构建脚本
    ├── Dockerfile.build        # 构建环境
    └── build_docker.sh         # 统一构建脚本
```

---

## 开发命令

```bash
# 帮助和版本
./run.sh help              # 显示所有命令
./run.sh version           # 显示版本信息

# 开发
./run.sh clean             # 清理构建产物
./run.sh debug             # 构建调试版本
./run.sh run               # 运行调试版本

# 发布工作流
./run.sh release           # 构建 release 版本
./run.sh deb               # 打包 DEB (默认: CPU)
./run.sh deb --gpu         # 打包 GPU DEB (~120MB)
./run.sh deb --cpu         # 打包 CPU DEB (~18MB)

# 测试
./run.sh test              # 运行所有测试
./run.sh test --unit       # 仅单元测试
./run.sh test --int        # 仅集成测试
./run.sh test --native     # C++ 测试
./run.sh test --coverage   # 生成覆盖率报告

# 代码质量
./run.sh analyze           # 静态分析
./run.sh format            # 格式检查
```

---

## 贡献

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送分支 (`git push origin feature/amazing-feature`)
5. 发起 Pull Request

请确保：
- 所有测试通过 (`./run.sh test`)
- 代码格式正确 (`./run.sh format`)
- 无分析器警告 (`./run.sh analyze`)

---

## 许可证

MIT License - 详见 [LICENSE](LICENSE)

---

<div align="center">
  <sub>使用 Flutter 和 ONNX Runtime 用 ❤️ 构建</sub>
</div>
