import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gosolarleads/theme/app_theme.dart';

class ReturnPolicyPage extends StatefulWidget {
  const ReturnPolicyPage({super.key});

  @override
  State<ReturnPolicyPage> createState() => _ReturnPolicyPageState();
}

class _ReturnPolicyPageState extends State<ReturnPolicyPage> {
  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Return Policy'),
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
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero / Intro
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
                          Text('Return Policy', style: txt.displaySmall),
                          const SizedBox(height: 6),
                          Text(
                            'At GoSolar India, we take pride in delivering high-quality products and services. '
                            'To maintain transparency, please review our policy before making a purchase.',
                            style: txt.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'No Returns Accepted',
                    icon: Icons.block_outlined,
                    child: Text(
                      'Once a purchase has been completed through our platform, we do not accept returns of any kind. '
                      'Products and services cannot be sent back, exchanged, or replaced once the order is confirmed.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  _SectionCard(
                    title: 'Why No Returns?',
                    icon: Icons.balance_outlined,
                    child: Text(
                      'To ensure the best possible prices and operational efficiency, we follow a strict no-return policy. '
                      'We encourage customers to carefully review all product or service details before placing an order.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  _SectionCard(
                    title: 'Support Instead of Returns',
                    icon: Icons.support_agent_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'While returns are not possible, our support team is committed to assisting you if you experience any issue with your purchase.',
                          style: txt.bodyLarge,
                        ),
                        const SizedBox(height: 12),
                        const _CopyableRow(
                          label: 'Email',
                          value: 'support@gosol.in',
                          icon: Icons.email_outlined,
                        ),
                      ],
                    ),
                  ),

                  // Helpful CTA
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
                          Text('Need Help? We’re Here for You',
                              style: txt.headlineLarge),
                          const SizedBox(height: 8),
                          Text(
                            'Our specialists can guide you with troubleshooting and resolutions.',
                            style: txt.bodyLarge,
                          ),
                          const SizedBox(height: 14),
                        ],
                      ),
                    ),
                  ),

                  // Contact Details
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
    );
  }
}

/* ---------- Shared UI (same style as other pages) ---------- */

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
          Expanded(child: Text(value, style: txt.bodyLarge)),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy_outlined),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$label copied')),
              );
            },
          ),
        ],
      ),
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
