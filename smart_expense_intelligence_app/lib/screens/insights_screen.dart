import 'package:flutter/material.dart';
import '../models/insight.dart';
import '../services/insights_service.dart';

class InsightsScreen extends StatefulWidget {
  final int refreshTrigger; // ✅ ADDED: The trigger listener
  const InsightsScreen({super.key, this.refreshTrigger = 0});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  final InsightsService _insightsService = InsightsService();
  late Future<List<Insight>> _insightsFuture;
  final Color oceanDeep = const Color(0xFF006064); 

  @override
  void initState() {
    super.initState();
    _loadInsights();
  }

  // ✅ ADDED: Forces the AI to recalculate the exact second a new expense is added
  @override
  void didUpdateWidget(covariant InsightsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.refreshTrigger != oldWidget.refreshTrigger) {
      _loadInsights();
    }
  }

  Future<void> _loadInsights() async {
    setState(() {
      _insightsFuture = _insightsService.generateInsights(DateTime.now());
    });
    await _insightsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F8),
      appBar: AppBar(
        automaticallyImplyLeading: false, // Ensures no back arrow on main tabs
        backgroundColor: oceanDeep,
        elevation: 0,
        title: const Text('Smart Insights', 
          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        color: oceanDeep,
        onRefresh: _loadInsights,
        child: FutureBuilder<List<Insight>>(
          future: _insightsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: oceanDeep));
            }
            final insights = snapshot.data ?? [];
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              itemCount: insights.length,
              itemBuilder: (context, index) {
                final insight = insights[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 20.0),
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        insight.type == 'warning' ? Icons.warning_amber_rounded : 
                        (insight.type == 'positive' ? Icons.check_circle_outline : Icons.lightbulb_rounded),
                        color: insight.type == 'warning' ? Colors.orange : 
                               (insight.type == 'positive' ? Colors.green : oceanDeep),
                        size: 40,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(insight.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Text(insight.message, style: const TextStyle(fontSize: 17, color: Colors.black87, height: 1.5)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}