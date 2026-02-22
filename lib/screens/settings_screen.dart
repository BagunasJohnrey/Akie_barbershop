import 'dart:ui'; 
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/counter_provider.dart';
import '../models/barber_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _priceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _priceController.text = context.read<CounterProvider>().globalPrice.toString();
  }

  void _showTopAlert(BuildContext context, String message, {bool isError = false}) {
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16, 
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
    final provider = Provider.of<CounterProvider>(context);

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
                'SYSTEM SETTINGS',
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                    fontSize: 14,
                    color: Colors.white70),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          Positioned(top: 100, right: -70, child: _buildGlow(280, Colors.blueAccent.withValues(alpha: 0.12))),
          Positioned(bottom: 100, left: -70, child: _buildGlow(320, Colors.blueAccent.withValues(alpha: 0.08))),

          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 120),
                _buildSectionLabel("GLOBAL HAIRCUT PRICE"),
                _buildGlassCard(
                  child: Row(
                    children: [
                      const Text("₱", style: TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _priceController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          decoration: const InputDecoration(border: InputBorder.none, hintText: "0.00", hintStyle: TextStyle(color: Colors.white12)),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.check_circle_rounded, color: Colors.blueAccent, size: 28),
                        onPressed: () {
                          final newPrice = int.tryParse(_priceController.text);
                          if (newPrice != null) {
                            HapticFeedback.mediumImpact();
                            provider.updateGlobalPrice(newPrice);
                            _showTopAlert(context, 'Price updated successfully!');
                          } else {
                            _showTopAlert(context, 'Invalid price format', isError: true);
                          }
                        },
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                _buildSectionLabel("SECURITY PIN"),
                _buildGlassCard(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Current Access PIN", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600)),
                          Text(
                            provider.appPin,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 4),
                          ),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Colors.white10, height: 1),
                      ),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          icon: const Icon(Icons.lock_reset_rounded, size: 20),
                          label: const Text("CHANGE ACCESS PIN", style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.blueAccent,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.blueAccent.withValues(alpha: 0.05),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () => _showChangePinDialog(context, provider),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionLabel("MANAGE BARBERS"),
                    TextButton.icon(
                      icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                      label: const Text("ADD NEW", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
                      onPressed: () => _showAddBarberDialog(context, provider),
                    ),
                  ],
                ),

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: Supabase.instance.client.from('barbers').select().eq('is_active', true).order('name', ascending: true),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: Colors.blueAccent)));
                    }
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text("No active barbers found.", style: TextStyle(color: Colors.white24)));
                    }

                    final barbers = snapshot.data!.map((b) => Barber.fromMap(b)).toList();

                    return ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: barbers.length,
                      itemBuilder: (context, index) {
                        final barber = barbers[index];
                        return _buildBarberTile(context, provider, barber);
                      },
                    );
                  },
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 4),
        child: Text(text, style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.5)),
      );

  Widget _buildGlassCard({required Widget child}) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: child,
      );

  Widget _buildBarberTile(BuildContext context, CounterProvider provider, Barber barber) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: (barber.isAbsent ? Colors.redAccent : Colors.blueAccent).withValues(alpha: 0.1),
            child: Icon(Icons.person_rounded, color: barber.isAbsent ? Colors.redAccent : Colors.blueAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(barber.name.toUpperCase(), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                Text(
                  barber.isAbsent ? "• ABSENT TODAY" : "• OFF: ${barber.dayOff}",
                  style: TextStyle(color: barber.isAbsent ? Colors.redAccent : Colors.white38, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          IconButton(icon: const Icon(Icons.edit_note_rounded, color: Colors.white38), onPressed: () => _showEditBarberDialog(context, provider, barber)),
          IconButton(icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 22), onPressed: () => _showDeleteConfirmation(context, provider, barber)),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context, CounterProvider provider) {
    final pinController = TextEditingController();
    _showPremiumDialog(
      context: context,
      title: "New Access PIN",
      topIcon: Icons.pin_rounded,
      content: TextField(
        controller: pinController,
        maxLength: 4,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 32, letterSpacing: 15, fontWeight: FontWeight.w900),
        decoration: const InputDecoration(border: InputBorder.none, counterText: "", hintText: "••••", hintStyle: TextStyle(color: Colors.white10)),
      ),
      onConfirm: () async {
        if (pinController.text.length == 4) {
          await provider.updateAppPin(pinController.text);
          if (!context.mounted) return false;
          setState(() {});
          _showTopAlert(context, 'Security PIN updated successfully!');
          return true;
        }
        _showTopAlert(context, 'PIN must be exactly 4 digits', isError: true);
        return false;
      },
    );
  }

  void _showAddBarberDialog(BuildContext context, CounterProvider provider) {
    final nameController = TextEditingController();
    String selectedDayOff = 'Monday';
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    _showPremiumDialog(
      context: context,
      title: "Add New Staff",
      topIcon: Icons.person_add_rounded,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildDialogField(nameController, "Full Name", Icons.badge_rounded),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedDayOff,
            dropdownColor: const Color(0xFF1A1C29),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            decoration: _dialogInputDecoration("Day Off", Icons.event_repeat_rounded),
            items: days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
            onChanged: (val) => selectedDayOff = val!,
          ),
        ],
      ),
      onConfirm: () async {
        if (nameController.text.isNotEmpty) {
          await provider.addBarber(nameController.text, selectedDayOff);
          if (!context.mounted) return false;
          setState(() {});
          _showTopAlert(context, '${nameController.text} added successfully!');
          return true;
        }
        _showTopAlert(context, 'Name cannot be empty', isError: true);
        return false;
      },
    );
  }

  void _showEditBarberDialog(BuildContext context, CounterProvider provider, Barber barber) {
    final nameController = TextEditingController(text: barber.name);
    String selectedDayOff = barber.dayOff;
    bool isAbsent = barber.isAbsent;
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];

    _showPremiumDialog(
      context: context,
      title: "Edit Staff",
      topIcon: Icons.manage_accounts_rounded,
      content: StatefulBuilder(
        builder: (context, setDState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(nameController, "Name", Icons.edit_rounded),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: selectedDayOff,
              dropdownColor: const Color(0xFF1A1C29),
              style: const TextStyle(color: Colors.white),
              decoration: _dialogInputDecoration("Day Off", Icons.event_available_rounded),
              items: days.map((day) => DropdownMenuItem(value: day, child: Text(day))).toList(),
              onChanged: (val) => selectedDayOff = val!,
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Absent Today', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
              value: isAbsent,
              activeThumbColor: Colors.redAccent,
              onChanged: (val) => setDState(() => isAbsent = val),
            ),
          ],
        ),
      ),
      onConfirm: () async {
        if (nameController.text.isNotEmpty) {
          await provider.updateBarber(barber.id, nameController.text, selectedDayOff, isAbsent);
          if (!context.mounted) return false;
          setState(() {});
          _showTopAlert(context, 'Staff record updated!');
          return true;
        }
        return false;
      },
    );
  }

  void _showDeleteConfirmation(BuildContext context, CounterProvider provider, Barber barber) {
    _showPremiumDialog(
      context: context,
      title: "Remove Staff?",
      topIcon: Icons.person_remove_rounded,
      confirmText: "Delete",
      confirmColor: Colors.redAccent,
      content: Text(
        "Are you sure you want to remove ${barber.name}? This will hide them from the dashboard.", 
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white60)
      ),
      onConfirm: () async {
        await provider.deleteBarber(barber.id);
        if (!context.mounted) return false;
        setState(() {});
        _showTopAlert(context, '${barber.name} has been removed.');
        return true;
      },
    );
  }

  // REFACTORED: Master Template for Glass Modals
  void _showPremiumDialog({
    required BuildContext context, 
    required String title, 
    required Widget content, 
    required Future<bool> Function() onConfirm, 
    String confirmText = "Save", 
    Color confirmColor = Colors.blueAccent,
    IconData? topIcon,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, a1, a2) => const SizedBox.shrink(),
      transitionBuilder: (context, anim, a2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(
            opacity: anim,
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
                      border: Border.all(color: confirmColor.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (topIcon != null) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: confirmColor.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(topIcon, color: confirmColor, size: 32),
                          ),
                          const SizedBox(height: 16),
                        ],
                        Text(
                          title, 
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        content,
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: TextButton(
                                onPressed: () => Navigator.pop(context), 
                                child: const Text("Cancel", style: TextStyle(color: Colors.white38, fontWeight: FontWeight.w600))
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: confirmColor.withValues(alpha: 0.8), 
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  if (await onConfirm()) {
                                    if (context.mounted) Navigator.pop(context);
                                  }
                                },
                                child: Text(confirmText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
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

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon) => TextField(
        controller: controller,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        decoration: _dialogInputDecoration(label, icon),
      );

  InputDecoration _dialogInputDecoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white38, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
      );
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