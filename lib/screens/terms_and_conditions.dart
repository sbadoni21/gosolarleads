import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gosolarleads/theme/app_theme.dart';

class TermsAndConditions extends StatefulWidget {
  const TermsAndConditions({super.key});

  @override
  State<TermsAndConditions> createState() => _TermsAndConditionsState();
}

class _TermsAndConditionsState extends State<TermsAndConditions> {
  final TextEditingController _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: true,
        title: const Text('Terms and Conditions'),
        centerTitle: true,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FBFF), Color(0xFFF6FFFA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero / Title
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Terms & Conditions', style: txt.displaySmall),
                          const SizedBox(height: 6),
                          Text(
                            'Welcome to GoSol. By using our website or mobile applications, you agree to abide by these Terms & Conditions.',
                            style: txt.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Terms Sections
                  _SectionCard(
                    title: 'Use of Services',
                    icon: Icons.gavel_outlined,
                    child: Text(
                      'You agree to use our platform only for lawful purposes. You may not misuse our services for fraudulent, '
                      'harmful, or unauthorized activities.',
                      style: txt.bodyLarge,
                    ),
                  ),
                  _SectionCard(
                    title: 'User Accounts',
                    icon: Icons.person_outline,
                    child: Text(
                      'You are responsible for maintaining the confidentiality of your account information, including your password. '
                      'Any activity under your account will be considered your responsibility.',
                      style: txt.bodyLarge,
                    ),
                  ),
                  _SectionCard(
                    title: 'Intellectual Property',
                    icon: Icons.workspace_premium_outlined,
                    child: Text(
                      'All content, logos, trademarks, and materials on our platform are the property of GoSol and may not be copied, '
                      'reproduced, or distributed without written consent.',
                      style: txt.bodyLarge,
                    ),
                  ),
                  _SectionCard(
                    title: 'Limitation of Liability',
                    icon: Icons.shield_moon_outlined,
                    child: Text(
                      'While we strive to provide accurate and reliable services, GoSol is not liable for any indirect, incidental, or '
                      'consequential damages that may arise from the use of our services.',
                      style: txt.bodyLarge,
                    ),
                  ),
                  _SectionCard(
                    title: 'Changes to Terms',
                    icon: Icons.update_outlined,
                    child: Text(
                      'We may update these Terms & Conditions as necessary. Your continued use of our platform implies acceptance of the revised terms.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  // Help CTA
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Have Questions? We’re Here to Help!',
                              style: txt.headlineLarge),
                          const SizedBox(height: 8),
                          Text(
                            'goSolar is one of the world’s leading renewable energy solutions provider.',
                            style: txt.bodyLarge,
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _GradientButton(
                                label: 'Learn More',
                                onPressed: () {},
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.support_agent_outlined),
                                label: const Text('Contact Support'),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Two-column: Contact + Latest News (no Expanded on narrow)
                  LayoutBuilder(
                    builder: (context, c) {
                      final isWide = c.maxWidth >= 900;

                      if (isWide) {
                        // Wide screens: Row with Expanded is fine (bounded vertically).
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SectionCard(
                                title: 'Contact Us',
                                icon: Icons.place_outlined,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: const [
                                    _ContactLine(
                                      icon: Icons.location_on_outlined,
                                      text:
                                          'B-36, Nehru Colony, Dalanwala, Dehradun – 248001, Uttarakhand, INDIA',
                                    ),
                                    _ContactLine(
                                      icon: Icons.email_outlined,
                                      text: 'contact@gosol.in',
                                      copyable: true,
                                    ),
                                    _ContactLine(
                                      icon: Icons.phone_outlined,
                                      text: '+91 9997154360',
                                      copyable: true,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _SectionCard(
                                title: 'Latest News',
                                icon: Icons.newspaper_outlined,
                                child: Column(
                                  children: const [
                                    _NewsItem(
                                        title:
                                            'Best Solar Energy Stocks For 2024'),
                                    _NewsItem(
                                        title:
                                            '4kw solar panel price in India'),
                                    _NewsItem(
                                        title:
                                            'Monocrystalline Solar Panel Prices in India'),
                                    _NewsItem(
                                        title:
                                            'Affordable Hybrid Solar System Prices in India'),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      }

                      // Narrow screens: Column without Expanded (safe in scroll view).
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _SectionCard(
                            title: 'Contact Us',
                            icon: Icons.place_outlined,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                _ContactLine(
                                  icon: Icons.location_on_outlined,
                                  text:
                                      'B-36, Nehru Colony, Dalanwala, Dehradun – 248001, Uttarakhand, INDIA',
                                ),
                                _ContactLine(
                                  icon: Icons.email_outlined,
                                  text: 'contact@gosol.in',
                                  copyable: true,
                                ),
                                _ContactLine(
                                  icon: Icons.phone_outlined,
                                  text: '+91 9997154360',
                                  copyable: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  // Footer copyright
                  Center(
                    child: Text(
                      'Copyright 2024 © Go Solar 2025',
                      style: txt.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: SizedBox(
            height: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- Top Nav Bar ---------- */
class _TopNavBar extends StatelessWidget {
  final void Function(String route) onTapItem;
  const _TopNavBar({required this.onTapItem});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 0,
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Logo
                  Container(
                    width: 44,
                    height: 44,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                    ),
                    alignment: Alignment.center,
                    child: ClipOval(
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Image.asset(
                          'assets/gosol_logo.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.solar_power_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'GoSol',
                    style: Theme.of(context)
                        .textTheme
                        .headlineLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  // Menu
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ---------- Shared UI ---------- */
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: txt.headlineLarge)),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContactLine extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool copyable;
  const _ContactLine({
    required this.icon,
    required this.text,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: txt.bodyLarge)),
          if (copyable)
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_all_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Copied to clipboard')),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _NewsItem extends StatelessWidget {
  final String title;
  const _NewsItem({required this.title});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.chevron_right),
      title: Text(title, style: txt.bodyLarge),
      onTap: () {},
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  const _FooterLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: onTap, child: Text(text));
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _GradientButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onPressed,
      child: Ink(
        decoration: AppTheme.gradientButtonDecoration,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        child: Text(
          label,
          style: txt.titleLarge?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}
