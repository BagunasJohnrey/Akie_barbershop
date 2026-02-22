import 'dart:ui'; // Required for ImageFilter
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/counter_provider.dart';
import '../models/barber_model.dart';
import '../utils/formatters.dart'; 
import 'expense_screen.dart';
import 'analytics_screen.dart';
import 'settings_screen.dart'; 

class CounterScreen extends StatefulWidget {
  const CounterScreen({super.key});

  @override
  State<CounterScreen> createState() => _CounterScreenState();
}

class _CounterScreenState extends State<CounterScreen> {
  bool _obscureMoney = false;
  late Future<List<Map<String, dynamic>>> _barbersFuture;

  @override
  void initState() {
    super.initState();
    _refreshBarbers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CounterProvider>().fetchTodayTransactions();
    });
  }

  void _refreshBarbers() {
    setState(() {
      _barbersFuture = Supabase.instance.client
          .from('barbers')
          .select()
          .eq('is_active', true)
          .order('name', ascending: true);
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

  void _logout(BuildContext context) {
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
                      color: const Color(0xFF1A1C29).withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
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
                          child: const Icon(Icons.lock_reset_rounded, color: Colors.redAccent, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text("Lock Dashboard?", 
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text("Access will require your secure PIN.", 
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white60, fontSize: 14)),
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
                                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
                                child: const Text("Lock", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showCloseDayConfirmation(BuildContext context) async {
    final provider = context.read<CounterProvider>();
    final allTransactions = provider.todayTransactions;
    final totalWalkIns = allTransactions.length;
    final totalRevenue = totalWalkIns * provider.globalPrice.toDouble();

    // Fetch the loaded barbers directly from our future
    final barbersData = await _barbersFuture;
    final barbers = barbersData.map((b) => Barber.fromMap(b)).toList();

    if (!context.mounted) return;

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
                      border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_rounded, color: Colors.blueAccent, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          "Close Day Summary",
                          style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
                        // Barber List Summary
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          child: SingleChildScrollView(
                            child: Column(
                              children: barbers.map((barber) {
                                final barberCount = allTransactions.where((t) => t['barber_id'] == barber.id).length;
                                final barberProfit = barberCount * (provider.globalPrice * 0.5);
                                
                                if (barberCount == 0) return const SizedBox.shrink();

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        barber.name.toUpperCase(),
                                        style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                                      ),
                                      Row(
                                        children: [
                                          Text(
                                            "${barberCount}x",
                                            style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            CurrencyFormatter.format(barberProfit),
                                            style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                        
                        Divider(color: Colors.white.withValues(alpha: 0.1), height: 32),
                        
                        // Total Day Summary
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Clients:", style: TextStyle(color: Colors.white60)),
                            Text(CurrencyFormatter.count.format(totalWalkIns), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text("Total Revenue:", style: TextStyle(color: Colors.white60)),
                            Text(CurrencyFormatter.format(totalRevenue), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Action Buttons
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
                                  backgroundColor: Colors.blueAccent.withValues(alpha: 0.8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  try {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(child: CircularProgressIndicator()),
                                    );

                                    await context.read<CounterProvider>().closeDay();

                                    if (!context.mounted) return;
                                    
                                    Navigator.pop(context); // Pop loading
                                    Navigator.pop(context); // Pop dialog

                                    HapticFeedback.heavyImpact();
                                    _showTopAlert(context, 'Day successfully closed & archived!');
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    Navigator.pop(context); 
                                    _showTopAlert(context, 'Error closing day: $error', isError: true);
                                  }
                                },
                                child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

  void _showReopenConfirmation(BuildContext context) {
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
                      border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.orangeAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.lock_open_rounded, color: Colors.orangeAccent, size: 32),
                        ),
                        const SizedBox(height: 16),
                        const Text("Reopen Shop?", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text(
                          "This will remove the saved summary report and restore today's counters to let you add more clients.", 
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
                                  backgroundColor: Colors.orangeAccent.withValues(alpha: 0.8),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  try {
                                    showDialog(
                                      context: context, barrierDismissible: false,
                                      builder: (context) => const Center(child: CircularProgressIndicator(color: Colors.orangeAccent)),
                                    );

                                    await context.read<CounterProvider>().reopenDay();

                                    if (!context.mounted) return;
                                    
                                    Navigator.pop(context); // Pop loading
                                    Navigator.pop(context); // Pop dialog

                                    HapticFeedback.lightImpact();
                                    _showTopAlert(context, 'Shop reopened! Counters restored.');
                                  } catch (error) {
                                    if (!context.mounted) return;
                                    Navigator.pop(context); 
                                    _showTopAlert(context, 'Error: $error', isError: true);
                                  }
                                },
                                child: const Text("Reopen", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
    // Watch the closed state here!
    final isShopClosed = context.watch<CounterProvider>().isShopClosed;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C12),
      drawer: _buildDrawer(context),
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
              title: Text(
                isShopClosed ? 'SHOP CLOSED' : 'AKIE BARBERSHOP',
                style: TextStyle(
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 3.5, 
                  fontSize: 14, 
                  color: isShopClosed ? Colors.redAccent : Colors.white70
                ),
              ),
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Colors.white),
                  onPressed: () => Scaffold.of(context).openDrawer(),
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(_obscureMoney ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: Colors.blueAccent.withValues(alpha: 0.7)),
                  onPressed: () => setState(() => _obscureMoney = !_obscureMoney),
                ),
                // Show Unlock icon if closed, Store icon if open
                if (isShopClosed)
                  IconButton(
                    icon: Icon(Icons.lock_open_rounded, color: Colors.orangeAccent.withValues(alpha: 0.8)),
                    onPressed: () => _showReopenConfirmation(context),
                    tooltip: "Reopen Day",
                  )
                else
                  IconButton(
                    icon: Icon(Icons.storefront_rounded, color: Colors.greenAccent.withValues(alpha: 0.8)),
                    onPressed: () => _showCloseDayConfirmation(context),
                    tooltip: "Close Day",
                  ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(top: 100, right: -70, child: _buildGlow(250, Colors.blueAccent.withValues(alpha: 0.1))),
          Positioned(bottom: 150, left: -70, child: _buildGlow(300, Colors.blueAccent.withValues(alpha: 0.07))),
          
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _barbersFuture, 
            builder: (context, barberSnapshot) {
              if (barberSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
              }
              if (!barberSnapshot.hasData || barberSnapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final barbers = barberSnapshot.data!.map((b) => Barber.fromMap(b)).toList();

              return Consumer<CounterProvider>(
                builder: (context, provider, child) {
                  final allTransactions = provider.todayTransactions;
                  final totalWalkIns = allTransactions.length;
                  final totalRevenue = totalWalkIns * provider.globalPrice.toDouble(); 

                  return Column(
                    children: [
                      const SizedBox(height: 120),
                      _buildGlassSummary(totalWalkIns, totalRevenue),
                      Expanded(
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 25, 20, 40),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2, 
                            mainAxisSpacing: 20, 
                            crossAxisSpacing: 20, 
                            childAspectRatio: 0.72, 
                          ),
                          itemCount: barbers.length,
                          itemBuilder: (context, index) {
                            final barber = barbers[index];
                            bool isOff = !provider.isBarberAvailable(barber);
                            final barberCount = allTransactions.where((t) => t['barber_id'] == barber.id).length;
                            final barberProfit = barberCount * (provider.globalPrice * 0.5);
                            return _buildBarberCard(context, provider, barber, barberCount, barberProfit, isOff);
                          },
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildGlassSummary(int totalWalkIns, double totalRevenue) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 20))
        ]
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryStat("TOTAL CLIENTS", CurrencyFormatter.count.format(totalWalkIns), Icons.person_add_rounded),
                Container(width: 1, height: 45, color: Colors.white.withValues(alpha: 0.05)),
                _buildSummaryStat(
                  "TODAY'S PROFIT", 
                  _obscureMoney ? "₱ ••••" : CurrencyFormatter.format(totalRevenue), 
                  Icons.account_balance_wallet_rounded
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBarberCard(BuildContext context, CounterProvider provider, Barber barber, int barberCount, double barberProfit, bool isOff) {
    // We check if the provider's shop is closed to disable clicks
    bool isDisabled = isOff || provider.isShopClosed;

    return GestureDetector(
      onTap: isDisabled ? null : () {
        HapticFeedback.lightImpact(); 
        provider.incrementWalkIn(barber.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          color: isDisabled ? Colors.white.withValues(alpha: 0.02) : Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: isDisabled ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.1),
            width: 1
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: Stack(
            children: [
              if (!isDisabled) 
                Positioned(
                  top: -15, right: -15, 
                  child: Icon(Icons.circle, size: 90, color: Colors.blueAccent.withValues(alpha: 0.03))
                ),
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      barber.name.toUpperCase(), 
                      style: TextStyle(
                        fontSize: 14, 
                        fontWeight: FontWeight.w800, 
                        color: isDisabled ? Colors.white24 : Colors.white, 
                        letterSpacing: 1.5
                      ), 
                      maxLines: 1, overflow: TextOverflow.ellipsis
                    ),
                    if (!isDisabled) 
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle, 
                          color: Colors.blueAccent.withValues(alpha: 0.1)
                        ),
                        child: const Icon(Icons.add_rounded, size: 26, color: Colors.blueAccent),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2))
                        ),
                        child: Text(
                          barber.isAbsent ? "ABSENT" : "OFF", 
                          style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 10)
                        ),
                      ),
                    Column(
                      children: [
                        Text(
                          CurrencyFormatter.count.format(barberCount), 
                          style: TextStyle(
                            fontSize: 32, 
                            color: isDisabled ? Colors.white10 : Colors.white, 
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1
                          )
                        ),
                        Text(
                          "SERVICES", 
                          style: TextStyle(fontSize: 8, color: isDisabled ? Colors.white10 : Colors.white38, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 10),
                        if (!isDisabled)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.withValues(alpha: 0.08), 
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: Text(
                              _obscureMoney ? "₱ •••" : CurrencyFormatter.format(barberProfit), 
                              style: const TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.w800)
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          color: const Color(0xFF0A0C12).withValues(alpha: 0.8),
          child: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 50),
                
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blueAccent.withValues(alpha: 0.15),
                            blurRadius: 40,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    Image.asset(
                      'assets/images/akie_logo.png',
                      height: 100, 
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => 
                        const Icon(Icons.content_cut_rounded, color: Colors.blueAccent, size: 60),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
                Container(width: 40, height: 2, color: Colors.blueAccent.withValues(alpha: 0.3)),
                
                const SizedBox(height: 40),
                
                _buildDrawerItem(Icons.bar_chart_rounded, "Business Analytics", Colors.blueAccent, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AnalyticsScreen()));
                }),
                _buildDrawerItem(Icons.receipt_long_rounded, "Expense Tracker", Colors.greenAccent, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ExpenseScreen()));
                }),
                _buildDrawerItem(Icons.settings_suggest_rounded, "System Settings", Colors.orangeAccent, () async {
                  Navigator.pop(context);
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
                  _refreshBarbers();
                }),
                
                const Spacer(),
                const Divider(color: Colors.white10, indent: 20, endIndent: 20),
                _buildDrawerItem(Icons.power_settings_new_rounded, "Lock App", Colors.redAccent, () {
                  Navigator.pop(context);
                  _logout(context);
                }),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, color: color.withValues(alpha: 0.8), size: 20),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600, fontSize: 14)),
      onTap: onTap,
    );
  }

  Widget _buildSummaryStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.blueAccent.withValues(alpha: 0.8), size: 20),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5)),
        Text(label, style: const TextStyle(fontSize: 9, color: Colors.white38, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(Icons.person_off_rounded, size: 64, color: Colors.white.withValues(alpha: 0.05)), 
          const SizedBox(height: 16), 
          const Text("No active staff found.", style: TextStyle(color: Colors.white24, fontSize: 14, fontWeight: FontWeight.w600))
        ]
      )
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