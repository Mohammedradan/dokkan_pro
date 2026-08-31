import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/category.dart';
import '../models/product.dart';
import '../models/supplier.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import '../widgets/pickers.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _barcode;
  late final TextEditingController _cost;
  late final TextEditingController _sell;
  late final TextEditingController _minStock;
  late final TextEditingController _qty;
  late final TextEditingController _notes;

  int? _categoryId;
  int? _supplierId;
  String _unit = 'قطعة';
  bool _saving = false;

  static const List<String> _units = [
    'قطعة',
    'كيلو',
    'عبوة',
    'علبة',
    'لتر',
    'كيس',
    'كرتونة',
    'زجاجة',
  ];

  bool get _isEdit => widget.product != null;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _name = TextEditingController(text: p?.name ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? '');
    _cost = TextEditingController(
        text: p != null ? _num(p.costPrice) : '');
    _sell = TextEditingController(
        text: p != null ? _num(p.sellPrice) : '');
    _minStock = TextEditingController(
        text: p != null ? _num(p.minStock) : '');
    _qty = TextEditingController();
    _notes = TextEditingController(text: p?.notes ?? '');
    _categoryId = p?.categoryId;
    _supplierId = p?.supplierId;
    if (p != null) _unit = p.unit;
  }

  @override
  void dispose() {
    _name.dispose();
    _barcode.dispose();
    _cost.dispose();
    _sell.dispose();
    _minStock.dispose();
    _qty.dispose();
    _notes.dispose();
    super.dispose();
  }

  String _num(double v) {
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final state = context.read<AppState>();
    setState(() => _saving = true);
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      final p = widget.product;
      if (p == null) {
        await state.addProduct(Product(
          name: _name.text.trim(),
          barcode: _barcode.text.trim(),
          categoryId: _categoryId,
          supplierId: _supplierId,
          unit: _unit,
          costPrice: double.tryParse(_cost.text) ?? 0,
          sellPrice: double.tryParse(_sell.text) ?? 0,
          minStock: double.tryParse(_minStock.text) ?? 0,
          quantity: double.tryParse(_qty.text) ?? 0,
          notes: _notes.text.trim(),
          createdAt: now,
          updatedAt: now,
        ));
      } else {
        await state.updateProduct(p.copyWith(
          name: _name.text.trim(),
          barcode: _barcode.text.trim(),
          categoryId: _categoryId,
          supplierId: _supplierId,
          unit: _unit,
          costPrice: double.tryParse(_cost.text) ?? 0,
          sellPrice: double.tryParse(_sell.text) ?? 0,
          minStock: double.tryParse(_minStock.text) ?? 0,
          notes: _notes.text.trim(),
          updatedAt: now,
        ));
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final category = state.categoryById(_categoryId);
    final supplier = state.supplierById(_supplierId);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'تعديل منتج' : 'منتج جديد'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج *',
                prefixIcon: Icon(Icons.shopping_basket_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل اسم المنتج' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              textInputAction: TextInputAction.next,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'الباركود (اختياري)',
                prefixIcon: Icon(Icons.qr_code_2),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ReadOnlyField(
              label: 'الفئة',
              value: category?.name ?? '',
              icon: Icons.category_outlined,
              onTap: () => _pickCategory(context, state),
            ),
            const SizedBox(height: 12),
            ReadOnlyField(
              label: 'المورد',
              value: supplier?.name ?? '',
              icon: Icons.local_shipping_outlined,
              onTap: () => _pickSupplier(context, state),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _unit,
              decoration: const InputDecoration(
                labelText: 'وحدة القياس',
                prefixIcon: Icon(Icons.straighten),
                border: OutlineInputBorder(),
              ),
              items: [
                for (final u in _units)
                  DropdownMenuItem(value: u, child: Text(u)),
              ],
              onChanged: (v) => setState(() => _unit = v ?? 'قطعة'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _moneyField(_cost, 'سعر التكلفة'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _moneyField(_sell, 'سعر البيع'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _minStock,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    inputFormatters: [_decimalFormatter],
                    decoration: const InputDecoration(
                      labelText: 'حد الطلب الأدنى',
                      prefixIcon: Icon(Icons.trending_down),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _isEdit
                      ? AbsorbPointer(
                          child: TextFormField(
                            initialValue: _num(widget.product!.quantity),
                            decoration: const InputDecoration(
                              labelText: 'الكمية الحالية',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                              border: OutlineInputBorder(),
                            ),
                          ),
                        )
                      : TextFormField(
                          controller: _qty,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          inputFormatters: [_decimalFormatter],
                          decoration: const InputDecoration(
                            labelText: 'الكمية الافتتاحية',
                            prefixIcon: Icon(Icons.add_circle_outline),
                            border: OutlineInputBorder(),
                          ),
                        ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
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
              label: Text(_isEdit ? 'حفظ التعديلات' : 'إضافة المنتج'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _moneyField(TextEditingController controller, String label) {
    return TextFormField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [_decimalFormatter],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.payments_outlined),
        border: const OutlineInputBorder(),
      ),
    );
  }

  Future<void> _pickCategory(BuildContext context, AppState state) async {
    if (state.categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف فئات أولاً من صفحة الإعدادات')),
      );
      return;
    }
    final picked = await showDialog<Category>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('اختر الفئة'),
        children: [
          for (final c in state.categories)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, c),
              child: Row(
                children: [
                  Icon(Icons.category_outlined,
                      size: 18, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Text(c.name),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) setState(() => _categoryId = picked.id);
  }

  Future<void> _pickSupplier(BuildContext context, AppState state) async {
    if (state.suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف موردين أولاً من صفحة الإعدادات')),
      );
      return;
    }
    final picked = await pickSupplier(context);
    if (picked != null) setState(() => _supplierId = picked.id);
  }
}

final _decimalFormatter = FilteringTextInputFormatter.allow(
  RegExp(r'^\d*\.?\d{0,2}'),
);
