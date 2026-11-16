import 'dart:io';

import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/profile.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/core/state/app_data.dart';
import 'package:dysgraphia_app/core/storage/progress_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Attempt attempt(String letter, int stars) => Attempt(
  letter: letter,
  kind: PracticeKind.copy,
  stars: stars,
  overall: stars / 3,
  score: const {},
  drawing: Drawing([
    Stroke(const [StrokePoint(0, 0)]),
  ]),
);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('dys_state'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// A fresh app "launch" reading the same folder.
  ProviderContainer launch() {
    final c = ProviderContainer(
      overrides: [
        progressStoreProvider.overrideWithValue(
          ProgressStore(baseDirectory: () async => tmp),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<AppData> data(ProviderContainer c) => c.read(appDataProvider.future);
  AppDataNotifier notifier(ProviderContainer c) =>
      c.read(appDataProvider.notifier);

  test('first launch: no profiles, nobody chosen', () async {
    final d = await data(launch());
    expect(d.profiles, isEmpty);
    expect(d.current, isNull);
  });

  test('a new profile becomes current and survives a restart', () async {
    final c = launch();
    await data(c);
    await notifier(c).addProfile(Profile.create(name: 'Sami'));
    expect((await data(c)).current?.name, 'Sami');

    await notifier(c).addAttempt(attempt('a', 3));
    await notifier(c).addCheck(CheckRecord(tasks: 4, skipped: 0));

    // Restart: the only profile opens directly, with its history.
    final again = await data(launch());
    expect(again.current?.name, 'Sami');
    expect(again.history.attempts.single.letter, 'a');
    expect(again.history.checks, hasLength(1));
  });

  test('with several profiles the app asks who is practising', () async {
    final c = launch();
    await data(c);
    await notifier(c).addProfile(Profile.create(name: 'Sami'));
    await notifier(c).addAttempt(attempt('a', 3));
    await notifier(c).addProfile(Profile.create(name: 'Nora'));
    expect((await data(c)).history.attempts, isEmpty, reason: 'Nora is new');

    final c2 = launch();
    final d = await data(c2);
    expect(d.profiles, hasLength(2));
    expect(d.current, isNull);

    await notifier(c2).select(d.profiles.first.id);
    final sami = await data(c2);
    expect(sami.current?.name, 'Sami');
    expect(sami.history.attempts, hasLength(1));

    await notifier(c2).select(null);
    expect((await data(c2)).current, isNull);
  });

  test('editing and deleting profiles', () async {
    final c = launch();
    await data(c);
    await notifier(c).addProfile(Profile.create(name: 'Sami'));
    final sami = (await data(c)).current!;
    await notifier(c).addAttempt(attempt('a', 2));

    await notifier(c).updateProfile(sami.copyWith(name: 'Samir'));
    expect((await data(c)).current?.name, 'Samir');

    await notifier(c).deleteProfile(sami.id);
    final d = await data(c);
    expect(d.profiles, isEmpty);
    expect(d.current, isNull);
    // Its history is gone too, even for a new profile with the same id.
    final store = ProgressStore(baseDirectory: () async => tmp);
    expect((await store.loadHistory(sami.id)).attempts, isEmpty);
  });

  test('nothing is saved when nobody is chosen', () async {
    final c = launch();
    await data(c);
    await notifier(c).addAttempt(attempt('a', 3));
    expect((await data(c)).history.attempts, isEmpty);
  });
}
