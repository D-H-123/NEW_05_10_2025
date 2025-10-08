
// Simple bill model placeholder. In production, add Hive type adapters and encryption.
import 'package:hive/hive.dart';

part 'bill_model.g.dart'; // Generated file by Hive (run build_runner)

@HiveType(typeId: 0) // Every model needs a unique typeId
class Bill extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String imagePath;

  @HiveField(2)
  final String? vendor;

  @HiveField(3)
  final DateTime? date;

  @HiveField(4)
  final double? total;

  @HiveField(5)
  final String ocrText;

  // Extended fields to support categorization and analytics
  @HiveField(6)
  final String? categoryId;

  @HiveField(7)
  final String? currency;

  @HiveField(8)
  final double? subtotal;

  @HiveField(9)
  final double? tax;

  @HiveField(10)
  final String? notes;

  @HiveField(11)
  final DateTime createdAt;

  @HiveField(12)
  final DateTime updatedAt;

  @HiveField(13)
  final List<String>? tags;

  @HiveField(14)
  final String? location;

  // User-friendly title for manual or edited entries
  @HiveField(15)
  final String? title;

  // Subscription type to identify subscription bills
  @HiveField(16)
  final String? subscriptionType; // 'weekly', 'monthly', 'yearly', or null for non-subscriptions

  Bill({
    required this.id,
    required this.imagePath,
    this.vendor,
    this.date,
    this.total,
    String? ocrText,
    this.categoryId,
    this.currency,
    this.subtotal,
    this.tax,
    this.notes,
    this.tags,
    this.location,
    this.title,
    this.subscriptionType,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : ocrText = ocrText ?? 'Manual entry',
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();
}

