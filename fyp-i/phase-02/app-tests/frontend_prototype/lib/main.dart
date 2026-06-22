import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const PlayersZwzApp());
}

class AppColors {
  static const Color background = Color(0xFF050505);
  static const Color surface = Color(0xFF1B1B1B);
  static const Color surfaceLight = Color(0xFF252525);
  static const Color textMuted = Color(0xFFA7A7A7);
  static const Color lime = Color(0xFFD9FF00);
  static const Color limeDark = Color(0xFF97B300);
  static const Color danger = Color(0xFF510808);
  static const Color line = Color(0xFF343434);
}

class AppState extends ChangeNotifier {
  final Set<String> selectedSports = {'Cricket', 'Basketball', 'Badminton'};
  String username = 'afaq_aamir';
  bool strictReliability = true;
  bool prioritizeProximity = false;
  bool notifications = true;
  final List<JoinRequest> requests = [
    JoinRequest('Kamran K.', 'Cricket', 5.2),
    JoinRequest('Ali Ahmed', 'Cricket', 5.8),
  ];

  void toggleSport(String sport) {
    if (selectedSports.contains(sport)) {
      selectedSports.remove(sport);
    } else {
      selectedSports.add(sport);
    }
    notifyListeners();
  }

  void approve(JoinRequest request) {
    request.status = RequestStatus.approved;
    notifyListeners();
  }

  void reject(JoinRequest request) {
    request.status = RequestStatus.rejected;
    notifyListeners();
  }

  void updateUsername(String value) {
    username = value.trim().isEmpty ? username : value.trim();
    notifyListeners();
  }
}

final AppState appState = AppState();

enum RequestStatus { pending, approved, rejected }

class JoinRequest {
  JoinRequest(this.name, this.sport, this.reliability);
  final String name;
  final String sport;
  final double reliability;
  RequestStatus status = RequestStatus.pending;
}

class PlayersZwzApp extends StatelessWidget {
  const PlayersZwzApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appState,
      builder: (context, _) => MaterialApp(
        title: 'PlayersZWZ',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          scaffoldBackgroundColor: AppColors.background,
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.lime,
            brightness: Brightness.dark,
            surface: AppColors.surface,
          ),
          textTheme: const TextTheme(
            headlineLarge: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -1.2),
            headlineMedium: TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.8),
            titleLarge: TextStyle(fontWeight: FontWeight.w800),
            titleMedium: TextStyle(fontWeight: FontWeight.w700),
            bodyMedium: TextStyle(color: Colors.white),
          ),
        ),
        home: const SplashPage(),
      ),
    );
  }
}

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1700), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingPage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: BrandMark(size: 72)),
    );
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 42});
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size * .7,
      child: CustomPaint(painter: BrandMarkPainter()),
    );
  }
}

class BrandMarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.lime;
    final left = Path()
      ..moveTo(0, size.height * .15)
      ..lineTo(size.width * .42, size.height * .5)
      ..lineTo(0, size.height * .85)
      ..lineTo(size.width * .17, size.height * .5)
      ..close();
    final right = Path()
      ..moveTo(size.width, size.height * .15)
      ..lineTo(size.width * .58, size.height * .5)
      ..lineTo(size.width, size.height * .85)
      ..lineTo(size.width * .83, size.height * .5)
      ..close();
    canvas.drawPath(left, paint);
    canvas.drawPath(right, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardData> pages = const [
    _OnboardData('Welcome\nto PlayersZWZ', 'Your sports community for finding games, courts and new teammates.', Icons.map_outlined),
    _OnboardData('Find nearby\nplayers', 'Discover players and games around your city in just a few taps.', Icons.sports_soccer_outlined),
    _OnboardData('Book arenas\ninstantly', 'Reserve sports venues and invite your squad without the back-and-forth.', Icons.calendar_month_outlined),
    _OnboardData('AI-powered\nmatchmaking', 'Find a better match using distance, sport preference and reliability.', Icons.hub_outlined),
  ];

  void _next() {
    if (_index == pages.length - 1) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthCreatePage()));
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = pages[_index];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 22),
          child: Column(
            children: [
              const BrandMark(size: 42),
              const Spacer(),
              Expanded(
                flex: 6,
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemCount: pages.length,
                  itemBuilder: (context, index) => _OnboardHero(data: pages[index]),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: i == _index ? 25 : 7,
                    height: 7,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.lime : Colors.white24,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SocialButton(
                icon: Icons.g_mobiledata_rounded,
                label: 'Continue with Google',
                onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainShell())),
              ),
              const SizedBox(height: 10),
              SocialButton(
                icon: Icons.mail_outline_rounded,
                label: 'Sign up with email',
                onTap: _next,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Already have an account? ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AuthLoginPage())),
                    child: const Text('Log In', style: TextStyle(decoration: TextDecoration.underline, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardData {
  const _OnboardData(this.title, this.subtitle, this.icon);
  final String title;
  final String subtitle;
  final IconData icon;
}

class _OnboardHero extends StatelessWidget {
  const _OnboardHero({required this.data});
  final _OnboardData data;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(data.title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(data.subtitle, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textMuted, height: 1.45)),
        const SizedBox(height: 38),
        SizedBox(
          width: 270,
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.rotate(
                angle: -.15,
                child: Container(
                  width: 215,
                  height: 135,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.line),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, 12))],
                  ),
                  child: Center(child: Icon(data.icon, size: 70, color: Colors.white70)),
                ),
              ),
              Positioned(
                right: 18,
                top: 24,
                child: _FloatingBubble(icon: Icons.location_on_rounded, color: AppColors.lime),
              ),
              const Positioned(left: 18, bottom: 28, child: _FloatingBubble(icon: Icons.sports_cricket_rounded, color: Colors.white)),
              const Positioned(right: 36, bottom: 8, child: _FloatingBubble(icon: Icons.bolt_rounded, color: AppColors.lime)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FloatingBubble extends StatelessWidget {
  const _FloatingBubble({required this.icon, required this.color});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.surfaceLight,
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)],
      ),
      child: Icon(icon, color: color),
    );
  }
}

class AuthCreatePage extends StatefulWidget {
  const AuthCreatePage({super.key});

  @override
  State<AuthCreatePage> createState() => _AuthCreatePageState();
}

class _AuthCreatePageState extends State<AuthCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _firstName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _continue() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateProfilePage()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your\naccount',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(controller: _firstName, hint: 'First name', validator: _required),
            const SizedBox(height: 10),
            AppTextField(hint: 'Last name'),
            const SizedBox(height: 10),
            AppTextField(controller: _email, hint: 'Email address', keyboardType: TextInputType.emailAddress, validator: _emailValidator),
            const SizedBox(height: 10),
            AppTextField(
              controller: _password,
              hint: 'Password',
              obscureText: _obscure,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
              validator: (v) => (v == null || v.length < 4) ? 'Use at least 4 characters' : null,
            ),
            const SizedBox(height: 10),
            AppTextField(hint: 'Confirm password', obscureText: true),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Create account', onTap: _continue),
            const AuthDivider(),
            SocialButton(icon: Icons.g_mobiledata_rounded, label: 'Continue with Google', onTap: _continue),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Already have an account? ', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthLoginPage())),
                  child: const Text('Log In', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthLoginPage extends StatefulWidget {
  const AuthLoginPage({super.key});

  @override
  State<AuthLoginPage> createState() => _AuthLoginPageState();
}

class _AuthLoginPageState extends State<AuthLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _login() {
    if (_formKey.currentState?.validate() ?? false) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Login',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            AppTextField(controller: _email, hint: 'Email address', keyboardType: TextInputType.emailAddress, validator: _emailValidator),
            const SizedBox(height: 10),
            AppTextField(
              controller: _password,
              hint: 'Password',
              obscureText: _obscure,
              validator: _required,
              suffix: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 19),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: 'Login', onTap: _login),
            const AuthDivider(),
            SocialButton(icon: Icons.g_mobiledata_rounded, label: 'Continue with Google', onTap: _login),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Don't have an account? ", style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                GestureDetector(
                  onTap: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const AuthCreatePage())),
                  child: const Text('Sign up', style: TextStyle(fontSize: 12, decoration: TextDecoration.underline)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - 70),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const BrandMark(size: 46),
                const SizedBox(height: 28),
                Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 30),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String? _required(String? value) => (value == null || value.trim().isEmpty) ? 'This field is required' : null;
