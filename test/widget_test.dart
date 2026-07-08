import 'package:emotion_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows login entry screen', (tester) async {
    await tester.pumpWidget(const MindBalanceApp());

    expect(find.text('로그인'), findsWidgets);
    expect(find.text('회원가입'), findsWidgets);
  });
}
