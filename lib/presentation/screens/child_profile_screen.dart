import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:guardian_ai/core/localization/app_localizations.dart';

class ChildProfileScreen extends StatelessWidget {
  const ChildProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('child_profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Center(
            child: CircleAvatar(
              radius: 40,
              child: Text('ع', style: TextStyle(fontSize: 32)),
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'عمر أحمد',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          const Center(
            child: Text('الجهاز: هاتف ذكي (Android) • الحالة: متصل'),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('إحصائيات الاستخدام اليومي',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                      value: 0.65, backgroundColor: Colors.grey.shade200),
                  const SizedBox(height: 8),
                  const Text('متبقي ساعة و 30 دقيقة من الحد اليومي المسموح.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