String? _emailValidator(String? value) {
  if (value == null || value.trim().isEmpty) return 'Email is required';
  return value.contains('@') ? null : 'Enter a valid email';
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });
  final TextEditingController? controller;
  final String hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        suffixIcon: suffix,
        errorStyle: const TextStyle(fontSize: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.surface)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.lime)),
      ),
    );
  }
}

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.line)),
          Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or', style: TextStyle(color: AppColors.textMuted, fontSize: 12))),
          Expanded(child: Divider(color: AppColors.line)),
        ],
      ),
    );
  }
}

class CreateProfilePage extends StatefulWidget {
  const CreateProfilePage({super.key});

  @override
  State<CreateProfilePage> createState() => _CreateProfilePageState();
}

class _CreateProfilePageState extends State<CreateProfilePage> {
  final _controller = TextEditingController(text: 'afaq_aamir');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create profile', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 38),
              Center(
                child: Stack(
                  children: [
                    const CircleAvatar(radius: 46, backgroundColor: AppColors.surfaceLight, child: Icon(Icons.person_rounded, color: Colors.white70, size: 50)),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 29,
                        height: 29,
                        decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                        child: const Icon(Icons.edit_rounded, color: Colors.black, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.alternate_email_rounded, size: 19, color: AppColors.textMuted),
                  suffixIcon: const Icon(Icons.check_circle_rounded, color: AppColors.lime, size: 20),
                  filled: true,
                  fillColor: AppColors.surface,
                  hintText: 'Username',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 9),
              const Text('Your username can only contain alphabets, numbers, underscores and dots.', style: TextStyle(color: AppColors.textMuted, fontSize: 11, height: 1.4)),
              const Spacer(),
              PrimaryButton(
                label: 'Next',
                onTap: () {
                  appState.updateUsername(_controller.text);
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PickSportsPage()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PickSportsPage extends StatelessWidget {
  const PickSportsPage({super.key});

  static const List<_SportData> sports = [
    _SportData('Basketball', Icons.sports_basketball_rounded),
    _SportData('Badminton', Icons.sports_tennis_rounded),
    _SportData('Football', Icons.sports_soccer_rounded),
    _SportData('Skating', Icons.directions_run_rounded),
    _SportData('Cricket', Icons.sports_cricket_rounded),
    _SportData('Tennis', Icons.sports_tennis_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pick your sports', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 5),
              const Text('Personalize your match feed.', style: TextStyle(color: AppColors.textMuted)),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  itemCount: sports.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.12),
                  itemBuilder: (context, index) {
                    final sport = sports[index];
                    final selected = appState.selectedSports.contains(sport.name);
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => appState.toggleSport(sport.name),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.surface : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? AppColors.limeDark : Colors.transparent, width: selected ? 1.5 : 0),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(sport.icon, color: selected ? AppColors.lime : Colors.white70, size: 34),
                            const SizedBox(height: 10),
                            Text(sport.name, style: TextStyle(fontWeight: FontWeight.w700, color: selected ? AppColors.lime : Colors.white70)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              PrimaryButton(
                label: 'Continue',
                onTap: () => Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const MainShell()), (route) => false),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SportData {
  const _SportData(this.name, this.icon);
  final String name;
  final IconData icon;
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      ExplorePage(onCreateGame: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateGamePage()))),
      const ActivityPage(),
      const ProfilePage(),
    ];
    return Scaffold(
      body: pages[_tab],
      bottomNavigationBar: _BottomBar(
        currentIndex: _tab,
        onChanged: (value) => setState(() => _tab = value),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onChanged});
  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const data = [
      (Icons.map_outlined, 'Explore'),
      (Icons.bolt_outlined, 'Activity'),
      (Icons.person_outline_rounded, 'Profile'),
    ];
    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: AppColors.background, border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(24)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(data.length, (index) {
            final active = currentIndex == index;
            return Expanded(
              child: InkWell(
                onTap: () => onChanged(index),
                borderRadius: BorderRadius.circular(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(data[index].$1, color: active ? AppColors.lime : Colors.white54),
                    const SizedBox(height: 4),
                    Text(data[index].$2, style: TextStyle(fontSize: 10, color: active ? AppColors.lime : Colors.white54)),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key, required this.onCreateGame});
  final VoidCallback onCreateGame;

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final filters = ['All', 'Football', 'Basketball', 'Badminton'];
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: MapPainter())),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
                  child: Row(
                    children: [
                      Text('Explore', style: Theme.of(context).textTheme.headlineMedium),
                      const Spacer(),
                      _CircleIcon(icon: Icons.auto_awesome_outlined, onTap: () => _showComingSoon(context, 'AI match suggestions are ready for your demo.')),
                      const SizedBox(width: 8),
                      _CircleIcon(icon: Icons.search_rounded, onTap: () => _showSearch(context)),
                      const SizedBox(width: 8),
                      _CircleIcon(icon: Icons.add_rounded, onTap: widget.onCreateGame),
                    ],
                  ),
                ),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    scrollDirection: Axis.horizontal,
                    itemBuilder: (_, index) {
                      final item = filters[index];
                      return FilterPill(label: item, selected: item == _filter, onTap: () => setState(() => _filter = item));
                    },
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemCount: filters.length,
                  ),
                ),
                const Spacer(),
              ],
            ),
            Positioned(left: 78, top: 278, child: _MapGameMarker(label: 'Cricket\n3 slots left', icon: Icons.sports_cricket_rounded, onTap: () => _openGame(context))),
            Positioned(right: 25, top: 395, child: _MapGameMarker(label: 'Basketball\n5 slots left', icon: Icons.sports_basketball_rounded, onTap: () => _openGame(context))),
            Positioned(left: 45, bottom: 145, child: _MapGameMarker(label: 'Badminton\nFree spot', icon: Icons.sports_tennis_rounded, onTap: () => _openGame(context))),
            Positioned(
              right: 20,
              bottom: 80,
              child: Column(
                children: [
                  _CircleIcon(icon: Icons.my_location_rounded, onTap: () => _showComingSoon(context, 'Location centered on your current area.')),
                  const SizedBox(height: 8),
                  _CircleIcon(icon: Icons.layers_outlined, onTap: () => _showComingSoon(context, 'Map layers changed.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGame(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameDetailsPage()));
  }

  void _showSearch(BuildContext context) {
    showSearch(context: context, delegate: VenueSearchDelegate());
  }
}

class MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF171717);
    canvas.drawRect(Offset.zero & size, bg);
    final block = Paint()..color = const Color(0xFF202020);
    final road = Paint()
      ..color = const Color(0xFF313131)
      ..strokeWidth = 1.25
      ..style = PaintingStyle.stroke;
    for (var x = -80.0; x < size.width + 120; x += 95) {
      for (var y = 70.0; y < size.height; y += 84) {
        final rect = Rect.fromLTWH(x + (y ~/ 40 % 2) * 13, y, 72, 54);
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(6)), block);
      }
    }
    final lines = [
      [Offset(-30, 160), Offset(size.width + 30, 500)],
      [Offset(30, 650), Offset(size.width - 20, 150)],
      [Offset(0, 450), Offset(size.width, 670)],
      [Offset(size.width * .25, 0), Offset(size.width * .55, size.height)],
    ];
    for (final line in lines) canvas.drawLine(line[0], line[1], road);
    final label = TextPainter(textDirection: TextDirection.ltr);
    for (final item in const [
      ('Faisal Park', 56.0, 188.0),
      ('Jinnah Avenue', 168.0, 565.0),
      ('Sports District', 90.0, 360.0),
    ]) {
      label.text = TextSpan(text: item.$1, style: const TextStyle(color: Color(0xFF777777), fontSize: 10));
      label.layout();
      label.paint(canvas, Offset(item.$2, item.$3));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MapGameMarker extends StatelessWidget {
  const _MapGameMarker({required this.label, required this.icon, required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFF080808), border: Border.all(color: AppColors.line), borderRadius: BorderRadius.circular(13), boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 12)]),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 30, height: 30, decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle), child: Icon(icon, size: 17, color: Colors.black)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 9, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: 35,
        height: 35,
        decoration: BoxDecoration(color: AppColors.background.withOpacity(.92), shape: BoxShape.circle, border: Border.all(color: AppColors.line)),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class FilterPill extends StatelessWidget {
  const FilterPill({super.key, required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        decoration: BoxDecoration(color: selected ? Colors.black : AppColors.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: selected ? AppColors.lime : AppColors.line)),
        child: Text(label, style: TextStyle(fontSize: 11, color: selected ? AppColors.lime : Colors.white70, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class VenueSearchDelegate extends SearchDelegate<String> {
  final venues = const ['Pak Basketball Court', 'Gulberg Cricket Ground', 'F-9 Football Arena', 'Badminton Pro Centre'];

  @override
  List<Widget>? buildActions(BuildContext context) => [
        IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () => query = ''),
      ];

  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: () => close(context, ''));

  @override
  Widget buildResults(BuildContext context) => _build(context);

  @override
  Widget buildSuggestions(BuildContext context) => _build(context);

  Widget _build(BuildContext context) {
    final matches = venues.where((v) => v.toLowerCase().contains(query.toLowerCase())).toList();
    return Container(
      color: AppColors.background,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: matches.length,
        separatorBuilder: (_, __) => const Divider(color: AppColors.line),
        itemBuilder: (_, index) => ListTile(
          leading: const CircleAvatar(backgroundColor: AppColors.surface, child: Icon(Icons.location_on_outlined, color: AppColors.lime)),
          title: Text(matches[index]),
          subtitle: const Text('Nearby venue', style: TextStyle(color: AppColors.textMuted)),
          onTap: () {
            close(context, matches[index]);
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GameDetailsPage()));
          },
        ),
      ),
    );
  }
}

