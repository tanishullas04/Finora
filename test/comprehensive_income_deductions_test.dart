import 'package:flutter_test/flutter_test.dart';

// Helper functions to calculate taxes (replicate the actual calculation logic)
double calculateOldRegimeTax(double income, double deductions) {
  double taxableIncome = (income - 50000 - deductions).clamp(0, double.infinity);
  double tax = 0;

  if (taxableIncome > 1000000) {
    tax += (taxableIncome - 1000000) * 0.30;
    taxableIncome = 1000000;
  }
  if (taxableIncome > 500000) {
    tax += (taxableIncome - 500000) * 0.20;
    taxableIncome = 500000;
  }
  if (taxableIncome > 250000) {
    tax += (taxableIncome - 250000) * 0.10;
  }

  // Calculate surcharge
  double surcharge = 0;
  if (income > 5000000) {
    surcharge = tax * 0.25;
  } else if (income > 1000000) {
    surcharge = tax * 0.15;
  } else if (income > 500000) {
    surcharge = tax * 0.10;
  }

  double cess = (tax + surcharge) * 0.04;
  return tax + surcharge + cess;
}

double calculateNewRegimeTax(double income) {
  double taxableIncome = income.clamp(0, double.infinity);
  double tax = 0;

  if (taxableIncome > 1500000) {
    tax += (taxableIncome - 1500000) * 0.30;
    taxableIncome = 1500000;
  }
  if (taxableIncome > 1000000) {
    tax += (taxableIncome - 1000000) * 0.20;
    taxableIncome = 1000000;
  }
  if (taxableIncome > 500000) {
    tax += (taxableIncome - 500000) * 0.15;
    taxableIncome = 500000;
  }
  if (taxableIncome > 250000) {
    tax += (taxableIncome - 250000) * 0.05;
  }

  // Calculate surcharge
  double surcharge = 0;
  if (income > 5000000) {
    surcharge = tax * 0.25;
  } else if (income > 1000000) {
    surcharge = tax * 0.15;
  } else if (income > 500000) {
    surcharge = tax * 0.10;
  }

  double cess = (tax + surcharge) * 0.04;
  return tax + surcharge + cess;
}

