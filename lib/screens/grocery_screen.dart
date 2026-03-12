import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = state.groceryItems;
    final unpurchased = items.where((g) => !g.isPurchased).toList();
    final purchased = items.where((g) => g.isPurchased).toList();

    return Scaffold(
      appBar: AppBar(title: Text('Grocery List')),
      floatingActionButton: _filter == 'unpurchased'
          ? FloatingActionButton(
              heroTag: 'addGrocery',
              onPressed: () => showGroceryDialog(context),
              child: Icon(Icons.add_rounded),
            )
          : (purchased.isNotEmpty
              ? FloatingActionButton.small(
                  heroTag: 'clear',
                  onPressed: () => state.clearPurchasedGroceries(),
                  backgroundColor: AppTheme.accentOrange,
                  child: Icon(Icons.clear_all_rounded, color: Colors.white),
                )
              : null),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                _filterChip('Grocery List', 'unpurchased', isDark),
                SizedBox(width: 8),
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
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryDark
              : isDark
                  ? AppTheme.darkCard
                  : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildUnpurchasedList(List<GroceryItem> unpurchased, bool isDark, AppState state) {
    if (unpurchased.isEmpty) {
      return EmptyState(
        icon: Icons.shopping_cart_rounded,
        title: 'Grocery List Empty',
        subtitle: 'Add items to your shared grocery list.',
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${unpurchased.length} items remaining',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...unpurchased.map((item) => buildGroceryTile(context, item, isDark, state)),
      ],
    );
  }

  Widget _buildPurchasedList(List<GroceryItem> purchased, bool isDark, AppState state) {
    if (purchased.isEmpty) {
      return EmptyState(
        icon: Icons.check_circle_outline_rounded,
        title: 'No Purchased Items',
        subtitle: 'Items marked as purchased will appear here.',
      );
    }
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${purchased.length} items purchased',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              letterSpacing: 0.3,
            ),
          ),
        ),
        ...purchased.map((item) => buildGroceryTile(context, item, isDark, state)),
      ],
    );
  }
}

Widget buildGroceryTile(
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
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: AppTheme.accentTeal,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.isPurchased ? Icons.remove_circle_outline_rounded : Icons.check_circle_rounded, 
            color: Colors.white, 
            size: 28,
          ),
          SizedBox(height: 4),
          Text(
            item.isPurchased ? 'Unmark' : 'Purchased',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
    secondaryBackground: Container(
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.symmetric(horizontal: 20),
      alignment: Alignment.centerRight,
      decoration: BoxDecoration(
        color: AppTheme.accentOrange,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
          SizedBox(height: 4),
          Text(
            'Delete',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: EdgeInsets.only(bottom: 14),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: item.isPurchased
              ? AppTheme.accentTeal.withOpacity(0.4)
              : (isDark ? Colors.white12 : Colors.black.withOpacity(0.04)),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => state.toggleGroceryItem(item.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: item.isPurchased ? AppTheme.accentTeal : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: item.isPurchased
                      ? AppTheme.accentTeal
                      : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary.withOpacity(0.5)),
                  width: 2,
                ),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                child: item.isPurchased
                    ? Icon(Icons.check_rounded, color: Colors.white, size: 16, key: ValueKey('check'))
                    : SizedBox(key: ValueKey('empty')),
              ),
            ),
          ),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    decoration: item.isPurchased ? TextDecoration.lineThrough : null,
                    decorationColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    decorationThickness: 2.0,
                  ),
                  child: Text(item.name),
                ),
                SizedBox(height: 4),
                Text(
                  '${item.quantity} ${item.unit}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (item.addedBy == 'Smart Pantry') ...[
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentTeal.withOpacity(0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '🤖 Auto',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accentTeal,
                ),
              ),
            ),
            SizedBox(width: 8),
          ],
          IconButton(
            icon: Icon(Icons.edit_rounded, size: 22),
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(),
            onPressed: () => showGroceryDialog(context, item: item),
          ),
        ],
      ),
    ),
  );
}

void showGroceryDialog(BuildContext context, {GroceryItem? item}) {
  final nameCtrl = TextEditingController(text: item?.name ?? '');
  final qtyCtrl = TextEditingController(text: item?.quantity.toString() ?? '1');
  String unit = item?.unit ?? 'pcs';

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkSurface
        : AppTheme.lightSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => Padding(
        padding: EdgeInsets.fromLTRB(
            24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
                child: Container(
                    width: 48,
                    height: 5,
                    decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(3)))),
            SizedBox(height: 24),
            Text(item == null ? 'Add Grocery Item' : 'Edit Grocery Item',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(height: 24),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                hintText: 'Item name',
                filled: true,
                fillColor: Theme.of(context).brightness == Brightness.dark
                    ? AppTheme.darkCard
                    : AppTheme.lightCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Quantity',
                      filled: true,
                      fillColor: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkCard
                          : AppTheme.lightCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.darkCard
                          : AppTheme.lightCard,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: unit,
                        isExpanded: true,
                        items: ['pcs', 'kg', 'L', 'g', 'ml', 'dozen', 'pack']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (v) => setState(() => unit = v!),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 54,
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
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(item == null ? 'Add Item' : 'Save Changes',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
