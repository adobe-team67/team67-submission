# Adobe GenAI Editor - Flutter Frontend

> AI-powered image editing made intuitive. Select, transform, and create with the power of generative AI.

---

## What is this?

This is the mobile frontend for our AI Image Editor — a Flutter application that brings professional-grade generative AI editing to your fingertips. Built as part of the Inter IIT Tech Meet 14.0 Adobe problem statement, this app lets you:

- **Select objects** intelligently using YOLO segmentation or manual tools
- **Move & transform** selected objects naturally within images
- **Erase objects** seamlessly with AI-powered inpainting
- **Generate content** using text prompts (img2img, inpainting)
- **Stylize images** with various artistic effects
- **Auto-enhance** with aspect ratio correction, background removal, and more

The app connects to our Python/FastAPI backend for heavy AI lifting while providing a smooth, responsive native experience.

---

## Getting Started

### Prerequisites

- Flutter SDK `^3.6.0`
- Dart SDK (comes with Flutter)
- Android Studio / Xcode for device emulation
- A running instance of the backend API

### Quick Setup

1. **Clone and navigate to the project:**
   ```bash
   cd adobe_mvp
   ```

2. **Set up your environment:**
   ```bash
   cp .env.example .env
   ```
   
   Edit `.env` with your configuration:
   ```
   API_BASE_URL=https://your-backend-server.com
   USE_MOCK_API=false
   ```

3. **Install dependencies:**
   ```bash
   flutter pub get
   ```

4. **Run the app:**
   ```bash
   flutter run
   ```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `API_BASE_URL` | Backend API server URL | `http:\\localhost:8000` |
| `USE_MOCK_API` | Use mock responses for testing | `false` |

> **Security Note:** Never commit your `.env` file. It's already in `.gitignore`.

---

## Project Architecture Modules

```
lib/
├── main.dart                 # App entry point
├── app.dart                  # MaterialApp configuration
│
├── config/                   # Configuration & environment
│
├── core/                     # Core utilities
│
├── features/                 # Feature modules
│   ├── editor/               # Main image editor
│   ├── home/                 # Home screen
│   ├── splash/               # Splash screen
│   ├── gallery/              # Image gallery
│   ├── files/                # File management
│   ├── profile/              # User profile
│   └── learn/                # Tutorials & help
│
├── models/                   # Data models
│
├── services/                 # External services
│
├── state/                    # State management (Riverpod)
│
├── ui/                       # Shared UI components
│
└── workers/                  # Background processing
```

---

## Key Features

### Object Selection
- **Tap Selection** — Tap on objects for instant AI-powered selection
- **Brush Selection** — Paint over areas to select
- **Lasso Selection** — Draw freeform selections
- **YOLO Integration** — On-device object detection using TFLite

### AI Editing Tools
| Tool | Description |
|------|-------------|
| **Move** | Relocate selected objects with automatic background fill |
| **Erase** | Remove objects seamlessly |
| **Inpaint** | Fill selections with AI-generated content based on prompts |
| **Img2Img** | Transform the entire image with style prompts |
| **Stylize** | Apply artistic styles to your image |

### Smart Features
- **Voice Commands** — Speak your edit instructions
- **Undo/Redo** — Full edit history with state restoration
- **Auto Enhance** — One-tap improvements (aspect ratio, background removal)
- **Magic View** — Preview AI suggestions before applying

---

## Tech Stack

| Category | Technology |
|----------|------------|
| Framework | Flutter 3.6+ |
| State Management | Riverpod (StateNotifier pattern) |
| API Client | Dio, HTTP |
| On-device ML | TFLite Flutter (custom local package) |
| Image Processing | `image` package |
| Voice Input | speech_to_text |
| Animations | Lottie |
| Caching | cached_network_image |

---

## Supported Platforms

- ✅ Android
- ✅ iOS
- 🔄 Web (partial support)
- 🔄 Desktop (experimental)
