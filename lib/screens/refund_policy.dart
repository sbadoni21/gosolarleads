import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gosolarleads/theme/app_theme.dart';

class RefundPolicyPage extends StatefulWidget {
  const RefundPolicyPage({super.key});

  @override
  State<RefundPolicyPage> createState() => _RefundPolicyPageState();
}

class _RefundPolicyPageState extends State<RefundPolicyPage> {
  @override
  Widget build(BuildContext context) {
    final txt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Refund Policy'),
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
                          Text('Refund Policy', style: txt.displaySmall),
                          const SizedBox(height: 6),
                          Text(
                            'At GoSolar India, we value your trust and aim to provide the best service possible. '
                            'This Refund Policy explains our stance on refunds for purchases made through our platform.',
                            style: txt.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  _SectionCard(
                    title: 'No Refunds',
                    icon: Icons.cancel_presentation_outlined,
                    child: Text(
                      'All sales made through GoSolar India are final. We do not provide refunds for any products or services, '
                      'whether used or unused, once payment has been successfully processed.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  _SectionCard(
                    title: 'Exceptional Circumstances',
                    icon: Icons.rule_folder_outlined,
                    child: Text(
                      'Although refunds are not part of our standard policy, in rare cases such as duplicate payments, '
                      'billing errors, or technical issues, we may review the situation and provide assistance at our sole discretion.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  _SectionCard(
                    title: 'Customer Assistance',
                    icon: Icons.support_agent_outlined,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Even though we do not offer refunds, our dedicated support team is here to resolve any problems you may face.',
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 12),
                        _CopyableRow(
                          label: 'Email',
                          value: 'support@gosol.in',
                          icon: Icons.email_outlined,
                        ),
                      ],
                    ),
                  ),

                  _SectionCard(
                    title: 'Acknowledgement',
                    icon: Icons.verified_outlined,
                    child: Text(
                      'By completing a purchase on our platform, you acknowledge and agree to this Refund Policy. '
                      'We recommend reviewing this page from time to time for updates.',
                      style: txt.bodyLarge,
                    ),
                  ),

                  // Helpful CTA

                  const SizedBox(height: 12),

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

/* ------------ Shared UI (same look as other pages) ------------ */

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
