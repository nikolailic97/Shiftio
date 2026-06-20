import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../data/models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/company_provider.dart';
import 'worker_detail_screen.dart';

class AdminTeamScreen extends StatelessWidget {
  const AdminTeamScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final team = context.watch<CompanyProvider>().team;
    final currentUser = context.watch<AuthProvider>().currentUser;

    // Isključi trenutnog korisnika iz liste
    final otherMembers = team.where((m) => m.uid != currentUser?.uid).toList();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tim', style: theme.textTheme.displayMedium),
                  Text(
                    '${otherMembers.length} ${_memberLabel(otherMembers.length)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // ─── Team List ─────────────────────────────────────────────────────
            Expanded(
              child: otherMembers.isEmpty
                  ? _EmptyTeam()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: otherMembers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) => _TeamMemberCard(
                        member: otherMembers[i],
                        currentUserIsAdmin: currentUser?.isAdmin ?? false,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => WorkerDetailScreen(
                              worker: otherMembers[i],
                            ),
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

  String _memberLabel(int count) {
    if (count == 1) return 'član';
    if (count >= 2 && count <= 4) return 'člana';
    return 'članova';
  }
}

// ─── Team Member Card ─────────────────────────────────────────────────────────
class _TeamMemberCard extends StatelessWidget {
  final UserModel member;
  final bool currentUserIsAdmin;
  final VoidCallback? onTap;

  const _TeamMemberCard({
    required this.member,
    required this.currentUserIsAdmin,
    this.onTap,
  });

  Color get _avatarColor => AppColors
      .avatarColors[member.uid.hashCode.abs() % AppColors.avatarColors.length];

  Color get _roleColor {
    switch (member.role) {
      case UserRole.manager:
        return AppColors.managerColor;
      case UserRole.admin:
        return AppColors.adminColor;
      default:
        return AppColors.workerColor;
    }
  }

  String get _roleLabel {
    switch (member.role) {
      case UserRole.manager:
        return 'Menadžer';
      case UserRole.admin:
        return 'Admin';
      default:
        return 'Radnik';
    }
  }

  Future<void> _handleRoleToggle(BuildContext context) async {
    final companyProvider = context.read<CompanyProvider>();
    final isManager = member.role == UserRole.manager;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            isManager ? 'Ukloni ulogu menadžera' : 'Dodeli ulogu menadžera'),
        content: Text(
          isManager
              ? '${member.fullName} više neće moći da upravlja rasporedima.'
              : '${member.fullName} će moći da kreira raspored i odobrava zahteve.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Otkaži'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              minimumSize: Size.zero,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isManager ? 'Ukloni' : 'Dodeli'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (isManager) {
        await companyProvider.revokeManagerRole(member.uid);
      } else {
        await companyProvider.assignManagerRole(member.uid);
      }
    }
  }

  Future<void> _handleRemove(BuildContext context) async {
    final companyProvider = context.read<CompanyProvider>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Ukloni iz firme'),
        content: Text(
          'Da li ste sigurni da želite da uklonite ${member.fullName} iz firme?\n\nOvaj radnik više neće imati pristup Shiftio nalogu firme.',
        ),
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
            child: const Text('Ukloni'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await companyProvider.removeWorker(member.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _avatarColor,
                shape: BoxShape.circle,
              ),
              child: member.profileImageUrl != null
                  ? ClipOval(
                      child: Image.network(
                        member.profileImageUrl!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: Text(
                        member.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.fullName, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 2),
                  Text(member.email, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  // Role badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _roleColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _roleLabel,
                      style: TextStyle(
                        color: _roleColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Actions (samo Admin može)
            if (currentUserIsAdmin && member.role != UserRole.admin)
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'role',
                    child: Row(
                      children: [
                        Icon(
                          member.role == UserRole.manager
                              ? Icons.person_remove_rounded
                              : Icons.manage_accounts_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          member.role == UserRole.manager
                              ? 'Ukloni menadžera'
                              : 'Dodeli menadžera',
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: const [
                        Icon(
                          Icons.person_off_rounded,
                          size: 18,
                          color: AppColors.error,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Ukloni iz firme',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                ],
                onSelected: (value) {
                  if (value == 'role') _handleRoleToggle(context);
                  if (value == 'remove') _handleRemove(context);
                },
              ),
          ],
        ),
      ), // Container
    ); // GestureDetector
  }
}

// ─── Empty Team ───────────────────────────────────────────────────────────────
class _EmptyTeam extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.group_outlined,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text('Nema članova tima', style: theme.textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            'Podelite ID firme sa radnicima',
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
