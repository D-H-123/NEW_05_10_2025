import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:smart_receipt/features/storage/models/bill_model.dart';

final billBoxProvider = Provider<Box<Bill>>((ref) {
  return Hive.box<Bill>('billsBox');
});

class BillNotifier extends StateNotifier<List<Bill>> {
  final Box<Bill> box;
  BillNotifier(this.box) : super(box.values.toList());

  void addBill(Bill bill) {
    box.put(bill.id, bill);
    // ✅ Optimized: Immutable update instead of recreating entire list
    state = [...state, bill];
  }

  void updateBill(Bill bill) {
    box.put(bill.id, bill);
    // ✅ Optimized: Find and update only the changed item
    final index = state.indexWhere((b) => b.id == bill.id);
    if (index != -1) {
      state = [
        ...state.sublist(0, index),
        bill,
        ...state.sublist(index + 1),
      ];
    } else {
      // Bill not found in state, add it
      state = [...state, bill];
    }
  }

  void deleteBill(String billId) {
    box.delete(billId);
    // ✅ Optimized: Filter instead of recreating entire list
    state = state.where((b) => b.id != billId).toList();
  }

  void updateBillSubscriptionFrequency(String billId, String newFrequency) {
    final bill = box.get(billId);
    if (bill != null) {
      // Create a new Bill object with updated subscription type
      final updatedBill = Bill(
        id: bill.id,
        imagePath: bill.imagePath,
        vendor: bill.vendor,
        date: bill.date,
        total: bill.total,
        ocrText: bill.ocrText,
        categoryId: bill.categoryId,
        currency: bill.currency,
        subtotal: bill.subtotal,
        tax: bill.tax,
        notes: bill.notes,
        tags: bill.tags,
        location: bill.location,
        title: bill.title,
        subscriptionType: newFrequency,
        subscriptionEndDate: bill.subscriptionEndDate, // Preserve existing end date
        createdAt: bill.createdAt,
        updatedAt: DateTime.now(),
      );
      box.put(billId, updatedBill);
      // ✅ Optimized: Use updateBill method for consistency
      updateBill(updatedBill);
    }
  }
}

final billProvider = StateNotifierProvider<BillNotifier, List<Bill>>((ref) {
  final box = ref.watch(billBoxProvider);
  return BillNotifier(box);
});
