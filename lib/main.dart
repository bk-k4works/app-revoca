import 'dart:async';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'application/learning_controller.dart';
import 'application/review_prompt.dart';
import 'application/study_nudges.dart';
import 'data/learning_store.dart';
import 'data/content_repository.dart';
import 'domain/audio_asset.dart';
import 'services/audio_pack_service.dart';
import 'services/content_speech_service.dart';
import 'services/nudge_service.dart';
import 'services/review_service.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'services/speech_service.dart';
import 'ui/focus_theme.dart';
import 'ui/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase Analytics(first_open 등 자동 수집 이벤트)로 Google Ads 앱 캠페인 전환을 측정한다.
  // 초기화에 실패해도 학습 기능은 그대로 동작해야 한다.
  try {
    await Firebase.initializeApp();
  } catch (error) {
    debugPrint('Firebase init skipped: $error');
  }
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
  final StudyNudges _nudges = DeviceStudyNudges();
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
        return FocusVocaApp(
          controller: snapshot.data!,
          speech: _speech,
          nudges: _nudges,
          reviews: const StoreReviewPrompt(),
        );
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
    this.nudges = const NoStudyNudges(),
    this.reviews = const NoReviewPrompt(),
  });
  final LearningController controller;
  final SpeechService speech;
  final StudyNudges nudges;
  final ReviewPrompt reviews;
  @override
  State<FocusVocaApp> createState() => _FocusVocaAppState();
}

class _FocusVocaAppState extends State<FocusVocaApp>
    with WidgetsBindingObserver {
  Timer? _refresh, _review;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.addListener(_scheduleNudges);
    widget.controller.addListener(_askForReview);
    unawaited(widget.nudges.refresh(widget.controller));
  }

  // Once the result screen has settled, so the sheet never covers an answer.
  void _askForReview() {
    if (!widget.controller.reviewRequestDue) return;
    unawaited(widget.controller.markHintSeen(LearningController.reviewHint));
    _review = Timer(
      const Duration(milliseconds: 1500),
      () => unawaited(widget.reviews.request()),
    );
  }

  // Reminders and the widget follow study, at most once a second.
  void _scheduleNudges() {
    _refresh?.cancel();
    _refresh = Timer(
      const Duration(seconds: 1),
      () => unawaited(widget.nudges.refresh(widget.controller)),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(widget.speech.stop());
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      // A new day may have begun while the app was away.
      unawaited(widget.nudges.refresh(widget.controller));
    }
  }

  @override
  void dispose() {
    _refresh?.cancel();
    _review?.cancel();
    widget.controller.removeListener(_scheduleNudges);
    widget.controller.removeListener(_askForReview);
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
    home: HomeShell(
      controller: widget.controller,
      speech: widget.speech,
      nudges: widget.nudges,
    ),
  );
}
