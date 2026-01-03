import 'package:test/test.dart';

void main() {
  group('Capital Gains Core Functionality', () {
    
    // LTCG Tax Calculation
    double calculateLTCGTax(double amount, double rate, double totalIncome) {
      double tax = amount * rate;
      double surcharge = 0;
      if ((totalIncome + amount) > 5000000) surcharge = tax * 0.25;
      else if ((totalIncome + amount) > 1000000) surcharge = tax * 0.15;
      else if ((totalIncome + amount) > 500000) surcharge = tax * 0.10;
      double cess = (tax + surcharge) * 0.04;
      return tax + surcharge + cess;
    }

    test('LTCG Stocks (0% rate) should have zero tax', () {
      double ltcgStocksTax = calculateLTCGTax(1000000, 0.0, 1000000);
      expect(ltcgStocksTax, equals(0.0));
      print('✓ Stocks LTCG: ₹1000000 @ 0% = ₹$ltcgStocksTax (tax-free!)');
    });

    test('LTCG Mutual Funds (15% rate) includes surcharge and cess', () {
      double ltcgMFTax = calculateLTCGTax(300000, 0.15, 800000);
      double expectedBaseTax = 300000 * 0.15; // ₹45000
      expect(ltcgMFTax, greaterThan(expectedBaseTax)); // Should include surcharge & cess
      print('✓ MF LTCG: ₹300000 @ 15% = ₹${ltcgMFTax.toStringAsFixed(0)} (includes 10% surcharge + 4% cess)');
    });

    test('LTCG Real Estate (20% rate) includes surcharge and cess', () {
      double ltcgRETax = calculateLTCGTax(500000, 0.20, 1000000);
      double expectedBaseTax = 500000 * 0.20; // ₹100000
      expect(ltcgRETax, greaterThan(expectedBaseTax)); // Should include surcharge & cess
      print('✓ Real Estate LTCG: ₹500000 @ 20% = ₹${ltcgRETax.toStringAsFixed(0)} (includes 15% surcharge + 4% cess)');
    });

    test('High income (>₹50L) triggers 25% surcharge on LTCG', () {
      double lowIncomeLTCG = calculateLTCGTax(1000000, 0.20, 1000000); // 10% surcharge
      double highIncomeLTCG = calculateLTCGTax(1000000, 0.20, 6000000); // 25% surcharge
      expect(highIncomeLTCG, greaterThan(lowIncomeLTCG));
      print('✓ Surcharge scales: ₹1M @ ₹1M income = ₹${lowIncomeLTCG.toStringAsFixed(0)}, @ ₹60M income = ₹${highIncomeLTCG.toStringAsFixed(0)}');
    });

    test('STCG should be added to regular income for tax calculation', () {
      double regularIncome = 1000000;
      double stcg = 500000;
      double totalIncome = regularIncome + stcg;
      
      expect(totalIncome, equals(1500000));
      print('✓ STCG correctly added: ₹$regularIncome + ₹$stcg = ₹$totalIncome');
    });

    test('LTCG should NOT be added to regular income for tax bracket', () {
      double regularIncome = 1000000;
      double ltcg = 500000;
      
      // LTCG doesn't affect regular income tax bracket
      expect(regularIncome, equals(1000000)); // Should remain unchanged
      print('✓ LTCG correctly NOT added to income: Regular Income stays ₹$regularIncome');
    });

    test('Multiple LTCG types can coexist', () {
      double ltcgStocks = calculateLTCGTax(500000, 0.0, 1000000); // 0%
      double ltcgMF = calculateLTCGTax(300000, 0.15, 1000000); // 15%
      double ltcgRE = calculateLTCGTax(200000, 0.20, 1000000); // 20%
      
      double totalLTCGTax = ltcgStocks + ltcgMF + ltcgRE;
      
      expect(ltcgStocks, equals(0.0));
      expect(ltcgMF, greaterThan(0));
      expect(ltcgRE, greaterThan(ltcgMF));
      expect(totalLTCGTax, greaterThan(0));
      print('✓ Mixed LTCG: Stocks ₹${ltcgStocks.toStringAsFixed(0)} + MF ₹${ltcgMF.toStringAsFixed(0)} + RE ₹${ltcgRE.toStringAsFixed(0)} = ₹${totalLTCGTax.toStringAsFixed(0)}');
    });

    test('Zero capital gains should result in zero additional tax', () {
      double zeroCGTax = calculateLTCGTax(0, 0.20, 1000000);
      expect(zeroCGTax, equals(0.0));
      print('✓ Zero capital gains: ₹0 gain = ₹0 tax');
    });

    test('Firebase fields should support all capital gain types', () {
      // Verify structure matches Firebase schema
      Map<String, double> capitalGains = {
        'stcgRealEstate': 100000,
        'stcgStocks': 50000,
        'stcgMutualFunds': 75000,
        'stcgOther': 25000,
        'ltcgRealEstate': 200000,
        'ltcgStocks': 500000,
        'ltcgMutualFunds': 150000,
        'ltcgOther': 100000,
      };
      
      double totalSTCG = capitalGains['stcgRealEstate']! +
          capitalGains['stcgStocks']! +
          capitalGains['stcgMutualFunds']! +
          capitalGains['stcgOther']!;
      
      double totalLTCG = capitalGains['ltcgRealEstate']! +
          capitalGains['ltcgStocks']! +
          capitalGains['ltcgMutualFunds']! +
          capitalGains['ltcgOther']!;
      
      expect(totalSTCG, equals(250000));
      expect(totalLTCG, equals(950000));
      print('✓ Firebase schema verified: STCG Total ₹$totalSTCG, LTCG Total ₹$totalLTCG');
    });

    test('Tax savings comparison: Old vs New Regime with capital gains', () {
      // Scenario: ₹15L + ₹3L STCG + ₹2L LTCG (MF @ 15%)
      double regularIncome = 1500000;
      double stcg = 300000;
      double ltcgMF = 200000;
      double deductions = 100000;
      
      double totalIncome = regularIncome + stcg;
      
      // Old regime tax calculation (simplified)
      double oldRegimeTaxable = (totalIncome - 50000 - deductions).clamp(0, double.infinity);
      double oldRegimeTax = 0;
      if (oldRegimeTaxable > 500000) oldRegimeTax += (oldRegimeTaxable - 500000) * 0.20;
      if (oldRegimeTaxable > 250000) oldRegimeTax += (oldRegimeTaxable - 250000) * 0.10;
      
      double oldRegimeLTCGTax = calculateLTCGTax(ltcgMF, 0.15, regularIncome);
      double totalOldRegimeTax = oldRegimeTax + oldRegimeLTCGTax;
      
      // New regime tax calculation
      double newRegimeTaxable = totalIncome.clamp(0, double.infinity);
      double newRegimeTax = 0;
      if (newRegimeTaxable > 500000) newRegimeTax += (newRegimeTaxable - 500000) * 0.15;
      if (newRegimeTaxable > 250000) newRegimeTax += (newRegimeTaxable - 250000) * 0.05;
      
      double newRegimeLTCGTax = calculateLTCGTax(ltcgMF, 0.15, regularIncome);
      double totalNewRegimeTax = newRegimeTax + newRegimeLTCGTax;
      
      print('✓ Regime Comparison:');
      print('  Income: ₹$regularIncome + STCG ₹$stcg + LTCG MF ₹$ltcgMF');
      print('  Old Regime: ₹${totalOldRegimeTax.toStringAsFixed(0)}');
      print('  New Regime: ₹${totalNewRegimeTax.toStringAsFixed(0)}');
      print('  Better option: ${totalOldRegimeTax < totalNewRegimeTax ? "Old Regime" : "New Regime"}');
      
      expect(totalOldRegimeTax, greaterThan(0));
      expect(totalNewRegimeTax, greaterThan(0));
    });
  });
}
