Place the ONNX Runtime GenAI Android AAR file in this directory.

Download from:
https://github.com/microsoft/onnxruntime-genai/releases

Look for: onnxruntime-genai-android-X.Y.Z.aar

Then rename it to: onnxruntime-genai.aar

The build.gradle.kts references this file as:
  implementation(files("libs/onnxruntime-genai.aar"))
