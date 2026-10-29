import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';

class ProfilePhotoService {
  ProfilePhotoService(this.api);
  final ApiClient api;
  Uint8List? _decode(dynamic response) {
    if (response is! Map || !response.containsKey('photo')) {
      throw const FormatException('Invalid photo response');
    }
    final photo = response['photo'];
    if (photo == null) return null;
    if (photo is! Map ||
        photo['content_type'] != 'image/jpeg' ||
        photo['image'] is! String ||
        (photo['image'] as String).length > 180000) {
      throw const FormatException('Invalid photo response');
    }
    final bytes = base64Decode(photo['image']);
    if (bytes.length < 3 ||
        bytes[0] != 0xff ||
        bytes[1] != 0xd8 ||
        bytes[2] != 0xff) {
      throw const FormatException('Invalid photo response');
    }
    return bytes;
  }

  Future<Uint8List?> load() async =>
      _decode(await api.get('/api/v1/me/profile/photo'));
  Future<Uint8List> save(Uint8List data) async {
    final photo = _decode(await api
        .put('/api/v1/me/profile/photo', body: {'image': base64Encode(data)}));
    if (photo == null) throw const FormatException('Photo was not saved');
    return photo;
  }

  Future<void> remove() async {
    if (_decode(await api.delete('/api/v1/me/profile/photo')) != null) {
      throw const FormatException('Photo was not removed');
    }
  }
}

class ProfilePhotoPicker {
  final _picker = ImagePicker();
  Future<Uint8List?> choose() async => _read(await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
      requestFullMetadata: false));
  Future<Uint8List?> recover() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;
    final lost = await _picker.retrieveLostData();
    if (lost.exception != null) throw lost.exception!;
    return _read(lost.files?.firstOrNull);
  }

  Future<Uint8List?> _read(XFile? file) async {
    if (file == null) return null;
    if (await file.length() > 2 * 1024 * 1024) {
      throw const FormatException('Choose a photo smaller than 2 MB.');
    }
    return file.readAsBytes();
  }
}

/// Scoped to one signed-in user. Failed writes retain the last confirmed image.
class ProfilePhotoController extends ChangeNotifier {
  ProfilePhotoController(this.service, {ProfilePhotoPicker? picker})
      : picker = picker ?? ProfilePhotoPicker();
  final ProfilePhotoService service;
  final ProfilePhotoPicker picker;
  Uint8List? bytes, recovered;
  String? error;
  bool busy = false, _disposed = false;
  int _revision = 0;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (busy || _disposed) return;
    final revision = ++_revision;
    busy = true;
    error = null;
    _changed();
    try {
      final data = await service.load();
      if (!_disposed && revision == _revision) bytes = data;
    } catch (_) {
      if (!_disposed) error = 'Could not load your photo. Tap Retry.';
    } finally {
      if (!_disposed && revision == _revision) {
        busy = false;
        _changed();
      }
    }
  }

  Future<void> recover() async {
    try {
      final data = await picker.recover();
      if (!_disposed) {
        recovered = data;
        _changed();
      }
    } catch (_) {
      if (!_disposed) {
        error = 'Your photo selection was interrupted. Choose it again.';
        _changed();
      }
    }
  }

  Future<bool> save(Uint8List data) => _write(() async {
        bytes = await service.save(data);
        recovered = null;
      });
  Future<bool> remove() => _write(() async {
        await service.remove();
        bytes = null;
        recovered = null;
      });
  Future<bool> _write(Future<void> Function() operation) async {
    if (busy || _disposed) return false;
    ++_revision;
    busy = true;
    error = null;
    _changed();
    try {
      await operation();
      return !_disposed;
    } catch (exception) {
      if (!_disposed) {
        error = exception is ApiException && exception.statusCode == 400
            ? exception.message
            : 'Could not save your photo. Your previous photo is kept. Please retry.';
      }
      return false;
    } finally {
      if (!_disposed) {
        busy = false;
        _changed();
      }
    }
  }

  void discardRecovered() {
    recovered = null;
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    ++_revision;
    super.dispose();
  }
}
