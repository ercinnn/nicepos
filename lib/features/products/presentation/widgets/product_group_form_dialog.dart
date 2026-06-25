import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/product_group.dart';
import '../../application/products_provider.dart';

class ProductGroupFormDialog extends ConsumerStatefulWidget {
  final ProductGroup? group;
  final List<ProductGroup> allGroups;

  const ProductGroupFormDialog({super.key, this.group, required this.allGroups});

  @override
  ConsumerState<ProductGroupFormDialog> createState() => _ProductGroupFormDialogState();
}

class _ProductGroupFormDialogState extends ConsumerState<ProductGroupFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  String? _parentGroupId;
  late bool _showOnSalesPage;
  late bool _showOnPriceList;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.group?.name ?? '');
    _parentGroupId = widget.group?.parentGroupId;
    _showOnSalesPage = widget.group?.showOnSalesPage ?? false;
    _showOnPriceList = widget.group?.showOnPriceList ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final group = ProductGroup(
      id: widget.group?.id ?? '',
      name: _nameController.text.trim(),
      parentGroupId: _parentGroupId,
      showOnSalesPage: _showOnSalesPage,
      showOnPriceList: _showOnPriceList,
    );
    final repo = ref.read(productGroupRepositoryProvider);
    if (widget.group == null) {
      await repo.create(group);
    } else {
      await repo.update(widget.group!.id, group);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final parentOptions = widget.allGroups.where((g) => g.id != widget.group?.id).toList();

    return AlertDialog(
      title: Text(widget.group == null ? 'Yeni Grup Ekle' : 'Grubu Düzenle'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Grup Adı *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Grup adı giriniz' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _parentGroupId,
                decoration: const InputDecoration(labelText: 'Üst Grup'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('(Üst grup yok)')),
                  ...parentOptions.map((g) => DropdownMenuItem<String?>(value: g.id, child: Text(g.name))),
                ],
                onChanged: (v) => setState(() => _parentGroupId = v),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _showOnSalesPage,
                title: const Text('Satış Sayfasında göster'),
                onChanged: (v) => setState(() => _showOnSalesPage = v ?? false),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: _showOnPriceList,
                title: const Text("Fiyat Listesi'nde yer alsın"),
                onChanged: (v) => setState(() => _showOnPriceList = v ?? false),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Kapat')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: Text(widget.group == null ? 'Oluştur' : 'Kaydet'),
        ),
      ],
    );
  }
}
