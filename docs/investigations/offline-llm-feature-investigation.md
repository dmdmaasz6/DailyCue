# Feature Investigation: Offline LLM Integration for Life Balance Insights

**Date:** 2026-02-13
**Status:** Investigation Complete
**Feature:** Integrate an offline-capable LLM to provide personalized insights into daily activities and suggest improvements for life balance.

---

## 1. Executive Summary

This investigation evaluates integrating **Microsoft Foundry Local** (and alternative offline LLM runtimes) into DailyCue — a Flutter-based cross-platform daily activity planner — to provide AI-powered life balance insights. The app already tracks activities with completion history, categories, and scheduling data, and has an existing insights/statistics screen. Adding an offline LLM would transform rule-based statistics into personalized, natural-language coaching.

**Key finding:** Integration is feasible but requires a platform-channel approach in Flutter, as no mature first-party Flutter LLM packages exist. Microsoft's **Phi-4-mini** (3.8B parameters, MIT license) via **ONNX Runtime** is the recommended model for cross-platform offline inference.

---

## 2. Current Application Architecture

### Tech Stack
| Component | Technology |
|---|---|
| Framework | Flutter 3.1+ (Dart) |
| Platforms | iOS, Android, Web, macOS, Linux, Windows |
| State Management | Provider with ChangeNotifier |
| Local Storage | Hive 2.2.3 (NoSQL, offline-first) |
| Notifications | flutter_local_notifications |
| Existing AI/ML | **None** |

### Data Available for LLM Analysis
The app already collects rich data that an LLM could analyze:

- **Activity records** with title, description, category, scheduled time, repeat days
- **Completion history** — timestamped list of every completion event per activity
- **8 life categories:** General, Health, Work, Personal, Fitness, Family, Errands, Learning
- **Scheduling patterns** — which days, what times, early reminders, alarm settings
- **Statistical aggregates** — completion rates, trends, category distributions (7/30/90 days)

### Existing Insights Features
The app has a full statistics dashboard (`insights_screen.dart`) with:
- Completion rate trends with period comparison
- Category distribution (donut chart)
- Follow-through rates by area
- Daily rhythm patterns (bar charts, heatmaps)
- Strongest/weakest category highlights

**Opportunity:** The statistics engine provides computed metrics but no personalized interpretation, recommendations, or natural-language coaching. An LLM fills this gap.

---

## 3. Microsoft Foundry Local — Primary Option

### What It Is
Microsoft Foundry Local is an on-device AI inference solution that runs generative AI models entirely locally, with no Azure subscription and no internet connection (after initial model download). Announced at Microsoft Build 2025, it exposes an **OpenAI-compatible REST API** on localhost.

### Architecture
```
DailyCue App (Flutter)
    |
    v
Platform Channel (Dart → Native)
    |
    v
ONNX Runtime GenAI (native library)
    |
    v
Execution Providers: CUDA | DirectML | QNN | CoreML | CPU
    |
    v
Hardware: GPU | NPU | CPU
```

### Recommended Models

| Model | Parameters | Size (INT4) | Use Case | License |
|---|---|---|---|---|
| **Phi-4-mini-instruct** | 3.8B | ~2.5 GB | General insights, recommendations | MIT |
| **Phi-4-mini-flash-reasoning** | 3.8B | ~2.5 GB | Complex pattern analysis | MIT |
| **Phi-3.5-mini** | 3.8B | ~2.5 GB | Lighter alternative, well-tested | MIT |
| Phi-4 | 14B | ~8-10 GB | Desktop only (too large for mobile) | MIT |

**Recommendation:** Start with **Phi-4-mini-flash-reasoning** — it offers up to 10x higher throughput than standard Phi-4-mini with 2-3x lower latency, specifically engineered for edge/mobile.

### Platform Support

| Platform | Foundry Local Status | Alternative Runtime |
|---|---|---|
| Windows | Supported | Direct Foundry Local CLI/SDK |
| macOS | Supported | Direct Foundry Local CLI/SDK |
| Android | Private Preview | ONNX Runtime GenAI directly |
| iOS | **Not on roadmap** | ONNX Runtime GenAI or Core ML |
| Linux | Planned | ONNX Runtime GenAI directly |
| Web | Not available | WebLLM (@mlc-ai/web-llm) |

### SDKs Available
- **JavaScript/TypeScript:** `npm install foundry-local-sdk`
- **Python:** `pip install foundry-local-sdk`
- **C# / .NET:** `Microsoft.AI.Foundry.Local` (self-contained, no CLI needed)
- **Rust:** Also available

