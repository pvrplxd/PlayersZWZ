/// Common local and standard formats per sport, with total player counts.
class SportFormat {
  const SportFormat(this.name, this.players, {this.local = false});

  final String name;
  final int players;

  /// Street/local style (e.g. tape-ball cricket) versus the standard game.
  final bool local;
}

const sportFormats = <String, List<SportFormat>>{
  'Football': [
    SportFormat('Futsal 5-a-side', 10, local: true),
    SportFormat('7-a-side', 14, local: true),
    SportFormat('11-a-side', 22),
  ],
  'Cricket': [
    SportFormat('Tape ball 6-a-side', 12, local: true),
    SportFormat('Tape ball 8-a-side', 16, local: true),
    SportFormat('11-a-side', 22),
  ],
  'Basketball': [
    SportFormat('3x3 half court', 6, local: true),
    SportFormat('5v5 full court', 10),
  ],
  'Badminton': [
    SportFormat('Singles', 2),
    SportFormat('Doubles', 4),
  ],
  'Tennis': [
    SportFormat('Singles', 2),
    SportFormat('Doubles', 4),
  ],
  'Skating': [
    SportFormat('Group session', 6, local: true),
  ],
};


/// Roles a player can list per sport (must match the API's SPORT_ROLES).
const sportRoles = <String, List<String>>{
  'Football': ['Goalkeeper', 'Defender', 'Midfielder', 'Forward'],
  'Cricket': ['Batter', 'Bowler', 'All-rounder', 'Wicket-keeper'],
  'Basketball': ['Guard', 'Forward', 'Center'],
  'Badminton': ['Singles', 'Doubles'],
  'Tennis': ['Singles', 'Doubles'],
  'Skating': ['Street', 'Park', 'Speed'],
};

const skillLevels = ['Beginner', 'Intermediate', 'Advanced'];

SportFormat? formatFor(String sport, int players) {
  for (final format in sportFormats[sport] ?? const <SportFormat>[]) {
    if (format.players == players) return format;
  }
  return null;
}
