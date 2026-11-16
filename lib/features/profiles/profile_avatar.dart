import 'package:material_ui/material_ui.dart';

/// Pictures a profile can choose from (Profile.avatar is an index).
const profileAvatars = <(IconData, Color)>[
  (Icons.pets, Color(0xFFE07A2F)),
  (Icons.rocket_launch, Color(0xFF3C7DD9)),
  (Icons.star, Color(0xFFD9A400)),
  (Icons.local_florist, Color(0xFFD4537E)),
  (Icons.sports_soccer, Color(0xFF3B8A2E)),
  (Icons.palette, Color(0xFF7F5BD6)),
  (Icons.music_note, Color(0xFF1D9E85)),
  (Icons.directions_car, Color(0xFFC0392B)),
];

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.avatar,
    this.size = 48,
    this.selected = false,
  });

  final int avatar;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = profileAvatars[avatar % profileAvatars.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.18),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 3,
        ),
      ),
      child: Icon(icon, color: color, size: size * 0.55),
    );
  }
}
