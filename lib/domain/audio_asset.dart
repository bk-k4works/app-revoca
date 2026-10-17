class AudioAsset {
  const AudioAsset({
    required this.id,
    required this.senseId,
    required this.kind,
    required this.text,
    required this.language,
    required this.path,
    required this.sha256,
    required this.bytes,
    this.bundlePath,
    this.packId,
  });
  final String id, senseId, kind, text, language, path, sha256;
  final int bytes;
  final String? bundlePath, packId;
  factory AudioAsset.fromJson(Map<String, dynamic> json) => AudioAsset(
    id: json['assetId'],
    senseId: json['senseId'],
    kind: json['kind'],
    text: json['text'],
    language: json['language'],
    path: json['path'],
    sha256: json['fileSha256'],
    bytes: json['bytes'],
    bundlePath: json['bundlePath'],
    packId: json['packId'],
  );
}

class AudioPack {
  const AudioPack({
    required this.id,
    required this.sha256,
    required this.bytes,
    required this.files,
    this.url,
  });
  final String id, sha256;
  final int bytes;
  final Uri? url;
  final List<Map<String, dynamic>> files;
  factory AudioPack.fromJson(Map<String, dynamic> json) => AudioPack(
    id: json['id'],
    sha256: json['sha256'],
    bytes: json['bytes'],
    url: json['url'] == null ? null : Uri.parse(json['url']),
    files: List<Map<String, dynamic>>.from(json['assets']),
  );
}
