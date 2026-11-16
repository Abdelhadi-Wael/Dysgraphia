import 'dart:io';

import 'package:dysgraphia_app/core/models/history.dart';
import 'package:dysgraphia_app/core/models/profile.dart';
import 'package:dysgraphia_app/core/models/stroke.dart';
import 'package:dysgraphia_app/core/storage/progress_store.dart';
import 'package:flutter_test/flutter_test.dart';

Attempt attempt(String letter, int stars, {DateTime? at}) => Attempt(
  letter: letter,
  kind: PracticeKind.copy,
  stars: stars,
  overall: stars / 3,
  score: {'stars': stars},
  drawing: Drawing([
    Stroke(const [StrokePoint(0, 0), StrokePoint(0.2, -0.3, t: 40)]),
  ]),
  at: at,
);

void main() {
  late Directory tmp;
  late ProgressStore store;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('dys_store');
    store = ProgressStore(baseDirectory: () async => tmp);
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  test('empty store: no profiles, empty history', () async {
    expect(await store.loadProfiles(), isEmpty);
    expect((await store.loadHistory('nobody')).attempts, isEmpty);
  });

  test('profiles round-trip with all fields', () async {
    final p = Profile.create(
      name: 'Sami',
      avatar: 3,
      mode: ProfileMode.kid,
      hand: Hand.left,
      researchCode: 'P07',
    );
    await store.saveProfiles([p, Profile.create(name: 'Nora')]);
    final back = await store.loadProfiles();
    expect(back.map((p) => p.name), ['Sami', 'Nora']);
    expect(back.first.id, p.id);
    expect(back.first.avatar, 3);
    expect(back.first.hand, Hand.left);
    expect(back.first.researchCode, 'P07');
    expect(back.first.createdAt, p.createdAt);
  });

  test('history round-trips attempts with drawings and checks', () async {
    final h = History()
        .withAttempt(attempt('a', 3))
        .withAttempt(attempt('b', 1))
        .withCheck(CheckRecord(tasks: 4, skipped: 1, file: '/x.json'));
    await store.saveHistory('p1', h);
    final back = await store.loadHistory('p1');
    expect(back.attempts.map((a) => a.letter), ['a', 'b']);
    expect(back.attempts.first.drawing.strokes.single.points, hasLength(2));
    expect(back.attempts.first.kind, PracticeKind.copy);
    expect(back.checks.single.skipped, 1);
    expect(await store.loadHistory('p2'), isA<History>());
  });

  test('deleting a history removes its file', () async {
    await store.saveHistory('p1', History().withAttempt(attempt('a', 2)));
    await store.deleteHistory('p1');
    expect((await store.loadHistory('p1')).attempts, isEmpty);
    await store.deleteHistory('never-existed'); // no error
  });

  test('saving leaves no temporary files behind', () async {
    await store.saveProfiles([Profile.create(name: 'A')]);
    final names = tmp.listSync().map((f) => f.uri.pathSegments.last);
    expect(names, ['profiles.json']);
  });

  test('copyWith can clear the research code', () {
    final p = Profile.create(name: 'A', researchCode: 'P1');
    expect(p.copyWith(researchCode: () => null).researchCode, isNull);
    expect(p.copyWith(name: 'B').researchCode, 'P1');
  });

  test('ids are unique', () {
    expect({for (var i = 0; i < 200; i++) newId()}, hasLength(200));
  });
}
