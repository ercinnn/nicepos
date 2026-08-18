import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../application/sales_cart_notifier.dart';
import 'customer_picker_dialog.dart';

class CustomerTabs extends ConsumerWidget {
  final bool showCustomerButton;

  const CustomerTabs({super.key, this.showCustomerButton = true});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesCartProvider);
    final notifier = ref.read(salesCartProvider.notifier);

    return Row(
      children: [
        // Sekmeler — yatay kaydırmalı
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(5, (i) {
                final tab = salesState.tabs[i];
                final selected = salesState.activeTab == i;
                final label = tab.items.isEmpty
                    ? 'Müşteri ${i + 1}'
                    : 'Müşteri ${i + 1} (${tab.items.length})';
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(label),
                    selected: selected,
                    onSelected: (_) => notifier.selectTab(i),
                  ),
                );
              }),
            ),
          ),
        ),
        if (showCustomerButton) ...[
          const SizedBox(width: 8),
          // Müşteri seçici — kaydırmanın dışında sabit
          const CustomerSelectButton(),
        ],
      ],
    );
  }
}

/// Aktif sekmenin müşterisini gösterir/seçer — `CustomerTabs`'ten çıkarılmış
/// bağımsız bir widget (mobilde ödeme satırının üstündeki aksiyon satırında
/// da tek başına kullanılır, bkz. sales_screen.dart `_buildMobile`).
class CustomerSelectButton extends ConsumerWidget {
  const CustomerSelectButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesCartProvider);
    final notifier = ref.read(salesCartProvider.notifier);
    final active = salesState.active;

    if (active.customerId != null) {
      return Chip(
        avatar: const Icon(Icons.person, size: 16, color: AppColors.primary),
        label: Text(
          active.customerName ?? '',
          overflow: TextOverflow.ellipsis,
        ),
        onDeleted: () => notifier.clearCustomer(),
      );
    }
    return OutlinedButton.icon(
      onPressed: () async {
        final customer = await showDialog(
            context: context, builder: (_) => const CustomerPickerDialog());
        if (customer != null) {
          notifier.setCustomer(customer.id, customer.name);
        }
      },
      icon: const Icon(Icons.person_outline, size: 18),
      label: const Text('Müşteri Seç'),
    );
  }
}
