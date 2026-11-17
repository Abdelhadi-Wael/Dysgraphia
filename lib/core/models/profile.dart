import 'dart:math' as math;

import '../utils/time.dart';

enum ProfileMode { kid, adult }

enum Hand { left, right }

/// Someone who practises on this device.
class Profile {
  Profile({
    required this.id,
    required this.name,
    this.avatar = 0,
    this.mode = ProfileMode.kid,
    this.hand = Hand.right,
    this.researchCode,
    bool? readAloud,
    this.sounds = true,
    DateTime? createdAt,
  }) : readAloud = readAloud ?? mode == ProfileMode.kid,
       createdAt = utcMillis(createdAt ?? DateTime.now());

  /// Creates a profile with a fresh random id.
  factory Profile.create({
    required String name,
    int avatar = 0,
    ProfileMode mode = ProfileMode.kid,
    Hand hand = Hand.right,
    String? researchCode,
    bool? readAloud,
    bool sounds = true,
  }) => Profile(
    id: newId(),
    name: name,
    avatar: avatar,
    mode: mode,
    hand: hand,
    researchCode: researchCode,
    readAloud: readAloud,
    sounds: sounds,
  );

  final String id;

  /// First name or nickname, shown only on this device.
  final String name;

  /// Index into the avatar pictures (see profile_avatar.dart).
  final int avatar;
  final ProfileMode mode;
  final Hand hand;

  /// Optional code like "P01" used in exported files instead of the name,
  /// so research data never contains real names.
  final String? researchCode;

  /// Read instructions and tips aloud. On by default for children, who may
  /// not read yet; off by default for adults.
  final bool readAloud;

  /// Play sound effects (stars, finishing, a gentle "try again").
  final bool sounds;
  final DateTime createdAt;

  Profile copyWith({
    String? name,
    int? avatar,
    ProfileMode? mode,
    Hand? hand,
    String? Function()? researchCode,
    bool? readAloud,
    bool? sounds,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    avatar: avatar ?? this.avatar,
    mode: mode ?? this.mode,
    hand: hand ?? this.hand,
    researchCode: researchCode != null ? researchCode() : this.researchCode,
    readAloud: readAloud ?? this.readAloud,
    sounds: sounds ?? this.sounds,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar': avatar,
    'mode': mode.name,
    'hand': hand.name,
    'researchCode': researchCode,
    'readAloud': readAloud,
    'sounds': sounds,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
    id: j['id'] as String,
    name: j['name'] as String,
    avatar: (j['avatar'] as num?)?.toInt() ?? 0,
    mode: ProfileMode.values.byName(j['mode'] as String? ?? 'kid'),
    hand: Hand.values.byName(j['hand'] as String? ?? 'right'),
    researchCode: j['researchCode'] as String?,
    // Older files have no audio settings: use the defaults for the mode.
    readAloud: j['readAloud'] as bool?,
    sounds: j['sounds'] as bool? ?? true,
    createdAt: DateTime.parse(j['createdAt'] as String),
  );
}

final _rnd = math.Random();

/// Short unique id: time plus randomness, e.g. "m3x9k2a7f1".
String newId() =>
    DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
    _rnd.nextInt(1 << 30).toRadixString(36);
