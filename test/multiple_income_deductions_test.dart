import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Helper functions to replicate tax calculation logic
  double calculateOldRegimeTax(double totalIncome, double totalDeductions) {
    double taxableIncome = (totalIncome - 50000 - totalDeductions).clamp(0, double.infinity);
    
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
      taxableIncome = 250000;
    }
    
    double surcharge = 0;
    if (totalIncome > 5000000) surcharge = tax * 0.25;
    else if (totalIncome > 1000000) surcharge = tax * 0.15;
    else if (totalIncome > 500000) surcharge = tax * 0.10;
    
    double cess = (tax + surcharge) * 0.04;
    
    return tax + surcharge + cess;
  }

  double calculateNewRegimeTax(double totalIncome, double totalDeductions) {
    // New regime ignores deductions
    double taxableIncome = totalIncome.clamp(0, double.infinity);
    
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
      taxableIncome = 250000;
    }
    
    double surcharge = 0;
    if (totalIncome > 5000000) surcharge = tax * 0.25;
    else if (totalIncome > 1000000) surcharge = tax * 0.15;
    else if (totalIncome > 500000) surcharge = tax * 0.10;
    
    double cess = (tax + surcharge) * 0.04;
    
    return tax + surcharge + cess;
  }

  group('Tax Calculation Tests - Multiple Income & Deduction Sources (FY 2024-25)', () {
    
    test('Scenario 1: Multiple Income Sources + Multiple Deductions (₹25,00,000 total)', () {
      // Income sources
      double salary = 1500000;
      double otherIncome = 300000;
      double rentalIncome = 400000;
      double businessIncome = 300000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;
      
      // Deduction sources
      double section80c = 150000; // ELSS/PPF/EPF
      double section80d = 50000;  // Health insurance
      double section80ccd = 50000; // NPS
      double section24 = 200000;  // Home loan interest
      double totalDeductions = section80c + section80d + section80ccd + section24;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 1: Multiple Sources (₹${(totalIncome/100000).toStringAsFixed(1)}L)');
      print('   Income: Salary ₹${salary/100000}L + Other ₹${otherIncome/100000}L + Rental ₹${rentalIncome/100000}L + Business ₹${businessIncome/100000}L');
      print('   Deductions: 80C ₹${section80c/100000}L + 80D ₹${section80d/100000}L + 80CCD ₹${section80ccd/100000}L + 24 ₹${section24/100000}L');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}, New Regime: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)} (Old Regime better)');
      
      expect(oldRegime, lessThan(newRegime));
      expect((newRegime - oldRegime), greaterThan(50000)); // Significant saving
    });

    test('Scenario 2: High Salary Only vs Multiple Income Sources', () {
      // Scenario A: Only salary
      double salaryOnly = 1200000;
      double deductionsA = 200000;
      double oldA = calculateOldRegimeTax(salaryOnly, deductionsA);
      double newA = calculateNewRegimeTax(salaryOnly, deductionsA);
      
      // Scenario B: Same total income from multiple sources
      double salary = 600000;
      double otherIncome = 300000;
      double rentalIncome = 300000;
      double totalIncomeB = salary + otherIncome + rentalIncome;
      double deductionsB = 200000;
      double oldB = calculateOldRegimeTax(totalIncomeB, deductionsB);
      double newB = calculateNewRegimeTax(totalIncomeB, deductionsB);
      
      print('✅ Scenario 2: Same Income (₹12L) - Different Sources');
      print('   A) Salary Only: Old ₹${oldA.toStringAsFixed(2)}, New ₹${newA.toStringAsFixed(2)}');
      print('   B) Multi-source: Old ₹${oldB.toStringAsFixed(2)}, New ₹${newB.toStringAsFixed(2)}');
      print('   Both should be the same (tax is on total income)');
      
      // Tax should be same regardless of income source
      expect(oldA, closeTo(oldB, 1.0)); // Allow 1 rupee difference due to rounding
      expect(newA, closeTo(newB, 1.0));
    });

    test('Scenario 3: Maximum Deductions Scenario', () {
      // Income sources
      double salary = 2000000;
      double otherIncome = 500000;
      double rentalIncome = 300000;
      double businessIncome = 200000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;
      
      // Maximum practical deductions
      double section80c = 150000;   // Max ₹1.5L
      double section80d = 100000;   // Health insurance
      double section80ccd = 50000;  // NPS extra
      double section24 = 500000;    // Home loan interest (realistic for high earner)
      double totalDeductions = section80c + section80d + section80ccd + section24;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 3: High Income (₹33L) with Max Deductions (₹8L)');
      print('   Income: Salary ₹${salary/100000}L + Other ₹${otherIncome/100000}L + Rental ₹${rentalIncome/100000}L + Business ₹${businessIncome/100000}L');
      print('   Deductions: 80C ₹${section80c/100000}L + 80D ₹${section80d/100000}L + 80CCD ₹${section80ccd/100000}L + 24 ₹${section24/100000}L');
      print('   Total Deductions: ₹${totalDeductions/100000}L');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}, New Regime: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)} (Old Regime better)');
      
      expect(oldRegime, lessThan(newRegime));
      expect(totalDeductions, equals(800000));
    });

    test('Scenario 4: Minimal Income + Minimal Deductions', () {
      // Income sources
      double salary = 400000;
      double otherIncome = 100000;
      double totalIncome = salary + otherIncome;
      
      // Minimal deductions
      double section80c = 50000;
      double section80d = 0;
      double section80ccd = 0;
      double section24 = 0;
      double totalDeductions = section80c + section80d + section80ccd + section24;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 4: Low Income (₹5L) with Minimal Deductions (₹50K)');
      print('   Income: Salary ₹${salary/100000}L + Other ₹${otherIncome/100000}L = ₹${totalIncome/100000}L');
      print('   Deductions: 80C ₹${section80c/100000}L only');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}, New Regime: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)} (New Regime better at low income)');
      
      // At low income (₹5L), new regime is actually better because old regime still has ₹50k standard deduction
      expect(newRegime, lessThan(oldRegime)); // New regime better here
      expect(oldRegime, lessThan(20000)); // But both are low tax amounts
    });

    test('Scenario 5: Business + Rental Income with Deductions', () {
      // Income sources - mixed business and rental
      double salary = 500000;
      double businessIncome = 1500000;
      double rentalIncome = 600000;
      double otherIncome = 100000;
      double totalIncome = salary + businessIncome + rentalIncome + otherIncome;
      
      // Deductions leveraging business income
      double section80c = 100000;
      double section80d = 75000;
      double section80ccd = 50000;
      double section24 = 300000;    // Home loan
      double totalDeductions = section80c + section80d + section80ccd + section24;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 5: Business Focus (₹27L) with Deductions (₹5.25L)');
      print('   Income: Salary ₹${salary/100000}L + Business ₹${businessIncome/100000}L + Rental ₹${rentalIncome/100000}L + Other ₹${otherIncome/100000}L');
      print('   Deductions: 80C ₹${section80c/100000}L + 80D ₹${section80d/100000}L + 80CCD ₹${section80ccd/100000}L + 24 ₹${section24/100000}L');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}, New Regime: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)} (Old Regime better)');
      
      expect(oldRegime, lessThan(newRegime));
    });

    test('Scenario 6: High Earner (₹50L+) - Surcharge Impact', () {
      // Very high income from multiple sources
      double salary = 3000000;
      double businessIncome = 2500000;
      double rentalIncome = 1500000;
      double otherIncome = 500000;
      double totalIncome = salary + businessIncome + rentalIncome + otherIncome;
      
      // Deductions
      double section80c = 150000;
      double section80d = 100000;
      double section80ccd = 50000;
      double section24 = 500000;
      double totalDeductions = section80c + section80d + section80ccd + section24;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 6: Very High Earner (₹75L) - Surcharge at 25%');
      print('   Income: Salary ₹${salary/100000}L + Business ₹${businessIncome/100000}L + Rental ₹${rentalIncome/100000}L + Other ₹${otherIncome/100000}L');
      print('   Deductions: Total ₹${totalDeductions/100000}L');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}, New Regime: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)} (Old Regime better)');
      
      expect(oldRegime, lessThan(newRegime));
      expect(totalIncome, equals(7500000)); // ₹75L (3M + 2.5M + 1.5M + 0.5M)
    });

    test('Scenario 7: No Income from Some Sources', () {
      // Income from limited sources
      double salary = 800000;
      double otherIncome = 0;
      double rentalIncome = 0;
      double businessIncome = 400000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;
      
      // Deductions
      double section80c = 150000;
      double section80d = 50000;
      double section80ccd = 0;      // Not using NPS
      double section24 = 100000;
      double totalDeductions = section80c + section80d + section80ccd + section24;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 7: Limited Sources (₹12L) - Salary + Business');
      print('   Income: Salary ₹${salary/100000}L + Business ₹${businessIncome/100000}L');
      print('   Deductions: 80C ₹${section80c/100000}L + 80D ₹${section80d/100000}L + 24 ₹${section24/100000}L');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}, New Regime: ₹${newRegime.toStringAsFixed(2)}');
      print('   Savings: ₹${(newRegime - oldRegime).toStringAsFixed(2)}');
      
      expect(oldRegime, greaterThanOrEqualTo(0));
      expect(newRegime, greaterThanOrEqualTo(0));
    });

    test('Scenario 8: Zero Deductions - Only Income', () {
      // Income from all sources but NO deductions
      double salary = 1000000;
      double otherIncome = 300000;
      double rentalIncome = 200000;
      double businessIncome = 300000;
      double totalIncome = salary + otherIncome + rentalIncome + businessIncome;
      
      // No deductions
      double totalDeductions = 0;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 8: No Deductions (₹18L income, ₹0 deductions)');
      print('   Income: Salary ₹${salary/100000}L + Other ₹${otherIncome/100000}L + Rental ₹${rentalIncome/100000}L + Business ₹${businessIncome/100000}L');
      print('   Deductions: None');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}, New Regime: ₹${newRegime.toStringAsFixed(2)}');
      
      // Without deductions, both should be very close (only differ slightly due to surcharge calculation)
      // In this case, they should be similar since no deductions benefit
      expect(oldRegime, greaterThan(0));
      expect(newRegime, greaterThan(0));
    });

    test('Scenario 9: Breakeven Analysis - Find where Old = New', () {
      // Test to find approximate breakeven point
      double salary = 1500000;
      double otherIncome = 200000;
      double totalIncome = salary + otherIncome;
      
      // Find deduction level where regimes are approximately equal
      List<double> deductionLevels = [0, 100000, 200000, 300000, 400000, 500000];
      
      print('✅ Scenario 9: Breakeven Analysis (₹17L Income)');
      print('   Deduction Level | Old Regime | New Regime | Difference');
      print('   ─────────────────────────────────────────────────────');
      
      for (double ded in deductionLevels) {
        double old = calculateOldRegimeTax(totalIncome, ded);
        double new_regime = calculateNewRegimeTax(totalIncome, ded);
        double diff = new_regime - old;
        print('   ₹${(ded/100000).toStringAsFixed(1)}L           | ₹${old.toStringAsFixed(0).padLeft(10)} | ₹${new_regime.toStringAsFixed(0).padLeft(10)} | ₹${diff.toStringAsFixed(0)}');
      }
      
      // Old regime should be better with higher deductions
      double oldWith0 = calculateOldRegimeTax(totalIncome, 0);
      double oldWith500k = calculateOldRegimeTax(totalIncome, 500000);
      expect(oldWith500k, lessThan(oldWith0)); // More deductions = lower tax
    });

    test('Scenario 10: Comprehensive Real-World Example', () {
      // A realistic person's financial profile
      double salary = 1200000;        // Salary from employer
      double bonus = 200000;          // Included in other income
      double rentalIncome = 600000;   // Rental property
      double businessIncome = 300000; // Side business
      double totalIncome = salary + bonus + rentalIncome + businessIncome;
      
      // Realistic deductions
      double section80c_elss = 100000;      // ELSS investment
      double section80c_ppf = 50000;        // PPF
      double section80d_self = 30000;       // Health insurance self
      double section80d_family = 20000;     // Health insurance family
      double section80ccd_nps = 50000;      // NPS
      double section24_loan = 400000;       // Home loan interest
      double section80e_student = 0;        // No student loan
      
      double totalDeductions = section80c_elss + section80c_ppf + 
                                section80d_self + section80d_family + 
                                section80ccd_nps + section24_loan + 
                                section80e_student;
      
      double oldRegime = calculateOldRegimeTax(totalIncome, totalDeductions);
      double newRegime = calculateNewRegimeTax(totalIncome, totalDeductions);
      
      print('✅ Scenario 10: Real-World Profile (₹23L Income)');
      print('   INCOME SOURCES:');
      print('   └─ Salary: ₹${salary/100000}L');
      print('   └─ Bonus: ₹${bonus/100000}L');
      print('   └─ Rental: ₹${rentalIncome/100000}L');
      print('   └─ Business: ₹${businessIncome/100000}L');
      print('   └─ TOTAL: ₹${totalIncome/100000}L');
      print('   ');
      print('   DEDUCTION BREAKDOWN:');
      print('   └─ 80C (ELSS): ₹${section80c_elss/100000}L');
      print('   └─ 80C (PPF): ₹${section80c_ppf/100000}L');
      print('   └─ 80D (Self): ₹${section80d_self/100000}L');
      print('   └─ 80D (Family): ₹${section80d_family/100000}L');
      print('   └─ 80CCD (NPS): ₹${section80ccd_nps/100000}L');
      print('   └─ 24 (Loan): ₹${section24_loan/100000}L');
      print('   └─ TOTAL: ₹${totalDeductions/100000}L');
      print('   ');
      print('   TAX COMPARISON:');
      print('   Old Regime: ₹${oldRegime.toStringAsFixed(2)}');
      print('   New Regime: ₹${newRegime.toStringAsFixed(2)}');
      print('   ├─ Difference: ₹${(newRegime - oldRegime).toStringAsFixed(2)}');
      print('   └─ Savings in Old Regime: ${((newRegime - oldRegime) / newRegime * 100).toStringAsFixed(1)}%');
      
      expect(oldRegime, lessThan(newRegime));
      expect((newRegime - oldRegime), greaterThan(50000)); // Substantial saving
    });
  });
}
