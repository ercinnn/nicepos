import 'package:flutter/material.dart';

import '../../../data/models/domain_models.dart';
import 'domain_payment_step.dart';
import 'domain_registrant_form.dart';
import 'domain_search_step.dart';
import 'domain_status_tracker.dart';

// Domain ara → kayıt sahibi bilgisi → öde → durumu izle. Tek bir dialog
// içinde 4 adımı sırayla gösteren basit bir state machine — ayrı route'lara
// bölünmedi (bu akış yalnız bu ekrandan açılıyor, geri gezinme gerekmiyor).
Future<void> showDomainPurchaseWizard(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(child: _DomainWizardBody()),
        ),
      ),
    ),
  );
}

class _DomainWizardBody extends StatefulWidget {
  @override
  State<_DomainWizardBody> createState() => _DomainWizardBodyState();
}

class _DomainWizardBodyState extends State<_DomainWizardBody> {
  DomainCandidate? _candidate;
  DomainRegistrantContact? _registrant;
  String? _purchaseId;

  @override
  Widget build(BuildContext context) {
    if (_purchaseId != null) {
      return DomainStatusTracker(
        purchaseId: _purchaseId!,
        onDone: () => Navigator.of(context).pop(),
      );
    }
    if (_candidate != null && _registrant != null) {
      return DomainPaymentStep(
        candidate: _candidate!,
        registrant: _registrant!,
        onInitiated: (id) => setState(() => _purchaseId = id),
      );
    }
    if (_candidate != null) {
      return DomainRegistrantForm(
        domain: _candidate!.domain,
        onSubmit: (contact) => setState(() => _registrant = contact),
      );
    }
    return DomainSearchStep(
      onSelected: (candidate) => setState(() => _candidate = candidate),
    );
  }
}
