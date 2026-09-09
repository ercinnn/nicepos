import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../data/domain_purchase_repository.dart';
import '../../../data/models/domain_models.dart';

// Domain arama adımı — sales_screen.dart'taki canlı ürün aramasıyla aynı
// debounce deseni (Timer, 300ms). Yalnız MÜSAİT sonuçlar seçilebilir.
class DomainSearchStep extends StatefulWidget {
  final ValueChanged<DomainCandidate> onSelected;

  const DomainSearchStep({super.key, required this.onSelected});

  @override
  State<DomainSearchStep> createState() => _DomainSearchStepState();
}

class _DomainSearchStepState extends State<DomainSearchStep> {
  final _controller = TextEditingController();
  final _repository = DomainPurchaseRepository();
  Timer? _debounce;
  List<DomainCandidate> _results = [];
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final results = await _repository.search(value.trim());
        if (!mounted) return;
        setState(() {
          _results = results;
          _loading = false;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Domain Ara',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Şimdilik yalnız .com / .net / .org destekleniyor.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12.5),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _controller,
          autofocus: true,
          onChanged: _onChanged,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 20),
            hintText: 'Mağaza adınızı yazın...',
            isDense: true,
          ),
        ),
        const SizedBox(height: 12),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.danger))
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _results.length,
              separatorBuilder: (context, i) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = _results[i];
                return ListTile(
                  dense: true,
                  title: Text(r.domain),
                  trailing: r.available
                      ? Text(
                          '${r.priceAmount.toStringAsFixed(2)} ${r.priceCurrency}/yıl',
                          style: const TextStyle(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : const Text('Alınmış', style: TextStyle(color: AppColors.textMuted)),
                  onTap: r.available ? () => widget.onSelected(r) : null,
                );
              },
            ),
          ),
      ],
    );
  }
}
