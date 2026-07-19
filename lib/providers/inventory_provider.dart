import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';

/// 物品栏单个物品的运行时状态
class InventoryItem {
  /// 物品 ID（与 [ShopItem.id] 对应）
  final String id;

  /// 名称
  final String name;

  /// 描述
  final String desc;

  /// Emoji
  final String emoji;

  /// 当前数量
  final int quantity;

  /// 物品类型（道具/装备等）
  final String type;

  const InventoryItem({
    required this.id,
    required this.name,
    required this.desc,
    required this.emoji,
    this.quantity = 0,
    this.type = 'consumable',
  });

  InventoryItem copyWith({
    String? name,
    String? desc,
    String? emoji,
    int? quantity,
    String? type,
  }) {
    return InventoryItem(
      id: id,
      name: name ?? this.name,
      desc: desc ?? this.desc,
      emoji: emoji ?? this.emoji,
      quantity: quantity ?? this.quantity,
      type: type ?? this.type,
    );
  }

  /// 从商店物品构造（默认数量 0）
  factory InventoryItem.fromShopItem(ShopItem item, {int quantity = 0}) {
    return InventoryItem(
      id: item.id,
      name: item.name,
      desc: item.desc,
      emoji: item.emoji,
      quantity: quantity,
      type: 'consumable',
    );
  }
}

/// 物品栏状态
///
/// 对齐 Web 端 `inventorySlice`，管理玩家拥有的道具和装备。
/// 金币不在这里维护（[ProgressState] 持有），本状态只关注物品数量。
class InventoryState {
  /// 当前持有的物品列表
  final List<InventoryItem> items;

  /// 已装备的物品 ID（装备类）
  final String? equippedItemId;

  const InventoryState({
    this.items = const [],
    this.equippedItemId,
  });

  InventoryState copyWith({
    List<InventoryItem>? items,
    String? equippedItemId,
    bool clearEquipped = false,
  }) {
    return InventoryState(
      items: items ?? this.items,
      equippedItemId:
          clearEquipped ? null : (equippedItemId ?? this.equippedItemId),
    );
  }

  /// 根据ID查找物品
  InventoryItem? getItem(String id) {
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// 物品数量（不存在返回 0）
  int getQuantity(String id) {
    return getItem(id)?.quantity ?? 0;
  }

  /// 物品总数（叠加数量）
  int get totalQuantity => items.fold(0, (sum, i) => sum + i.quantity);
}

/// 物品栏 Notifier
class InventoryNotifier extends StateNotifier<InventoryState> {
  InventoryNotifier() : super(const InventoryState());

  /// 从商店物品定义初始化物品栏（所有数量为 0）
  void initFromShopItems() {
    state = InventoryState(
      items: ShopItems.all
          .map((item) => InventoryItem.fromShopItem(item))
          .toList(),
    );
  }

  /// 批量设置物品列表（用于持久化恢复）
  void setItems(List<InventoryItem> items) {
    state = InventoryState(items: items);
  }

  /// 添加物品数量
  void addItem(String itemId, {int amount = 1}) {
    if (amount == 0) return;
    final items = List<InventoryItem>.from(state.items);
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx < 0) {
      // 物品栏中不存在，尝试从商店定义补全元数据
      final def = _findShopItem(itemId);
      if (def == null) return;
      items.add(InventoryItem.fromShopItem(def, quantity: amount));
    } else {
      items[idx] =
          items[idx].copyWith(quantity: items[idx].quantity + amount);
    }
    state = InventoryState(items: items, equippedItemId: state.equippedItemId);
  }

  /// 使用物品（数量 -1）
  ///
  /// 返回是否成功（数量不足返回 false）。
  bool useItem(String itemId) {
    final items = List<InventoryItem>.from(state.items);
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx < 0 || items[idx].quantity <= 0) return false;
    items[idx] =
        items[idx].copyWith(quantity: items[idx].quantity - 1);
    state = InventoryState(items: items, equippedItemId: state.equippedItemId);
    return true;
  }

  /// 移除指定数量的物品
  void removeItem(String itemId, {int amount = 1}) {
    if (amount <= 0) return;
    final items = List<InventoryItem>.from(state.items);
    final idx = items.indexWhere((i) => i.id == itemId);
    if (idx < 0) return;
    final newQty = items[idx].quantity - amount;
    if (newQty <= 0) {
      items[idx] = items[idx].copyWith(quantity: 0);
    } else {
      items[idx] = items[idx].copyWith(quantity: newQty);
    }
    state = InventoryState(items: items, equippedItemId: state.equippedItemId);
  }

  /// 装备物品
  void equip(String itemId) {
    if (state.getQuantity(itemId) <= 0) return;
    state = state.copyWith(equippedItemId: itemId);
  }

  /// 卸下装备
  void unequip() {
    state = state.copyWith(clearEquipped: true);
  }

  /// 重置
  void reset() {
    state = const InventoryState();
  }

  ShopItem? _findShopItem(String id) {
    for (final item in ShopItems.all) {
      if (item.id == id) return item;
    }
    return null;
  }
}

/// 物品栏 Provider
final inventoryProvider =
    StateNotifierProvider<InventoryNotifier, InventoryState>((ref) {
  return InventoryNotifier();
});
