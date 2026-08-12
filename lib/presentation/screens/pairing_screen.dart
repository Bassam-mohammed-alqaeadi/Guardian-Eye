import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../application/guardian_providers.dart';
import '../../core/localization/app_localizations.dart';
import '../../domain/guardian_models.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key, required this.familyId});
  final String familyId;
  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  PairingRequest? _request;
  Future<void> _create() async {
    final request = await ref
        .read(pairingRepositoryProvider)
        .createParentAuthorizedRequest(
            familyId: widget.familyId, requestedRole: DeviceRole.childDevice);
    if (mounted) setState(() => _request = request);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
        appBar: AppBar(title: Text(l10n.t('pairDevice'))),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: _request == null
                    ? FilledButton(
                        onPressed: _create,
                        child: Text(l10n.t('generatePairing')))
                    : Column(mainAxisSize: MainAxisSize.min, children: [
                        QrImageView(
                            data:
                                'guardian-eye://pair?request=${_request!.id}&code=${_request!.code}',
                            size: 210),
                        const SizedBox(height: 16),
                        SelectableText(_request!.code,
                            style: Theme.of(context).textTheme.displayMedium),
                        const SizedBox(height: 12),
                        Text(l10n.t('pairingNotice'),
                            textAlign: TextAlign.center)
                      ]))));
  }
}
