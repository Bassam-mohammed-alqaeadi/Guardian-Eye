import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';

class ParentDashboardScreen extends StatelessWidget {
  const ParentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('parent_dashboard')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Family Health & AI Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded,
                          color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        'عائلة آمنة تماماً',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'لا توجد مخاطر حرجة تم رصدها اليوم. الذكاء الاصطناعي يراقب الرفاهية الرقمية بفعالية.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'أطفال العائلة',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          // Child Card Example
          Card(
            child: ListTile(
              leading: const CircleAvatar(
                child: Text('ع'),
              ),
              title: const Text('عمر (الابن)'),
              subtitle: const Text('وقت الشاشة اليوم: ساعتان • آمن'),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
              onTap: () => context.go('/child-profile'),
            ),
          ),
        ],
      ),
    );
  }
}
