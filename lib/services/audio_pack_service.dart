import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import '../domain/audio_asset.dart';

class AudioPackService {
  AudioPackService({
    required this.directory,
    required this.assets,
    required this.packs,
  });
  final Directory directory;
  final List<AudioAsset> assets;
  final List<AudioPack> packs;
  final Map<String, Future<void>> _downloads = {};

  File _file(String relative) {
    if (path.isAbsolute(relative) ||
        relative.contains('\\') ||
        relative.split('/').any((part) => part == '..' || part.isEmpty)) {
      throw const FormatException('Unsafe audio path.');
    }
    return File(path.join(directory.path, relative));
  }

  Future<bool> _valid(File file, String hash, int size) async =>
      await file.exists() &&
      await file.length() == size &&
      sha256.convert(await file.readAsBytes()).toString() == hash;

  Future<String?> localPath(AudioAsset asset) async {
    final file = _file(asset.path);
    if (await _valid(file, asset.sha256, asset.bytes)) return file.path;
    final bundle = asset.bundlePath;
    if (bundle == null) return null;
    try {
      final data = await rootBundle.load(bundle);
      final bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );
      if (bytes.length != asset.bytes ||
          sha256.convert(bytes).toString() != asset.sha256) {
        return null;
      }
      await file.parent.create(recursive: true);
      final pending = File('${file.path}.pending');
      await pending.writeAsBytes(bytes, flush: true);
      await pending.rename(file.path);
      return file.path;
    } on FlutterError {
      return null;
    }
  }

  Future<bool> isPackReady(String id) async {
    final pack = packs.where((p) => p.id == id).firstOrNull;
    if (pack == null) return false;
    for (final item in pack.files) {
      if (!await _valid(_file(item['path']), item['sha256'], item['bytes'])) {
        final asset = assets.where((a) => a.path == item['path']).firstOrNull;
        if (asset == null || await localPath(asset) == null) return false;
      }
    }
    return true;
  }

  Future<void> download(String id) => _downloads.putIfAbsent(id, () async {
    try {
      if (await isPackReady(id)) return;
      final pack = packs.firstWhere((p) => p.id == id);
      final url = pack.url;
      if (url == null || url.scheme != 'https' || url.userInfo.isNotEmpty) {
        throw StateError('이 단어장의 음성 팩 다운로드가 아직 준비되지 않았어요.');
      }
      if (pack.bytes <= 0 || pack.bytes > 100 * 1024 * 1024) {
        throw const FormatException('Invalid pack size.');
      }
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 20);
      try {
        final request = await client.getUrl(url);
        request.followRedirects = false;
        final response = await request.close().timeout(
          const Duration(seconds: 30),
        );
        if (response.statusCode != 200) {
          throw HttpException('Audio download failed: ${response.statusCode}');
        }
        final buffer = BytesBuilder(copy: false);
        await for (final chunk in response.timeout(
          const Duration(seconds: 30),
        )) {
          if (buffer.length + chunk.length > pack.bytes) {
            throw const FormatException('Oversized audio pack.');
          }
          buffer.add(chunk);
        }
        await installBytes(pack, buffer.takeBytes());
      } finally {
        client.close(force: true);
      }
    } finally {
      _downloads.remove(id);
    }
  });

  Future<void> installBytes(AudioPack pack, Uint8List bytes) async {
    if (bytes.length != pack.bytes ||
        sha256.convert(bytes).toString() != pack.sha256) {
      throw const FormatException('Audio pack checksum mismatch.');
    }
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final expected = {
      for (final file in pack.files) file['path'] as String: file,
    };
    if (archive.length != expected.length) {
      throw const FormatException('Unexpected pack files.');
    }
    final checked = <String, Uint8List>{};
    for (final file in archive) {
      _file(file.name); // Validate path before any write.
      final metadata = expected[file.name];
      if (!file.isFile ||
          file.isSymbolicLink ||
          metadata == null ||
          checked.containsKey(file.name) ||
          file.size != metadata['bytes'] ||
          file.size > 10 * 1024 * 1024) {
        throw const FormatException('Invalid audio pack entry.');
      }
      final data = file.content;
      if (data.length != metadata['bytes'] ||
          sha256.convert(data).toString() != metadata['sha256']) {
        throw const FormatException('Audio entry checksum mismatch.');
      }
      checked[file.name] = data;
    }
    // Validate every entry before installing any. Files are immutable by hash;
    // interrupted installation can resume without touching unrelated packs.
    for (final entry in checked.entries) {
      final target = _file(entry.key);
      await target.parent.create(recursive: true);
      final pending = File('${target.path}.pending');
      await pending.writeAsBytes(entry.value, flush: true);
      await pending.rename(target.path);
    }
  }
}
