import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../admin/admin_home_screen.dart';

class RegisterEmployerScreen extends StatefulWidget {
  const RegisterEmployerScreen({super.key});

  @override
  State<RegisterEmployerScreen> createState() => _RegisterEmployerScreenState();
}

class _RegisterEmployerScreenState extends State<RegisterEmployerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _companyNameController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  int _currentStep = 0;
  DateTime? _birthDate;

  final DateFormat _dateFmt = DateFormat('dd.MM.yyyy');

  @override
  void dispose() {
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 16),
      helpText: 'Datum rođenja',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: AppColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registerEmployer(
      name: _nameController.text,
      surname: _surnameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      companyName: _companyNameController.text,
      birthDate: _birthDate,
    );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminHomeScreen()),
        (route) => false,
      );
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (_nameController.text.isEmpty ||
          _surnameController.text.isEmpty ||
          _emailController.text.isEmpty ||
          _phoneController.text.isEmpty ||
          _passwordController.text.isEmpty ||
          _confirmPasswordController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Popunite sva polja')),
        );
        return;
      }
      if (_passwordController.text != _confirmPasswordController.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lozinke se ne poklapaju'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      setState(() => _currentStep = 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registracija — Poslodavac'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() => _currentStep--);
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step indicator
                Row(
                  children: [
                    _StepDot(isActive: _currentStep >= 0, label: '1'),
                    Expanded(
                      child: Container(
                        height: 2,
                        color: _currentStep >= 1
                            ? AppColors.primary
                            : AppColors.dividerLight,
                      ),
                    ),
                    _StepDot(isActive: _currentStep >= 1, label: '2'),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lični podaci', style: theme.textTheme.bodyMedium),
                    Text('Podaci o firmi', style: theme.textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(height: 28),

                if (authProvider.errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      authProvider.errorMessage!,
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.error),
                    ),
                  ),

                // ─── Step 0 ────────────────────────────────────────────────────
                if (_currentStep == 0) ...[
                  Text('Vaši podaci', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Ovi podaci će biti prikazani vašem timu.',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),

                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(hintText: 'Ime'),
                          textInputAction: TextInputAction.next,
                          validator: (v) => v!.isEmpty ? 'Obavezno' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _surnameController,
                          textCapitalization: TextCapitalization.words,
                          decoration:
                              const InputDecoration(hintText: 'Prezime'),
                          textInputAction: TextInputAction.next,
                          validator: (v) => v!.isEmpty ? 'Obavezno' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Datum rođenja
                  GestureDetector(
                    onTap: _pickBirthDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.inputFillDark
                            : AppColors.inputFillLight,
                        borderRadius: BorderRadius.circular(14),
                        border: _birthDate != null
                            ? Border.all(color: AppColors.primary, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.cake_outlined,
                              size: 20, color: AppColors.primary),
                          const SizedBox(width: 12),
                          Text(
                            _birthDate != null
                                ? _dateFmt.format(_birthDate!)
                                : 'Datum rođenja (opciono)',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: _birthDate != null
                                  ? null
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      hintText: 'Email adresa',
                      prefixIcon: Icon(Icons.email_outlined,
                          size: 20, color: AppColors.primary),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Obavezno polje';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                        return 'Neispravan email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      hintText: 'Broj telefona',
                      prefixIcon: Icon(Icons.phone_outlined,
                          size: 20, color: AppColors.primary),
                    ),
                    validator: (v) => v!.isEmpty ? 'Obavezno' : null,
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'Lozinka (min. 6 karaktera)',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          size: 20, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Obavezno';
                      if (v.length < 6) return 'Minimum 6 karaktera';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      hintText: 'Potvrdi lozinku',
                      prefixIcon: const Icon(Icons.lock_outline_rounded,
                          size: 20, color: AppColors.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 20),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (v) {
                      if (v!.isEmpty) return 'Obavezno';
                      if (v != _passwordController.text) {
                        return 'Lozinke se ne poklapaju';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 28),

                  ElevatedButton(
                    onPressed: _nextStep,
                    child: const Text('Nastavi'),
                  ),
                ],

                // ─── Step 1 ────────────────────────────────────────────────────
                if (_currentStep == 1) ...[
                  Text('Vaša firma', style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 4),
                  Text('Kreiraćemo firmu i generisati jedinstveni ID za vas.',
                      style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _companyNameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      hintText: 'Naziv firme (npr. Restoran Galeb)',
                      prefixIcon: Icon(Icons.business_rounded,
                          size: 20, color: AppColors.primary),
                    ),
                    validator: (v) => v!.isEmpty ? 'Unesite naziv firme' : null,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.infoLight,
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.info.withOpacity(0.25)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.info, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '• Dobićete 15-karakterni ID za firmu\n'
                            '• Podelite ID sa radnicima da se pridruže\n'
                            '• ID možete kopirati u Podešavanjima',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: AppColors.info, height: 1.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton(
                    onPressed: authProvider.isLoading ? null : _handleRegister,
                    child: authProvider.isLoading
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : const Text('Kreiraj nalog i firmu'),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StepDot extends StatelessWidget {
  final bool isActive;
  final String label;
  const _StepDot({required this.isActive, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.dividerLight,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textSecondaryLight,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
