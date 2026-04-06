import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../database/database_helper.dart';
import 'main_scaffold.dart'; // REQUIRED TO RESTART APP AFTER WIPE

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final Color oceanDeep = const Color(0xFF006064);

  Future<void> _showNameDialog() async {
    TextEditingController nameController = TextEditingController();
    await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text("Change Display Name"),
            content: TextField(
              controller: nameController,
              decoration: const InputDecoration(hintText: "Enter your name"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: oceanDeep),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('userName', nameController.text);

                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Name updated!")));
                  }
                },
                child:
                    const Text("Save", style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
  }

  Future<void> _exportData() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final expenses = await DatabaseHelper.instance.getExpenses();
      List<List<dynamic>> rows = [
        ["Date", "Merchant", "Category", "Amount", "Source"]
      ];

      for (var exp in expenses) {
        rows.add([
          exp['date_time'] ?? '',
          exp['merchant_name'] ?? 'Unknown',
          exp['category_name'] ?? 'Other',
          exp['amount'] ?? 0.0,
          exp['source'] ?? 'Manual',
        ]);
      }

      String csvData = csv.encode(rows);

      final directory = await getApplicationDocumentsDirectory();
      final path = "${directory.path}/smart_expense_export.csv";
      final file = File(path);
      await file.writeAsString(csvData);

      await Share.shareXFiles([XFile(path)], text: 'My Expense Data');
    } catch (e) {
      messenger.showSnackBar(
          const SnackBar(content: Text("Failed to export data.")));
    }
  }

  Future<void> _showWipeWarning() async {
    await showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text("Wipe All Data",
                style: TextStyle(color: Colors.red)),
            content: const Text(
                "Are you sure? This will delete all expenses and reset your name."),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  await DatabaseHelper.instance.wipeAllData();

                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('userName');

                  if (!dialogContext.mounted) return;

                  // INSTANT APP REFRESH FIX
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const MainScaffold()),
                    (Route<dynamic> route) => false,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("All data wiped successfully!")));
                  }
                },
                child: const Text("Wipe Data",
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        title: const Text('Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: oceanDeep,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 10),
        children: [
          ListTile(
            leading: Icon(Icons.person, color: oceanDeep, size: 30),
            title: const Text("Change Display Name",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Customize your dashboard greeting"),
            onTap: _showNameDialog,
          ),
          const Divider(),
          ListTile(
            leading: Icon(Icons.download, color: oceanDeep, size: 30),
            title: const Text("Export Data to CSV",
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text("Generate a spreadsheet of all expenses"),
            onTap: _exportData,
          ),
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.delete_forever, color: Colors.red, size: 30),
            title: const Text("Wipe All Data",
                style:
                    TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            subtitle: const Text("Permanently delete all expenses and budgets",
                style: TextStyle(color: Colors.red)),
            onTap: _showWipeWarning,
          ),
        ],
      ),
    );
  }
}
