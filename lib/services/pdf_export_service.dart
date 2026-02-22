import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<void> generateMonthlyReport({
    required String monthYear,
    required double gross,
    required double expenses,
    required double net,
    required List<Map<String, dynamic>> barberReports,
  }) async {
    final pdf = pw.Document();
    final String reportDate = DateFormat('MMMM d, yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("AKIE BARBERSHOP", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text("Monthly Financial Report: $monthYear", style: const pw.TextStyle(fontSize: 16)),
              pw.Text("Report Date: $reportDate", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 20),

              pw.Text("SUMMARY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              // Using "PHP" instead of the "₱" symbol to avoid font errors
              pw.Bullet(text: "Gross Revenue: PHP ${gross.toStringAsFixed(2)}"),
              pw.Bullet(text: "Total Expenses: PHP ${expenses.toStringAsFixed(2)}"),
              pw.Bullet(text: "Shop Net Profit: PHP ${net.toStringAsFixed(2)}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              
              pw.SizedBox(height: 30),

              pw.Text("BARBER EARNINGS", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                context: context,
                headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                data: <List<String>>[
                  ['Barber', 'Services', 'Profit (PHP)'], // Clarify currency in header
                  ...barberReports.map((r) => [
                    r['name'].toString().toUpperCase(),
                    r['count'].toString(),
                    r['profit'].toStringAsFixed(2) // No symbol needed inside the table cells if in header
                  ]),
                ],
              ),
              
              pw.Spacer(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text("Generated via Akie Barbershop App", 
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }
}