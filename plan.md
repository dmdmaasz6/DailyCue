# Implementation Plan: ONNX Runtime Offline LLM Chat Integration

## Overview

Integrate an offline LLM via ONNX Runtime GenAI into DailyCue with a chat interface that can **read/write activity data** and **read user statistics** to provide life balance coaching. The LLM uses a tool-calling pattern to interact with app data.

**Model:** Phi-3.5-mini-instruct (3.8B, INT4 quantized, ~2.3 GB)
- Best tested ONNX model with official optimized exports for mobile CPU
- Runs on 6 GB+ RAM devices — covers ~90% of phones in active use (2021+)
- Strong instruction-following and function-calling capability
- MIT license, no usage restrictions

**Runtime:** ONNX Runtime GenAI (C/C++ library, ~15 MB per platform)

---

## Architecture

```
┌─────────────────────── Flutter (Dart) ───────────────────────┐
│                                                               │
│  AiChatScreen ──> AiChatProvider ──> LlmService              │
│       (UI)         (state mgmt)      (orchestrator)          │
│                                           │                  │
│                                    ToolExecutor              │
│                                    ├─ ActivityTool           │
│                                    ├─ StatisticsTool         │
│                                    └─ ScheduleTool           │
│                                           │                  │
│                                    PromptBuilder             │
│                                    (formats tool calls       │
│                                     & system prompts)        │
│                                           │                  │
│                              ModelManager                    │
│                              (download, verify, lifecycle)   │
│                                           │                  │
│                              OnnxChannel                     │
│                              (MethodChannel bridge)          │
└───────────────────────────────┬───────────────────────────────┘
                                │ Platform Channel
┌───────────────────────────────┴───────────────────────────────┐
│                     Native Layer                              │
│                                                               │
│  Android (Kotlin)                  iOS (Swift)                │
│  OnnxInferencePlugin               OnnxInferencePlugin        │
│  ├─ loadModel(path)                ├─ loadModel(path)         │
│  ├─ generate(prompt, params)       ├─ generate(prompt, params)│
│  ├─ generateStream(prompt)         ├─ generateStream(prompt)  │
│  └─ unloadModel()                  └─ unloadModel()           │
│                                                               │
│  ONNX Runtime GenAI (aar/framework)                           │
│  ├─ CPU Execution Provider (XNNPACK)                          │
│  └─ Model: Phi-3.5-mini-instruct-onnx (INT4)                 │
└───────────────────────────────────────────────────────────────┘
```

---

## Files to Create/Modify

### New Files

| # | File | Purpose |
|---|---|---|
| 1 | `lib/models/chat_message.dart` | Data model for chat messages (user, assistant, tool calls, tool results) |
| 2 | `lib/models/llm_tool.dart` | Tool definition model (name, description, parameters, handler) |
| 3 | `lib/services/onnx_channel.dart` | Platform channel wrapper — load model, generate text, stream tokens |
| 4 | `lib/services/llm_service.dart` | High-level LLM orchestrator — manages conversation loop with tool calling |
| 5 | `lib/services/model_manager.dart` | Model download, storage, verification, deletion |
| 6 | `lib/services/tool_executor.dart` | Dispatches tool calls to the correct handler, returns results |
| 7 | `lib/services/prompt_builder.dart` | Builds system prompts and formats tool definitions for Phi-3.5 chat template |
| 8 | `lib/providers/ai_chat_provider.dart` | ChangeNotifier managing chat state, message history, loading states |
| 9 | `lib/screens/ai_chat_screen.dart` | Chat UI — message bubbles, input field, streaming response display |
| 10 | `lib/widgets/chat_message_bubble.dart` | Styled message bubble widget (user/assistant/tool action indicators) |
| 11 | `lib/widgets/model_download_card.dart` | Download progress UI with size info, pause/resume, cancel |
| 12 | `android/app/src/main/kotlin/.../OnnxInferencePlugin.kt` | Android native ONNX Runtime GenAI integration |
| 13 | `ios/Runner/OnnxInferencePlugin.swift` | iOS native ONNX Runtime GenAI integration |

### Modified Files

