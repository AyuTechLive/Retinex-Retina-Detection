import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';

class Home extends StatefulWidget {
  const Home({Key? key}) : super(key: key);

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  List? _recognitions;
  String _result = '';
  bool _modelLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/optimized_Model.tflite",
        labels: "assets/labels.txt", // Make sure you have this file
        numThreads: 1,
        isAsset: true,
        useGpuDelegate: false,
      );
      setState(() {
        _modelLoaded = true;
        _result = 'Model loaded successfully';
      });
    } catch (e) {
      setState(() {
        _result = 'Failed to load model: $e';
      });
    }
  }

  Future<void> _getImage() async {
    if (!_modelLoaded) {
      setState(() {
        _result = 'Model not loaded. Please wait or restart the app.';
      });
      return;
    }

    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _result = 'Processing image...';
      });
      await _classifyImage();
    }
  }

  Future<void> _classifyImage() async {
    if (_image == null) return;

    try {
      var recognitions = await Tflite.runModelOnImage(
        path: _image!.path,
        imageMean: 0.0, // Use 127.5 if your model requires 0-255 input range
        imageStd: 255.0, // Use 127.5 if your model requires 0-255 input range
        numResults: 2, // Change this based on your model's output
        threshold: 0.1, // Adjust this threshold as needed
      );

      setState(() {
        _recognitions = recognitions;
        if (_recognitions != null && _recognitions!.isNotEmpty) {
          var topResult = _recognitions![0];
          _result = 'Predicted: ${topResult['label']}\n'
              'Confidence: ${(topResult['confidence'] * 100).toStringAsFixed(2)}%';
        } else {
          _result = 'No predictions';
        }
      });
    } catch (e) {
      setState(() {
        _result = 'Error classifying image: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screensize = MediaQuery.of(context).size;
    final double height = screensize.height;
    final double width = screensize.width;
    return Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: width,
            height: height * 0.4,
            child: ClipRRect(
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Image.asset('assets/bg1.png'),
            ),
          ),
          IconButton(
            onPressed: _getImage,
            icon: Image.asset(
              'assets/imgup.png',
              scale: 5,
            ),
          ),
          SizedBox(height: 20),
          Text(_result,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  void dispose() {
    Tflite.close();
    super.dispose();
  }
}
