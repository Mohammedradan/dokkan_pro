import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../models/supplier.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

class MovementFormScreen extends StatefulWidget {
  final Product? product;
  final String initialType;

  const MovementFormScreen({
    super.key,
    this.product,
    this.initialType = 'receive',
  });

  @override
  State<MovementFormScreen> createState() => _MovementFormScreenState();
}

class _MovementFormScreenState extends State<MovementFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _qtyController = TextEditingController();
  final _costController = TextEditingController();
  final _noteController = TextEditingController();

  late String _type;
  Product? _product;
  Supplier? _supplier;
  DateTime? _expiry;
  bool _saving = false;

  bool get _isReceive => _type == 'receive';
  bool get _isIncoming => _type == 'receive' || _type == 'adjust_in';

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _product = widget.product;
    if (widget.product != null && _isReceive) {
      _costController.text = widget.product!.costPrice == 0
          ? ''
          : _num(widget.product!.costPrice);
    }
  }

  @override
  void dispose() {
    _qtyController.dispose();
    _costController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String _num(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    final product = _product;
    if (product == null) return;

    setState(() => _saving = true);
    try {
      await state.addMovement(
        product: product,
        type: _type,
        quantity: double.parse(_qtyController.text),
        unitCost: _isReceive
            ? (double.tryParse(_costController.text) ?? 0)
            : null,
        supplierId: _isReceive ? _supplier?.id : null,
        expiryDate: _isReceive && _expiry != null
            ? _expiry!.millisecondsSinceEpoch
            : null,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الحركة بنجاح')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('حركة مخزون — ${movementTypeLabel(_type)}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // نوع الحركة
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in const [
                  ('receive', 'استلام', Icons.move_to_inbox_rounded),
                  ('adjust_in', 'تسوية زيادة', Icons.add_circle_outline),
                  ('adjust_out', 'تسوية نقص', Icons.remove_circle_outline),
                  ('waste', 'هالك', Icons.delete_forever_outlined),
                  ('return_supplier', 'مرتجع', Icons.assignment_return_outlined),
                ])
                  ChoiceChip(
                    avatar: Icon(entry.$3,
                        size: 16,
                        color: _type == entry.$1
                            ? scheme.onSecondaryContainer
                            : scheme.onSurfaceVariant),
                    label: Text(entry.$2),
                    selected: _type == entry.$1,
                    onSelected: (_) => setState(() => _type = entry.$1),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // المنتج
            if (_product == null)
              ReadOnlyField(
                label: 'المنتج *',
                value: '',
                icon: Icons.shopping_basket_outlined,
                onTap: () async {
                  final p = await pickProduct(context);
                  if (p != null) {
                    setState(() {
                      _product = p;
                      if (_isReceive && p.costPrice > 0) {
                        _costController.text = _num(p.costPrice);
                      }
                    });
                  }
                },
              )
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  child: Icon(Icons.shopping_basket_outlined,
                      color: scheme.onPrimaryContainer),
                ),
                title: Text(_product!.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  'متوفر: ${qtyWithUnit(_product!.quantity, _product!.unit)}',
                ),
                trailing: IconButton(
                  tooltip: 'تغيير المنتج',
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: () async {
                    final p = await pickProduct(context);
                    if (p != null) setState(() => _product = p);
                  },
                ),
              ),
            const SizedBox(height: 16),

            // الكمية
            TextFormField(
              controller: _qtyController,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_decimalFormatter],
              decoration: InputDecoration(
                labelText: 'الكمية * (${_product?.unit ?? ''})',
                prefixIcon: const Icon(Icons.numbers),
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                final qty = double.tryParse(v ?? '');
                if (qty == null || qty <= 0) return 'أدخل كمية صحيحة';
                if (!_isIncoming &&
                    _product != null &&
                    qty > _product!.quantity) {
                  return 'الكمية المتوفرة: ${formatQty(_product!.quantity)} ${_product!.unit}';
                }
                return null;
              },
            ),

            if (_isReceive) ...[
              const SizedBox(height: 12),
              // المورد
              ReadOnlyField(
                label: 'المورد (اختياري)',
                value: _supplier?.name ?? '',
                icon: Icons.local_shipping_outlined,
                onTap: () async {
                  if (state.suppliers.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('لا يوجد موردون بعد. أضفهم من الإعدادات')),
                    );
                    return;
                  }
                  final s = await pickSupplier(context);
                  if (s != null) setState(() => _supplier = s);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _costController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [_decimalFormatter],
                decoration: const InputDecoration(
                  labelText: 'سعر التكلفة للوحدة',
                  prefixIcon: Icon(Icons.payments_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              // تاريخ الصلاحية
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _expiry ?? now.add(const Duration(days: 30)),
                    firstDate: now.subtract(const Duration(days: 365)),
                    lastDate: now.add(const Duration(days: 365 * 5)),
                    helpText: 'اختر تاريخ انتهاء الصلاحية',
                  );
                  if (picked != null) setState(() => _expiry = picked);
                },
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'تاريخ انتهاء الصلاحية (اختياري)',
                    prefixIcon: Icon(Icons.event_outlined),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _expiry == null
                        ? 'بدون تاريخ صلاحية'
                        : formatDate(_expiry!.millisecondsSinceEpoch),
                    style: TextStyle(
                      color: _expiry == null
                          ? scheme.outline
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
              if (_expiry != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _expiry = null),
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('إزالة التاريخ'),
                  ),
                ),
            ],

            const SizedBox(height: 12),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظة (اختياري)',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text('تسجيل الحركة'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,2}'),
);
