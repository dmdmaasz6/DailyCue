package com.example.dailycue

import android.app.ActivityManager
import android.content.Context
import ai.onnxruntime.genai.GenAIException
import ai.onnxruntime.genai.SimpleGenAI
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import java.io.File

class OnnxInferencePlugin(
    private val context: Context,
    flutterEngine: FlutterEngine,
) : MethodChannel.MethodCallHandler {

    private val methodChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "com.dailycue/onnx_inference"
    )
    private val deviceInfoChannel = MethodChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "com.dailycue/device_info"
    )
    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "com.dailycue/onnx_inference_stream"
    )

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var eventSink: EventChannel.EventSink? = null
    private var generationJob: Job? = null

    private var modelLoaded = false
    private var genAI: SimpleGenAI? = null

    init {
        methodChannel.setMethodCallHandler(this)
        deviceInfoChannel.setMethodCallHandler(this)
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
                generationJob?.cancel()
            }
        })
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "loadModel" -> {
                val path = call.argument<String>("modelPath")
                if (path == null) {
                    result.error("INVALID_ARG", "modelPath is required", null)
                    return
                }
                scope.launch {
                    try {
                        loadModel(path)
                        withContext(Dispatchers.Main) {
                            result.success(true)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("LOAD_FAILED", e.message, null)
                        }
                    }
                }
            }

            "generate" -> {
                val prompt = call.argument<String>("prompt") ?: ""
                val maxTokens = call.argument<Int>("maxTokens") ?: 512
                val temperature = call.argument<Double>("temperature") ?: 0.7
                val topP = call.argument<Double>("topP") ?: 0.9

                scope.launch {
                    try {
                        val response = generate(prompt, maxTokens, temperature, topP)
                        withContext(Dispatchers.Main) {
                            result.success(response)
                        }
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            result.error("GENERATE_FAILED", e.message, null)
                        }
                    }
                }
            }

            "startGeneration" -> {
                val prompt = call.argument<String>("prompt") ?: ""
                val maxTokens = call.argument<Int>("maxTokens") ?: 512
                val temperature = call.argument<Double>("temperature") ?: 0.7
                val topP = call.argument<Double>("topP") ?: 0.9

                generationJob = scope.launch {
                    try {
                        generateStream(prompt, maxTokens, temperature, topP)
                    } catch (e: CancellationException) {
                        // Generation was stopped by user
                    } catch (e: Exception) {
                        withContext(Dispatchers.Main) {
                            eventSink?.error("STREAM_FAILED", e.message, null)
                        }
                    }
                }
                result.success(null)
            }

            "stopGeneration" -> {
                generationJob?.cancel()
                generationJob = null
                result.success(null)
            }

            "unloadModel" -> {
                unloadModel()
                result.success(null)
            }

            "isModelLoaded" -> {
                result.success(modelLoaded)
            }

            "getTotalRam" -> {
                val activityManager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
                val memInfo = ActivityManager.MemoryInfo()
                activityManager?.getMemoryInfo(memInfo)
                result.success(memInfo.totalMem) // Returns bytes
            }

            else -> result.notImplemented()
        }
    }

    @Throws(GenAIException::class)
    private fun loadModel(path: String) {
        val dir = File(path)
        if (!dir.exists() || !dir.isDirectory) {
            throw Exception("Model directory not found: $path")
        }

        // Log all files in the model directory for debugging
        android.util.Log.d("OnnxInferencePlugin", "Model directory: $path")
        dir.listFiles()?.forEach { file ->
            android.util.Log.d("OnnxInferencePlugin", "  - ${file.name} (${file.length()} bytes)")
        }

        val requiredFiles = listOf(
            "genai_config.json",
            "tokenizer.json",
            "tokenizer_config.json",
            "special_tokens_map.json"
        )
        for (fileName in requiredFiles) {
            if (!File(dir, fileName).exists()) {
                throw Exception("Missing required model file: $fileName in $path")
            }
        }

        try {
            android.util.Log.d("OnnxInferencePlugin", "Creating SimpleGenAI with path: $path")
            genAI = SimpleGenAI(path)
            modelLoaded = true
            android.util.Log.d("OnnxInferencePlugin", "Model loaded successfully")
        } catch (e: Exception) {
            android.util.Log.e("OnnxInferencePlugin", "Failed to load model", e)
            throw Exception("Failed to initialize ONNX Runtime GenAI: ${e.message}")
        }
    }

    @Throws(GenAIException::class)
    private fun generate(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
    ): String {
        if (!modelLoaded || genAI == null) throw Exception("Model not loaded")

        val params = genAI!!.createGeneratorParams()
        params.setSearchOption("max_length", maxTokens.toDouble())
        params.setSearchOption("temperature", temperature)
        params.setSearchOption("top_p", topP)

        return genAI!!.generate(params, prompt, null)
    }

    @Throws(GenAIException::class)
    private suspend fun generateStream(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
    ) {
        if (!modelLoaded || genAI == null) throw Exception("Model not loaded")

        val params = genAI!!.createGeneratorParams()
        params.setSearchOption("max_length", maxTokens.toDouble())
        params.setSearchOption("temperature", temperature)
        params.setSearchOption("top_p", topP)

        // SimpleGenAI.generate with a Consumer<String> listener streams
        // tokens one at a time via the callback.
        genAI!!.generate(params, prompt) { token ->
            if (generationJob?.isCancelled == true) return@generate
            runBlocking(Dispatchers.Main) {
                eventSink?.success(token)
            }
        }

        withContext(Dispatchers.Main) {
            eventSink?.endOfStream()
        }
    }

    private fun unloadModel() {
        genAI?.close()
        genAI = null
        modelLoaded = false
    }

    fun dispose() {
        scope.cancel()
        unloadModel()
    }
}
