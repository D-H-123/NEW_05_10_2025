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
    state = box.values.toList();
  }

  void updateBill(Bill bill) {
    box.put(bill.id, bill);
    state = box.values.toList();
  }

  void deleteBill(String billId) {
    box.delete(billId);
    state = box.values.toList();
  }
}

final billProvider = StateNotifierProvider<BillNotifier, List<Bill>>((ref) {
  final box = ref.watch(billBoxProvider);
  return BillNotifier(box);
});
