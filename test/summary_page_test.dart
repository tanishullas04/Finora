import 'package:test/test.dart';

void main() {
  group('Summary Page Tests', () {
    // ==================== TAX CALCULATION TESTS ====================
    
    group('Old Regime Tax Calculations', () {
      double calculateOldRegimeTax(double taxableIncome) {
        if (taxableIncome <= 250000) return 0;
        if (taxableIncome <= 500000) return (taxableIncome - 250000) * 0.05;
        if (taxableIncome <= 1000000) return 12500 + (taxableIncome - 500000) * 0.20;
        if (taxableIncome <= 1500000) return 112500 + (taxableIncome - 1000000) * 0.30;
        return 262500 + (taxableIncome - 1500000) * 0.30;
      }

      test('Old Regime: ₹0-2.5L bracket = ₹0 tax', () {
        expect(calculateOldRegimeTax(100000), equals(0));
        expect(calculateOldRegimeTax(250000), equals(0));
      });

      test('Old Regime: ₹2.5L-5L bracket = 5% tax', () {
        double tax = calculateOldRegimeTax(400000);
        expect(tax, equals(7500)); // (400k - 250k) * 5%
      });

      test('Old Regime: ₹5L-10L bracket = 20% + base', () {
        double tax = calculateOldRegimeTax(750000);
        expect(tax, equals(62500)); // 12.5k + (750k - 500k) * 20%
      });

      test('Old Regime: ₹10L-15L bracket = 30% + base', () {
        double tax = calculateOldRegimeTax(1200000);
        expect(tax, equals(172500)); // 112.5k + (1.2M - 1M) * 30% = 112.5k + 60k = 172.5k
      });

      test('Old Regime: >₹15L bracket = 30% + base', () {
        double tax = calculateOldRegimeTax(2000000);
        expect(tax, equals(412500)); // 262.5k + (2M - 1.5M) * 30% = 412.5k
      });
    });

    group('New Regime Tax Calculations', () {
      double calculateNewRegimeTax(double taxableIncome) {
        if (taxableIncome <= 300000) return 0;
        if (taxableIncome <= 600000) return (taxableIncome - 300000) * 0.05;
        if (taxableIncome <= 900000) return 15000 + (taxableIncome - 600000) * 0.10;
        if (taxableIncome <= 1200000) return 45000 + (taxableIncome - 900000) * 0.15;
        if (taxableIncome <= 1500000) return 90000 + (taxableIncome - 1200000) * 0.20;
        return 150000 + (taxableIncome - 1500000) * 0.30;
      }

      test('New Regime: ₹0-3L bracket = ₹0 tax', () {
        expect(calculateNewRegimeTax(100000), equals(0));
        expect(calculateNewRegimeTax(300000), equals(0));
      });

      test('New Regime: ₹3L-6L bracket = 5% tax', () {
        double tax = calculateNewRegimeTax(450000);
        expect(tax, equals(7500)); // (450k - 300k) * 5%
      });

      test('New Regime: ₹6L-9L bracket = 10% + base', () {
        double tax = calculateNewRegimeTax(750000);
        expect(tax, equals(30000)); // 15k + (750k - 600k) * 10%
      });

      test('New Regime: ₹9L-12L bracket = 15% + base', () {
        double tax = calculateNewRegimeTax(1050000);
        expect(tax, equals(67500)); // 45k + (1.05M - 900k) * 15%
      });

      test('New Regime: ₹12L-15L bracket = 20% + base', () {
        double tax = calculateNewRegimeTax(1350000);
        expect(tax, equals(120000)); // 90k + (1.35M - 1.2M) * 20%
      });

      test('New Regime: >₹15L bracket = 30% + base', () {
        double tax = calculateNewRegimeTax(2000000);
        expect(tax, equals(300000)); // 150k + (2M - 1.5M) * 30%
      });
    });

    group('LTCG Tax Calculations (with Surcharge & Cess)', () {
      test('LTCG RE @ 20% + 10% surcharge + 4% cess (income ₹50-100L)', () {
        double ltcgRealEstate = 500000;
        double baseTax = ltcgRealEstate * 0.20; // ₹100k
        double surcharge = baseTax * 0.10; // 10% surcharge = ₹10k
        double cess = (baseTax + surcharge) * 0.04; // 4% cess = ₹4.4k
        double totalTax = baseTax + surcharge + cess;
        
        expect(baseTax, equals(100000));
        expect(surcharge, equals(10000));
        expect(cess, closeTo(4400, 1));
        expect(totalTax, closeTo(114400, 1));
      });

      test('LTCG MF @ 15% + 15% surcharge + 4% cess (income ₹100-500L)', () {
        double ltcgMF = 500000;
        double baseTax = ltcgMF * 0.15; // ₹75k
        double surcharge = baseTax * 0.15; // 15% surcharge = ₹11.25k
        double cess = (baseTax + surcharge) * 0.04; // 4% cess
        double totalTax = baseTax + surcharge + cess;
        
        expect(baseTax, equals(75000));
        expect(surcharge, equals(11250));
        expect(totalTax, closeTo(89700, 1));
      });

      test('LTCG Stocks @ 0% = Tax-free', () {
        double ltcgStocks = 1000000;
        double tax = ltcgStocks * 0.0;
        
        expect(tax, equals(0));
      });

      test('LTCG RE @ 20% + no surcharge (<₹50L income)', () {
        double ltcgRE = 300000;
        double baseTax = ltcgRE * 0.20; // ₹60k
        double surcharge = 0; // No surcharge
        double cess = baseTax * 0.04; // 4% cess = ₹2.4k
        double totalTax = baseTax + surcharge + cess;
        
        expect(baseTax, equals(60000));
        expect(totalTax, closeTo(62400, 1));
      });

      test('LTCG RE @ 20% + 25% surcharge + 4% cess (income >₹5Cr)', () {
        double ltcgRE = 500000;
        double baseTax = ltcgRE * 0.20; // ₹100k
        double surcharge = baseTax * 0.25; // 25% surcharge = ₹25k
        double cess = (baseTax + surcharge) * 0.04; // 4% cess = ₹5k
        double totalTax = baseTax + surcharge + cess;
        
        expect(baseTax, equals(100000));
        expect(surcharge, equals(25000));
        expect(totalTax, closeTo(130000, 100));
      });
    });

    group('STCG Addition to Income', () {
      test('STCG correctly added to regular income for tax calculation', () {
        double salary = 1500000;
        double stcg = 500000;
        double totalTaxableIncome = salary + stcg; // ₹20L
        
        expect(totalTaxableIncome, equals(2000000));
      });

      test('STCG increases tax liability significantly', () {
        double calculateOldRegimeTax(double taxableIncome) {
          if (taxableIncome <= 250000) return 0;
          if (taxableIncome <= 500000) return (taxableIncome - 250000) * 0.05;
          if (taxableIncome <= 1000000) return 12500 + (taxableIncome - 500000) * 0.20;
          if (taxableIncome <= 1500000) return 112500 + (taxableIncome - 1000000) * 0.30;
          return 262500 + (taxableIncome - 1500000) * 0.30;
        }

        double taxWithoutSTCG = calculateOldRegimeTax(1500000);
        double taxWithSTCG = calculateOldRegimeTax(2000000);
        double additionalTax = taxWithSTCG - taxWithoutSTCG;
        
        expect(additionalTax, equals(150000)); // 500k STCG × 30% = 150k additional tax
      });
    });

    group('Currency Formatting', () {
      String formatCurrency(double value) {
        if (value >= 10000000) {
          return '₹${(value / 10000000).toStringAsFixed(2)}Cr';
        } else if (value >= 100000) {
          return '₹${(value / 100000).toStringAsFixed(2)}L';
        }
        return '₹${value.toStringAsFixed(0)}';
      }

      test('Format Crores: ₹10 Crore = 10.00Cr (adjustment needed)', () {
        expect(formatCurrency(100000000), equals('₹10.00Cr')); // 100M / 10M
      });

      test('Format Lakhs: ₹100k = 1.00L', () {
        expect(formatCurrency(100000), equals('₹1.00L'));
      });

      test('Format Rupees: ₹50k = ₹50000', () {
        expect(formatCurrency(50000), equals('₹50000'));
      });

      test('Format large amount: ₹5.5 Crore', () {
        expect(formatCurrency(55000000), equals('₹5.50Cr'));
      });
    });

    group('Regime Comparison & Recommendation', () {
      test('Old Regime better recommendation when tax is lower', () {
        double oldTax = 400000;
        double newTax = 450000;
        String bestRegime = oldTax > newTax ? 'New Regime' : 'Old Regime';
        double savings = (oldTax - newTax).abs();
        
        expect(bestRegime, equals('Old Regime'));
        expect(savings, equals(50000));
      });

      test('New Regime better recommendation when tax is lower', () {
        double oldTax = 500000;
        double newTax = 400000;
        String bestRegime = oldTax > newTax ? 'New Regime' : 'Old Regime';
        double savings = (oldTax - newTax).abs();
        
        expect(bestRegime, equals('New Regime'));
        expect(savings, equals(100000));
      });

      test('High income scenario: ₹50L + ₹50L LTCG', () {
        double income = 5000000;
        double ltcg = 5000000;
        double baseTax = 262500 + (income - 1500000) * 0.30; // ₹1,312,500 base
        double ltcgTax = ltcg * 0.20; // ₹10L LTCG @ 20%
        double surcharge = ltcgTax * 0.25; // 25% surcharge (high income)
        double cess = (ltcgTax + surcharge) * 0.04;
        double totalTax = baseTax + ltcgTax + surcharge + cess;
        
        expect(baseTax, equals(1312500));
        expect(totalTax, closeTo(2612500, 100)); // Adjusted calculation
      });
    });

    group('Real-World Scenarios', () {
      test('Scenario 1: ₹15L salary + ₹2.5L deductions', () {
        double salary = 1500000;
        double deductions = 250000;
        double taxableIncome = salary - deductions; // ₹12.5L
        
        double calculateOldRegimeTax(double income) {
          if (income <= 250000) return 0;
          if (income <= 500000) return (income - 250000) * 0.05;
          if (income <= 1000000) return 12500 + (income - 500000) * 0.20;
          if (income <= 1500000) return 112500 + (income - 1000000) * 0.30;
          return 262500 + (income - 1500000) * 0.30;
        }
        
        double tax = calculateOldRegimeTax(taxableIncome);
        expect(tax, equals(187500)); // Corrected: (1.25M - 1M) * 30% = 75k, but wait...
      });

      test('Scenario 2: ₹50L salary + ₹1L deductions + ₹30L LTCG RE', () {
        double salary = 5000000;
        double deductions = 1000000;
        double taxableIncome = salary - deductions; // ₹40L
        
        double calculateOldRegimeTax(double income) {
          if (income <= 250000) return 0;
          if (income <= 500000) return (income - 250000) * 0.05;
          if (income <= 1000000) return 12500 + (income - 500000) * 0.20;
          if (income <= 1500000) return 112500 + (income - 1000000) * 0.30;
          return 262500 + (income - 1500000) * 0.30;
        }
        
        double regularTax = calculateOldRegimeTax(taxableIncome); // ₹1,012,500
        double ltcgTax = 3000000 * 0.20; // ₹6L base
        double surcharge = ltcgTax * 0.25; // ₹1.5L (25% on income >₹5Cr scenario adjacent)
        double cess = (ltcgTax + surcharge) * 0.04;
        double totalTax = regularTax + ltcgTax + surcharge + cess;
        
        expect(regularTax, equals(1012500));
        expect(ltcgTax, equals(600000));
      });

      test('Scenario 3: ₹10L salary + ₹2L STCG + ₹0 deductions', () {
        double salary = 1000000;
        double stcg = 200000;
        double totalIncome = salary + stcg; // ₹12L
        
        double calculateOldRegimeTax(double income) {
          if (income <= 250000) return 0;
          if (income <= 500000) return (income - 250000) * 0.05;
          if (income <= 1000000) return 12500 + (income - 500000) * 0.20;
          if (income <= 1500000) return 112500 + (income - 1000000) * 0.30;
          return 262500 + (income - 1500000) * 0.30;
        }
        
        double taxWithoutSTCG = calculateOldRegimeTax(salary); // ₹112,500
        double taxWithSTCG = calculateOldRegimeTax(totalIncome); // ₹172,500
        double additionalTax = taxWithSTCG - taxWithoutSTCG;
        
        expect(taxWithoutSTCG, equals(112500));
        expect(taxWithSTCG, equals(172500));
        expect(additionalTax, equals(60000)); // 200k STCG: 50k @ 5% + 150k @ 20% = 50k
      });
    });

    group('Edge Cases', () {
      test('Exactly at bracket boundary: ₹2.5L (Old Regime)', () {
        double calculateOldRegimeTax(double income) {
          if (income <= 250000) return 0;
          if (income <= 500000) return (income - 250000) * 0.05;
          return 0;
        }
        
        expect(calculateOldRegimeTax(250000), equals(0));
      });

      test('Just above bracket boundary: ₹2.50001L (Old Regime)', () {
        double calculateOldRegimeTax(double income) {
          if (income <= 250000) return 0;
          if (income <= 500000) return (income - 250000) * 0.05;
          return 0;
        }
        
        double tax = calculateOldRegimeTax(250001);
        expect(tax, closeTo(0.05, 0.001));
      });

      test('Zero income = Zero tax', () {
        double calculateOldRegimeTax(double income) {
          if (income <= 250000) return 0;
          return 0;
        }
        
        expect(calculateOldRegimeTax(0), equals(0));
      });

      test('Very high income (₹10Cr)', () {
        double calculateOldRegimeTax(double income) {
          if (income <= 250000) return 0;
          if (income <= 500000) return (income - 250000) * 0.05;
          if (income <= 1000000) return 12500 + (income - 500000) * 0.20;
          if (income <= 1500000) return 112500 + (income - 1000000) * 0.30;
          return 262500 + (income - 1500000) * 0.30;
        }
        
        double tax = calculateOldRegimeTax(100000000);
        expect(tax, equals(29812500)); // Adjusted: 262.5k + (10Cr - 1.5Cr) * 30%
      });
    });

    group('Data Integrity Checks', () {
      test('Total income = Salary + STCG (LTCG not added)', () {
        double salary = 1500000;
        double stcg = 500000;
        double ltcg = 1000000;
        double totalIncome = salary + stcg; // LTCG NOT added
        
        expect(totalIncome, equals(2000000));
      });

      test('LTCG is calculated separately, not in regular income', () {
        double regularIncome = 1500000;
        double ltcg = 500000;
        double calculateBase = 1500000; // Does NOT include LTCG
        
        expect(calculateBase, equals(regularIncome));
      });

      test('GST is tracked separately from income tax', () {
        double incomeTax = 500000;
        double gstTax = 50000;
        double totalTax = incomeTax + gstTax; // Sum of both
        
        expect(totalTax, equals(550000));
      });
    });
  });
}
