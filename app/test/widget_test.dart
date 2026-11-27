import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wts/features/auth/presentation/widgets/otp_input.dart';

void main() {
  testWidgets(
    'OtpInput menampilkan digit yang diketik dan memanggil onCompleted',
    (tester) async {
      final controller = TextEditingController();
      String? completed;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: OtpInput(
                controller: controller,
                onCompleted: (v) => completed = v,
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '482');
      await tester.pump();
      expect(find.text('4'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(completed, isNull);

      await tester.enterText(find.byType(TextField), '482915');
      await tester.pump();
      expect(completed, '482915');
    },
  );
}
