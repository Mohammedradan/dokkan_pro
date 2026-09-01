import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../state/app_state.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import 'barcode_scanner_screen.dart';
import 'product_details_screen.dart';
import 'product_form_screen.dart';
import 'stock_take_screen.dart';

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  int? _categoryFilter;
  String _sort = 'name'; // name | stock | expiry

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final query = _query.trim().toLowerCase();

    var items = state.products.where((p) {
      if (query.isNotEmpty &&
          !p.name.toLowerCase().contains(query) &&
          !p.barcode.toLowerCase().contains(query)) {
        return false;
      }
      if (_categoryFilter != null && p.categoryId != _categoryFilter) {
        return false;
      }
      return true;
    }).toList();

    switch (_sort) {
      case 'stock':
        items.sort((a, b) {
          final sa = a.isOutOfStock
              ? 0
              : a.isLowStock
                  ? 1
                  : 2;
          final sb = b.isOutOfStock
              ? 0
              : b.isLowStock
                  ? 1
                  : 2;
          if (sa != sb) return sa.compareTo(sb);
          return a.quantity.compareTo(b.quantity);
        });
        break;
      case 'expiry':
        items.sort((a, b) {
          final ea = _nearestExpiry(state, a.id);
          final eb = _nearestExpiry(state, b.id);
          if (ea == null && eb == null) return 0;
          if (ea == null) return 1;
          if (eb == null) return -1;
          return ea.compareTo(eb);
        });
        break;
      default:
        items.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            tooltip: 'مسح باركود',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () => _scanBarcode(context),
          ),
          IconButton(
            tooltip: 'جرد المخزون',
            icon: const Icon(Icons.fact_check_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StockTakeScreen()),
            ),
          ),
          IconButton(
            tooltip: 'إضافة منتج',
            icon: const Icon(Icons.add_box_outlined),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الباركود...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          // فلاتر
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('الكل'),
                  selected: _categoryFilter == null,
                  onSelected: (_) => setState(() => _categoryFilter = null),
                ),
                for (final c in state.categories)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(c.name),
                      selected: _categoryFilter == c.id,
                      onSelected: (_) =>
                          setState(() => _categoryFilter = c.id),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Text('ترتيب:',
                    style: TextStyle(fontSize: 12.5)),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _sort,
                  isDense: true,
                  underline: const SizedBox(),
                  style: TextStyle(fontSize: 12.5, color: scheme.primary),
                  items: const [
                    DropdownMenuItem(value: 'name', child: Text('الاسم')),
                    DropdownMenuItem(value: 'stock', child: Text('حالة المخزون')),
                    DropdownMenuItem(
                        value: 'expiry', child: Text('أقرب صلاحية')),
                  ],
                  onChanged: (v) => setState(() => _sort = v ?? 'name'),
                ),
                const Spacer(),
                Text(
                  '${items.length} منتج',
                  style: TextStyle(fontSize: 12, color: scheme.outline),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: items.isEmpty
                ? const EmptyState(
                    icon: Icons.inventory_2_outlined,
                    title: 'لا توجد منتجات',
                    subtitle: 'اضغط زر + لإضافة أول منتج',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 90),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (context, i) =>
                        _ProductTile(
                      product: items[i],
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailsScreen(product: items[i]),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  int? _nearestExpiry(AppState state, int? productId) {
    if (productId == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    final list = state
        .batchesOf(productId)
        .where((b) => b.expiryDate != null && b.expiryDate! >= now)
        .toList()
      ..sort((a, b) => a.expiryDate!.compareTo(b.expiryDate!));
    if (list.isEmpty) return null;
    return list.first.expiryDate;
  }

  void _openForm(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const ProductFormScreen()));
  }

  /// مسح باركود: إن وُجد المنتج يُفتح، وإلا يُفتح نموذج الإضافة بالباركود.
  Future<void> _scanBarcode(BuildContext context) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
    if (code == null || !mounted) return;

    final state = context.read<AppState>();
    final matches =
        state.products.where((p) => p.barcode == code).toList();
    if (matches.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailsScreen(product: matches.first),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('منتج جديد بالباركود: $code — أكمل البيانات')),
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductFormScreen(initialBarcode: code),
        ),
      );
    }
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;

  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final state = context.watch<AppState>();
    final category = state.categoryById(product.categoryId);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(
          product.name.isEmpty ? '؟' : product.name.characters.first,
          style: TextStyle(
            color: scheme.onPrimaryContainer,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      title: Text(
        product.name,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [
          category?.name ?? 'بدون فئة',
          if (product.barcode.isNotEmpty) 'باركود: ${product.barcode}',
        ].join(' • '),
        style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          StatusBadge(status: product.stockStatus()),
          const SizedBox(height: 4),
          Text(
            qtyWithUnit(product.quantity, product.unit),
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
