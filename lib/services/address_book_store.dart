

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/address_book_entry.dart';

class AddressBookStore {
  static const _prefsKey = 'address_book_entries_v1';

  Future<List<AddressBookEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final rawList = prefs.getStringList(_prefsKey) ?? const [];
    return rawList
        .map((raw) {
          try {
            final map = jsonDecode(raw) as Map<String, dynamic>;
            return AddressBookEntry.fromJson(map);
          } catch (_) {
            return null;
          }
        })
        .whereType<AddressBookEntry>()
        .toList();
  }

  Future<void> saveEntries(List<AddressBookEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _prefsKey,
      entries.map((e) => jsonEncode(e.toJson())).toList(),
    );
  }

  Future<void> upsertEntry(AddressBookEntry entry) async {
    final entries = await loadEntries();
    final updated = entries.where((e) => e.address != entry.address).toList()
      ..add(entry)
      ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
    await saveEntries(updated);
  }

  Future<void> removeEntry(String address) async {
    final entries = await loadEntries();
    final updated = entries.where((e) => e.address != address).toList();
    await saveEntries(updated);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }
}