import 'package:flutter/material.dart';
import 'package:smart_receipt/core/services/local_storage_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late bool _dateTranslation;
  late bool _location;
  late bool _calendarResults;
  late bool _notes;

  @override
  void initState() {
    super.initState();
    _dateTranslation = LocalStorageService.getBoolSetting(LocalStorageService.kDateTranslation);
    _location = LocalStorageService.getBoolSetting(LocalStorageService.kLocation);
    _calendarResults = LocalStorageService.getBoolSetting(LocalStorageService.kCalendarResults);
    _notes = LocalStorageService.getBoolSetting(LocalStorageService.kNotes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Date translation'),
            value: _dateTranslation,
            onChanged: (v) async {
              setState(() => _dateTranslation = v);
              await LocalStorageService.setBoolSetting(LocalStorageService.kDateTranslation, v);
            },
          ),
          SwitchListTile(
            title: const Text('Location (paid)'),
            value: _location,
            onChanged: (v) async {
              setState(() => _location = v);
              await LocalStorageService.setBoolSetting(LocalStorageService.kLocation, v);
            },
          ),
          SwitchListTile(
            title: const Text('Calendar results'),
            value: _calendarResults,
            onChanged: (v) async {
              setState(() => _calendarResults = v);
              await LocalStorageService.setBoolSetting(LocalStorageService.kCalendarResults, v);
            },
          ),
          SwitchListTile(
            title: const Text('Notes'),
            value: _notes,
            onChanged: (v) async {
              setState(() => _notes = v);
              await LocalStorageService.setBoolSetting(LocalStorageService.kNotes, v);
            },
          ),
        ],
      ),
    );
  }
}