| # | File | Change |
|---|---|---|
| 14 | `lib/app_shell.dart` | Add "AI Coach" tab to bottom navigation (4th tab before Settings) |
| 15 | `lib/app.dart` | Register `AiChatProvider` in the Provider tree; inject dependencies |
| 16 | `lib/main.dart` | Initialize `ModelManager` service at startup |
| 17 | `lib/services/storage_service.dart` | Add chat history Hive box (`ai_chat_history`); add model settings storage |
| 18 | `lib/utils/constants.dart` | Add AI-related constants (model URLs, Hive box names, tool names) |
| 19 | `pubspec.yaml` | Add `http`, `path_provider`, `crypto` dependencies for model download |
| 20 | `android/app/build.gradle.kts` | Add ONNX Runtime GenAI AAR dependency |
| 21 | `ios/Podfile` | Add ONNX Runtime GenAI pod |

---

## Step-by-Step Implementation

### Step 1: Dependencies and Constants

**`pubspec.yaml`** — Add:
```yaml
http: ^1.2.0          # Model download with progress
path_provider: ^2.1.2 # App documents directory for model storage
crypto: ^3.0.3        # SHA256 verification of downloaded model
```

**`lib/utils/constants.dart`** — Add:
```dart
// AI Coach constants
static const String hiveBoxAiChat = 'ai_chat_history';
static const String modelFileName = 'phi-3.5-mini-instruct-int4-cpu';
static const int modelSizeBytes = 2400000000; // ~2.3 GB
static const int maxConversationTurns = 20;
static const int maxGenerationTokens = 512;
static const double modelTemperature = 0.7;
static const double modelTopP = 0.9;
```

### Step 2: Data Models

**`lib/models/chat_message.dart`**:
```dart
enum ChatRole { user, assistant, system, toolCall, toolResult }

class ChatMessage {
  final String id;
  final ChatRole role;
  final String content;
  final DateTime timestamp;
  final String? toolName;        // For toolCall/toolResult messages
  final Map<String, dynamic>? toolArgs;  // Arguments passed to tool
  final bool? toolSuccess;       // Whether tool execution succeeded

  // toJson/fromJson for Hive persistence
}
```

**`lib/models/llm_tool.dart`**:
```dart
class LlmTool {
  final String name;
  final String description;
  final Map<String, LlmToolParam> parameters;
  final Future<String> Function(Map<String, dynamic>) handler;
}

class LlmToolParam {
  final String type;        // string, integer, boolean
  final String description;
  final bool required;
  final List<String>? enumValues;
}
```

### Step 3: Platform Channel (Dart side)

**`lib/services/onnx_channel.dart`**:
```dart
class OnnxChannel {
  static const _channel = MethodChannel('com.dailycue/onnx_inference');

  Future<bool> loadModel(String modelPath);
  Future<String> generate(String prompt, {
    int maxTokens = 512,
    double temperature = 0.7,
    double topP = 0.9,
    List<String>? stopSequences,
  });
  Stream<String> generateStream(String prompt, { /* same params */ });
  Future<void> unloadModel();
  Future<bool> isModelLoaded();
}
```

The `generateStream` method uses an `EventChannel` for token-by-token streaming to the UI.

### Step 4: Native Android Plugin

**`android/app/build.gradle.kts`** — Add:
```kotlin
dependencies {
    implementation("com.microsoft.onnxruntime:onnxruntime-genai-android:latest")
}
```

**`OnnxInferencePlugin.kt`**:
- Registers MethodChannel `com.dailycue/onnx_inference`
- `loadModel(path)`: Creates `OgaModel` + `OgaTokenizer` from directory path
- `generate(prompt, params)`: Tokenizes → runs `OgaGenerator` loop → decodes → returns full text
- `generateStream(prompt)`: Same but sends tokens via EventChannel sink as they're generated
- `unloadModel()`: Disposes model and tokenizer
- Runs inference on a background thread via Kotlin coroutines

### Step 5: Native iOS Plugin

**`ios/Podfile`** — Add ONNX Runtime GenAI pod.

