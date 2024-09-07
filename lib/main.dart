import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_v2/tflite_v2.dart';
import 'package:image/image.dart' as img;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retinal Diagnostic',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ImagePickerDemo(),
    );
  }
}

class ImagePickerDemo extends StatefulWidget {
  @override
  _ImagePickerDemoState createState() => _ImagePickerDemoState();
}

class _ImagePickerDemoState extends State<ImagePickerDemo> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;
  String result = "";
  String probability1 = "";
  String probability2 = "";
  bool _isAnalyzing = false;

  @override
  void initState() {
    super.initState();
    loadModel().then((value) {
      setState(() {});
    });
  }

  Future<void> loadModel() async {
    try {
      await Tflite.loadModel(
        model: "assets/optimized_Model.tflite",
        labels: "assets/labels.txt",
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error loading model: $e');
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      setState(() {
        _image = image;
        result = "";
        probability1 = "";
        probability2 = "";
      });

      detectImage(File(_image!.path));
    } catch (e) {
      if (kDebugMode) {
        print('Error picking image: $e');
      }
    }
  }

  Future<void> detectImage(File image) async {
    setState(() {
      _isAnalyzing = true;
    });

    try {
      img.Image? decodedImage = img.decodeImage(image.readAsBytesSync());
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      img.Image resizedImage =
          img.copyResize(decodedImage, width: 256, height: 256);

      var resizedImageBytes = img.encodeJpg(resizedImage);
      if (resizedImageBytes is! Uint8List) {
        resizedImageBytes = Uint8List.fromList(resizedImageBytes);
      }

      final tempDir = Directory.systemTemp;
      final tempFile = File('${tempDir.path}/resized_image.jpg');
      await tempFile.writeAsBytes(resizedImageBytes);

      var recognitions = await Tflite.runModelOnImage(
        path: tempFile.path,
        imageMean: 0.0,
        imageStd: 255.0,
        numResults: 2,
        threshold: 0.5,
        asynch: true,
      );

      setState(() {
        if (recognitions != null && recognitions.isNotEmpty) {
          String label = recognitions[0]['label'].toString();
          double confidence = recognitions[0]['confidence'];

          result = label == "RD"
              ? "Retinal Detachment Detected"
              : "No Retinal Detachment Detected";
          probability1 = 'Confidence RD: ${confidence.toStringAsFixed(2)}';
          probability2 =
              'Confidence Non-RD: ${(1 - confidence).toStringAsFixed(2)}';
        } else {
          result = 'No result';
          probability1 = '';
          probability2 = '';
        }
        _isAnalyzing = false;
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error running model: $e');
      }
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 40),
              Text(
                'Retinal Diagnostic',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'Upload Retinal Image',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Upload a retinal image'),
                      Icon(Icons.arrow_forward_ios),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Text(
                'Analysis',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text('We will analyze the image within seconds.'),
              SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _image != null && !_isAnalyzing
                          ? () => detectImage(File(_image!.path))
                          : null,
                      child: Text(
                        'Start analysis',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _image = null;
                          result = "";
                          probability1 = "";
                          probability2 = "";
                        });
                      },
                      child: Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              if (_image != null || result.isNotEmpty)
                Text(
                  'Result',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              if (_image != null)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_image!.path),
                      height: 200,
                      width: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              if (result.isNotEmpty)
                Container(
                  margin: EdgeInsets.only(top: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (result == "Retinal Detachment Detected")
                        SizedBox(height: 5),
                      // Text(probability1),
                      // Text(probability2),
                      SizedBox(height: 10),
                      Text(
                        'Note: this is for diagnostic purposes only. Consult your doctor for medical advice.',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              if (_isAnalyzing)
                Container(
                  margin: EdgeInsets.only(top: 20),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