class GameDetailsPage extends StatefulWidget {
  const GameDetailsPage({super.key});

  @override
  State<GameDetailsPage> createState() => _GameDetailsPageState();
}

class _GameDetailsPageState extends State<GameDetailsPage> {
  String _day = 'Today';
  String _time = '04:00 PM';

  @override
  Widget build(BuildContext context) {
    const days = ['Today', 'Mon', 'Tue', 'Wed', 'Thurs'];
    const times = ['08:00 AM', '12:00 PM', '04:00 PM', '08:00 PM'];
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Explore'), surfaceTintColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 150,
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.line)),
                child: const Center(child: Icon(Icons.sports_basketball_rounded, color: AppColors.lime, size: 65)),
              ),
              const SizedBox(height: 16),
              Row(children: [Text('Pak Basketball Court', style: Theme.of(context).textTheme.titleLarge), const Spacer(), const Icon(Icons.star_rounded, color: AppColors.lime, size: 18), const Text(' 4.5')]),
              const SizedBox(height: 4),
              const Text('Johar Town, Lahore', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(height: 18),
              Wrap(spacing: 7, children: days.map((d) => FilterPill(label: d, selected: _day == d, onTap: () => setState(() => _day = d))).toList()),
              const SizedBox(height: 18),
              const Text('Available Slots', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: times.map((t) => SizedBox(width: 150, child: FilterPill(label: t, selected: _time == t, onTap: () => setState(() => _time = t)))).toList(),
              ),
              const SizedBox(height: 18),
              const Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 9),
              Row(children: [Expanded(child: FilterPill(label: 'Cash', selected: true, onTap: () {})), const SizedBox(width: 9), Expanded(child: FilterPill(label: 'Online', selected: false, onTap: () {}))]),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
                child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Organizer Note', style: TextStyle(fontWeight: FontWeight.w700)), SizedBox(height: 5), Text('Please remember to bring your own equipment.', style: TextStyle(color: AppColors.textMuted, fontSize: 12))]),
              ),
              const Spacer(),
              PrimaryButton(label: 'Request Booking', onTap: () => _confirmBooking(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmBooking(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Booking requested'),
        content: Text('Your $_day $_time basketball slot has been sent to the organizer.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Great', style: TextStyle(color: AppColors.lime)))],
      ),
    );
  }
}