**`OnnxInferencePlugin.swift`**:
- Mirrors Android API via FlutterMethodChannel
- Uses `OgaModel`, `OgaTokenizer`, `OgaGeneratorParams` from onnxruntime-genai framework
- Inference on background DispatchQueue
- Streaming via FlutterEventChannel

### Step 6: Model Manager

**`lib/services/model_manager.dart`**:
```dart
class ModelManager {
  // Model lifecycle
  Future<bool> isModelDownloaded();
  Future<String> getModelPath();
  Future<int> getModelSizeOnDisk();

  // Download with progress
  Stream<DownloadProgress> downloadModel();   // yields DownloadProgress(bytesReceived, totalBytes)
  Future<void> cancelDownload();
  Future<void> deleteModel();

  // Verification
  Future<bool> verifyModelIntegrity();
}
```

The model files are stored in the app's documents directory under `models/phi-3.5-mini/`. The download streams a `.tar.gz` archive from Hugging Face and extracts the ONNX model files (model.onnx, model.onnx.data, tokenizer files, genai_config.json).

### Step 7: Tool Executor and Tools

**`lib/services/tool_executor.dart`**:

Defines 8 tools the LLM can call:

```
┌─────────────────────────────────────────────────────────────────┐
│ TOOL                  │ READ/WRITE │ DESCRIPTION                │
├───────────────────────┼────────────┼────────────────────────────┤
│ get_today_schedule    │ READ       │ All activities for today   │
│                       │            │ with completion status     │
│                       │            │                            │
│ get_all_activities    │ READ       │ Full activity list with    │
│                       │            │ metadata and categories    │
│                       │            │                            │
│ get_activity          │ READ       │ Single activity detail     │
│   params: id          │            │ by ID                      │
│                       │            │                            │
│ get_statistics        │ READ       │ PeriodStats for a given    │
│   params: period      │            │ period (week/month/quarter)│
│   (week|month|quarter)│            │                            │
│                       │            │                            │
│ create_activity       │ WRITE      │ Create new activity        │
│   params: title,      │            │ Returns created activity   │
│   time, category,     │            │                            │
│   repeatDays?,        │            │                            │
│   description?        │            │                            │
│                       │            │                            │
│ update_activity       │ WRITE      │ Modify existing activity   │
│   params: id, +any    │            │ fields                     │
│   mutable fields      │            │                            │
│                       │            │                            │
│ mark_complete         │ WRITE      │ Mark activity done today   │
│   params: id          │            │                            │
│                       │            │                            │
│ get_balance_summary   │ READ       │ Custom aggregation:        │
│                       │            │ time per category, gaps,   │
│                       │            │ overloaded areas, missing  │
│                       │            │ categories                 │
└───────────────────────┴────────────┴────────────────────────────┘
```

Each tool handler accesses `ActivityProvider` and `StatisticsCalculator` to retrieve/mutate data, then returns a JSON string result for the LLM to interpret.

**Write tool safety:** `create_activity` and `update_activity` require user confirmation via a dialog before executing. The LLM proposes the change, the user sees a preview card, and taps confirm/reject. `mark_complete` executes immediately (low risk, easily reversible).

### Step 8: Prompt Builder

**`lib/services/prompt_builder.dart`**:

Builds prompts using **Phi-3.5 chat template** (`<|system|>`, `<|user|>`, `<|assistant|>`, `<|end|>`).

**System prompt structure:**
```
<|system|>
You are DailyCue AI Coach, a helpful life balance assistant embedded
in a daily activity planner app. You help users understand their habits,
improve their routines, and build a balanced life.

You have access to the following tools to read and modify the user's
activity data. Always check the user's data before giving advice.

## Tools
[JSON tool definitions]

## Tool Calling Format
To use a tool, respond with:
<tool_call>{"name": "tool_name", "arguments": {...}}</tool_call>

Wait for the tool result before continuing your response.

## Guidelines
- Be concise and encouraging
- Ground all advice in the user's actual data
- When suggesting new activities, use create_activity tool
- Always check statistics before making claims about patterns
- Respect user privacy — all data stays on their device
- Ask before making changes to existing activities
<|end|>
```

