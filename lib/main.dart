import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_tts/flutter_tts.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MaterialApp(
    theme: ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
    ),
    home: TextRecognitionApp(cameras: cameras),
    debugShowCheckedModeBanner: false,
  ));
}

class TextRecognitionApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const TextRecognitionApp({Key? key, required this.cameras}) : super(key: key);

  @override
  State<TextRecognitionApp> createState() => _TextRecognitionAppState();
}

class _TextRecognitionAppState extends State<TextRecognitionApp> {
  late CameraController _controller;
  File? _image;
  String _extractedText = '';
  bool _isDetecting = false;
  Size _imageSize = Size.zero;

  late final TextRecognizer _textRecognizer;
  FlutterTts? _flutterTts;

  @override
  void initState() {
    super.initState();
    _initializeCamera(widget.cameras.first);
    _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    _flutterTts = FlutterTts();
    _flutterTts!.setLanguage("pt-BR");
    _flutterTts!.setSpeechRate(0.5);
  }

  Future<void> _initializeCamera(CameraDescription camera) async {
    _controller = CameraController(camera, ResolutionPreset.high);
    await _controller.initialize();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _image = File(image.path);
        _extractedText = '';
      });
      _processImage();
    }
  }

  Future<void> _captureImage() async {
    if (!_controller.value.isInitialized) return;
    final picture = await _controller.takePicture();
    setState(() {
      _image = File(picture.path);
      _extractedText = '';
    });
    _processImage();
  }

  Future<void> _processImage() async {
    if (_image == null) return;
    setState(() => _isDetecting = true);

    final inputImage = InputImage.fromFilePath(_image!.path);
    final bytes = await _image!.readAsBytes();
    final decoded = await decodeImageFromList(bytes);
    _imageSize = Size(decoded.width.toDouble(), decoded.height.toDouble());

    final result = await _textRecognizer.processImage(inputImage);
    setState(() {
      _extractedText = result.text;
      _isDetecting = false;
    });

    if (_extractedText.isNotEmpty) {
      await _speakText();
    }
  }

  Future<void> _speakText() async {
    if (_flutterTts != null && _extractedText.isNotEmpty) {
      await _flutterTts!.speak(_extractedText);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    _flutterTts?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Reconhecimento de Texto')),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _image == null ? _buildCameraPreview() : Image.file(_image!),
          ),
          Expanded(
            flex: 2,
            child: _isDetecting
                ? const Center(child: CircularProgressIndicator())
                : _buildTextResults(),
          ),
        ],
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'gallery',
            onPressed: _pickImage,
            child: const Icon(Icons.photo_library),
          ),
          const SizedBox(width: 16),
          FloatingActionButton(
            heroTag: 'camera',
            onPressed: _captureImage,
            child: const Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: _controller.value.aspectRatio,
        child: CameraPreview(_controller),
      ),
    );
  }

  Widget _buildTextResults() {
    if (_extractedText.isEmpty) {
      return const Center(child: Text('Nenhum texto detectado', style: TextStyle(fontSize: 18)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Text(_extractedText, style: const TextStyle(fontSize: 16)),
    );
  }
}
