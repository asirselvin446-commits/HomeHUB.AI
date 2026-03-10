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

class _GroceryScreenState extends State<GroceryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Grocery & Pantry'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryDark,
          labelColor: AppTheme.primaryDark,
          unselectedLabelColor:
              isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
          tabs: [
            Tab(text: '🛒 Grocery List'),
            Tab(text: '📦 Pantry'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _GroceryListTab(),
          _PantryTab(),
        ],
      ),
    );
  }
}

class _GroceryListTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = state.groceryItems;
    final unpurchased = items.where((g) => !g.isPurchased).toList();
    final purchased = items.where((g) => g.isPurchased).toList();

    return Scaffold(
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (purchased.isNotEmpty)
            FloatingActionButton.small(
              heroTag: 'clear',
              onPressed: () => state.clearPurchasedGroceries(),
              backgroundColor: AppTheme.accentOrange,
              child: Icon(Icons.clear_all_rounded, color: Colors.white),
            ),
          SizedBox(height: 8),
          FloatingActionButton(
            heroTag: 'addGrocery',
            onPressed: () => _showAddDialog(context),
            child: Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.shopping_cart_rounded,
              title: 'Grocery List Empty',
              subtitle:
                  'Add items to your shared grocery list.\nLow pantry items will be suggested automatically!',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                if (unpurchased.isNotEmpty) ...[
                  Text(
                    'To Buy (${unpurchased.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppTheme.darkText : AppTheme.lightText,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...unpurchased
                      .map((item) => _groceryTile(context, item, isDark, state)),
                ],
                if (purchased.isNotEmpty) ...[
                  SizedBox(height: 20),
                  Text(
                    'Purchased (${purchased.length})',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.lightTextSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...purchased
                      .map((item) => _groceryTile(context, item, isDark, state)),
                ],
              ],
            ),
    );
  }

  Widget _groceryTile(
      BuildContext context, GroceryItem item, bool isDark, AppState state) {
    return Dismissible(
      key: Key(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => state.deleteGroceryItem(item.id),
      background: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.only(right: 16),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: AppTheme.accentOrange,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => state.toggleGroceryItem(item.id),
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: item.isPurchased
                      ? AppTheme.accentTeal
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: item.isPurchased
                        ? AppTheme.accentTeal
                        : isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary,
                    width: 2,
                  ),
                ),
                child: item.isPurchased
                    ? Icon(Icons.check_rounded, color: Colors.white, size: 14)
                    : null,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  decoration:
                      item.isPurchased ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            Text(
              '${item.quantity} ${item.unit}',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary,
              ),
            ),
            if (item.addedBy == 'Smart Pantry') ...[
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '🤖 Auto',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.accentTeal,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController(text: '1');
    String unit = 'pcs';

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
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16),
              Text('Add Grocery Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(hintText: 'Item name'),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: qtyCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(hintText: 'Quantity'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: unit,
                      items: ['pcs', 'kg', 'L', 'g', 'ml', 'dozen', 'pack']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => unit = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      context.read<AppState>().addGroceryItem(GroceryItem(
                            id: '',
                            name: nameCtrl.text,
                            quantity: int.tryParse(qtyCtrl.text) ?? 1,
                            unit: unit,
                          ));
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add Item', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PantryTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = state.pantryItems;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'addPantry',
        onPressed: () => _showAddDialog(context),
        child: Icon(Icons.add_rounded),
      ),
      body: items.isEmpty
          ? EmptyState(
              icon: Icons.inventory_2_rounded,
              title: 'Pantry Empty',
              subtitle:
                  'Track household items and get alerts when they run low',
            )
          : ListView(
              padding: EdgeInsets.all(20),
              children: [
                // Low stock alert
                if (state.lowPantryItems.isNotEmpty)
                  Container(
                    padding: EdgeInsets.all(14),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppTheme.accentOrange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_rounded,
                            color: AppTheme.accentOrange, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '${state.lowPantryItems.length} items running low',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accentOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ...items.map((item) => _pantryTile(context, item, isDark, state)),
              ],
            ),
    );
  }

  Widget _pantryTile(
      BuildContext context, PantryItem item, bool isDark, AppState state) {
    final isLow = item.isLow;

    return Container(
      margin: EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
        borderRadius: BorderRadius.circular(14),
        border: isLow
            ? Border.all(color: AppTheme.accentOrange.withOpacity(0.3))
            : null,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isLow
                  ? AppTheme.accentOrange.withOpacity(0.15)
                  : AppTheme.accentTeal.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isLow ? Icons.warning_rounded : Icons.inventory_2_rounded,
              color: isLow ? AppTheme.accentOrange : AppTheme.accentTeal,
              size: 20,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  ),
                ),
                SizedBox(height: 4),
                // Stock bar
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: item.stockPercentage,
                          backgroundColor: isLow
                              ? AppTheme.accentOrange.withOpacity(0.15)
                              : AppTheme.accentTeal.withOpacity(0.15),
                          valueColor: AlwaysStoppedAnimation(
                              isLow ? AppTheme.accentOrange : AppTheme.accentTeal),
                          minHeight: 6,
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      '${item.currentQuantity} ${item.unit}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isLow ? AppTheme.accentOrange : AppTheme.accentTeal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(width: 8),
          // Quick quantity adjustment
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _qtyButton(Icons.remove, () {
                if (item.currentQuantity > 0) {
                  state.updatePantryQuantity(
                      item.id, (item.currentQuantity - 0.5).clamp(0, 999));
                }
              }, isDark),
              SizedBox(width: 4),
              _qtyButton(Icons.add, () {
                state.updatePantryQuantity(item.id, item.currentQuantity + 0.5);
              }, isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkCardAlt : Color(0xFFF0F2F5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 16,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final currentCtrl = TextEditingController(text: '1');
    final minCtrl = TextEditingController(text: '0.5');
    String unit = 'kg';

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
              20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              SizedBox(height: 16),
              Text('Add Pantry Item',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(hintText: 'Item name'),
              ),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: currentCtrl,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(hintText: 'Current qty'),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: minCtrl,
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(hintText: 'Min qty (alert)'),
                    ),
                  ),
                  SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: DropdownButtonFormField<String>(
                      value: unit,
                      items: ['kg', 'L', 'pcs', 'g', 'ml']
                          .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                          .toList(),
                      onChanged: (v) => setState(() => unit = v!),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (nameCtrl.text.isNotEmpty) {
                      context.read<AppState>().addPantryItem(PantryItem(
                            id: '',
                            name: nameCtrl.text,
                            currentQuantity:
                                double.tryParse(currentCtrl.text) ?? 1,
                            minimumQuantity:
                                double.tryParse(minCtrl.text) ?? 0.5,
                            unit: unit,
                          ));
                      Navigator.pop(ctx);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Add Item', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