The `PromptBuilder` also:
- Injects a brief context snapshot (current time, day of week, today's completion count) at the start of each conversation
- Formats tool results as `<|tool_result|>{"name": "...", "result": ...}<|end|>`
- Manages token budget — trims older messages when approaching context limit (~4096 tokens for efficient mobile inference)

### Step 9: LLM Service (Orchestrator)

**`lib/services/llm_service.dart`**:
```dart
class LlmService {
  final OnnxChannel _onnx;
  final ToolExecutor _toolExecutor;
  final PromptBuilder _promptBuilder;
  final ModelManager _modelManager;

  // Main chat loop
  Stream<LlmEvent> chat(String userMessage, List<ChatMessage> history);

  // LlmEvent types:
  // - LlmTokenEvent(token)        → streaming text to UI
  // - LlmToolCallEvent(name, args) → tool being invoked
  // - LlmToolResultEvent(result)   → tool result ready
  // - LlmConfirmEvent(action)      → needs user confirmation for write
  // - LlmDoneEvent(fullResponse)   → generation complete
  // - LlmErrorEvent(error)         → inference failed
}
```

**Chat loop logic:**
1. Build full prompt from system + history + new user message
2. Call `_onnx.generateStream()` to get token stream
3. Accumulate tokens; detect `<tool_call>` pattern in output
4. If tool call detected: pause generation, parse tool name + args
5. For write tools: emit `LlmConfirmEvent` → wait for user approval
6. Execute tool via `_toolExecutor`, get result string
7. Append tool result to prompt, resume generation
8. Repeat until no more tool calls or max iterations (3) reached
9. Emit `LlmDoneEvent` with final response

### Step 10: AI Chat Provider

**`lib/providers/ai_chat_provider.dart`**:
```dart
class AiChatProvider extends ChangeNotifier {
  // State
  List<ChatMessage> messages = [];
  bool isGenerating = false;
  bool isModelLoaded = false;
  ModelDownloadState downloadState; // notStarted, downloading, downloaded, failed
  double downloadProgress = 0.0;

  // Actions
  Future<void> sendMessage(String text);
  Future<void> confirmToolAction(String messageId, bool approved);
  Future<void> loadModel();
  Future<void> downloadModel();
  Future<void> cancelDownload();
  Future<void> deleteModel();
  Future<void> clearChat();

  // Persists chat history to Hive between sessions
  Future<void> _saveChatHistory();
  Future<void> _loadChatHistory();
}
```

### Step 11: Chat UI Screen

**`lib/screens/ai_chat_screen.dart`**:

**Layout:**
```
┌──────────────────────────────────┐
│  AI Coach              [clear]   │  ← AppBar
├──────────────────────────────────┤
│                                  │
│  ┌─ Assistant ─────────────────┐ │
│  │ Hi! I'm your AI Coach.     │ │  ← Welcome message
│  │ Ask me about your habits.  │ │
│  └────────────────────────────┘ │
│                                  │
│  ┌────────────── User ────────┐ │
│  │ How am I doing this week?  │ │  ← User message (right-aligned)
│  └────────────────────────────┘ │
│                                  │
│  ┌─ Assistant ─────────────────┐ │
│  │ 📊 Reading your stats...   │ │  ← Tool call indicator
│  │                            │ │
│  │ You're at 78% completion   │ │  ← Streaming response
│  │ this week, up from 72%...  │ │
│  └────────────────────────────┘ │
│                                  │
│  ┌─ Action Required ──────────┐ │
│  │ Create "Evening Walk"      │ │  ← Write confirmation card
│  │ 🏃 Fitness · 7:00 PM      │ │
│  │ [Approve]     [Decline]    │ │
│  └────────────────────────────┘ │
│                                  │
├──────────────────────────────────┤
│  [  Type a message...    ] [➤]  │  ← Input field + send button
└──────────────────────────────────┘
```

**States:**
- **No model:** Shows `ModelDownloadCard` with model info, size, and download button
- **Downloading:** Progress bar with percentage, cancel button
- **Model ready:** Chat interface with message list and input
- **Generating:** Input disabled, streaming text with typing indicator
- **Tool action pending:** Confirmation card inline in chat

**Quick suggestion chips** shown above the input when chat is empty:
- "How's my balance this week?"
- "What should I focus on today?"
- "Suggest a new habit"
- "Analyze my strongest area"

### Step 12: App Shell Integration

**`lib/app_shell.dart`** — Add 4th tab:
```dart
NavigationDestination(
  icon: Icon(Icons.auto_awesome_outlined),
  selectedIcon: Icon(Icons.auto_awesome),
  label: 'AI Coach',
)
```

Navigation order: Dashboard | Insights | Routines | **AI Coach** | Settings

### Step 13: Provider Wiring

**`lib/app.dart`** — Add to provider tree:
```dart
ChangeNotifierProvider(
  create: (context) => AiChatProvider(
    llmService: LlmService(
      onnx: OnnxChannel(),
      toolExecutor: ToolExecutor(activityProvider: activityProvider),
      promptBuilder: PromptBuilder(),
      modelManager: ModelManager(),
    ),
    storage: storageService,
  ),
)
```

**`lib/main.dart`** — Add:
```dart
final modelManager = ModelManager();
// No heavy init needed — model loads on-demand when user opens AI Coach
```

**`lib/services/storage_service.dart`** — Add:
```dart
static const hiveBoxAiChat = 'ai_chat_history';
// Open box in init()
// Add getChatHistory() / saveChatHistory() methods
```

---

## Model Selection Rationale

### Why Phi-3.5-mini-instruct (INT4-CPU)?

| Criterion | Phi-3.5-mini (chosen) | Phi-4-mini-flash | SmolLM 1.5B |
|---|---|---|---|
| Parameters | 3.8B | 3.8B | 1.5B |
| RAM needed | ~3 GB | ~3 GB | ~1.5 GB |
| Download size | ~2.3 GB | ~2.3 GB | ~1 GB |
| Min phone RAM | 6 GB | 6 GB | 4 GB |
| Phone coverage | ~90% active devices | ~90% | ~98% |
| ONNX mobile CPU export | Official, well-tested | Newer, less tested | Limited ONNX support |
| Instruction following | Excellent | Excellent | Moderate |
| Tool/function calling | Strong | Strong | Weak |
| Multilingual | 128K context, multi-lang | Good | Limited |
| License | MIT | MIT | Apache 2.0 |

**Phi-3.5-mini wins** because:
1. **Official ONNX mobile CPU export** exists on Hugging Face — no custom conversion needed
2. **Best tested** of all Phi variants on ONNX Runtime mobile — Microsoft's own reference model
3. **Strong tool calling** — critical for our read/write activity data pattern
4. **6 GB phone coverage (~90%)** is acceptable — most phones sold since 2021 have 6+ GB
5. Phi-4-mini-flash is newer and less battle-tested on mobile ONNX; can upgrade later

### Device Compatibility

| RAM | % of Active Phones | Experience |
|---|---|---|
| 4 GB | ~8% | Not supported (shows "device not compatible" message) |
| 6 GB | ~25% | Supported with reduced context (2048 tokens) |
| 8 GB+ | ~67% | Full experience (4096 token context) |

---

## Implementation Order

1. **Constants + dependencies** (`pubspec.yaml`, `constants.dart`)
2. **Data models** (`chat_message.dart`, `llm_tool.dart`)
3. **Platform channel** (`onnx_channel.dart`)
4. **Android native plugin** (`OnnxInferencePlugin.kt` + gradle)
5. **iOS native plugin** (`OnnxInferencePlugin.swift` + Podfile)
6. **Model manager** (`model_manager.dart`)
7. **Prompt builder** (`prompt_builder.dart`)
8. **Tool executor** with all 8 tools (`tool_executor.dart`)
9. **LLM service** orchestrator (`llm_service.dart`)
10. **Storage updates** for chat history (`storage_service.dart`)
11. **AI Chat provider** (`ai_chat_provider.dart`)
12. **Chat UI widgets** (`chat_message_bubble.dart`, `model_download_card.dart`)
13. **Chat screen** (`ai_chat_screen.dart`)
14. **App shell + wiring** (`app_shell.dart`, `app.dart`, `main.dart`)
