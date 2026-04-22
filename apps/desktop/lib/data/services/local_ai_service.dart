import 'dart:io';
import 'dart:convert';
import 'dart:developer';

class LocalAiService {
  final String _host = '127.0.0.1';
  final int _port = 8765;

  /// Internal helper to send commands to the Python sidecar
  Future<Map<String, dynamic>?> _sendCommand(String cmd, [Map<String, dynamic>? extras]) async {
    try {
      final socket = await Socket.connect(_host, _port);

      final Map<String, dynamic> payload = {"command": cmd};
      if (extras != null) {
        payload.addAll(extras);
      }

      socket.write(jsonEncode(payload));

      // Wait for the response and decode it
      final responseString = await socket.cast<List<int>>().transform(utf8.decoder).join();
      socket.destroy();

      log("Raw backend response: $responseString", name: 'LocalAiService');

      return jsonDecode(responseString);
    } catch (e) {
      log("AI Socket communication error: $e", name: 'LocalAiService');
      return null;
    }
  }

  /// Checks if the Llama model was successfully loaded by the Python script
  Future<bool> checkAiStatus() async {
    final response = await _sendCommand("status");

    if (response != null && response['status'] == 'success') {
      log(response['message'], name: 'LocalAiService');
      return true;
    } else {
      log(response?['message'] ?? "Failed to connect to AI Engine.", name: 'LocalAiService');
      return false;
    }
  }

  /// Sends a prompt to the Gemma model and returns the response
  Future<String> generateResponse(String userPrompt) async {
    log("Sending prompt to AI: $userPrompt", name: 'LocalAiService');

    final response = await _sendCommand("generate", {"prompt": userPrompt});

    if (response != null && response['status'] == 'success') {
      log("AI Generated Response: ${response['response']}", name: 'LocalAiService');
      return response['response'];
    } else {
      log("AI Generation Error Payload: $response", name: 'LocalAiService');
      return "Error: Could not generate a response. Please check if the model is loaded.";
    }
  }
}
