package com.example.dailycue

import android.content.Context
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
    private val eventChannel = EventChannel(
        flutterEngine.dartExecutor.binaryMessenger,
        "com.dailycue/onnx_inference_stream"
    )

    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var eventSink: EventChannel.EventSink? = null
    private var generationJob: Job? = null

    // ONNX Runtime GenAI objects — loaded dynamically
    private var modelLoaded = false
    private var modelPath: String? = null

    // Placeholder references for ONNX Runtime GenAI objects.
    // In a full build these would be:
    //   private var model: OgaModel? = null
    //   private var tokenizer: OgaTokenizer? = null
    // For now we use Any? to allow compilation without the AAR.
    private var model: Any? = null
    private var tokenizer: Any? = null

    init {
        methodChannel.setMethodCallHandler(this)
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
                        // Generation was stopped
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

            else -> result.notImplemented()
        }
    }

    private fun loadModel(path: String) {
        val dir = File(path)
        if (!dir.exists() || !dir.isDirectory) {
            throw Exception("Model directory not found: $path")
        }

        // When ONNX Runtime GenAI AAR is added, this becomes:
        // model = OgaModel(path)
        // tokenizer = OgaTokenizer(model)
        //
        // For now, validate that the required files exist.
        val requiredFiles = listOf("genai_config.json", "tokenizer.json")
        for (fileName in requiredFiles) {
            if (!File(dir, fileName).exists()) {
                throw Exception("Missing required model file: $fileName")
            }
        }

        modelPath = path
        modelLoaded = true
    }

    private fun generate(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
    ): String {
        if (!modelLoaded) throw Exception("Model not loaded")

        // When ONNX Runtime GenAI AAR is added, this becomes:
        // val params = OgaGeneratorParams(model)
        // params.setSearchOption("max_length", maxTokens.toDouble())
        // params.setSearchOption("temperature", temperature)
        // params.setSearchOption("top_p", topP)
        //
        // val sequences = tokenizer!!.encode(prompt)
        // params.setInputSequences(sequences)
        //
        // val output = model!!.generate(params)
        // val response = tokenizer!!.decode(output.getSequence(0))
        // return response

        // Stub: return empty until ONNX Runtime GenAI is linked
        return "[Model inference requires ONNX Runtime GenAI library]"
    }

    private suspend fun generateStream(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
    ) {
        if (!modelLoaded) throw Exception("Model not loaded")

        // When ONNX Runtime GenAI AAR is added, this becomes:
        // val params = OgaGeneratorParams(model)
        // params.setSearchOption("max_length", maxTokens.toDouble())
        // params.setSearchOption("temperature", temperature)
        // params.setSearchOption("top_p", topP)
        //
        // val sequences = tokenizer!!.encode(prompt)
        // params.setInputSequences(sequences)
        //
        // val generator = OgaGenerator(model, params)
        // val stream = OgaTokenizerStream(tokenizer)
        //
        // while (!generator.isDone) {
        //     ensureActive()
        //     generator.computeLogits()
        //     generator.generateNextToken()
        //     val token = generator.getLastTokenInSequence(0)
        //     val text = stream.decode(token)
        //     withContext(Dispatchers.Main) {
        //         eventSink?.success(text)
        //     }
        // }

        // Stub: send placeholder token
        withContext(Dispatchers.Main) {
            eventSink?.success("[Model streaming requires ONNX Runtime GenAI library]")
            eventSink?.endOfStream()
        }
    }

    private fun unloadModel() {
        // When ONNX Runtime GenAI AAR is added:
        // model?.close()
        // tokenizer?.close()
        model = null
        tokenizer = null
        modelLoaded = false
        modelPath = null
    }

    fun dispose() {
        scope.cancel()
        unloadModel()
    }
}
