import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:image/image.dart' as img;
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:meal_log/l10n/app_localizations.dart';
import 'package:meal_log/widgets/native_ad_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  await initializeDateFormatting('ko_KR');
  runApp(const MyApp());
}

class ProcessImageParams {
  final Uint8List imageBytes;
  final Uint8List? foodNameWatermarkBytes;
  final Uint8List? dateWatermarkBytes;

  ProcessImageParams({
    required this.imageBytes,
    this.foodNameWatermarkBytes,
    this.dateWatermarkBytes,
  });
}

Future<Uint8List?> processImageInIsolate(ProcessImageParams params) async {
  final originalImage = img.decodeImage(params.imageBytes);
  if (originalImage == null) return null;

  final imageWidth = originalImage.width;
  final imageHeight = originalImage.height;

  if (params.foodNameWatermarkBytes != null) {
    final foodNameWatermarkImage =
        img.decodePng(params.foodNameWatermarkBytes!);
    if (foodNameWatermarkImage != null) {
      img.compositeImage(
        originalImage,
        foodNameWatermarkImage,
        dstX: 16,
        dstY: 16,
      );
    }
  }

  if (params.dateWatermarkBytes != null) {
    final dateWatermarkImage = img.decodePng(params.dateWatermarkBytes!);
    if (dateWatermarkImage != null) {
      img.compositeImage(
        originalImage,
        dateWatermarkImage,
        dstX: 16,
        dstY: imageHeight - dateWatermarkImage.height - 16,
      );
    }
  }

  return Uint8List.fromList(img.encodeJpg(originalImage));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Meal Log',
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
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
  List<dynamic> _gridItems = []; // 사진과 광고가 섞인 리스트

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

      imageFiles
          .sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      // 랜덤하게 광고 섞기
      final List<dynamic> newGridItems = [];
      final random = Random();

      for (var imageFile in imageFiles) {
        newGridItems.add(imageFile);
        // 50% 확률로 광고 추가
        if (random.nextBool()) {
          newGridItems.add("AD");
        }
      }

      setState(() {
        _mealImages = imageFiles;
        _gridItems = newGridItems;
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
    // context를 사용할 수 없는 곳이므로 기본값 리턴.
    // 하지만 이 함수는 build 메서드 안에서 호출되거나 context를 전달받아야 함.
    // 일단 'Food'나 '음식' 대신 빈 문자열이나 코드로 처리하고 UI에서 변환하는 게 좋지만,
    // 간단하게 하기 위해 여기서는 context를 전달받도록 수정하거나,
    // 호출하는 쪽에서 처리해야 함.
    // _extractFoodNameFromFile은 UI 렌더링 시 호출되므로 context 접근 가능.
    return 'Food';
  }

  Future<Uint8List> _createSingleTextWatermark(
      String text, int imageWidth, int imageHeight, bool isFoodName) async {
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
        (textPainter.width + 32).toInt(), (textPainter.height + 32).toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  Future<String> _showFoodNameDialog() async {
    final TextEditingController controller = TextEditingController();
    String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.enterFoodNameTitle),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(AppLocalizations.of(context)!.defaultFoodName),
              child: Text(AppLocalizations.of(context)!.skip),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.of(context).pop(text.isEmpty
                    ? AppLocalizations.of(context)!.defaultFoodName
                    : text);
              },
              child: Text(AppLocalizations.of(context)!.confirm),
            ),
          ],
        );
      },
    );
    return result ?? AppLocalizations.of(context)!.defaultFoodName;
  }

  Future<void> _takePicture() async {
    final cameraStatus = await Permission.camera.request();
    if (!cameraStatus.isGranted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.cameraPermissionRequired)),
        );
      }
      return;
    }

    final _picker = ImagePicker();
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      try {
        if (mounted) {
          final now = DateTime.now();
          final formattedDate = DateFormat(
                  AppLocalizations.of(context)!.dateFormat,
                  Localizations.localeOf(context).toString())
              .format(now);

          // 다이얼로그를 먼저 표시 (프로그레스 바 전에)
          final foodName = await _showFoodNameDialog();

          // 다이얼로그가 끝난 후 프로그레스 바 표시
          setState(() {
            _isProcessing = true;
          });

          final imageBytes = await pickedFile.readAsBytes();

          // 워터마크 생성 (UI 스레드에서 실행해야 함)
          final tempImage = img.decodeImage(
              imageBytes); // 크기 확인용 가벼운 디코딩 (헤더만 읽으면 좋겠지만 image 패키지는 전체 디코딩함. 하지만 여기서 크기만 알면 됨)
          // 최적화를 위해 decodeImage 대신 decodeInfo를 쓸 수 있으면 좋겠지만 image 패키지 버전에 따라 다름.
          // 일단 여기서 decodeImage를 하면 두 번 하는 셈이 되므로,
          // 워터마크 생성에 필요한 width/height를 얻기 위해 decodeImage를 하되,
          // 실제 합성은 isolate에서 하도록 함.

          // 개선: decodeImage도 무거우므로 isolate에서 하고 싶지만, 워터마크 생성에 width/height가 필요함.
          // 일단 decodeImage는 메인에서 하되, 합치기와 인코딩(가장 무거운 작업)을 isolate로 보냄.
          // 더 좋은 방법: isolate에서 decode하고 width/height를 리턴받고, 다시 워터마크 만들고, 다시 isolate로 보내기? -> 너무 복잡.
          // 절충안: decodeImage는 메인에서 수행 (어쩔 수 없음). 하지만 composite와 encodeJpg는 isolate에서 수행.

          final originalImage = img.decodeImage(imageBytes);

          if (originalImage != null) {
            final imageWidth = originalImage.width;
            final imageHeight = originalImage.height;

            final foodNameWatermarkBytes = await _createSingleTextWatermark(
                foodName, imageWidth, imageHeight, true);

            final dateWatermarkBytes = await _createSingleTextWatermark(
                formattedDate, imageWidth, imageHeight, false);

            // 무거운 작업을 백그라운드 isolate로 위임
            final modifiedImageBytes = await compute(
              processImageInIsolate,
              ProcessImageParams(
                imageBytes: imageBytes,
                foodNameWatermarkBytes: foodNameWatermarkBytes,
                dateWatermarkBytes: dateWatermarkBytes,
              ),
            );

            if (modifiedImageBytes != null) {
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
                  SnackBar(
                      content: Text(AppLocalizations.of(context)!.photoSaved)),
                );
              }
            }
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.errorOccurred(e.toString()))),
          );
        }
      } finally {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.appTitle),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          _gridItems.isEmpty
              ? Center(
                  child: Text(
                    AppLocalizations.of(context)!.noPhotosMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
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
                  itemCount: _gridItems.length,
                  itemBuilder: (context, index) {
                    final item = _gridItems[index];

                    // 광고인 경우
                    if (item is String && item == "AD") {
                      return const Card(
                        elevation: 4,
                        child: NativeAdWidget(),
                      );
                    }

                    // 사진인 경우
                    final imageFile = item as File;
                    String foodName = _extractFoodNameFromFile(imageFile);
                    if (foodName == 'Food' || foodName == '음식') {
                      foodName = AppLocalizations.of(context)!.defaultFoodName;
                    }
                    return Card(
                      elevation: 4,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(8)),
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
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.processingPhoto,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
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