class CreateGamePage extends StatefulWidget {
  const CreateGamePage({super.key});

  @override
  State<CreateGamePage> createState() => _CreateGamePageState();
}

class _CreateGamePageState extends State<CreateGamePage> {
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 17, minute: 0);
  String _sport = 'Cricket';
  int _players = 11;
  String _payment = 'Cash';

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';
    return Scaffold(
      appBar: AppBar(backgroundColor: AppColors.background, title: const Text('Create Game'), surfaceTintColor: Colors.transparent),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const LabelText('Match Date'),
            const SizedBox(height: 7),
            Row(children: [Expanded(child: SelectionBox(icon: Icons.calendar_today_outlined, label: dateLabel, onTap: _pickDate)), const SizedBox(width: 10), Expanded(child: SelectionBox(icon: Icons.schedule_outlined, label: _time.format(context), onTap: _pickTime))]),
            const SizedBox(height: 16),
            const LabelText('Choose Sports'),
            const SizedBox(height: 7),
            DropdownButtonFormField<String>(
              value: _sport,
              dropdownColor: AppColors.surface,
              decoration: _formDecoration(),
              items: const ['Cricket', 'Basketball', 'Football', 'Badminton'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => _sport = v ?? _sport),
            ),
            const SizedBox(height: 16),
            const LabelText('Add Location'),
            const SizedBox(height: 7),
            SelectionBox(icon: Icons.location_on_outlined, label: 'Gulberg Cricket Ground', onTap: () => _showComingSoon(context, 'Venue picker is interactive in the full product.')),
            const SizedBox(height: 16),
            const LabelText('Required Players'),
            const SizedBox(height: 7),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: Row(children: [const Text('Slots to fill'), const Spacer(), IconButton(onPressed: _players > 2 ? () => setState(() => _players--) : null, icon: const Icon(Icons.remove_circle_outline)), Text('$_players'), IconButton(onPressed: () => setState(() => _players++), icon: const Icon(Icons.add_circle_outline))]),
            ),
            const SizedBox(height: 16),
            const LabelText('Entry Fee'),
            const SizedBox(height: 7),
            TextFormField(initialValue: '200', keyboardType: TextInputType.number, decoration: _formDecoration(prefix: const Text('Rs.  ', style: TextStyle(color: AppColors.lime)))),
            const SizedBox(height: 16),
            const LabelText('Payment Method'),
            const SizedBox(height: 7),
            Row(children: [Expanded(child: FilterPill(label: 'Cash', selected: _payment == 'Cash', onTap: () => setState(() => _payment = 'Cash'))), const SizedBox(width: 8), Expanded(child: FilterPill(label: 'Online', selected: _payment == 'Online', onTap: () => setState(() => _payment = 'Online')))]),
            const SizedBox(height: 16),
            const LabelText('Organizer Note'),
            const SizedBox(height: 7),
            TextFormField(maxLines: 3, initialValue: 'Splitting arena reservation cost evenly. Please remember to bring your own equipment.', decoration: _formDecoration()),
            const SizedBox(height: 22),
            PrimaryButton(label: 'Host game', onTap: () => _hostGame(context)),
          ]),
        ),
      ),
    );
  }

  InputDecoration _formDecoration({Widget? prefix}) => InputDecoration(
        prefixIcon: prefix,
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.surface)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.lime)),
      );

  void _hostGame(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Game hosted successfully. Join requests will appear in Activity.')));
    Future.delayed(const Duration(milliseconds: 650), () {
      if (mounted) Navigator.of(context).pop();
    });
  }
}

