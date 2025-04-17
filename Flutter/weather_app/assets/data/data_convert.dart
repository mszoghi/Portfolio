import 'dart:convert';
import 'dart:io';

void main() async {
  // Define input and output file paths.
  final inputPath = 'us.txt';
  final outputPath = 'us.csv';
  
  // Define CSV header.
  final header = 'country code,postal code,place name,admin name1,admin code1,admin name2,admin code2,admin name3,admin code3,latitude,longitude,accuracy';
  
  try {
    // Read the entire file as lines.
    final lines = await File(inputPath).readAsLines(encoding: utf8);
    
    // Process each line, split by tabs, and join with commas.
    final csvLines = lines.map((line) {
      // Skip empty lines if any.
      if (line.trim().isEmpty) return '';
      final fields = line.split('\t');
      return fields.join(',');
    }).where((line) => line.isNotEmpty).toList();
    
    // Combine header with processed lines.
    final outputContent = [header, ...csvLines].join('\n');
    
    // Write the CSV content to the output file.
    await File(outputPath).writeAsString(outputContent, encoding: utf8);
    print('CSV conversion completed successfully. Output: $outputPath');
  } catch (e) {
    print('Error during CSV conversion: $e');
  }
}