### Key Limitation
Foundry Local itself does not support iOS and has limited Android support (private preview). For a cross-platform Flutter app, the better strategy is to use **ONNX Runtime GenAI directly** as the inference engine, which supports all platforms.

---

## 4. Alternative Offline LLM Runtimes

### ONNX Runtime GenAI (Recommended for Flutter)
- **Best cross-platform coverage:** Android, iOS, Windows, macOS, Linux, Web
- Supports Phi, Llama, Gemma, Mistral, Qwen, and 130,000+ models
- Hardware acceleration: CUDA, DirectML, QNN (Qualcomm NPU), CoreML, CPU
- Handles full LLM pipeline: tokenization, KV cache, sampling

### MediaPipe LLM Inference API (Best for Mobile Quality)
- Supports Android, iOS, Web
- **Gemma 3n E4B:** 60-70 tok/s, 0.3s time-to-first-token, 3GB memory, multimodal
- Google is migrating to LiteRT-LM (more open-source flexibility)

### llama.cpp (Most Model Flexibility)
- Pure C/C++, works on Android (NDK) and iOS
- Broadest model format support (GGUF)
- Requires more integration work for Flutter

### Apple Foundation Models (iOS 26+ Only)
- Zero model download, free, built-in ~3B model
- Only available on Apple devices with iOS 26+
- Simplest path for iOS-only features

### WebLLM (Web Platform Only)
- `@mlc-ai/web-llm` — WebGPU-accelerated browser inference
- 80% of native speed, OpenAI-compatible API
- Good for Flutter Web target

---

## 5. Proposed Feature: AI Life Balance Coach

### 5.1 Feature Description
Add an "AI Coach" capability to DailyCue that analyzes the user's activity data and provides:

1. **Personalized Daily Briefings** — Natural-language summary of the day ahead with balance observations
2. **Life Balance Score** — AI-computed balance score across the 8 categories with explanations
3. **Smart Recommendations** — Suggestions for activities to add, reschedule, or adjust based on patterns
4. **Weekly Reflections** — End-of-week AI-generated retrospective on habit consistency and growth
5. **Pattern Detection** — Identify emerging habits, breaking routines, or burnout indicators
6. **Natural Language Q&A** — Ask questions like "Am I spending enough time on fitness?" or "What's my most productive time of day?"

### 5.2 Data Flow Architecture

```
┌─────────────────────────────────────────────────┐
│                  DailyCue App                    │
│                                                  │
│  ┌──────────────┐    ┌────────────────────────┐ │
│  │ Activity Data │───>│ Statistics Calculator   │ │
│  │ (Hive Store)  │    │ (Existing)             │ │
│  └──────────────┘    └──────────┬─────────────┘ │
│                                  │               │
│                                  v               │
│                      ┌───────────────────────┐   │
│                      │  Prompt Builder        │   │
│                      │  (Dart Service)        │   │
│                      │  - Formats user data   │   │
│                      │  - Builds system prompt │   │
│                      │  - Manages context     │   │
│                      └──────────┬────────────┘   │
│                                  │               │
│                                  v               │
│                      ┌───────────────────────┐   │
│                      │  LLM Service           │   │
│                      │  (Platform Channel)    │   │
│                      │  - Model management    │   │
│                      │  - Inference calls     │   │
│                      │  - Response streaming  │   │
│                      └──────────┬────────────┘   │
│                                  │               │
│  ┌──────────────┐               │               │
│  │  AI Insights  │<─────────────┘               │
│  │  Screen (UI)  │                               │
│  └──────────────┘                               │
└─────────────────────────────────────────────────┘
                       │
          Platform Channel (MethodChannel)
                       │
                       v
┌─────────────────────────────────────────────────┐
│           Native Inference Layer                 │
│                                                  │
│  ┌─────────┐  ┌─────────┐  ┌────────────────┐  │
│  │ Android  │  │  iOS    │  │ Desktop        │  │
│  │ ONNX RT  │  │ ONNX RT │  │ Foundry Local  │  │
│  │ GenAI    │  │ GenAI / │  │ or ONNX RT     │  │
│  │          │  │ CoreML  │  │ GenAI          │  │
│  └─────────┘  └─────────┘  └────────────────┘  │
│                                                  │
│  Model: Phi-4-mini-flash-reasoning (INT4, ~2.5GB)│
└─────────────────────────────────────────────────┘
```

### 5.3 Prompt Engineering Strategy

The LLM would receive structured prompts containing:

```
You are a personal life balance coach embedded in a daily activity planner.
Analyze the user's activity data and provide actionable, encouraging insights.

USER DATA:
- Total activities: 12 across 5 categories
- Completion rate (7 days): 78% (up from 72%)
- Category breakdown:
  - Work: 4 activities, 95% completion
  - Health: 2 activities, 60% completion
  - Fitness: 1 activity, 40% completion
  - Family: 3 activities, 85% completion
  - Learning: 2 activities, 70% completion
- Strongest: Work (95%)
- Weakest: Fitness (40%)
- Daily pattern: Most completions 6-9 AM, drop-off after 6 PM
- Trend: Health declining (-15% vs prior week)

Provide a brief, personalized insight about their life balance
and one specific suggestion for improvement.
```

### 5.4 Integration Points in Existing Code

| File | Integration |
|---|---|
| `lib/services/` | Add `llm_service.dart` — model lifecycle, inference calls via platform channel |
| `lib/services/` | Add `prompt_builder_service.dart` — transforms stats into LLM prompts |
| `lib/utils/statistics_calculator.dart` | Already computes the metrics needed; extend to produce LLM-ready data |
| `lib/screens/insights_screen.dart` | Add "AI Coach" tab or section alongside existing statistics |
| `lib/screens/dashboard_screen.dart` | Add optional AI daily briefing card |
| `lib/providers/` | Add `ai_coach_provider.dart` — manages AI state, caching, user preferences |
| `lib/models/` | Add `ai_insight.dart` — data model for cached insights |
| `android/` | Native ONNX Runtime GenAI integration (Kotlin) |
| `ios/` | Native ONNX Runtime GenAI or Core ML integration (Swift) |
| `windows/`, `macos/`, `linux/` | Foundry Local SDK or ONNX Runtime GenAI integration |

### 5.5 User Experience Design

**Model Download Flow:**
1. User enables "AI Coach" in settings (opt-in)
2. App shows model size (~2.5 GB) and prompts for WiFi download
3. Download progress indicator with pause/resume
4. Model cached locally; all future inference is offline

**Insights Interaction:**
1. **Passive insights** — Generated daily/weekly, cached, shown on dashboard and insights screen
2. **Active Q&A** — Chat-style interface where users ask specific questions about their habits
3. **Contextual tips** — When viewing a specific activity, the AI provides targeted advice

**Privacy Guarantee:**
- All data stays on-device
- No telemetry, no cloud calls
- Model runs fully offline after download
- User can delete model and all AI data at any time

---

## 6. Hardware Requirements and Constraints

### Mobile (Phi-4-mini, INT4 quantization)
| Requirement | Specification |
|---|---|
| Storage | ~2.5 GB for model + ~500 MB for runtime |
| RAM | 8 GB+ recommended (4 GB minimum with reduced context) |
| Performance | ~15-30 tok/s on modern smartphones (Snapdragon 8 Gen 2+, A15+) |
| Time-to-first-token | 0.5-2 seconds depending on device |
| Battery impact | Moderate during inference; negligible when idle |

### Desktop (Phi-4-mini or Phi-4)
| Requirement | Specification |
|---|---|
| Storage | 2.5-10 GB depending on model |
| RAM | 8 GB+ (16 GB for Phi-4 14B) |
| Performance | 30-120 tok/s depending on hardware |
| GPU | Optional but recommended (NVIDIA 2000+, AMD 6000+) |

### Minimum Device Support
- **Android:** Snapdragon 778G / Dimensity 8000+ with 8 GB RAM (2022+ flagships, 2023+ mid-range)
- **iOS:** iPhone 12+ (A14 Bionic, 4 GB RAM — reduced context window) or iPhone 13+ (recommended)
- **Desktop:** Any modern machine with 8 GB+ RAM

---

## 7. Implementation Phases

### Phase 1: Foundation (Core Infrastructure)
- Set up ONNX Runtime GenAI native integration for Android and iOS via platform channels
- Implement model download manager with progress tracking and caching
- Create `LLMService` Dart interface for cross-platform model interaction
- Add Foundry Local integration for Windows/macOS desktop
- Unit test the inference pipeline with sample prompts

### Phase 2: Prompt Engineering & Insights Generation
- Build `PromptBuilderService` that transforms `StatisticsCalculator` output into structured prompts
- Design system prompts for each insight type (daily briefing, balance score, recommendations)
- Implement response parsing and `AIInsight` data model with local caching
- Create `AiCoachProvider` for state management
- A/B test prompt templates for quality and relevance

