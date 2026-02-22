import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/counter_provider.dart';
import '../utils/formatters.dart';

class ExpenseScreen extends StatefulWidget {
  const ExpenseScreen({super.key});

  @override
  State<ExpenseScreen> createState() => _ExpenseScreenState();
}

class _ExpenseScreenState extends State<ExpenseScreen> {
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedCategory = 'Supplies';
  late Future<List<Map<String, dynamic>>> _expensesFuture;
  
  // Track which tile is expanded
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    setState(() {
      _expensesFuture = context.read<CounterProvider>().fetchAllExpenses();
    });
  }

  void _showTopAlert(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16, // Just below status bar
        left: 0,
        right: 0,
        child: SafeArea(
          child: _PremiumTopAlert(
            message: message,
            isError: isError,
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Auto dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 130, spreadRadius: 50)],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                'SHOP EXPENSES',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                  fontSize: 14,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(top: 100, right: -70, child: _buildGlow(250, Colors.blueAccent.withValues(alpha: 0.12))),
          Positioned(bottom: 100, left: -70, child: _buildGlow(300, Colors.redAccent.withValues(alpha: 0.08))),

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 120),
                _buildLabel("LOG NEW EXPENSE"),
                
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Column(
                    children: [
                      _buildInputContainer(
                        child: DropdownButtonFormField<String>(
                          dropdownColor: const Color(0xFF1A1C29),
                          initialValue: _selectedCategory,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                          items: ['Rent', 'Supplies', 'Electricity', 'Misc']
                              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val!),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            prefixIcon: Icon(Icons.category_rounded, color: Colors.blueAccent, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(_amountController, "Amount (PHP)", Icons.payments_rounded, TextInputType.number),
                      const SizedBox(height: 12),
                      _buildTextField(_descController, "Description (Optional)", Icons.description_rounded, TextInputType.text),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: () async {
                            final amount = int.tryParse(_amountController.text) ?? 0;
                            if (amount > 0) {
                              HapticFeedback.mediumImpact();
                              try {
                              await context.read<CounterProvider>().addExpense(amount, _selectedCategory, _descController.text);
                                if (!context.mounted) return; // <--- NEW
                                _amountController.clear(); 
                                _descController.clear(); 
                                _refresh();
                                _showTopAlert(context, 'Expense saved successfully!');
                              } catch (e) {
                                if (!context.mounted) return; // <--- NEW
                                _showTopAlert(context, 'Error saving expense', isError: true);
                              }
                            } else {
                              _showTopAlert(context, 'Please enter a valid amount', isError: true);
                            }
                          },
                          child: const Text('SAVE EXPENSE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _expensesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
                    }
                    
                    final allExpenses = snapshot.data ?? [];
                    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
                    final todayTotal = allExpenses
                        .where((e) => DateFormat('yyyy-MM-dd').format(DateTime.parse(e['date'])) == today)
                        .fold(0.0, (sum, e) => sum + (e['amount'] ?? 0));

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTodaySummary(todayTotal),
                        const SizedBox(height: 30),
                        _buildLabel("RECENT EXPENSE HISTORY"),
                        if (allExpenses.isEmpty)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.only(top: 20),
                              child: Text("No records found.", style: TextStyle(color: Colors.white24, fontWeight: FontWeight.w600)),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            padding: EdgeInsets.zero,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: allExpenses.length,
                            itemBuilder: (context, index) {
                              final exp = allExpenses[index];
                              final formattedDate = DateFormat('MMM dd, yyyy').format(DateTime.parse(exp['date']).toLocal());
                              return _buildExpenseTile(context, exp, formattedDate, index);
                            },
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaySummary(double total) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [Colors.redAccent.withValues(alpha: 0.15), Colors.redAccent.withValues(alpha: 0.05)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Text("TOTAL EXPENSE TODAY", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(total),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseTile(BuildContext context, Map<String, dynamic> exp, String date, int index) {
    bool isExpanded = _expandedIndex == index;
    String description = exp['description'] ?? "No description provided.";

    return GestureDetector(
      onTap: () {
        setState(() {
          _expandedIndex = isExpanded ? null : index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: isExpanded ? Colors.blueAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                _getCategoryIcon(exp['category']),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, 
                    children: [
                      Text(exp['category'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                      Text(date, style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "- ${CurrencyFormatter.format(exp['amount'])}", 
                      style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 15),
                    ),
                    const SizedBox(height: 4),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white24,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
            if (isExpanded) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(color: Colors.white10, height: 1),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      description,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton(
                    onPressed: () => _showDeleteConfirmation(context, exp['id'].toString()),
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  // REFINED GLASS DIALOG (Copied from Settings design)
// REFINED GLASS DIALOG (Matched to Counter Screen)
  void _showDeleteConfirmation(BuildContext context, String id) {
    HapticFeedback.vibrate();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim1,
            child: AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1C29).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          "Delete Record?", 
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "This action cannot be undone. Are you sure you want to remove this expense?", 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 14)
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("Cancel", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent.withValues(alpha: 0.8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  try {
                                    // Optional: Show loading indicator while deleting
                                    showDialog(
                                      context: context, 
                                      barrierDismissible: false,
                                      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.redAccent)),
                                    );
                                  await context.read<CounterProvider>().deleteExpense(id);
                                    
                                    if (!context.mounted) return; // <--- NEW
                                    
                                    Navigator.pop(context); // Pop loading dialog
                                    Navigator.pop(context); // Pop confirmation modal
                                    
                                    _refresh();
                                    _showTopAlert(context, 'Expense record deleted.');
                                  } catch (e) {
                                    if (!context.mounted) return; // <--- NEW
                                    Navigator.pop(context); // Pop loading dialog
                                    Navigator.pop(context); // Pop confirmation modal
                                    _showTopAlert(context, 'Error deleting expense', isError: true);
                                  }
                                },
                                child: const Text("Delete", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 12, left: 4), 
    child: Text(t, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
  );

  Widget _buildInputContainer({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12), 
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.2), 
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
    ), 
    child: child,
  );

  Widget _buildTextField(TextEditingController c, String h, IconData icon, TextInputType t) => _buildInputContainer(
    child: TextField(
      controller: c, 
      keyboardType: t, 
      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600), 
      decoration: InputDecoration(
        icon: Icon(icon, color: Colors.blueAccent, size: 20),
        border: InputBorder.none, 
        hintText: h, 
        hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
      ),
    ),
  );

  Widget _getCategoryIcon(String cat) { 
    IconData i; Color c; 
    switch (cat) { 
      case 'Rent': i = Icons.home_work_rounded; c = Colors.orangeAccent; break; 
      case 'Supplies': i = Icons.inventory_2_rounded; c = Colors.blueAccent; break; 
      case 'Electricity': i = Icons.electric_bolt_rounded; c = Colors.yellowAccent; break; 
      default: i = Icons.miscellaneous_services_rounded; c = Colors.purpleAccent; 
    } 
    return Container(
      padding: const EdgeInsets.all(10), 
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), shape: BoxShape.circle), 
      child: Icon(i, color: c, size: 22),
    ); 
  }
}

class _PremiumTopAlert extends StatelessWidget {
  final String message;
  final bool isError;

  const _PremiumTopAlert({
    required this.message, 
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      tween: Tween<double>(begin: -100, end: 0),
      builder: (context, double value, child) {
        return Transform.translate(
          offset: Offset(0, value),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: Center( 
          child: ClipRRect(
            borderRadius: BorderRadius.circular(25),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), 
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6), 
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), 
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isError ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded, 
                      color: isError ? Colors.redAccent : Colors.greenAccent, 
                      size: 22
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2, 
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}