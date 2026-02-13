package com.example.dailycue

import android.content.Context
import ai.onnxruntime.genai.Generator
import ai.onnxruntime.genai.GeneratorParams
import ai.onnxruntime.genai.Model
import ai.onnxruntime.genai.Tokenizer
import ai.onnxruntime.genai.TokenizerStream
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

    private var modelLoaded = false
    private var modelPath: String? = null
    private var model: Model? = null
    private var tokenizer: Tokenizer? = null

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

        val requiredFiles = listOf("genai_config.json", "tokenizer.json")
        for (fileName in requiredFiles) {
            if (!File(dir, fileName).exists()) {
                throw Exception("Missing required model file: $fileName")
            }
        }

        model = Model(path)
        tokenizer = Tokenizer(model)

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

        val params = GeneratorParams(model)
        params.setSearchOption("max_length", maxTokens.toDouble())
        params.setSearchOption("temperature", temperature)
        params.setSearchOption("top_p", topP)

        val sequences = tokenizer!!.encode(prompt)
        params.setInputSequences(sequences)

        val output = model!!.generate(params)
        val response = tokenizer!!.decode(output.getSequence(0))

        output.close()
        params.close()

        return response
    }

    private suspend fun generateStream(
        prompt: String,
        maxTokens: Int,
        temperature: Double,
        topP: Double,
    ) {
        if (!modelLoaded) throw Exception("Model not loaded")

        val params = GeneratorParams(model)
        params.setSearchOption("max_length", maxTokens.toDouble())
        params.setSearchOption("temperature", temperature)
        params.setSearchOption("top_p", topP)

        val sequences = tokenizer!!.encode(prompt)
        params.setInputSequences(sequences)

        val generator = Generator(model, params)
        val stream = TokenizerStream(tokenizer)

        try {
            while (!generator.isDone) {
                ensureActive()
                generator.computeLogits()
                generator.generateNextToken()
                val token = generator.getLastTokenInSequence(0)
                val text = stream.decode(token)
                withContext(Dispatchers.Main) {
                    eventSink?.success(text)
                }
            }
            withContext(Dispatchers.Main) {
                eventSink?.endOfStream()
            }
        } finally {
            stream.close()
            generator.close()
            params.close()
        }
    }

    private fun unloadModel() {
        tokenizer?.close()
        model?.close()
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