### Phase 3: UI Integration
- Add "AI Coach" section to insights screen with generated insights
- Add daily briefing card to dashboard screen
- Build chat-style Q&A interface for habit questions
- Implement model download/management UI in settings
- Add contextual AI tips on activity detail views

### Phase 4: Optimization & Polish
- Profile and optimize inference latency per platform
- Implement inference caching (avoid re-generating identical insights)
- Add fallback for low-memory devices (reduced context, smaller model)
- Battery and thermal management during sustained inference
- Accessibility and localization of AI-generated content
- Beta testing and prompt refinement based on real user data patterns

---

## 8. Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Model size (2.5 GB) deters downloads | Reduced adoption | Offer "lite" mode with smaller model (Phi-3.5-mini or SmolLM 1.5B); progressive download |
| Inconsistent quality across devices | Poor UX on low-end hardware | Device capability detection; graceful degradation; minimum spec enforcement |
| iOS ONNX Runtime maturity | Bugs or performance gaps on iOS | Evaluate Core ML conversion as iOS-specific alternative; Apple Foundation Models for iOS 26+ |
| Hallucinated advice | Harmful or incorrect recommendations | Constrain outputs with structured prompts; present insights as suggestions, not directives; include disclaimers |
| Flutter platform channel complexity | High maintenance across 6 platforms | Abstract via clean interface; prioritize Android/iOS first, desktop second |
| Battery/thermal impact | User frustration | Limit inference to user-initiated or scheduled (1x/day); cache results aggressively |
| ONNX Runtime GenAI is relatively new | API instability | Pin versions; maintain abstraction layer to swap runtimes |

---

## 9. Alternative Approaches Considered

### Cloud-Only LLM (e.g., GPT-4o-mini, Claude Haiku)
- **Pro:** No model download, consistent quality, simpler integration
- **Con:** Requires internet, ongoing API costs, privacy concerns with activity data
- **Verdict:** Could be offered as optional complement, but offline-first is a differentiator

### Google Gemma 3n via MediaPipe
- **Pro:** Best mobile performance (60-70 tok/s), multimodal, 2-3 GB footprint
- **Con:** Ties to Google ecosystem; MediaPipe migrating to LiteRT-LM (transition risk)
- **Verdict:** Strong alternative to Phi; worth prototyping alongside ONNX approach

### Apple Foundation Models Only
- **Pro:** Zero download, free, built-in on iOS 26+
- **Con:** Apple-only; not available on Android, desktop, or web
- **Verdict:** Use as iOS 26+ enhancement layer on top of cross-platform ONNX solution

### Hybrid On-Device + Cloud
- **Pro:** Best of both worlds — fast local inference + cloud fallback for complex queries
- **Con:** Adds complexity; requires cloud infrastructure
- **Verdict:** Recommended as a Phase 5 enhancement after core offline feature ships

---

## 10. Recommendation

**Proceed with implementation** using the following strategy:

1. **Primary runtime:** ONNX Runtime GenAI (cross-platform: Android, iOS, Windows, macOS, Linux)
2. **Primary model:** Phi-4-mini-flash-reasoning (3.8B, INT4, MIT license, ~2.5 GB)
3. **Desktop enhancement:** Foundry Local SDK on Windows/macOS for simplified model management
4. **iOS enhancement:** Evaluate Apple Foundation Models framework for iOS 26+ devices as a zero-download fast path
5. **Integration pattern:** Flutter platform channels with a clean Dart abstraction layer
6. **Privacy-first:** All inference on-device, no data leaves the device, opt-in feature

This approach aligns with DailyCue's existing offline-first, local-storage architecture and adds meaningful AI value without compromising privacy or requiring subscriptions.

---

## References

- [Microsoft Foundry Local Documentation](https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-local/what-is-foundry-local)
- [ONNX Runtime GenAI](https://github.com/microsoft/onnxruntime-genai)
- [Phi-4 Model Family](https://azure.microsoft.com/en-us/products/phi)
- [Foundry Local SDK Reference](https://learn.microsoft.com/en-us/azure/ai-foundry/foundry-local/reference/reference-sdk)
- [MediaPipe LLM Inference](https://ai.google.dev/edge/mediapipe/solutions/genai/llm_inference)
- [Gemma 3n Developer Guide](https://developers.googleblog.com/en/introducing-gemma-3n-developer-guide/)
- [Apple Foundation Models](https://developer.apple.com/machine-learning/api/)
- [WebLLM](https://github.com/mlc-ai/web-llm)
- [React Native ExecuTorch](https://docs.swmansion.com/react-native-executorch/)
