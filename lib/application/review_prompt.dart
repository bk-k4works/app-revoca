/// The store's own rating sheet, kept out of the controller so it stays free
/// of platform plugins. [NoReviewPrompt] is used where no store is available.
abstract interface class ReviewPrompt {
  /// Asks the store to show its rating sheet. The store decides whether it
  /// actually appears, and never says whether the student rated.
  Future<void> request();
}

class NoReviewPrompt implements ReviewPrompt {
  const NoReviewPrompt();
  @override
  Future<void> request() async {}
}
