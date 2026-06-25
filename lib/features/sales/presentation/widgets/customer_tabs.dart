import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../application/sales_cart_notifier.dart';
import 'customer_picker_dialog.dart';

class CustomerTabs extends ConsumerWidget {
  const CustomerTabs({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final salesState = ref.watch(salesCartProvider);
    final notifier = ref.read(salesCartProvider.notifier);
    final active = salesState.active;

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
        const SizedBox(width: 8),
        // Müşteri seçici — kaydırmanın dışında sabit
        if (active.customerId != null)
          Chip(
            avatar: const Icon(Icons.person, size: 16, color: AppColors.primary),
            label: Text(
              active.customerName ?? '',
              overflow: TextOverflow.ellipsis,
            ),
            onDeleted: () => notifier.clearCustomer(),
          )
        else
          OutlinedButton.icon(
            onPressed: () async {
              final customer = await showDialog(
                  context: context, builder: (_) => const CustomerPickerDialog());
              if (customer != null) {
                notifier.setCustomer(customer.id, customer.name);
              }
            },
            icon: const Icon(Icons.person_outline, size: 18),
            label: const Text('Müşteri Seç'),
          ),
      ],
    );
  }
}