class LabelText extends StatelessWidget {
  const LabelText(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600));
}

class SelectionBox extends StatelessWidget {
  const SelectionBox({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
        child: Row(children: [Icon(icon, color: AppColors.textMuted, size: 18), const SizedBox(width: 9), Expanded(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12))), const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textMuted)]),
      ),
    );
  }
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key});
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  String _tab = 'Hosted';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Text('Activity', style: Theme.of(context).textTheme.headlineMedium), const Spacer(), IconButton(onPressed: () => _showComingSoon(context, 'Notifications are up to date.'), icon: const Icon(Icons.notifications_none_rounded))]),
            const SizedBox(height: 12),
            Row(children: ['Hosted', 'Joined', 'History'].map((item) => Padding(padding: const EdgeInsets.only(right: 7), child: FilterPill(label: item, selected: _tab == item, onTap: () => setState(() => _tab = item)))).toList()),
            const SizedBox(height: 16),
            if (_tab == 'Hosted') _HostedGameCard(onReview: () => _showRequests(context)) else Expanded(child: Center(child: Text(_tab == 'Joined' ? 'No joined games yet' : 'Your completed games will appear here', style: const TextStyle(color: AppColors.textMuted)))),
          ]),
        ),
      ),
    );
  }

  void _showRequests(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 48, height: 4, decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 18),
              Row(children: [Text('Join Requests', style: Theme.of(context).textTheme.titleLarge), const Spacer(), Text('${appState.requests.where((r) => r.status == RequestStatus.pending).length}', style: const TextStyle(color: AppColors.textMuted))]),
              const SizedBox(height: 14),
              ...appState.requests.map((request) => _RequestTile(
                    request: request,
                    onApprove: () {
                      appState.approve(request);
                      setModalState(() {});
                    },
                    onReject: () {
                      appState.reject(request);
                      setModalState(() {});
                    },
                  )),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HostedGameCard extends StatelessWidget {
  const _HostedGameCard({required this.onReview});
  final VoidCallback onReview;
  @override
  Widget build(BuildContext context) {
    final pending = appState.requests.where((r) => r.status == RequestStatus.pending).length;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FilterPill(label: '🏏 Cricket', selected: true, onTap: () {}),
        const SizedBox(height: 9),
        const Text('Gulberg Cricket Ground', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 5),
        const Text('Today · 12 Jun · 5:00 PM', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(height: 7),
        const Text('Participants:  K  W  2/11  9/11', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
        const Divider(color: AppColors.line, height: 22),
        Row(children: [Text('Join Requests:\n$pending pending', style: const TextStyle(fontSize: 11)), const Spacer(), SizedBox(width: 110, child: PrimaryButton(label: 'Review', compact: true, onTap: onReview))]),
      ]),
    );
  }
}

