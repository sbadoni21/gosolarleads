import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gosolarleads/theme/app_theme.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
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
            constraints: const BoxConstraints(maxWidth: 920),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header / Logo + Title
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                      child: Row(
                        children: [
                          // Logo (replace with your asset)
                          Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: AppTheme.primaryGradient,
                            ),
                            alignment: Alignment.center,
                            child: ClipOval(
                              child: SizedBox(
                                width: 48,
                                height: 48,
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
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('GoSolar India Privacy Policy',
                                    style: txt.displaySmall),
                                const SizedBox(height: 4),
                                Text(
                                  'We respect your privacy and are committed to protecting your personal data.',
                                  style: txt.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Intro
                  _SectionCard(
                    title: 'Overview',
                    icon: Icons.verified_user_outlined,
                    child: Text(
                      'GoSolar India (“we”, “our”, “us”) respects your privacy and is committed to protecting your personal data. '
                      'This Privacy Policy explains how we collect, use, and safeguard your information when you use our website or mobile applications.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  // Information We Collect
                  _SectionCard(
                    title: 'Information We Collect',
                    icon: Icons.folder_shared_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Bullet(
                            'Personal information such as name, email address, phone number, payment details, and delivery information.'),
                        _Bullet(
                            'Non-personal information such as device type, IP address, and browsing behavior.'),
                      ],
                    ),
                  ),

                  // How We Use Information
                  _SectionCard(
                    title: 'How We Use Information',
                    icon: Icons.insights_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Bullet(
                            'Provide and improve our services and complete transactions.'),
                        _Bullet(
                            'Respond to queries and send updates about products or services.'),
                        _Bullet(
                            'Use aggregated data for analytics and service improvements.'),
                      ],
                    ),
                  ),

                  // Data Sharing
                  _SectionCard(
                    title: 'Data Sharing',
                    icon: Icons.share_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        _Bullet('We do not sell your data.'),
                        _Bullet(
                            'Limited sharing may occur with trusted service providers (payment processors, logistics partners, analytics tools) solely to deliver our services.'),
                      ],
                    ),
                  ),

                  // Your Rights
                  _SectionCard(
                    title: 'Your Rights',
                    icon: Icons.privacy_tip_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _Bullet(
                            'Request access, correction, or deletion of your personal information at any time.'),
                        const SizedBox(height: 8),
                        _CopyableRow(
                          label: 'Contact',
                          value: 'support@GoSolar India.in',
                          icon: Icons.email_outlined,
                        ),
                      ],
                    ),
                  ),

                  // Policy Updates
                  _SectionCard(
                    title: 'Policy Updates',
                    icon: Icons.update_outlined,
                    child: Text(
                      'We may update this policy periodically. Continued use of our services indicates your acceptance of the updated policy.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  // Help / CTA
                  Card(
                    elevation: 0,
                    color: Colors.white,
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
                            'goSolar is one of the world’s leading renewable energy solutions providers.',
                            style: txt.bodyLarge,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _GradientButton(
                                label: 'Learn More',
                                onPressed: () {},
                              ),
                              OutlinedButton.icon(
                                icon: const Icon(Icons.headset_mic_outlined),
                                label: const Text('Contact Us'),
                                onPressed: () {},
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Contact Card
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
                          text: 'contact@GoSolar India.in',
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

                  // Newsletter / Email capture (non-functional demo)
                  Card(
                    elevation: 0,
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Your Email', style: txt.titleLarge),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.alternate_email),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "*Don't worry, we don't spam.",
                            style: txt.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send_outlined),
                              label: const Text('Subscribe'),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Thanks! We’ll keep you posted at ${_emailController.text.trim().isEmpty ? 'your email' : _emailController.text.trim()}.',
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Footer Links
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _FooterLink(text: 'Privacy Policy', onTap: () {}),
                      _FooterLink(text: 'Terms and Conditions', onTap: () {}),
                      _FooterLink(text: 'Return Policy', onTap: () {}),
                      _FooterLink(text: 'Refund Policy', onTap: () {}),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Copyright
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

/// Section Card with title + icon
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
      color: Colors.white,
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
              Expanded(
                child: Text(title, style: txt.headlineLarge),
              ),
            ]),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Bullet point line
class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Icon(Icons.check_circle_outline, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: txt.bodyLarge)),
        ],
      ),
    );
  }
}

/// Contact line with optional copy-to-clipboard
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

/// Copyable field row used in rights section
class _CopyableRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _CopyableRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Text('$label: ', style: txt.titleMedium),
          Expanded(
            child: Text(value, style: txt.bodyLarge),
          ),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Email copied')),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Gradient primary button
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

/// Footer link (text button style)
class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _FooterLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      child: Text(text),
    );
  }
}
