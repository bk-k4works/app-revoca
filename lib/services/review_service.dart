import 'package:in_app_review/in_app_review.dart';

import '../application/review_prompt.dart';

/// The App Store and Google Play in-app rating sheet. Both limit how often it
/// may appear, so a request can quietly show nothing.
class StoreReviewPrompt implements ReviewPrompt {
  const StoreReviewPrompt();
  @override
  Future<void> request() async {
    try {
      final review = InAppReview.instance;
      if (await review.isAvailable()) await review.requestReview();
    } catch (_) {
      // No store on this device (a sideloaded or debug build): skip it.
    }
  }
}
