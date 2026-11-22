import 'package:apexduanju/data/mappers.dart';
import 'package:apexduanju/models/drama.dart';
import 'package:apexduanju/theme/app_theme.dart';
import 'package:apexduanju/widgets/drama_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Drama _drama({int seasonCount = 0}) {
  return Drama(
    id: '1',
    title: '持械入宋：第一季',
    kind: '短剧',
    category: '短剧',
    tags: const <String>['短剧'],
    episodes: 100,
    rating: 0,
    viewers: '',
    description: '',
    coverColors: paletteFor('持械入宋'),

    episodeTitles: const <String>[],
    seasonCount: seasonCount,
  );
}

void main() {
  testWidgets('多季剧卡片显示总季数角标', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 260,
            child: DramaCard(drama: _drama(seasonCount: 12), onTap: () {}),
          ),
        ),
      ),
    );

    expect(find.text('共12季'), findsOneWidget);
    expect(find.text('全100集'), findsOneWidget);
  });

  testWidgets('单季剧不显示季数角标', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 160,
            height: 260,
            child: DramaCard(drama: _drama(), onTap: () {}),
          ),
        ),
      ),
    );

    expect(find.textContaining('共'), findsNothing);
  });
}
