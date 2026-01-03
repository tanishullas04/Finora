import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finora/screens/income.dart';
import 'package:finora/screens/deductions.dart';

void main() {
  group('Income Screen Tests', () {
    testWidgets('Income screen renders with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IncomeScreen(),
        ),
      );

      expect(find.text('Income'), findsWidgets);
      expect(find.byType(TextField), findsWidgets);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });

    testWidgets('Income screen shows Continue button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IncomeScreen(),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Income screen has input fields for income sources', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IncomeScreen(),
        ),
      );

      // Should have 4 text fields for different income types
      expect(find.byType(TextField).evaluate().length, greaterThanOrEqualTo(4));
    });

    testWidgets('Income screen expansion tiles are displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IncomeScreen(),
        ),
      );

      expect(find.byType(ExpansionTile), findsWidgets);
    });
  });

  group('Deductions Screen Tests', () {
    testWidgets('Deductions screen renders with title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeductionsScreen(),
        ),
      );

      expect(find.text('Deductions'), findsWidgets);
      expect(find.byType(ExpansionTile), findsWidgets);
    });

    testWidgets('Deductions screen shows Continue button', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeductionsScreen(),
        ),
      );

      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('Deductions screen has all sections displayed', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeductionsScreen(),
        ),
      );

      expect(find.text('Section 80C (limit ₹1,50,000)'), findsOneWidget);
      expect(find.text('Section 80D (Health Insurance)'), findsOneWidget);
      expect(find.text('Section 80CCD(1B) (NPS extra ₹50,000)'), findsOneWidget);
      expect(find.text('Section 24 (Home Loan Interest)'), findsOneWidget);
    });

    testWidgets('Deductions screen has 4 input fields', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeductionsScreen(),
        ),
      );

      expect(find.byType(TextField).evaluate().length, greaterThanOrEqualTo(4));
    });

    testWidgets('Deductions screen has 4 expansion tiles', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: DeductionsScreen(),
        ),
      );

      expect(find.byType(ExpansionTile).evaluate().length, greaterThanOrEqualTo(4));
    });
  });
}
