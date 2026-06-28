import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../admin/admin_home_screen.dart';

/// Onboarding wizard za novog admina — prikazuje se odmah posle
/// uspešne registracije firme. 4 koraka, svaki sa "Preskoči" opcijom.
class OnboardingScreen extends StatefulWidget {
  final String companyId;
  final String inviteCode;

  const OnboardingScreen({
    super.key,
    required this.companyId,
    required this.inviteCode,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _codeCopied = false;

  static const int _totalPages = 4;

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  void _finish() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
      (route) => false,
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.inviteCode));
    setState(() => _codeCopied = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _codeCopied = false);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = context.read<AuthProvider>().currentUser;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ─── Progress bar + Skip ────────────────────────────────────────
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (_currentPage + 1) / _totalPages,
                        backgroundColor: AppColors.primary.withOpacity(0.15),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AppColors.primary),
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    onPressed: _finish,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      'Preskoči',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ─── Stranice ──────────────────────────────────────────────────
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Stranica 1 — Dobrodošlica
                  _OnboardingPage(
                    icon: Icons.waving_hand_rounded,
                    iconColor: const Color(0xFFFFB300),
                    title: 'Dobrodošli u Shiftio!',
                    subtitle:
                        'Postavićemo vašu firmu za 2 minuta.\n'
                        'Pratite ove korake da biste krenuli.',
                    content: Column(
                      children: [
                        _FeatureRow(
                          icon: Icons.calendar_month_rounded,
                          color: AppColors.primary,
                          label: 'Kreirajte raspored smena',
                        ),
                        _FeatureRow(
                          icon: Icons.group_rounded,
                          color: AppColors.info,
                          label: 'Pozovite radnike u tim',
                        ),
                        _FeatureRow(
                          icon: Icons.beach_access_rounded,
                          color: AppColors.success,
                          label: 'Odobravajte zahteve za odmor',
                        ),
                        _FeatureRow(
                          icon: Icons.bar_chart_rounded,
                          color: AppColors.adminColor,
                          label: 'Pratite radne sate (Pro plan)',
                        ),
                      ],
                    ),
                    buttonLabel: 'Počnimo!',
                    onNext: _nextPage,
                  ),

                  // Stranica 2 — Invite code
                  _OnboardingPage(
                    icon: Icons.key_rounded,
                    iconColor: AppColors.primary,
                    title: 'Pozovite radnike',
                    subtitle:
                        'Podelite ovaj kod vašim radnicima.\n'
                        'Oni će ga uneti pri registraciji.',
                    content: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'ID vaše firme',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.inviteCode,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: AppColors.primary,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ElevatedButton.icon(
                                onPressed: _copyCode,
                                icon: Icon(
                                  _codeCopied
                                      ? Icons.check_rounded
                                      : Icons.copy_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                    _codeCopied ? 'Kopirano!' : 'Kopiraj kod'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _codeCopied
                                      ? AppColors.success
                                      : AppColors.primary,
                                  minimumSize: Size.zero,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Ovaj kod možete uvek naći u Profil → ID firme',
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                    buttonLabel: 'Nastavi',
                    onNext: _nextPage,
                  ),

                  // Stranica 3 — Prva smena
                  _OnboardingPage(
                    icon: Icons.add_circle_outline_rounded,
                    iconColor: AppColors.success,
                    title: 'Kreirajte prvu smenu',
                    subtitle:
                        'Odaberite datum, radnika i vreme.\n'
                        'Radnik će odmah dobiti obaveštenje.',
                    content: Column(
                      children: [
                        _StepRow(
                          step: '1',
                          label: 'Idite na Raspored (donji meni)',
                        ),
                        _StepRow(
                          step: '2',
                          label: 'Odaberite željeni datum',
                        ),
                        _StepRow(
                          step: '3',
                          label: 'Pritisnite + dugme ili "Dodaj smenu"',
                        ),
                        _StepRow(
                          step: '4',
                          label: 'Izaberite radnika, vreme i trajanje',
                        ),
                      ],
                    ),
                    buttonLabel: 'Nastavi',
                    onNext: _nextPage,
                  ),

                  // Stranica 4 — Gotovo
                  _OnboardingPage(
                    icon: Icons.celebration_rounded,
                    iconColor: AppColors.adminColor,
                    title: 'Sve je postavljeno!',
                    subtitle:
                        'Vaša firma "${user?.fullName ?? ''}" je spremna.\n'
                        'Možete početi sa upravljanjem.',
                    content: Column(
                      children: [
                        _FeatureRow(
                          icon: Icons.check_circle_rounded,
                          color: AppColors.success,
                          label: 'Firma je kreirana',
                        ),
                        _FeatureRow(
                          icon: AppColors.success != null
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          color: AppColors.success,
                          label: 'ID firme ste kopirali',
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.infoLight,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppColors.info.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_outline_rounded,
                                  color: AppColors.info, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Savet: Podesite politiku odmora u '
                                  'Profil → Politika odmora pre nego što '
                                  'radnici počnu da podnose zahteve.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.info,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    buttonLabel: 'Idemo!',
                    onNext: _finish,
                  ),
                ],
              ),
            ),

            // ─── Dot indikatori ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _totalPages,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? AppColors.primary
                          : AppColors.primary.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Onboarding stranica ──────────────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget content;
  final String buttonLabel;
  final VoidCallback onNext;

  const _OnboardingPage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.buttonLabel,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 16),

          // Ikonica
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 40),
          ),
          const SizedBox(height: 20),

          // Naslov
          Text(
            title,
            style: theme.textTheme.headlineLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Podnaslov
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Sadržaj
          Expanded(child: SingleChildScrollView(child: content)),
          const SizedBox(height: 20),

          // Dugme
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: Text(buttonLabel),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Pomoćni widgeti ──────────────────────────────────────────────────────────

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _FeatureRow({
    required this.icon,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: theme.textTheme.titleLarge)),
        ],
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String step;
  final String label;

  const _StepRow({required this.step, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: theme.textTheme.titleLarge)),
        ],
      ),
    );
  }
}