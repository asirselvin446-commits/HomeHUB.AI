import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/common_widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GroceryScreen extends StatefulWidget {
  const GroceryScreen({super.key});

  @override
  State<GroceryScreen> createState() => _GroceryScreenState();
}

class _GroceryScreenState extends State<GroceryScreen> {
  String _filter = 'unpurchased';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = AppColors.isDark(context);

    final items = state.groceryItems;
    final unpurchased = items.where((g) => !g.isPurchased).toList();
    final purchased = items.where((g) => g.isPurchased).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Grocery List')),
      floatingActionButton: _filter == 'unpurchased'
          ? FloatingActionButton(
              heroTag: 'addGrocery',
              onPressed: () => showGroceryDialog(context),
              child: const Icon(Icons.add_rounded),
            )
          : (purchased.isNotEmpty
              ? FloatingActionButton.small(
                  heroTag: 'clear',
                  onPressed: () => state.clearPurchasedGroceries(),
                  backgroundColor: AppColors.error,
                  child: const Icon(Icons.clear_all_rounded, color: Colors.white),
                )
              : null),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                _filterChip('Grocery List', 'unpurchased', isDark),
                const SizedBox(width: 8),
                _filterChip('Purchased', 'purchased', isDark),
              ],
            ),
          ),

          Expanded(
            child: _filter == 'unpurchased'
                ? _buildUnpurchasedList(unpurchased, isDark, state)
                : _buildPurchasedList(purchased, isDark, state),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isDark) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : isDark
                  ? AppColors.darkCard
                  : AppColors.lightSurfaceAlt,
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: selected
              ? null
              : Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildUnpurchasedList(List<GroceryItem> unpurchased, bool isDark, AppState state) {
    if (unpurchased.isEmpty) {
      return const EmptyState(
        icon: Icons.shopping_cart_rounded,
        title: 'Grocery List Empty',
        subtitle: 'Add items to your shared grocery list.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${unpurchased.length} items remaining',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        ...unpurchased.asMap().entries.map((e) => _buildGroceryTile(context, e.value, isDark, state)
            .animate(delay: (e.key * 50).ms)
            .fade(duration: 300.ms)
            .slideX(begin: 0.05, duration: 300.ms)),
      ],
    );
  }

  Widget _buildPurchasedList(List<GroceryItem> purchased, bool isDark, AppState state) {
    if (purchased.isEmpty) {
      return const EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No Purchased Items',
        subtitle: 'Items marked as purchased will appear here.',
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            '${purchased.length} items purchased',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary(context),
            ),
          ),
        ),
        ...purchased.asMap().entries.map((e) => _buildGroceryTile(context, e.value, isDark, state)
            .animate(delay: (e.key * 50).ms)
            .fade(duration: 300.ms)
            .slideX(begin: 0.05, duration: 300.ms)),
      ],
    );
  }

  Widget _buildGroceryTile(
      BuildContext context, GroceryItem item, bool isDark, AppState state) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.horizontal,
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          state.deleteGroceryItem(item.id);
        } else {
          state.toggleGroceryItem(item.id);
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              item.isPurchased ? Icons.remove_circle_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white, size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              item.isPurchased ? 'Unmark' : 'Done',
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
            SizedBox(height: 2),
            Text('Delete', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: item.isPurchased
                ? AppColors.primary.withOpacity(0.3)
                : isDark
                    ? AppColors.darkBorder
                    : Colors.black.withOpacity(0.04),
          ),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => state.toggleGroceryItem(item.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: item.isPurchased ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: item.isPurchased
                        ? AppColors.primary
                        : AppColors.textSecondary(context).withOpacity(0.5),
                    width: 2,
                  ),
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, animation) =>
                      ScaleTransition(scale: animation, child: child),
                  child: item.isPurchased
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14, key: ValueKey('check'))
                      : const SizedBox(key: ValueKey('empty')),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text(context),
                      decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.textSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${item.quantity} ${item.unit}',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            if (item.addedBy == 'Smart Pantry') ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '🤖 Auto',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            IconButton(
              icon: const Icon(Icons.edit_rounded, size: 18),
              color: AppColors.textSecondary(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () => showGroceryDialog(context, item: item),
            ),
          ],
        ),
      ),
    );
  }
}

void showGroceryDialog(BuildContext context, {GroceryItem? item}) {
  final nameCtrl = TextEditingController(text: item?.name ?? '');
  final qtyCtrl = TextEditingController(text: item?.quantity.toString() ?? '1');
  String unit = item?.unit ?? 'pcs';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary(context).withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item == null ? 'Add Grocery Item' : 'Edit Grocery Item',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.text(context),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(hintText: 'Item name'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: 'Quantity'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: unit,
                    decoration: const InputDecoration(hintText: 'Unit'),
                    items: ['pcs', 'kg', 'L', 'g', 'ml', 'dozen', 'pack']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) => setState(() => unit = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  if (nameCtrl.text.isNotEmpty) {
                    final newItem = GroceryItem(
                      id: item?.id ?? '',
                      name: nameCtrl.text,
                      quantity: int.tryParse(qtyCtrl.text) ?? 1,
                      unit: unit,
                      isPurchased: item?.isPurchased ?? false,
                      addedBy: item?.addedBy ?? 'User',
                      category: item?.category ?? 'General',
                    );
                    if (item == null) {
                      context.read<AppState>().addGroceryItem(newItem);
                    } else {
                      context.read<AppState>().updateGroceryItem(newItem);
                    }
                    Navigator.pop(ctx);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                ),
                child: Text(
                  item == null ? 'Add Item' : 'Save Changes',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
