import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

part 'custom_category.g.dart';

/// Custom category model that users can create
@HiveType(typeId: 2)
class CustomCategory extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String emoji; // Emoji or symbol to represent the category

  @HiveField(3)
  final int colorValue; // Color stored as int

  @HiveField(4)
  final List<String> keywords; // Keywords for OCR detection

  @HiveField(5)
  final List<String> availableIn; // 'receipt', 'expense', 'subscription'

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime updatedAt;

  CustomCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.colorValue,
    required this.keywords,
    required this.availableIn,
    required this.createdAt,
    required this.updatedAt,
  });

  // Convenience getter for color
  Color get color => Color(colorValue);

  // Create a copy with optional updates
  CustomCategory copyWith({
    String? name,
    String? emoji,
    int? colorValue,
    List<String>? keywords,
    List<String>? availableIn,
    DateTime? updatedAt,
  }) {
    return CustomCategory(
      id: id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      colorValue: colorValue ?? this.colorValue,
      keywords: keywords ?? this.keywords,
      availableIn: availableIn ?? this.availableIn,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'emoji': emoji,
      'colorValue': colorValue,
      'keywords': keywords,
      'availableIn': availableIn,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  // Create from JSON
  factory CustomCategory.fromJson(Map<String, dynamic> json) {
    return CustomCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      emoji: json['emoji'] as String,
      colorValue: json['colorValue'] as int,
      keywords: (json['keywords'] as List<dynamic>).cast<String>(),
      availableIn: (json['availableIn'] as List<dynamic>).cast<String>(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  String toString() {
    return 'CustomCategory(id: $id, name: $name, emoji: $emoji, availableIn: $availableIn)';
  }
}

