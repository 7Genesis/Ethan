import 'dart:convert';

import 'package:http/http.dart' as http;

const String ollamaBaseUrl = String.fromEnvironment(
  'OLLAMA_BASE_URL',
  defaultValue: 'http://localhost:11434',
);

class AiSupportService {
  final http.Client _client;

  AiSupportService({http.Client? client}) : _client = client ?? http.Client();

  Future<String> askSupportAI(String message) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return 'Descreva sua dúvida para eu ajudar.';
    }

    final prompt =
        '''
Você é assistente de suporte do Projeto Ethan.
Responda de forma objetiva e prática em português.
Temas: criar cotação, enviar proposta, completar cadastro, alterar dados, suporte, XML fiscal.
Se o usuário pedir atendimento humano, oriente abrir chamado.

Pergunta do usuário:
$trimmed
''';

    try {
      final response = await _client
          .post(
            Uri.parse('$ollamaBaseUrl/api/generate'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'llama3.1',
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return _unavailableMessage;
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return _unavailableMessage;
      }

      final raw = (decoded['response'] ?? '').toString().trim();
      if (raw.isEmpty) {
        return _unavailableMessage;
      }

      return raw;
    } catch (_) {
      return _unavailableMessage;
    }
  }

  static const String _unavailableMessage =
      'Assistente indisponível no momento. Você pode abrir um chamado de suporte.';
}
