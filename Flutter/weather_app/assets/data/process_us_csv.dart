import 'dart:io';

Future<void> processUsCsv() async {
  final inputPath = 'us.csv';
  final outputPath = 'uszips.csv';
  
  try {
    // Read all lines from CSV.
    final lines = await File(inputPath).readAsLines();

    if(lines.isEmpty) {
      print('Input CSV is empty.');
      return;
    }
    
    // Parse header row.
    final header = lines.first.split(',');
    
    // Identify indices to always remove.
    final removeIndices = <int>{};
    final countryCodeIdx = header.indexOf('country code');
    final adminName1Idx = header.indexOf('admin name1');
    if (countryCodeIdx != -1) removeIndices.add(countryCodeIdx);
    if (adminName1Idx != -1) removeIndices.add(adminName1Idx);
    
    // Always remove 'admin name3' and 'admin code3'
    final adminName3Idx = header.indexOf('admin name3');
    final adminCode3Idx = header.indexOf('admin code3');
    if (adminName3Idx != -1) removeIndices.add(adminName3Idx);
    if (adminCode3Idx != -1) removeIndices.add(adminCode3Idx);
    
    // Function to process each row by removing selected indices.
    List<String> processRow(String line) {
      final fields = line.split(',');
      final List<String> newFields = [];
      for (int i = 0; i < fields.length; i++) {
        if (!removeIndices.contains(i)) {
          newFields.add(fields[i]);
        }
      }
      return newFields;
    }
    
    // Process header and data rows.
    final processedLines = lines.map((line) => processRow(line).join(',')).toList();
    
    // Write to output file.
    await File(outputPath).writeAsString(processedLines.join('\n'));
    print('Processed CSV written to $outputPath');
  } catch (e) {
    print('Error processing CSV: $e');
  }
}

// For quick testing, you can uncomment the following main function.
void main() async {
  await processUsCsv();
}
