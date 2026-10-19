import 'package:flutter/material.dart';
import '../application/learning_controller.dart';
import '../services/speech_service.dart';
import 'deck_screen.dart';
import 'widgets.dart';

Future<void> openWordSearch(
  BuildContext context,
  LearningController controller,
  SpeechService speech,
) => Navigator.of(context).push(
  MaterialPageRoute<void>(
    builder: (_) => WordSearchScreen(controller: controller, speech: speech),
  ),
);

/// Finds any sense in the course by English word or Korean meaning.
class WordSearchScreen extends StatefulWidget {
  const WordSearchScreen({
    super.key,
    required this.controller,
    required this.speech,
  });
  final LearningController controller;
  final SpeechService speech;
  @override
  State<WordSearchScreen> createState() => _WordSearchScreenState();
}

class _WordSearchScreenState extends State<WordSearchScreen> {
  final TextEditingController _input = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String _detail(String id) {
    final controller = widget.controller;
    final deck = controller.deckOf(id)?.title;
    final review = controller.nextReview(id);
    final today = controller.now();
    final status = review == null
        ? '새 단어'
        : !review.isAfter(today)
        ? '오늘 복습'
        : '다음 복습 ${review.month}월 ${review.day}일';
    return [?deck, status].join(' · ');
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, child) {
      final vocabulary = widget.controller.vocabulary;
      final results = vocabulary.search(_query);
      final headwords = vocabulary.words.map((w) => w.headword.id).toSet();
      return Scaffold(
        appBar: AppBar(title: const Text('단어 찾기')),
        body: SafeArea(
          top: false,
          child: PageContent(
            children: [
              // Same input settings as the spelling answer, so what is typed
              // or handwritten arrives without autocorrection.
              TextField(
                key: const Key('word-search'),
                controller: _input,
                autofocus: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                smartDashesType: SmartDashesType.disabled,
                smartQuotesType: SmartQuotesType.disabled,
                textInputAction: TextInputAction.search,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '영단어 또는 뜻',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: '지우기',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => setState(() {
                            _input.clear();
                            _query = '';
                          }),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              if (_query.trim().isEmpty)
                Caption(
                  '${_thousands(headwords.length)}개 단어에서 찾아요. earned처럼 바뀐 형태로 써도 기본형을 찾아 줘요.',
                )
              else if (results.isEmpty)
                const PaperCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '목록에 없는 단어예요.',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 8),
                      Caption(
                        '철자를 확인하거나 뜻으로 찾아 보세요. study처럼 아주 기본적인 단어는 이 목록에 없을 수 있어요.',
                      ),
                    ],
                  ),
                )
              else ...[
                Caption('뜻 ${results.length}개'),
                for (final group in groupByHeadword(results)) ...[
                  HeadwordHeading(group: group),
                  for (final word in group)
                    SenseTile(
                      word: word,
                      controller: widget.controller,
                      speech: widget.speech,
                      detail: _detail(word.id),
                    ),
                ],
              ],
            ],
          ),
        ),
      );
    },
  );
}

String _thousands(int value) => value.toString().replaceAllMapped(
  RegExp(r'\B(?=(\d{3})+(?!\d))'),
  (_) => ',',
);
