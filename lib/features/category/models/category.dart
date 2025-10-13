import 'package:flutter/material.dart';

// Helper function to create IconData
IconData _createIconData(int codePoint) {
  return IconData(codePoint, fontFamily: 'MaterialIcons');
}

class Category {
  final String id;
  final String name;
  final String type;
  final IconData icon;
  final String? parentId;

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.parentId,
  });

  Category copyWith({
    String? id,
    String? name,
    String? type,
    IconData? icon,
    String? parentId,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      parentId: parentId ?? this.parentId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'icon': icon.codePoint,
      'parentId': parentId,
    };
  }

  static Category fromMap(Map<String, dynamic> map, String id) {
    final iconCode = map['icon'] as int;
    return Category(
      id: id,
      name: map['name'],
      type: map['type'],
      icon: _createIconData(iconCode),
      parentId: map['parentId'],
    );
  }

  // category from firestore
  factory Category.fromFirestore(Map<String, dynamic> data) {
    final iconCode = data['icon'] as int;
    return Category(
      id: data['id'] as String,
      name: data['name'] as String,
      type: data['type'] as String,
      icon: _createIconData(iconCode),
      parentId: data['parentId'] as String?,
    );
  }
}
