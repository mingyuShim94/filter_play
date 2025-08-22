import 'package:flutter/material.dart';
import 'filter_item.dart';

class FilterCategory {
  final String id;
  final String name;
  final IconData icon;
  final bool isEnabled;
  final List<FilterItem> items;

  const FilterCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.isEnabled,
    required this.items,
  });

  FilterCategory copyWith({
    String? id,
    String? name,
    IconData? icon,
    bool? isEnabled,
    List<FilterItem>? items,
  }) {
    return FilterCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      isEnabled: isEnabled ?? this.isEnabled,
      items: items ?? this.items,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterCategory &&
        other.id == id &&
        other.name == name &&
        other.icon == icon &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        name.hashCode ^
        icon.hashCode ^
        isEnabled.hashCode;
  }

  @override
  String toString() {
    return 'FilterCategory(id: $id, name: $name, isEnabled: $isEnabled, items: ${items.length})';
  }
}