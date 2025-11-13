import 'dart:io';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class VoiceRecorderService {
  static final VoiceRecorderService _instance = VoiceRecorderService._internal();
  factory VoiceRecorderService() => _instance;
  VoiceRecorderService._internal() {
    _initRecorder();
  }

  FlutterSoundRecorder? _recorder;
  final AudioPlayer _player = AudioPlayer();
  
  bool _isRecording = false;
  bool _isPlaying = false;
  String? _currentRecordingPath;
  Duration _recordingDuration = Duration.zero;

  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  Duration get recordingDuration => _recordingDuration;

  // Initialize the recorder
  Future<void> _initRecorder() async {
    _recorder = FlutterSoundRecorder();
    await _recorder!.openRecorder();
  }

  // Check and request microphone permission
  Future<bool> checkPermissions() async {
    final status = await Permission.microphone.status;
    if (status != PermissionStatus.granted) {
      final result = await Permission.microphone.request();
      return result == PermissionStatus.granted;
    }
    return true;
  }

  // Start recording
  Future<bool> startRecording() async {
    try {
      if (_recorder == null) {
        await _initRecorder();
      }
      
      if (!await checkPermissions()) {
        return false;
      }

      // Get application documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/voice_messages');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${recordingsDir.path}/voice_message_$timestamp.aac';

      // Start recording
      await _recorder!.startRecorder(
        toFile: _currentRecordingPath,
        codec: Codec.aacADTS,
      );
      _isRecording = true;
      _recordingDuration = Duration.zero;
      
      return true;
    } catch (e) {
      print('Error starting recording: $e');
      return false;
    }
  }

  // Stop recording and return file path
  Future<String?> stopRecording() async {
    try {
      if (!_isRecording || _recorder == null) return null;

      await _recorder!.stopRecorder();
      _isRecording = false;
      
      if (_currentRecordingPath != null && await File(_currentRecordingPath!).exists()) {
        return _currentRecordingPath;
      }
      return null;
    } catch (e) {
      print('Error stopping recording: $e');
      _isRecording = false;
      return null;
    }
  }

  // Cancel recording
  Future<void> cancelRecording() async {
    try {
      if (_isRecording && _recorder != null) {
        await _recorder!.stopRecorder();
        _isRecording = false;
        
        // Delete the file if it exists
        if (_currentRecordingPath != null) {
          final file = File(_currentRecordingPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      print('Error canceling recording: $e');
    }
  }

  // Play voice message
  Future<bool> playVoiceMessage(String filePath) async {
    try {
      if (_isPlaying) {
        await _player.stop();
      }

      await _player.setFilePath(filePath);
      await _player.play();
      _isPlaying = true;
      
      // Listen for completion
      _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });
      
      return true;
    } catch (e) {
      print('Error playing voice message: $e');
      _isPlaying = false;
      return false;
    }
  }

  // Pause voice message
  Future<void> pauseVoiceMessage() async {
    try {
      await _player.pause();
      _isPlaying = false;
    } catch (e) {
      print('Error pausing voice message: $e');
    }
  }

  // Resume voice message
  Future<void> resumeVoiceMessage() async {
    try {
      await _player.play();
      _isPlaying = true;
    } catch (e) {
      print('Error resuming voice message: $e');
    }
  }

  // Stop voice message
  Future<void> stopVoiceMessage() async {
    try {
      await _player.stop();
      _isPlaying = false;
    } catch (e) {
      print('Error stopping voice message: $e');
    }
  }

  // Get audio duration
  Future<Duration?> getAudioDuration(String filePath) async {
    try {
      await _player.setFilePath(filePath);
      return _player.duration;
    } catch (e) {
      print('Error getting audio duration: $e');
      return null;
    }
  }

  // Get current playback position
  Stream<Duration> get positionStream => _player.positionStream;

  // Get current playback duration
  Duration? get duration => _player.duration;

  // Get current playback position
  Duration get position => _player.position;

  // Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  // Dispose resources
  void dispose() {
    _recorder?.closeRecorder();
    _player.dispose();
  }
}