class _RequestTile extends StatelessWidget {
  const _RequestTile({required this.request, required this.onApprove, required this.onReject});
  final JoinRequest request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final pending = request.status == RequestStatus.pending;
    final statusText = request.status == RequestStatus.approved ? 'Approved' : request.status == RequestStatus.rejected ? 'Rejected' : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        CircleAvatar(radius: 20, backgroundColor: Colors.white12, child: Text(request.name.substring(0, 1))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(request.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text(request.sport, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)), Text('⚡ Reliability Score: ${request.reliability}', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)), if (pending) const SizedBox(height: 8), if (pending) Row(children: [Expanded(child: _MiniAction(label: 'Approve', positive: true, onTap: onApprove)), const SizedBox(width: 7), Expanded(child: _MiniAction(label: 'Reject', positive: false, onTap: onReject))]) else Padding(padding: const EdgeInsets.only(top: 6), child: Text(statusText!, style: TextStyle(fontSize: 11, color: request.status == RequestStatus.approved ? AppColors.lime : Colors.redAccent))),])),
      ]),
    );
  }
}

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.positive, required this.onTap});
  final String label;
  final bool positive;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: positive ? AppColors.lime : AppColors.danger, borderRadius: BorderRadius.circular(7)),
        child: Text(label, style: TextStyle(fontSize: 10, color: positive ? Colors.black : Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: appState,
          builder: (context, _) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Text('Profile', style: Theme.of(context).textTheme.headlineMedium), const Spacer(), IconButton(onPressed: () => _editUsername(context), icon: const Icon(Icons.edit_outlined)), IconButton(onPressed: () => _showComingSoon(context, 'No new notifications.'), icon: const Icon(Icons.notifications_none_rounded))]),
              const SizedBox(height: 12),
              Row(children: [const CircleAvatar(radius: 28, backgroundColor: AppColors.surfaceLight, child: Icon(Icons.person_rounded, size: 32)), const SizedBox(width: 12), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Afaq Bin Aamir', style: Theme.of(context).textTheme.titleMedium), Text('@${appState.username}', style: const TextStyle(color: AppColors.textMuted, fontSize: 12))])]),
              const SizedBox(height: 14),
              _ReliabilityCard(),
              const SizedBox(height: 12),
              const Row(children: [Expanded(child: _Stat(value: '11', label: 'Games')), SizedBox(width: 8), Expanded(child: _Stat(value: '3', label: 'Trophies')), SizedBox(width: 8), Expanded(child: _Stat(value: '4.8', label: 'Rating'))]),
              const SizedBox(height: 16),
              const Text('AI Features', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              _SwitchSetting(title: 'Prioritize Proximity', subtitle: 'Force AI to favor closest grounds', value: appState.prioritizeProximity, onChanged: (v) { appState.prioritizeProximity = v; appState.notifyListeners(); }),
              const SizedBox(height: 8),
              _SwitchSetting(title: 'Strict Reliability Match', subtitle: 'Only show top-tier trusted hosts', value: appState.strictReliability, onChanged: (v) { appState.strictReliability = v; appState.notifyListeners(); }),
              const SizedBox(height: 16),
              const Text('Sports Preferences', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: appState.selectedSports.map((s) => FilterPill(label: s, selected: true, onTap: () => appState.toggleSport(s))).toList()),
              const SizedBox(height: 18),
              _SwitchSetting(title: 'Notifications', subtitle: 'Game activity and nearby player alerts', value: appState.notifications, onChanged: (v) { appState.notifications = v; appState.notifyListeners(); }),
            ]),
          ),
        ),
      ),
    );
  }

  void _editUsername(BuildContext context) {
    final controller = TextEditingController(text: appState.username);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Edit username'),
        content: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Username')),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')), TextButton(onPressed: () { appState.updateUsername(controller.text); Navigator.of(context).pop(); }, child: const Text('Save', style: TextStyle(color: AppColors.lime)))],
      ),
    );
  }
}

