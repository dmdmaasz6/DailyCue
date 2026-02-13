import Flutter
import Foundation

public class OnnxInferencePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var eventSink: FlutterEventSink?
    private var generationTask: DispatchWorkItem?

    private let inferenceQueue = DispatchQueue(
        label: "com.dailycue.onnx_inference",
        qos: .userInitiated
    )

    // ONNX Runtime GenAI objects — loaded dynamically.
    // In a full build with the onnxruntime-genai pod, these would be typed:
    //   private var model: OgaModel?
    //   private var tokenizer: OgaTokenizer?
    private var model: AnyObject?
    private var tokenizer: AnyObject?
    private var modelLoaded = false
    private var modelPath: String?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = OnnxInferencePlugin()
        let methodChannel = FlutterMethodChannel(
            name: "com.dailycue/onnx_inference",
            binaryMessenger: registrar.messenger()
        )
        let eventChannel = FlutterEventChannel(
            name: "com.dailycue/onnx_inference_stream",
            binaryMessenger: registrar.messenger()
        )

        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - FlutterPlugin

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any]

        switch call.method {
        case "loadModel":
            guard let path = args?["modelPath"] as? String else {
                result(FlutterError(code: "INVALID_ARG", message: "modelPath is required", details: nil))
                return
            }
            inferenceQueue.async { [weak self] in
                do {
                    try self?.loadModel(path: path)
                    DispatchQueue.main.async { result(true) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "LOAD_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "generate":
            let prompt = args?["prompt"] as? String ?? ""
            let maxTokens = args?["maxTokens"] as? Int ?? 512
            let temperature = args?["temperature"] as? Double ?? 0.7
            let topP = args?["topP"] as? Double ?? 0.9

            inferenceQueue.async { [weak self] in
                do {
                    let response = try self?.generate(
                        prompt: prompt,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        topP: topP
                    ) ?? ""
                    DispatchQueue.main.async { result(response) }
                } catch {
                    DispatchQueue.main.async {
                        result(FlutterError(code: "GENERATE_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }

        case "startGeneration":
            let prompt = args?["prompt"] as? String ?? ""
            let maxTokens = args?["maxTokens"] as? Int ?? 512
            let temperature = args?["temperature"] as? Double ?? 0.7
            let topP = args?["topP"] as? Double ?? 0.9

            let task = DispatchWorkItem { [weak self] in
                do {
                    try self?.generateStream(
                        prompt: prompt,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        topP: topP
                    )
                } catch {
                    DispatchQueue.main.async {
                        self?.eventSink?(FlutterError(code: "STREAM_FAILED", message: error.localizedDescription, details: nil))
                    }
                }
            }
            generationTask = task
            inferenceQueue.async(execute: task)
            result(nil)

        case "stopGeneration":
            generationTask?.cancel()
            generationTask = nil
            result(nil)

        case "unloadModel":
            unloadModel()
            result(nil)

        case "isModelLoaded":
            result(modelLoaded)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - FlutterStreamHandler

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        generationTask?.cancel()
        return nil
    }

    // MARK: - Model Operations

    private func loadModel(path: String) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: path) else {
            throw NSError(domain: "OnnxInference", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Model directory not found: \(path)"
            ])
        }

        // When onnxruntime-genai pod is added, this becomes:
        // model = try OgaModel(path)
        // tokenizer = try OgaTokenizer(model!)

        let requiredFiles = ["genai_config.json", "tokenizer.json"]
        for fileName in requiredFiles {
            let filePath = (path as NSString).appendingPathComponent(fileName)
            guard fileManager.fileExists(atPath: filePath) else {
                throw NSError(domain: "OnnxInference", code: 2, userInfo: [
                    NSLocalizedDescriptionKey: "Missing required model file: \(fileName)"
                ])
            }
        }

        modelPath = path
        modelLoaded = true
    }

    private func generate(prompt: String, maxTokens: Int, temperature: Double, topP: Double) throws -> String {
        guard modelLoaded else {
            throw NSError(domain: "OnnxInference", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Model not loaded"
            ])
        }

        // When onnxruntime-genai pod is added, this becomes:
        // let params = try OgaGeneratorParams(model!)
        // try params.setSearchOption("max_length", value: Double(maxTokens))
        // try params.setSearchOption("temperature", value: temperature)
        // try params.setSearchOption("top_p", value: topP)
        //
        // let sequences = try tokenizer!.encode(prompt)
        // try params.setInputSequences(sequences)
        //
        // let output = try model!.generate(params)
        // return try tokenizer!.decode(output.getSequence(0))

        return "[Model inference requires ONNX Runtime GenAI framework]"
    }

    private func generateStream(prompt: String, maxTokens: Int, temperature: Double, topP: Double) throws {
        guard modelLoaded else {
            throw NSError(domain: "OnnxInference", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Model not loaded"
            ])
        }

        // When onnxruntime-genai pod is added, this becomes:
        // let params = try OgaGeneratorParams(model!)
        // try params.setSearchOption("max_length", value: Double(maxTokens))
        // try params.setSearchOption("temperature", value: temperature)
        // try params.setSearchOption("top_p", value: topP)
        //
        // let sequences = try tokenizer!.encode(prompt)
        // try params.setInputSequences(sequences)
        //
        // let generator = try OgaGenerator(model!, params)
        // let stream = try OgaTokenizerStream(tokenizer!)
        //
        // while !generator.isDone() {
        //     if generationTask?.isCancelled == true { break }
        //     try generator.computeLogits()
        //     try generator.generateNextToken()
        //     let token = generator.getLastTokenInSequence(0)
        //     let text = try stream.decode(token)
        //     DispatchQueue.main.async { [weak self] in
        //         self?.eventSink?(text)
        //     }
        // }

        DispatchQueue.main.async { [weak self] in
            self?.eventSink?("[Model streaming requires ONNX Runtime GenAI framework]")
            self?.eventSink?(FlutterEndOfEventStream)
        }
    }

    private func unloadModel() {
        // When onnxruntime-genai pod is added:
        // model = nil
        // tokenizer = nil
        model = nil
        tokenizer = nil
        modelLoaded = false
        modelPath = nil
    }
}
