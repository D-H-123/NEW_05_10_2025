import 'package:flutter/material.dart';

class CurrencyPicker extends StatelessWidget {
  final String? selectedCode;
  final ValueChanged<String> onSelected;

  const CurrencyPicker({super.key, required this.selectedCode, required this.onSelected});

  static const List<String> commonCurrencies = [
    'USD','EUR','GBP','CAD','AUD','CHF','INR','BRL'
  ];

  String _getCurrencySymbol(String code) {
    switch (code) {
      case 'USD': return '\$';
      case 'EUR': return '€';
      case 'GBP': return '£';
      case 'CAD': return 'C\$';
      case 'AUD': return 'A\$';
      case 'CHF': return 'CHF';
      case 'INR': return '₹';
      case 'BRL': return 'R\$';
      default: return code;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Select currency'),
      children: [
        SizedBox(
          width: 360,
          height: 420,
          child: ListView.builder(
            itemCount: commonCurrencies.length,
            itemBuilder: (context, index) {
              final code = commonCurrencies[index];
              final symbol = _getCurrencySymbol(code);
              return RadioListTile<String>(
                value: code,
                groupValue: selectedCode,
                title: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Center(
                        child: Text(
                          symbol,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(code),
                  ],
                ),
                onChanged: (v) {
                  if (v != null) {
                    onSelected(v);
                    Navigator.of(context).pop();
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

Future<void> showCurrencyPicker({
  required BuildContext context,
  required String? selectedCode,
  required ValueChanged<String> onSelected,
}) async {
  await showDialog(
    context: context,
    builder: (_) => CurrencyPicker(selectedCode: selectedCode, onSelected: onSelected),
  );
}