class _ReliabilityCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [Row(children: [const Text('Reliability Score', style: TextStyle(color: AppColors.textMuted, fontSize: 11)), const Spacer(), Text('8.4', style: const TextStyle(color: AppColors.lime, fontWeight: FontWeight.w700))]), const SizedBox(height: 8), ClipRRect(borderRadius: BorderRadius.circular(4), child: const LinearProgressIndicator(value: .84, backgroundColor: AppColors.line, color: AppColors.lime, minHeight: 4))]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Column(children: [Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))]),
    );
  }
}

class _SwitchSetting extends StatelessWidget {
  const _SwitchSetting({required this.title, required this.subtitle, required this.value, required this.onChanged});
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 9, 7, 9),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12)),
      child: Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)), const SizedBox(height: 3), Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 10))])), Switch(value: value, activeColor: AppColors.lime, onChanged: onChanged)]),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onTap, this.compact = false});
  final String label;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: compact ? 33 : 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(compact ? 9 : 15)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: compact ? 11 : 13)), if (!compact) ...[const Spacer(), Container(width: 25, height: 25, decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_rounded, size: 16))]]),
      ),
    );
  }
}

class SocialButton extends StatelessWidget {
  const SocialButton({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: AppColors.lime, size: 22),
        label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
        style: OutlinedButton.styleFrom(backgroundColor: AppColors.surface, side: const BorderSide(color: AppColors.surface), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11))),
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
}
