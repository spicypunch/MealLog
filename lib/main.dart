
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Log',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isProcessing = false;
  List<File> _mealImages = [];

  @override
  void initState() {
    super.initState();
    _loadMealImages();
  }

  Future<Directory> _getMealLogDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final mealLogDir = Directory('${appDir.path}/MealLog');
    if (!await mealLogDir.exists()) {
      await mealLogDir.create(recursive: true);
    }
    return mealLogDir;
  }

  Future<void> _loadMealImages() async {
    try {
      final mealLogDir = await _getMealLogDirectory();
      final files = await mealLogDir.list().toList();
      final imageFiles = files
          .whereType<File>()
          .where((file) => file.path.toLowerCase().endsWith('.jpg'))
          .toList();
      
      imageFiles.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      
      setState(() {
        _mealImages = imageFiles;
      });
    } catch (e) {
      debugPrint('Error loading meal images: $e');
    }
  }

  String _extractFoodNameFromFile(File file) {
    try {
      final fileName = file.path.split('/').last;
      final parts = fileName.split('_');
      if (parts.length >= 3) {
        // meal_timestamp_encodedFoodName.jpg 형식
        final encodedFoodName = parts[2].replaceAll('.jpg', '');
        return Uri.decodeComponent(encodedFoodName);
      }
    } catch (e) {
      debugPrint('Error extracting food name: $e');
    }
    return '음식'; // 기본값
  }
  
  Future<Uint8List> _createSingleTextWatermark(String text, int imageWidth, int imageHeight, bool isFoodName) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: isFoodName ? imageWidth * 0.05 : imageWidth * 0.06,
      fontWeight: isFoodName ? FontWeight.bold : FontWeight.bold,
      shadows: [
        Shadow(
          offset: const Offset(2, 2),
          blurRadius: 4,
          color: Colors.black,
        ),
      ],
    );
    
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();
    
    // 투명한 배경 - 패딩만 적용
    textPainter.paint(canvas, const Offset(16, 16));
    
    final picture = recorder.endRecording();
    final img = await picture.toImage(
      (textPainter.width + 32).toInt(), 
      (textPainter.height + 32).toInt()
    );
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    
    return byteData!.buffer.asUint8List();
  }

  Future<String> _showFoodNameDialog() async {
    final TextEditingController controller = TextEditingController();
    String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('음식 이름을 입력해주세요'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop('음식'),
              child: const Text('건너뛰기'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(context).pop(text.isEmpty ? '음식' : text);
              },
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
    return result ?? '음식';
  }

  Future<bool> _requestStoragePermission() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    if (deviceInfo.version.sdkInt >= 33) {
      return await Permission.photos.request().isGranted;
    } else {
      return await Permission.storage.request().isGranted;
    }
  }

  Future<void> _takePicture() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Camera permission is required.')),
        );
      }
      return;
    }

    final hasStoragePermission = await _requestStoragePermission();
    if (hasStoragePermission) {
      final imagePicker = ImagePicker();
      final pickedFile = await imagePicker.pickImage(source: ImageSource.camera);

      if (pickedFile != null) {
        try {
          final now = DateTime.now();
          final formattedDate = DateFormat('yy년 M월 d일 h:mm a', 'ko_KR').format(now);

          // 다이얼로그를 먼저 표시 (프로그레스 바 전에)
          final foodName = await _showFoodNameDialog();
          
          // 다이얼로그가 끝난 후 프로그레스 바 표시
          setState(() {
            _isProcessing = true;
          });

          final imageBytes = await pickedFile.readAsBytes();
          final originalImage = img.decodeImage(imageBytes);

          if (originalImage != null) {
            
            final imageWidth = originalImage.width;
            final imageHeight = originalImage.height;
            
            final foodNameWatermarkBytes = await _createSingleTextWatermark(foodName, imageWidth, imageHeight, true);
            final foodNameWatermarkImage = img.decodePng(foodNameWatermarkBytes);
            
            final dateWatermarkBytes = await _createSingleTextWatermark(formattedDate, imageWidth, imageHeight, false);
            final dateWatermarkImage = img.decodePng(dateWatermarkBytes);
            
            if (foodNameWatermarkImage != null) {
              img.compositeImage(
                originalImage,
                foodNameWatermarkImage,
                dstX: 16,
                dstY: 16,
              );
            }
            
            if (dateWatermarkImage != null) {
              img.compositeImage(
                originalImage,
                dateWatermarkImage,
                dstX: 16,
                dstY: imageHeight - dateWatermarkImage.height - 16,
              );
            }

            final modifiedImageBytes = Uint8List.fromList(img.encodeJpg(originalImage));

            final mealLogDir = await _getMealLogDirectory();
            final timestamp = DateTime.now().millisecondsSinceEpoch;
            final encodedFoodName = Uri.encodeComponent(foodName);
            final fileName = 'meal_${timestamp}_$encodedFoodName.jpg';
            final file = File('${mealLogDir.path}/$fileName');
            await file.writeAsBytes(modifiedImageBytes);

            await ImageGallerySaverPlus.saveImage(
              modifiedImageBytes,
              quality: 95,
              name: "meal_log_$timestamp",
            );

            await _loadMealImages();

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('사진이 저장되었습니다!')),
              );
            }

          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('오류가 발생했습니다: $e')),
            );
          }
        } finally {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Permission Required'),
            content: const Text('Storage/Photo permission is required to save photos. Please enable it in app settings.'),
            actions: <Widget>[
              TextButton(
                child: const Text('Cancel'),
                onPressed: () => Navigator.of(context).pop(),
              ),
              TextButton(
                child: const Text('Open Settings'),
                onPressed: () {
                  openAppSettings();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Log'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _mealImages.isEmpty
              ? const Center(
                  child: Text(
                    '아직 저장된 사진이 없습니다.\n아래 카메라 버튼을 눌러 첫 번째 식사를 기록해보세요!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(8.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 8.0,
                    mainAxisSpacing: 8.0,
                    childAspectRatio: 0.8, // 텍스트 공간을 위해 세로를 더 길게
                  ),
                  itemCount: _mealImages.length,
                  itemBuilder: (context, index) {
                    final imageFile = _mealImages[index];
                    final foodName = _extractFoodNameFromFile(imageFile);
                    return Card(
                      elevation: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                              child: Image.file(
                                imageFile,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              foodName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '사진 처리 중...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isProcessing ? null : _takePicture,
        tooltip: 'Take Picture',
        backgroundColor: _isProcessing ? Colors.grey : Colors.green,
        child: const Icon(Icons.camera_alt, color: Colors.white),
      ),
    );
  }
}
