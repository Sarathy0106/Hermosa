import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermosa/theme.dart';
import 'package:hermosa/widgets/cover_image.dart';

void main() {
  test('Hermosa tonal surfaces maintain visual hierarchy', () {
    expect(AppColors.bg, isNot(AppColors.surface));
    expect(AppColors.surface, isNot(AppColors.surfaceHigh));
    expect(AppColors.textPrimary.computeLuminance(),
        greaterThan(AppColors.bg.computeLuminance()));
  });

  testWidgets('cover image has an accessible visual fallback', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: const Scaffold(body: CoverImage(url: '', size: 96)),
      ),
    );

    expect(find.byIcon(Icons.music_note_rounded), findsOneWidget);
    expect(tester.getSize(find.byType(CoverImage)), const Size(96, 96));
  });
}
