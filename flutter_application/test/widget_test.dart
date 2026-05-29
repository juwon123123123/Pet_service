import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application/main.dart';

void main() {
  testWidgets('shows onboarding screen', (tester) async {
    await tester.pumpWidget(const PetTimesApp());

    expect(find.text('PET TIMES'), findsOneWidget);
    expect(find.text('시작하기'), findsOneWidget);
  });
}
