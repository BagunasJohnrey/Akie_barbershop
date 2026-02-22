import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/counter_provider.dart';
import '../utils/formatters.dart';
import '../services/pdf_export_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = true;

  double _grossRevenue = 0;
  double _totalExpenses = 0;
  List<Map<String, dynamic>> _barberReports = [];
  double _monthlyGross = 0;
  double _monthlyExpenses = 0;
  List<FlSpot> _dailyProfitSpots = [];

  @override
  void initState() {
    super.initState();
    _loadAllReports();
  }

  Future<void> _loadAllReports() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    final provider = context.read<CounterProvider>();
    final supabase = Supabase.instance.client;

    try {
      // 1. Setup Date Strings
      final selectedDateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      final monthStartStr = DateFormat('yyyy-MM-dd').format(DateTime(_selectedDate.year, _selectedDate.month, 1));
      final monthEndStr = DateFormat('yyyy-MM-dd').format(DateTime(_selectedDate.year, _selectedDate.month + 1, 0));

      final dayStartUtc = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day).toUtc().toIso8601String();
      final dayEndUtc = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59).toUtc().toIso8601String();
      final monthStartUtc = DateTime(_selectedDate.year, _selectedDate.month, 1).toUtc().toIso8601String();
      final monthEndUtc = DateTime(_selectedDate.year, _selectedDate.month + 1, 0, 23, 59, 59).toUtc().toIso8601String();

      // 2. Fetch Data from Supabase
      final barbersData = await supabase.from('barbers').select();
      final dailyReport = await supabase.from('daily_reports').select().eq('date', selectedDateStr).maybeSingle();
      final dailyExpenses = await supabase.from('expenses').select().gte('date', dayStartUtc).lte('date', dayEndUtc);
      final monthlyReports = await supabase.from('daily_reports').select().gte('date', monthStartStr).lte('date', monthEndStr);
      final monthlyExpenses = await supabase.from('expenses').select().gte('date', monthStartUtc).lte('date', monthEndUtc);

      // Map Barber IDs to Names for easy lookup
      Map<String, String> barberIdToName = {};
      for (var b in barbersData) {
        barberIdToName[b['id']] = b['name'];
      }

      // 3. Calculate Daily Stats
      double tempGross = 0;
      List<Map<String, dynamic>> tempBarberReports = [];

      // If viewing a closed day (or past day), use the saved report
      if (dailyReport != null) {
        tempGross = (dailyReport['total_revenue'] ?? 0).toDouble();
        
        if (dailyReport['barber_stats'] != null) {
          Map<String, dynamic> stats = dailyReport['barber_stats'];
          stats.forEach((barberId, count) {
            double bEarnings = (count as int) * (provider.globalPrice * 0.5);
            tempBarberReports.add({
              'name': barberIdToName[barberId] ?? 'Unknown Barber',
              'count': count,
              'profit': bEarnings,
            });
          });
        }
      } 
      // If viewing TODAY and the shop isn't closed yet, use live Provider data
      else if (selectedDateStr == todayStr) {
        tempGross = provider.todayTransactions.length * provider.globalPrice.toDouble();
        
        Map<String, int> liveCounts = {};
        for (var t in provider.todayTransactions) {
          String bId = t['barber_id'];
          liveCounts[bId] = (liveCounts[bId] ?? 0) + 1;
        }
        
        liveCounts.forEach((barberId, count) {
          double bEarnings = count * (provider.globalPrice * 0.5);
          tempBarberReports.add({
            'name': barberIdToName[barberId] ?? 'Unknown Barber',
            'count': count,
            'profit': bEarnings,
          });
        });
      }

      double tempExp = 0;
      for (var e in dailyExpenses) { tempExp += (e['amount'] ?? 0).toDouble(); }

      // 4. Calculate Monthly Stats & Chart Data
      double tempMGross = 0;
      Map<int, double> dailyGrossMap = {};
      
      for (var r in monthlyReports) {
        double rev = (r['total_revenue'] ?? 0).toDouble();
        tempMGross += rev;
        int day = DateTime.parse(r['date']).day;
        dailyGrossMap[day] = rev;
      }

      // Inject today's live data into the monthly total if viewing the current month and it isn't closed yet
      if (_selectedDate.year == DateTime.now().year && _selectedDate.month == DateTime.now().month && !provider.isShopClosed) {
        double todayLiveRev = provider.todayTransactions.length * provider.globalPrice.toDouble();
        tempMGross += todayLiveRev;
        dailyGrossMap[DateTime.now().day] = todayLiveRev;
      }

      double tempMExpTotal = 0;
      Map<int, double> dailyExpMap = {};
      for (var e in monthlyExpenses) {
        double amt = (e['amount'] ?? 0).toDouble();
        tempMExpTotal += amt;
        int day = DateTime.parse(e['date']).toLocal().day;
        dailyExpMap[day] = (dailyExpMap[day] ?? 0) + amt;
      }

      // Generate the Graph Spots
      List<FlSpot> spots = [];
      final daysInMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).day;
      final currentDayOfMonth = DateTime.now().day;
      final isCurrentMonth = _selectedDate.year == DateTime.now().year && _selectedDate.month == DateTime.now().month;

      for (int i = 1; i <= daysInMonth; i++) {
        // Stop plotting flat lines for future days in the current month
        if (isCurrentMonth && i > currentDayOfMonth) break; 
        
        double dayShopGross = dailyGrossMap[i] ?? 0;
        double dayExpenses = dailyExpMap[i] ?? 0;
        double dayNet = (dayShopGross * 0.5) - dayExpenses;
        
        spots.add(FlSpot(i.toDouble(), dayNet));
      }

      // Sort barber reports by count (highest first)
      tempBarberReports.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

      if (!mounted) return;
      setState(() {
        _grossRevenue = tempGross; 
        _totalExpenses = tempExp; 
        _barberReports = tempBarberReports;
        _monthlyGross = tempMGross; 
        _monthlyExpenses = tempMExpTotal; 
        _dailyProfitSpots = spots;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Analytics Load Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double dailyShopNet = (_grossRevenue * 0.5) - _totalExpenses;
    double monthlyShopNet = (_monthlyGross * 0.5) - _monthlyExpenses;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C12),
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              elevation: 0,
              backgroundColor: Colors.white.withValues(alpha: 0.02),
              centerTitle: true,
              title: const Text(
                'SHOP REPORT',
                style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 3.0, fontSize: 14, color: Colors.white70),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent),
                  onPressed: () => PdfExportService.generateMonthlyReport(
                    monthYear: DateFormat('MMMM yyyy').format(_selectedDate),
                    gross: _monthlyGross,
                    expenses: _monthlyExpenses,
                    net: monthlyShopNet,
                    barberReports: _barberReports,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.calendar_month_rounded, color: Colors.blueAccent),
                  onPressed: () => _selectDate(context),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          _buildGlow(100, -70, Colors.blueAccent.withValues(alpha: 0.12)),
          _buildLoadingOrContent(dailyShopNet, monthlyShopNet),
        ],
      ),
    );
  }

  Widget _buildLoadingOrContent(double dailyNet, double monthlyNet) {
    if (_isLoading) return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 120),
          _buildHeader(DateFormat('EEEE, MMM d, yyyy').format(_selectedDate)),
          const SizedBox(height: 20),
          _buildSectionLabel("FINANCIAL SUMMARY"),
          _buildSummaryCard(dailyNet),
          const SizedBox(height: 30),
          _buildSectionLabel("BARBER EARNINGS"),
          if (_barberReports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No records for this date.", style: TextStyle(color: Colors.white38))),
            )
          else
            ..._barberReports.map((r) => _buildBarberCard(r)),
          const SizedBox(height: 30),
          _buildSectionLabel("MONTHLY PROFIT TREND"),
          _buildLineChart(),
          const SizedBox(height: 30),
          _buildSectionLabel("${DateFormat('MMMM').format(_selectedDate).toUpperCase()} OVERVIEW"),
          _buildMonthlyCard(monthlyNet, _monthlyGross, _monthlyExpenses),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildGlow(double top, double right, Color color) => Positioned(
    top: top, right: right,
    child: Container(
      width: 280, height: 280,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: color, blurRadius: 130, spreadRadius: 50)]),
    ),
  );

  Widget _buildHeader(String date) => Text(date.toUpperCase(), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 12));
  Widget _buildSectionLabel(String text) => Padding(padding: const EdgeInsets.only(bottom: 12, left: 4), child: Text(text, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)));

  Widget _buildSummaryCard(double net) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              _buildStatRow("Gross Revenue", _grossRevenue, Colors.greenAccent),
              _buildStatRow("Total Expenses", _totalExpenses, Colors.redAccent, isNegative: true),
              const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: Divider(color: Colors.white10, height: 1)),
              _buildStatRow("NET PROFIT", net, Colors.white, isHeader: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, double amount, Color color, {bool isHeader = false, bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: isHeader ? Colors.white : Colors.white38, fontSize: isHeader ? 16 : 14, fontWeight: isHeader ? FontWeight.w900 : FontWeight.w600)),
          Text("${isNegative ? '- ' : ''}${CurrencyFormatter.format(amount)}", style: TextStyle(color: color, fontSize: isHeader ? 22 : 16, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildBarberCard(Map<String, dynamic> report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start, 
            children: [
              Text(report['name'].toString().toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.1)),
              const SizedBox(height: 4),
              Text("${report['count']} services completed", style: const TextStyle(color: Colors.white24, fontSize: 11, fontWeight: FontWeight.bold)),
            ]
          ),
          Text(CurrencyFormatter.format(report['profit']), style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w900, fontSize: 18, letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    if (_dailyProfitSpots.isEmpty) return const SizedBox(height: 200, child: Center(child: Text("No trend data available", style: TextStyle(color: Colors.white24))));
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(10, 20, 25, 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: LineChart(
        LineChartData(
          minY: 0,
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.05), strokeWidth: 1)),
          titlesData: const FlTitlesData(show: true, rightTitles: AxisTitles(), topTitles: AxisTitles(), leftTitles: AxisTitles()),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: _dailyProfitSpots,
              isCurved: true,
              gradient: const LinearGradient(colors: [Colors.blueAccent, Colors.cyanAccent]),
              barWidth: 4,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [Colors.blueAccent.withValues(alpha: 0.2), Colors.transparent], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
            )
          ]
        )
      ),
    );
  }

  Widget _buildMonthlyCard(double net, double gross, double exp) {
    return Container(
      padding: const EdgeInsets.all(28), 
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(colors: [Colors.blueAccent.withValues(alpha: 0.15), Colors.blueAccent.withValues(alpha: 0.05)]), 
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2))
      ), 
      child: Column(
        children: [
          const Text("ESTIMATED SHOP PROFIT", style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)), 
          const SizedBox(height: 12), 
          Text(CurrencyFormatter.format(net), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1.5)), 
          const SizedBox(height: 25), 
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround, 
            children: [
              _buildSmallStat("MONTHLY GROSS", gross, Colors.white70), 
              Container(width: 1, height: 30, color: Colors.white10),
              _buildSmallStat("MONTHLY EXPENSES", exp, Colors.redAccent)
            ]
          )
        ]
      )
    );
  }

  Widget _buildSmallStat(String l, double a, Color c) => Column(
    children: [
      Text(l, style: const TextStyle(color: Colors.white38, fontSize: 8, fontWeight: FontWeight.w900, letterSpacing: 1.0)), 
      const SizedBox(height: 4),
      Text(CurrencyFormatter.format(a), style: TextStyle(color: c, fontWeight: FontWeight.w900, fontSize: 16))
    ]
  );

  Future<void> _selectDate(BuildContext context) async { 
    final DateTime? picked = await showDatePicker(
      context: context, 
      initialDate: _selectedDate, 
      firstDate: DateTime(2025), 
      lastDate: DateTime.now(), 
      builder: (context, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Colors.blueAccent, surface: Color(0xFF1A1C29)),
          dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF0A0C12)),
        ), 
        child: child!
      )
    ); 
    if (picked != null) { 
      setState(() => _selectedDate = picked); 
      _loadAllReports(); 
    } 
  }
}