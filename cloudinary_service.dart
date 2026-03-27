import 'dart:io';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  static const String _cloudName = 'dqkvt7kwz';
  static const String _apiKey = '394382375422322';
  static const String _profileUploadPreset = 'profile_upload';
  static const String _cnicUploadPreset = 'cnic_upload';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
  ));
  final ImagePicker _picker = ImagePicker();

  String get _uploadUrl => 'https://api.cloudinary.com/v1_1/$_cloudName/image/upload';

  Future<String?> _uploadImage(
      File imageFile, {
        required String uploadPreset,
        String? folder,
        String? publicId,
      }) async {
    try {
      FormData formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          imageFile.path,
          filename: imageFile.path.split('/').last,
        ),
        'upload_preset': uploadPreset,
        'api_key': _apiKey,
        'timestamp': (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString(),
      });

      if (folder != null) formData.fields.add(MapEntry('folder', folder));
      if (publicId != null) formData.fields.add(MapEntry('public_id', publicId));

      Response response = await _dio.post(
        _uploadUrl,
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
            'Accept': 'application/json',
          },
          validateStatus: (status) => status! < 500,
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        String secureUrl = data['secure_url'];
        print('[SUCCESS] Image uploaded successfully. URL: $secureUrl');
        return secureUrl;
      } else {
        print('[ERROR] Cloudinary upload failed. Status: ${response.statusCode}, Response: ${response.data}');
        return null;
      }
    } catch (e, stackTrace) {
      print('[ERROR] Cloudinary upload exception: $e\n$stackTrace');
      return null;
    }
  }

  Future<String?> uploadProfileImage(File imageFile, String userId) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final publicId = '${userId}_profile_$timestamp';

      return await _uploadImage(
        imageFile,
        uploadPreset: _profileUploadPreset,
        folder: 'profile_images/$userId',
        publicId: publicId,
      );
    } catch (e) {
      print('[ERROR] uploadProfileImage: $e');
      return null;
    }
  }

  Future<String?> pickAndUploadProfileImage(String userId) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile == null) return null;

      final File imageFile = File(pickedFile.path);

      if (!await imageFile.exists()) {
        print('[ERROR] Image file does not exist: ${pickedFile.path}');
        return null;
      }

      final fileSize = await imageFile.length();

      if (fileSize > 10 * 1024 * 1024) {
        print('[ERROR] File too large: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        return null;
      }

      return await uploadProfileImage(imageFile, userId);
    } catch (e, stackTrace) {
      print('[ERROR] pickAndUploadProfileImage: $e\n$stackTrace');
      return null;
    }
  }

  Future<Map<String, String?>> uploadCnicImages(
      File frontImage,
      File backImage,
      String userId,
      ) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final frontUrl = await _uploadImage(
        frontImage,
        uploadPreset: _cnicUploadPreset,
        folder: 'cnic_images/$userId',
        publicId: '${userId}_cnic_front_$timestamp',
      );

      final backUrl = await _uploadImage(
        backImage,
        uploadPreset: _cnicUploadPreset,
        folder: 'cnic_images/$userId',
        publicId: '${userId}_cnic_back_$timestamp',
      );

      return {
        'frontUrl': frontUrl,
        'backUrl': backUrl,
      };
    } catch (e) {
      print('[ERROR] uploadCnicImages: $e');
      return {};
    }
  }

  Future<Map<String, String?>> pickAndUploadCnicImages(String userId) async {
    try {
      final XFile? frontFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 800,
      );

      if (frontFile == null) return {};

      final XFile? backFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
        maxHeight: 800,
      );

      if (backFile == null) return {};

      final File frontImage = File(frontFile.path);
      final File backImage = File(backFile.path);

      if (!await frontImage.exists() || !await backImage.exists()) {
        print('[ERROR] One or both CNIC image files do not exist.');
        return {};
      }

      return await uploadCnicImages(frontImage, backImage, userId);
    } catch (e) {
      print('[ERROR] pickAndUploadCnicImages: $e');
      return {};
    }
  }

  String getOptimizedUrl(String originalUrl, {int width = 300, int height = 300}) {
    try {
      if (originalUrl.isEmpty) return originalUrl;

      String cleanUrl = originalUrl.split('?').first;
      final uri = Uri.parse(cleanUrl);
      final path = uri.path;

      final transformedPath = path.replaceFirst(
        '/upload/',
        '/upload/w_$width,h_$height,c_fill,q_auto,f_auto/',
      );

      return '${uri.scheme}://${uri.host}$transformedPath';
    } catch (e) {
      return originalUrl;
    }
  }

  String getThumbnailUrl(String originalUrl) {
    return getOptimizedUrl(originalUrl, width: 150, height: 150);
  }

  String getMediumUrl(String originalUrl) {
    return getOptimizedUrl(originalUrl, width: 500, height: 500);
  }

  Future<bool> isImageValid(String url) async {
    try {
      if (url.isEmpty) return false;
      final response = await _dio.head(url);
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}