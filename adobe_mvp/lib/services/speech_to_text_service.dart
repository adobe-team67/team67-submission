import 'package:speech_to_text/speech_to_text.dart';

/// Service class to handle speech-to-text functionality
class SpeechToTextService {
  final SpeechToText _speechToText = SpeechToText();
  bool _isInitialized = false;
  String? _lastError;

  /// Check if the service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if speech recognition is available on the device
  bool get isAvailable => _speechToText.isAvailable;
  
  /// Get the last error message
  String get lastError => _lastError ?? 'Speech recognition not available. Check microphone permission or try on a real device.';

  /// Initialize the speech recognition service
  Future<bool> initialize() async {
    if (_isInitialized) {
      return true;
    }

    try {
      _isInitialized = await _speechToText.initialize(
        onError: (error) {
          _lastError = error.errorMsg;
        },
        onStatus: (status) {},
        debugLogging: false,
      );
      
      if (!_isInitialized) {
        _lastError = 'Speech recognition not available. This may be because:\n'
            '• Microphone permission was denied\n'
            '• No speech recognizer is installed (common on emulators)\n'
            '• Google Play Services is not available';
      }
      
      return _isInitialized;
    } catch (e) {
      _lastError = 'Failed to initialize: $e';
      return false;
    }
  }

  /// Start listening for speech input
  /// [onResult] - Callback function that receives the recognized text
  /// [onComplete] - Optional callback when listening completes
  /// [onError] - Optional callback when an error occurs
  Future<void> startListening({
    required Function(String) onResult,
    Function()? onComplete,
    Function(String)? onError,
  }) async {
    if (!_isInitialized) {
      onError?.call('Speech recognition not initialized');
      return;
    }

    if (_speechToText.isListening) {
      return;
    }

    // Clear any previous error
    _lastError = null;

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }

          if (result.finalResult) {
            stopListening();
            if (result.recognizedWords.isEmpty) {
              onError?.call('No speech detected. Please speak clearly.');
            }
            onComplete?.call();
          }
        },
        listenFor: const Duration(seconds: 30), // Longer listening time
        pauseFor: const Duration(seconds: 3), // Standard pause duration
        partialResults: true,
        listenMode: ListenMode.dictation, // Better for longer phrases
        localeId: 'en_US', // Explicitly set locale
        onDevice: false, // Use cloud recognition for better accuracy
      );
    } catch (e) {
      _lastError = 'Error starting speech recognition: $e';
      onError?.call(_lastError!);
    }
  }

  /// Stop listening for speech input
  Future<void> stopListening() async {
    if (_speechToText.isListening) {
      await _speechToText.stop();
    }
  }

  /// Cancel the current speech recognition session
  Future<void> cancel() async {
    if (_speechToText.isListening) {
      await _speechToText.cancel();
    }
  }

  /// Check if currently listening
  bool get isListening => _speechToText.isListening;

  /// Dispose of resources
  void dispose() {
    _speechToText.cancel();
  }
}
