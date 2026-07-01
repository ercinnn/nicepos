import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/company.dart';
import '../../application/products_provider.dart';

class CompaniesScreen extends ConsumerWidget {
  const CompaniesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final companiesAsync = ref.watch(companiesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Firmalar',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _openForm(context, ref, null),
              icon: const Icon(Icons.add),
              label: const Text('Yeni Firma Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: Card(
            child: companiesAsync.when(
              data: (companies) => _CompaniesTable(
                companies: companies,
                onEdit: (c) => _openForm(context, ref, c),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Hata: $e')),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openForm(
      BuildContext context, WidgetRef ref, Company? company) async {
    final nameCtrl = TextEditingController(text: company?.name ?? '');
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(company == null ? 'Yeni Firma' : 'Firma Düzenle'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Firma Adı *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Firma adı zorunlu.' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );

    if (saved == true) {
      final name = nameCtrl.text.trim();
      final repo = ref.read(companyRepositoryProvider);
      if (company == null) {
        await repo.create(Company(id: '', name: name));
      } else {
        await repo.update(company.id, Company(id: company.id, name: name));
      }
      ref.invalidate(companiesProvider);
    }
    nameCtrl.dispose();
  }
}

class _CompaniesTable extends ConsumerWidget {
  final List<Company> companies;
  final void Function(Company) onEdit;

  const _CompaniesTable({required this.companies, required this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (companies.isEmpty) {
      return const Center(child: Text('Henüz firma eklenmemiş.'));
    }

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Sıra')),
            DataColumn(label: Text('Firma Adı')),
            DataColumn(label: Text('İşlem')),
          ],
          rows: List.generate(companies.length, (i) {
            final c = companies[i];
            return DataRow(cells: [
              DataCell(Text('${i + 1}')),
              DataCell(Text(c.name)),
              DataCell(Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => onEdit(c),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete,
                        size: 18, color: AppColors.danger),
                    onPressed: () => _delete(context, ref, c),
                  ),
                ],
              )),
            ]);
          }),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Company c) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Firmayı Sil'),
        content: Text('"${c.name}" firmasını silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Vazgeç')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Sil')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(companyRepositoryProvider).delete(c.id);
      ref.invalidate(companiesProvider);
    }
  }
}
