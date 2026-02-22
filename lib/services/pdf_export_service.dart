import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfExportService {
  static Future<void> generateMonthlyReport({
    required String monthYear,
    required String selectedDate, // Add this parameter
    required double gross,
    required double expenses,
    required double net,
    required List<Map<String, dynamic>> barberReports,
  }) async {
    final pdf = pw.Document();
    
    // REMOVE the DateTime.now() variable and just use the selectedDate parameter

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("AKIE BARBERSHOP", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.Text("Monthly Financial Report: $monthYear", style: const pw.TextStyle(fontSize: 16)),
              
              // Update this line to use the new parameter
              pw.Text("Selected Date: $selectedDate", style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
              
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 1),
              pw.SizedBox(height: 20),

              pw.Text("SUMMARY", style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
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
                  ['Barber', 'Services', 'Profit (PHP)'], 
                  ...barberReports.map((r) => [
                    r['name'].toString().toUpperCase(),
                    r['count'].toString(),
                    r['profit'].toStringAsFixed(2) 
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