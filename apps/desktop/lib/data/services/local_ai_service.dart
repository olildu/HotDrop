import 'dart:io';
import 'dart:convert';
import 'dart:developer' as dev;

class LocalAiService {
  final String _host = '127.0.0.1';
  final int _port = 8765;

  void _log(String functionName, String message, {Object? error, StackTrace? stackTrace}) {
    dev.log(message, name: functionName, error: error, stackTrace: stackTrace);
  }

  /// Internal helper to send commands to the Python sidecar
  Future<Map<String, dynamic>?> _sendCommand(String cmd, [Map<String, dynamic>? extras]) async {
    _log('_sendCommand', 'Sending command: $cmd');
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

      _log('_sendCommand', 'Raw backend response received for: $cmd');

      return jsonDecode(responseString);
    } catch (e) {
      _log('_sendCommand', 'AI socket communication error', error: e);
      return null;
    }
  }

  /// Checks if the Llama model was successfully loaded by the Python script
  Future<bool> checkAiStatus() async {
    _log('checkAiStatus', 'Checking local AI service status');
    final response = await _sendCommand("status");

    if (response != null && response['status'] == 'success') {
      _log('checkAiStatus', response['message']?.toString() ?? 'AI status success');
      return true;
    } else {
      _log('checkAiStatus', response?['message']?.toString() ?? 'Failed to connect to AI Engine.');
      return false;
    }
  }

  /// Sends a prompt to the Gemma model and returns the response
  Future<String> generateResponse(String userPrompt) async {
    _log('generateResponse', 'Sending prompt to AI (${userPrompt.length} chars)');

    final response = await _sendCommand("generate", {"prompt": userPrompt});

    if (response != null && response['status'] == 'success') {
      _log('generateResponse', 'AI response generated successfully');
      return response['response'];
    } else {
      _log('generateResponse', 'AI generation failed: $response');
      return "Error: Could not generate a response. Please check if the model is loaded.";
    }
  }
}
