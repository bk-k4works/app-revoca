import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'application/learning_controller.dart';
import 'data/learning_store.dart';
import 'data/content_repository.dart';
import 'domain/audio_asset.dart';
import 'services/audio_pack_service.dart';
import 'services/content_speech_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'services/speech_service.dart';
import 'ui/focus_theme.dart';
import 'ui/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const Bootstrap());
}

class Bootstrap extends StatefulWidget {
  const Bootstrap({super.key});
  @override
  State<Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<Bootstrap> {
  late Future<LearningController> _loading = _load();
  SpeechService _speech = DeviceSpeechService();
  ContentRepository? _content;
  SqliteLearningStore? _store;
  Future<LearningController> _load() async {
    final content = await ContentRepository.openBundled();
    SqliteLearningStore? store;
    try {
      final vocabulary = await content.loadVocabulary();
      store = await SqliteLearningStore.open();
      final controller = LearningController(
        vocabulary: vocabulary,
        store: store,
      );
      await controller.initialize();
      final packs = AudioPackService(
        directory: Directory(
          path.join((await getApplicationSupportDirectory()).path, 'audio'),
        ),
        assets: (await content.audioAssets()).map(AudioAsset.fromJson).toList(),
        packs: (vocabulary.provenance['audioPacks'] as List? ?? [])
            .map((p) => AudioPack.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
      );
      _speech = ContentSpeechService(
        packs: packs,
        fallback: _speech,
        player: LocalAudioPlayer(),
      );
      _content = content;
      _store = store;
      return controller;
    } catch (_) {
      await store?.database.close();
      await content.database.close();
      rethrow;
    }
  }

  @override
  void dispose() {
    unawaited(_speech.stop());
    unawaited(_content?.database.close());
    unawaited(_store?.database.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<LearningController>(
    future: _loading,
    builder: (context, snapshot) {
      if (snapshot.hasData) {
        return FocusVocaApp(controller: snapshot.data!, speech: _speech);
      }
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: focusTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    're:voca',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  if (snapshot.hasError) ...[
                    const Text(
                      '단어장과 학습 기록을 불러오지 못했어요.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _loading = _load()),
                      child: const Text('다시 불러오기'),
                    ),
                  ] else
                    const CircularProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class FocusVocaApp extends StatefulWidget {
  const FocusVocaApp({
    super.key,
    required this.controller,
    required this.speech,
  });
  final LearningController controller;
  final SpeechService speech;
  @override
  State<FocusVocaApp> createState() => _FocusVocaAppState();
}

class _FocusVocaAppState extends State<FocusVocaApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(widget.speech.stop());
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '리보카',
    debugShowCheckedModeBanner: false,
    locale: const Locale('ko'),
    supportedLocales: const [Locale('ko'), Locale('en')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: focusTheme(Brightness.light),
    darkTheme: focusTheme(Brightness.dark),
    home: HomeShell(controller: widget.controller, speech: widget.speech),
  );
}
