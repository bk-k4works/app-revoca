import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import '../domain/vocabulary.dart';

class ContentRepository {
  ContentRepository(this.database);
  final Database database;

  static Future<ContentRepository> openBundled() async {
    final catalog =
        jsonDecode(await rootBundle.loadString('assets/content/catalog.json'))
            as Map<String, dynamic>;
    if (kReleaseMode && catalog['developmentOnly'] != false) {
      throw const FormatException(
        'Install human-approved content before release.',
      );
    }
    final hash = catalog['databaseSha256'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(hash)) {
      throw const FormatException('Invalid content hash.');
    }
    final directory = Directory(path.join(await getDatabasesPath(), 'content'));
    await directory.create(recursive: true);
    final file = File(path.join(directory.path, '$hash.sqlite'));
    if (!await file.exists() ||
        sha256.convert(await file.readAsBytes()).toString() != hash) {
      final bytes = await rootBundle.load('assets/content/content.sqlite');
      final data = bytes.buffer.asUint8List(
        bytes.offsetInBytes,
        bytes.lengthInBytes,
      );
      if (sha256.convert(data).toString() != hash) {
        throw const FormatException('Content database checksum mismatch.');
      }
      final pending = File('${file.path}.pending');
      await pending.writeAsBytes(data, flush: true);
      await pending.rename(file.path);
    }
    return ContentRepository(
      await openDatabase(file.path, readOnly: true, singleInstance: false),
    );
  }

  Future<Map<String, dynamic>> metadata() async => {
    for (final row in await database.query('metadata'))
      row['key'] as String: jsonDecode(row['value'] as String),
  };

  Future<List<Sense>> loadSenses(List<String> ids) async {
    if (ids.isEmpty) return [];
    final rows = await database.query(
      'senses',
      columns: ['payload'],
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    return rows
        .map((r) => Sense.fromJson(jsonDecode(r['payload'] as String)))
        .toList();
  }

  Future<List<Sense>> loadDeck(String deckId) async {
    final rows = await database.rawQuery(
      '''SELECT s.payload FROM deck_items d
      JOIN senses s ON s.id=d.sense_id WHERE d.deck_id=? ORDER BY d.position''',
      [deckId],
    );
    return rows
        .map((r) => Sense.fromJson(jsonDecode(r['payload'] as String)))
        .toList();
  }

  Future<List<Sense>> search(
    String query, {
    int limit = 50,
    int offset = 0,
  }) async {
    final escaped = query
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    final rows = await database.rawQuery(
      '''SELECT s.payload FROM senses s
      JOIN headwords h ON h.id=s.headword_id
      WHERE h.term LIKE ? ESCAPE '\\' OR s.meaning LIKE ? ESCAPE '\\'
        OR json_extract(s.payload, '\$.term') LIKE ? ESCAPE '\\'
      ORDER BY h.term, s.id LIMIT ? OFFSET ?''',
      ['%$escaped%', '%$escaped%', '%$escaped%', limit, offset],
    );
    return rows
        .map((r) => Sense.fromJson(jsonDecode(r['payload'] as String)))
        .toList();
  }

  Future<List<Map<String, dynamic>>> audioAssets() async =>
      (await database.query('audio_assets', columns: ['payload']))
          .map(
            (r) => jsonDecode(r['payload'] as String) as Map<String, dynamic>,
          )
          .toList();

  Future<Vocabulary> loadVocabulary() async {
    final meta = await metadata();
    final heads = {
      for (final row in await database.query('headwords'))
        row['id'] as String: Headword.fromJson(
          jsonDecode(row['payload'] as String),
        ),
    };
    // Keep examples and provenance out of the startup index; load on demand.
    final rows = await database.rawQuery(
      r'''SELECT s.id,s.headword_id,s.pos,s.meaning,
      s.meaning_alternatives AS alternatives,
      s.distractor_exclusions AS exclusions,
      json_extract(s.payload, '$.acceptedSpellings') AS spellings,
      json_extract(s.payload, '$.nearSynonymHeadwords') AS synonyms,
      json_extract(s.payload, '$.term') AS term
      FROM senses s ORDER BY s.rowid''',
    );
    final words = rows
        .map(
          (r) => Sense(
            id: r['id'] as String,
            headword: Headword(
              id: r['headword_id'] as String,
              // A sense may show a display form (customs) of its list headword.
              term: r['term'] as String? ?? heads[r['headword_id']]!.term,
              source: heads[r['headword_id']]!.source,
              acceptedSpellings: List<String>.from(
                jsonDecode(r['spellings'] as String),
              ),
            ),
            pos: r['pos'] as String,
            meaning: r['meaning'] as String,
            meaningAlternatives: List<String>.from(
              jsonDecode(r['alternatives'] as String? ?? '[]'),
            ),
            distractorExclusions: List<String>.from(
              jsonDecode(r['exclusions'] as String? ?? '[]'),
            ),
            nearSynonymHeadwords: List<String>.from(
              jsonDecode(r['synonyms'] as String? ?? '[]'),
            ),
            detailsLoaded: false,
          ),
        )
        .toList();
    final items = await database.query('deck_items', orderBy: 'position');
    final decks = (await database.query('decks', orderBy: 'position'))
        .map(
          (r) => WordDeck(
            id: r['id'] as String,
            title: r['title'] as String,
            subtitle: r['subtitle'] as String,
            wordIds: items
                .where((i) => i['deck_id'] == r['id'])
                .map((i) => i['sense_id'] as String)
                .toList(),
          ),
        )
        .toList();
    return Vocabulary(
      words: words,
      decks: decks,
      provenance: meta,
      idMigrations: Map<String, String>.from(meta['idMigrations'] ?? {}),
      detailLoader: loadSenses,
    );
  }
}