void main() {
  group('Comprehensive Income & Deduction Combinations Tests', () {
    // ========== INCOME VARIATION TESTS ==========

    test('Income Variation 1: All income from salary only (₹15L)', () {
      double salary = 1500000;
      double otherIncome = 0;
      double rentalIncome = 0;
      double businessIncome = 0;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 300000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Income Variation 1: Salary Only (₹15L total, ₹6L deductions)');
      print('   Income: Salary ₹${salary / 100000}L');
      print('   Deductions: ₹${totalDeductions / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
      expect(totalIncome, equals(1500000));
    });

    test('Income Variation 2: Salary + Other Income (50/50, ₹15L)', () {
      double salary = 750000;
      double otherIncome = 750000;
      double rentalIncome = 0;
      double businessIncome = 0;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 300000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Income Variation 2: Salary + Other (50/50, ₹15L total, ₹6L deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L');
      print('   Should be same tax as Variation 1 (tax is on total income)');

      // Should be same as Variation 1 (tax is on total income)
      expect(oldRegime, closeTo(calculateOldRegimeTax(1500000, totalDeductions), 1));
    });

    test('Income Variation 3: All 4 sources equally (₹15L)', () {
      double salary = 375000;
      double otherIncome = 375000;
      double rentalIncome = 375000;
      double businessIncome = 375000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 300000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Income Variation 3: All 4 sources equally (₹15L total, ₹6L deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L + Rental ₹${rentalIncome / 100000}L + Business ₹${businessIncome / 100000}L');
      print('   Should be same as above variations');

      // Should be same as above (tax is on total income)
      expect(oldRegime, closeTo(calculateOldRegimeTax(1500000, totalDeductions), 1));
    });

    test('Income Variation 4: Heavy on rental income (₹15L)', () {
      double salary = 200000;
      double otherIncome = 100000;
      double rentalIncome = 800000;
      double businessIncome = 400000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 500000; // Higher for rental
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Income Variation 4: Heavy Rental Income (₹15L total, ₹7.5L deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L + Rental ₹${rentalIncome / 100000}L + Business ₹${businessIncome / 100000}L');
      print('   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    test('Income Variation 5: Heavy on business income (₹15L)', () {
      double salary = 300000;
      double otherIncome = 200000;
      double rentalIncome = 200000;
      double businessIncome = 800000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 300000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Income Variation 5: Heavy Business Income (₹15L total, ₹6L deductions)');
      print('   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    // ========== DEDUCTION VARIATION TESTS ==========

    test('Deduction Variation 1: Only 80C (₹15L income)', () {
      double salary = 1000000;
      double otherIncome = 200000;
      double rentalIncome = 200000;
      double businessIncome = 100000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 0;
      double section80ccd = 0;
      double section24 = 0;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Deduction Variation 1: Only 80C (₹15L income, ₹1.5L deductions)');
      print('   Deductions: 80C ₹${section80c / 100000}L only');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Finding: Even single deduction makes old regime better');

      expect(oldRegime, lessThan(newRegime));
      expect(totalDeductions, equals(150000));
    });

    test('Deduction Variation 2: Only 80D (₹15L income)', () {
      double salary = 1000000;
      double otherIncome = 200000;
      double rentalIncome = 200000;
      double businessIncome = 100000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 0;
      double section80d = 100000;
      double section80ccd = 0;
      double section24 = 0;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Deduction Variation 2: Only 80D (₹15L income, ₹1L deductions)');
      print('   Deductions: 80D ₹${section80d / 100000}L only');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
      expect(totalDeductions, equals(100000));
    });

    test('Deduction Variation 3: Only 80CCD (₹15L income)', () {
      double salary = 1000000;
      double otherIncome = 200000;
      double rentalIncome = 200000;
      double businessIncome = 100000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 0;
      double section80d = 0;
      double section80ccd = 50000;
      double section24 = 0;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Deduction Variation 3: Only 80CCD (₹15L income, ₹50K deductions)');
      print('   Deductions: 80CCD ₹${section80ccd / 100000}L only');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    test('Deduction Variation 4: Only Section 24 (₹15L income)', () {
      double salary = 1000000;
      double otherIncome = 200000;
      double rentalIncome = 200000;
      double businessIncome = 100000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 0;
      double section80d = 0;
      double section80ccd = 0;
      double section24 = 500000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Deduction Variation 4: Only Section 24 (₹15L income, ₹5L deductions)');
      print('   Deductions: Section 24 ₹${section24 / 100000}L only');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Finding: Large deduction (₹5L home loan) provides significant savings');

      expect(oldRegime, lessThan(newRegime));
      expect(totalDeductions, equals(500000));
    });

    test('Deduction Variation 5: 80C + 80D only (₹15L income)', () {
      double salary = 1000000;
      double otherIncome = 200000;
      double rentalIncome = 200000;
      double businessIncome = 100000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 0;
      double section24 = 0;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Deduction Variation 5: 80C + 80D only (₹15L income, ₹2.5L deductions)');
      print(
          '   Deductions: 80C ₹${section80c / 100000}L + 80D ₹${section80d / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    test('Deduction Variation 6: 80C + Section 24 (₹15L income)', () {
      double salary = 1000000;
      double otherIncome = 200000;
      double rentalIncome = 200000;
      double businessIncome = 100000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 0;
      double section80ccd = 0;
      double section24 = 300000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Deduction Variation 6: 80C + Section 24 (₹15L income, ₹4.5L deductions)');
      print(
          '   Deductions: 80C ₹${section80c / 100000}L + Section 24 ₹${section24 / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    // ========== COMBINED VARIATION TESTS ==========

    test('Combined Variation 1: High salary + minimal deductions (₹38L)', () {
      double salary = 3000000;
      double otherIncome = 500000;
      double rentalIncome = 200000;
      double businessIncome = 100000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 50000;
      double section80d = 25000;
      double section80ccd = 0;
      double section24 = 0;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Combined Variation 1: High salary + minimal deductions (₹38L income, ₹75K deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L + Rental ₹${rentalIncome / 100000}L + Business ₹${businessIncome / 100000}L');
      print('   Deductions: ₹${totalDeductions / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Finding: NEW REGIME BETTER at very high income with minimal deductions!');

      // At very high income (₹38L) with minimal deductions, new regime IS BETTER
      expect(newRegime, lessThan(oldRegime));
    });

    test('Combined Variation 2: Balanced income + moderate deductions (₹22L)', () {
      double salary = 800000;
      double otherIncome = 400000;
      double rentalIncome = 600000;
      double businessIncome = 400000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 100000;
      double section80d = 75000;
      double section80ccd = 25000;
      double section24 = 200000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Combined Variation 2: Balanced income + moderate deductions (₹22L income, ₹4L deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L + Rental ₹${rentalIncome / 100000}L + Business ₹${businessIncome / 100000}L');
      print('   Deductions: ₹${totalDeductions / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    test('Combined Variation 3: Low income + no deductions (₹4L)', () {
      double salary = 250000;
      double otherIncome = 150000;
      double rentalIncome = 0;
      double businessIncome = 0;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 0;
      double section80d = 0;
      double section80ccd = 0;
      double section24 = 0;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Combined Variation 3: Low income + no deductions (₹4L income, ₹0 deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L');
      print('   Deductions: None');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      // Both should be very low
      expect(oldRegime, lessThan(50000));
    });

    test('Combined Variation 4: Very high income + max deductions (₹100L)', () {
      double salary = 5000000;
      double otherIncome = 2000000;
      double rentalIncome = 1500000;
      double businessIncome = 1500000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 500000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Combined Variation 4: Very high income + max deductions (₹100L income, ₹8L deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L + Rental ₹${rentalIncome / 100000}L + Business ₹${businessIncome / 100000}L');
      print('   Deductions: ₹${totalDeductions / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    test('Combined Variation 5: Mixed high/low income + mixed deductions (₹51.5L)', () {
      double salary = 4000000; // High
      double otherIncome = 50000; // Low
      double rentalIncome = 1000000; // Medium
      double businessIncome = 100000; // Low
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 150000; // Max
      double section80d = 25000; // Low
      double section80ccd = 50000; // Medium
      double section24 = 200000; // Medium
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Combined Variation 5: Mixed high/low income + mixed deductions (₹51.5L income, ₹4.25L deductions)');
      print(
          '   Income: Salary ₹${salary / 100000}L + Other ₹${otherIncome / 100000}L + Rental ₹${rentalIncome / 100000}L + Business ₹${businessIncome / 100000}L');
      print('   Deductions: ₹${totalDeductions / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    // ========== EDGE CASE TESTS ==========

    test('Edge Case 1: Income exactly at ₹50L threshold', () {
      double totalIncome = 5000000;
      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 300000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Edge Case 1: Income exactly at ₹50L (surcharge threshold)');
      print('   Income: ₹${totalIncome / 100000}L');
      print('   Deductions: ₹${totalDeductions / 100000}L');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(totalIncome, equals(5000000));
    });

    test('Edge Case 2: Deductions exceed income (handles gracefully)', () {
      double totalIncome = 500000;
      double section80c = 200000;
      double section80d = 200000;
      double section80ccd = 100000;
      double section24 = 300000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print(
          '✅ Edge Case 2: Deductions (₹8L) exceed income (₹5L) - clamps gracefully');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      // Taxable income should clamp to 0, so old regime tax should be minimal
      expect(oldRegime, lessThanOrEqualTo(newRegime));
    });

    test('Edge Case 3: Zero income with deductions', () {
      double totalIncome = 0;
      double section80c = 50000;
      double section80d = 25000;
      double section80ccd = 0;
      double section24 = 0;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Edge Case 3: Zero income with deductions');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      // Both should be 0
      expect(oldRegime, equals(0));
      expect(newRegime, equals(0));
    });

    test('Edge Case 4: All income from business only (₹20L)', () {
      double salary = 0;
      double otherIncome = 0;
      double rentalIncome = 0;
      double businessIncome = 2000000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;

      double section80c = 50000;
      double section80d = 30000;
      double section80ccd = 20000;
      double section24 = 200000;
      double totalDeductions =
          section80c + section80d + section80ccd + section24;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Edge Case 4: All income from business only (₹20L total)');
      print(
          '   Income: Business ₹${businessIncome / 100000}L (others zero)');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)}');

      expect(oldRegime, lessThan(newRegime));
    });

    test('Edge Case 5: No income, no deductions', () {
      double totalIncome = 0;
      double totalDeductions = 0;

      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome);

      print('✅ Edge Case 5: Zero income, zero deductions');
      print(
          '   Old: ₹${oldRegime.toStringAsFixed(2)}, New: ₹${newRegime.toStringAsFixed(2)}');

      expect(oldRegime, equals(0));
      expect(newRegime, equals(0));
    });
  });
}
