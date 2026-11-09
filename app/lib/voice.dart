import 'package:speech_to_text/speech_to_text.dart';

/// Speech to text through the phone's own recognizer (Android and iOS). The recognizer may use the internet to do this.
class VoiceInput {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;

  bool get listening => _speech.isListening;

  /// Asks for the microphone / speech permission the first time. False if the phone cannot or may not listen.
  Future<bool> init({void Function(String status)? onStatus, void Function(String error)? onError}) async {
    _available = await _speech.initialize(
      onStatus: onStatus,
      onError: (e) => onError?.call(e.errorMsg),
    );
    return _available;
  }

  /// Listens for one phrase. [onPartial] shows what is being heard; [onFinal] gets the finished phrase.
  Future<void> listen({required void Function(String) onPartial, required void Function(String) onFinal}) async {
    if (!_available) return;
    await _speech.listen(
      onResult: (r) {
        if (r.finalResult) {
          onFinal(r.recognizedWords);
        } else {
          onPartial(r.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 8),
        pauseFor: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> stop() => _speech.stop();
}
