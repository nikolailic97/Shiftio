import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import '../../providers/request_provider.dart';
import '../auth/login_screen.dart';
import '../admin/export_screen.dart';
import '../admin/leave_policy_screen.dart';
import '../../../main.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isSendingTicket = false;

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Odjavi se'),
        content: const Text('Da li ste sigurni da se želite odjaviti?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Odjavi se'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await context.read<AuthProvider>().logout();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _openSupportDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Podrška'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Opišite problem ili sugestiju:'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Vaša poruka...'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              setState(() => _isSendingTicket = true);
              final user = context.read<AuthProvider>().currentUser;
              if (user != null) {
                try {
                  await context.read<RequestProvider>().sendSupportTicket(
                        userId: user.uid,
                        message: controller.text.trim(),
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Poruka je poslata. Hvala!'),
                        backgroundColor: AppColors.success,
                      ),
                    );
                  }
                } catch (_) {}
              }
              if (mounted) setState(() => _isSendingTicket = false);
            },
            child: const Text('Pošalji'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  void _toggleTheme() {
    try {
      ShiftioApp.of(context).toggleTheme();
    } catch (_) {}
  }

  bool get _isDarkMode {
    try {
      return ShiftioApp.of(context).isDarkMode;
    } catch (_) {
      return Theme.of(context).brightness == Brightness.dark;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // ─── Dohvati providere sigurno ────────────────────────────────────────────
    final user = context.watch<AuthProvider>().currentUser;

    if (user == null) {
      return const Scaffold(
        body:
            Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    // CompanyProvider — može biti nedostupan za neke konfiguracije
    CompanyProvider? companyProvider;
    try {
      companyProvider = context.watch<CompanyProvider>();
    } catch (_) {}

    final company = companyProvider?.company;
    final avatarColor = AppColors
        .avatarColors[user.uid.hashCode.abs() % AppColors.avatarColors.length];

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            const SizedBox(height: 16),

            // ─── Header ───────────────────────────────────────────────────────
            Text('Profil', style: theme.textTheme.displayMedium),
            const SizedBox(height: 24),

            // ─── Avatar + Info ────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          color: avatarColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: avatarColor.withOpacity(0.4),
                              blurRadius: 20,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            user.initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.backgroundDark
                                  : AppColors.backgroundLight,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(user.fullName, style: theme.textTheme.headlineLarge),
                  const SizedBox(height: 4),
                  Text(user.email, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: _roleColor(user.role).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _roleLabel(user.role),
                      style: TextStyle(
                        color: _roleColor(user.role),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // ─── Company ID (samo admin) ───────────────────────────────────────
            if (user.isAdmin && company != null) ...[
              _SectionTitle(label: 'Firma'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.business_rounded,
                label: company.name,
                subtitle: 'Naziv firme',
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: company.inviteCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ID firme je kopiran!'),
                      backgroundColor: AppColors.success,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key_rounded,
                          color: AppColors.primary, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID firme',
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: AppColors.primary)),
                            Text(
                              company.inviteCode,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: AppColors.primary,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.copy_rounded,
                          color: AppColors.primary, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // ─── Export (samo admin) ───────────────────────────────────────────
            if (user.isAdmin) ...[
              _SectionTitle(label: 'Firma'),
              const SizedBox(height: 10),
              _SettingsTile(
                icon: Icons.beach_access_rounded,
                label: 'Politika odmora',
                subtitle: 'Postavi kvote odmora za firmu',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const LeavePolicyScreen(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _SettingsTile(
                icon: Icons.download_rounded,
                label: 'Export podataka',
                subtitle: 'Excel / CSV izvještaj o radu',
                onTap: () {
                  try {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MultiProvider(
                          providers: [
                            ChangeNotifierProvider.value(
                                value: context.read<AuthProvider>()),
                            ChangeNotifierProvider.value(
                                value: context.read<CompanyProvider>()),
                          ],
                          child: const ExportScreen(),
                        ),
                      ),
                    );
                  } catch (_) {}
                },
              ),
              const SizedBox(height: 24),
            ],

            // ─── Podešavanja ──────────────────────────────────────────────────
            _SectionTitle(label: 'Podešavanja'),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.cardDark : AppColors.cardLight,
                borderRadius: BorderRadius.circular(14),
              ),
              child: SwitchListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dark_mode_rounded,
                      color: AppColors.primary, size: 20),
                ),
                title: Text('Tamni mod', style: theme.textTheme.titleLarge),
                subtitle: Text(
                  _isDarkMode ? 'Uključen' : 'Isključen',
                  style: theme.textTheme.bodySmall,
                ),
                value: _isDarkMode,
                onChanged: (_) {
                  _toggleTheme();
                  setState(() {});
                },
              ),
            ),

            const SizedBox(height: 24),

            // ─── Podrška ──────────────────────────────────────────────────────
            _SectionTitle(label: 'Podrška'),
            const SizedBox(height: 10),

            _SettingsTile(
              icon: Icons.bug_report_outlined,
              label: 'Prijavi grešku / Sugestija',
              trailing: _isSendingTicket
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.primary))
                  : null,
              onTap: _isSendingTicket ? null : _openSupportDialog,
            ),

            const SizedBox(height: 24),

            // ─── Odjava ───────────────────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _handleLogout,
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text('Odjavi se'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return AppColors.adminColor;
      case UserRole.manager:
        return AppColors.managerColor;
      default:
        return AppColors.workerColor;
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'Admin / Poslodavac';
      case UserRole.manager:
        return 'Menadžer';
      default:
        return 'Radnik';
    }
  }
}

// ─── Section Title ────────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textSecondaryLight,
          ),
    );
  }
}

// ─── Settings Tile ────────────────────────────────────────────────────────────
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: theme.textTheme.titleLarge),
                    if (subtitle != null)
                      Text(subtitle!, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              trailing ??
                  (onTap != null
                      ? Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        )
                      : const SizedBox.shrink()),
            ],
          ),
        ),
      ),
    );
  }
}
