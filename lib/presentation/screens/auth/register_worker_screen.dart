import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/id_generator.dart';
import '../../../data/models/company_model.dart';
import '../worker/worker_home_screen.dart';

class RegisterWorkerScreen extends StatefulWidget {
  const RegisterWorkerScreen({super.key});

  @override
  State<RegisterWorkerScreen> createState() => _RegisterWorkerScreenState();
}

class _RegisterWorkerScreenState extends State<RegisterWorkerScreen> {
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _surnameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  int _currentStep = 0; // 0 = unos koda, 1 = lični podaci
  CompanyModel? _validatedCompany;
  bool _isValidatingCode = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _surnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _validateCode() async {
    final code = _codeController.text.trim().toUpperCase();

    if (code.isEmpty) {
      _showError('Unesite kod firme.');
      return;
    }

    setState(() => _isValidatingCode = true);

    final authProvider = context.read<AuthProvider>();
    final company = await authProvider.validateCompanyCode(code);

    setState(() => _isValidatingCode = false);

    if (company == null) {
      _showError(
          'Firma sa ovim kodom nije pronađena.\nProvjerite kod i pokušajte ponovo.');
      return;
    }

    setState(() {
      _validatedCompany = company;
      _currentStep = 1;
    });
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Lozinke se ne poklapaju');
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registerWorker(
      name: _nameController.text,
      surname: _surnameController.text,
      email: _emailController.text,
      phone: _phoneController.text,
      password: _passwordController.text,
      companyId: _validatedCompany!.companyId,
    );

    if (success && mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
        (route) => false,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registracija — Radnik'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (_currentStep > 0) {
              setState(() {
                _currentStep = 0;
                _validatedCompany = null;
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Step Indicator ─────────────────────────────────────────────
              Row(
                children: [
                  _StepDot(isActive: true, label: '1'),
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
                  Text('Kod firme', style: theme.textTheme.bodyMedium),
                  Text('Vaši podaci', style: theme.textTheme.bodyMedium),
                ],
              ),

              const SizedBox(height: 32),

              // ─── Step 0: Unos koda ───────────────────────────────────────────
              if (_currentStep == 0) ...[
                Text(
                  'Unesite kod firme',
                  style: theme.textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Zatražite ovaj kod od vašeg poslodavca ili menadžera.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),

                // Code Input
                TextFormField(
                  controller: _codeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 3,
                  ),
                  decoration: InputDecoration(
                    hintText: 'SHFT-XXX-XXX-XXX',
                    hintStyle: TextStyle(
                      fontSize: 18,
                      letterSpacing: 2,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 20,
                    ),
                  ),
                  inputFormatters: [
                    _UpperCaseFormatter(),
                  ],
                ),

                const SizedBox(height: 32),

                ElevatedButton(
                  onPressed: _isValidatingCode ? null : _validateCode,
                  child: _isValidatingCode
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Potvrdi kod'),
                ),
              ],

              // ─── Step 1: Lični Podaci ────────────────────────────────────────
              if (_currentStep == 1 && _validatedCompany != null) ...[
                // Company confirmed banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.success.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Firma pronađena!',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                            Text(
                              _validatedCompany!.name,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                Text(
                  'Vaši podaci',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'Ovi podaci će biti vidljivi vašem poslodavcu.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),

                // Error
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

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration:
                                  const InputDecoration(hintText: 'Ime'),
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
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v!.isEmpty) return 'Obavezno';
                          if (v.length < 6) return 'Min. 6 karaktera';
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
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscureConfirm = !_obscureConfirm),
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
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text('Kreiraj nalog'),
                ),
              ],

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Uppercase Formatter ──────────────────────────────────────────────────────
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

// ─── Step Dot ─────────────────────────────────────────────────────────────────
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
