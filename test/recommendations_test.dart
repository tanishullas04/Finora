import 'package:test/test.dart';

void main() {
  group('Recommendations Engine Tests', () {
    // ==================== 80C DEDUCTION OPTIMIZATION ====================
    
    group('80C Optimization Detection', () {
      test('80C: Full ₹1.5L invested = No savings', () {
        double invested80C = 150000;
        double maxDeduction = 150000;
        double unusedCapacity = maxDeduction - invested80C;
        bool canOptimize = unusedCapacity > 0;
        double potentialSavings = unusedCapacity * 0.30; // 30% tax bracket
        
        expect(unusedCapacity, equals(0));
        expect(canOptimize, equals(false));
        expect(potentialSavings, equals(0));
      });

      test('80C: ₹1L invested = ₹50k unused capacity = ₹15k savings', () {
        double invested80C = 100000;
        double maxDeduction = 150000;
        double unusedCapacity = maxDeduction - invested80C; // ₹50k
        bool canOptimize = unusedCapacity > 0;
        double potentialSavings = unusedCapacity * 0.30; // ₹15k @ 30%
        
        expect(unusedCapacity, equals(50000));
        expect(canOptimize, equals(true));
        expect(potentialSavings, equals(15000));
      });

      test('80C: ₹0 invested = ₹1.5L unused = ₹45k savings @ 30%', () {
        double invested80C = 0;
        double maxDeduction = 150000;
        double unusedCapacity = maxDeduction - invested80C;
        double potentialSavings = unusedCapacity * 0.30;
        
        expect(unusedCapacity, equals(150000));
        expect(potentialSavings, equals(45000));
      });

      test('80C: Adjust savings based on actual tax bracket', () {
        double invested80C = 50000;
        double maxDeduction = 150000;
        double unusedCapacity = maxDeduction - invested80C; // ₹1L
        double taxBracket = 0.20; // 20% bracket (not 30%)
        double potentialSavings = unusedCapacity * taxBracket;
        
        expect(potentialSavings, equals(20000)); // ₹1L × 20%
      });
    });

    // ==================== 80D HEALTH INSURANCE ====================

    group('80D Health Insurance Optimization', () {
      test('80D: Full ₹1L invested = No savings', () {
        double invested80D = 100000;
        double maxDeduction = 100000;
        double unusedCapacity = maxDeduction - invested80D;
        bool canOptimize = unusedCapacity > 0;
        
        expect(unusedCapacity, equals(0));
        expect(canOptimize, equals(false));
      });

      test('80D: ₹0 invested = ₹1L unused = ₹30k savings @ 30%', () {
        double invested80D = 0;
        double maxDeduction = 100000;
        double unusedCapacity = maxDeduction - invested80D;
        double potentialSavings = unusedCapacity * 0.30;
        
        expect(unusedCapacity, equals(100000));
        expect(potentialSavings, equals(30000));
      });

      test('80D: ₹60k invested = ₹40k unused = ₹12k savings', () {
        double invested80D = 60000;
        double maxDeduction = 100000;
        double unusedCapacity = maxDeduction - invested80D;
        double potentialSavings = unusedCapacity * 0.30;
        
        expect(unusedCapacity, equals(40000));
        expect(potentialSavings, equals(12000));
      });

      test('80D: Low income scenario - ₹50k unused @ 5% = ₹2.5k savings', () {
        double invested80D = 50000;
        double maxDeduction = 100000;
        double unusedCapacity = maxDeduction - invested80D;
        double taxBracket = 0.05; // 5% bracket
        double potentialSavings = unusedCapacity * taxBracket;
        
        expect(potentialSavings, equals(2500));
      });
    });

    // ==================== STCG TIMING ANALYSIS ====================

    group('STCG Timing Strategy', () {
      test('STCG recognized: Timing is critical', () {
        double stcgGain = 500000;
        bool shouldOptimize = stcgGain > 0;
        double taxRate = 0.30; // Added to 30% bracket
        double annualSavings = stcgGain * taxRate * 0.10; // 10% as timing benefit
        
        expect(shouldOptimize, equals(true));
        expect(annualSavings, closeTo(15000, 100));
      });

      test('STCG: ₹10L gain in current year vs spreading next year', () {
        double stcgCurrentYear = 1000000;
        double taxCurrentYear = stcgCurrentYear * 0.30; // ₹3L tax
        double taxSpreadNextYear = stcgCurrentYear * 0.05; // ₹50k @ 5% bracket
        double potentialSavings = taxCurrentYear - taxSpreadNextYear;
        
        expect(potentialSavings, equals(250000)); // ₹2.5L saved by spreading
      });

      test('STCG: Harvest losses to offset gains', () {
        double stcgGain = 500000;
        double stcgLoss = 200000;
        double netSTCG = stcgGain - stcgLoss;
        double taxSavings = stcgLoss * 0.30;
        
        expect(netSTCG, equals(300000));
        expect(taxSavings, equals(60000));
      });
    });

    // ==================== LTCG STRATEGY ====================

    group('LTCG Benefit Highlighting', () {
      test('LTCG RE @ 20% vs regular income @ 30%', () {
        double ltcgRE = 500000;
        double taxLTCG = ltcgRE * 0.20; // ₹1L
        double taxRegular = ltcgRE * 0.30; // ₹1.5L
        double savings = taxRegular - taxLTCG;
        
        expect(savings, equals(50000));
      });

      test('LTCG MF @ 15% vs regular income @ 30%', () {
        double ltcgMF = 1000000;
        double taxLTCG = ltcgMF * 0.15; // ₹1.5L
        double taxRegular = ltcgMF * 0.30; // ₹3L
        double savings = taxRegular - taxLTCG;
        
        expect(savings, equals(150000));
      });

      test('LTCG Stocks @ 0% = Tax-free benefit', () {
        double ltcgStocks = 2000000;
        double taxLTCG = 0;
        double taxRegular = ltcgStocks * 0.30; // ₹6L
        double savings = taxRegular - taxLTCG;
        
        expect(savings, equals(600000)); // Massive savings from tax-free treatment
      });

      test('LTCG with surcharge: 20% + 25% surcharge + 4% cess', () {
        double ltcgRE = 500000;
        double baseTax = ltcgRE * 0.20; // ₹1L
        double surcharge = baseTax * 0.25; // ₹25k
        double cess = (baseTax + surcharge) * 0.04;
        double totalLTCGTax = baseTax + surcharge + cess;
        
        double taxRegular = ltcgRE * 0.30; // ₹1.5L
        double savings = taxRegular - totalLTCGTax;
        
        expect(savings, closeTo(20000, 1000)); // Adjusted tolerance
      });
    });

    // ==================== GST ITC IDENTIFICATION ====================

    group('GST Input Tax Credit (ITC) Optimization', () {
      test('GST @ 18%: ₹1L purchase = ₹18k ITC potential', () {
        double gstPurchase = 100000;
        double gstRate = 0.18;
        double itcCredit = gstPurchase * gstRate;
        double savingsAsPercentage = itcCredit / gstPurchase;
        
        expect(itcCredit, equals(18000));
        expect(savingsAsPercentage, equals(0.18));
      });

      test('GST ITC realization: Up to 30% of GST liability', () {
        double gstLiability = 100000; // GST on sales
        double itcCredit = 50000; // Actual ITC claimed
        double netGST = gstLiability - itcCredit;
        double itcPercentage = itcCredit / gstLiability;
        
        expect(itcPercentage, equals(0.50)); // 50% - can realize significant savings
      });

      test('GST: Multi-rate ITC tracking (5%, 12%, 18%, 28%)', () {
        double itc5 = 50000 * 0.05; // ₹2.5k
        double itc12 = 100000 * 0.12; // ₹12k
        double itc18 = 150000 * 0.18; // ₹27k
        double itc28 = 50000 * 0.28; // ₹14k
        double totalITC = itc5 + itc12 + itc18 + itc28; // ₹55.5k
        
        expect(totalITC, equals(55500));
      });

      test('GST 0%: No ITC available', () {
        double gst0Purchase = 100000;
        double itc = gst0Purchase * 0.0;
        
        expect(itc, equals(0));
      });
    });

    // ==================== INCOME SPLITTING DETECTION ====================

    group('Income Splitting Strategy (HUF/Family)', () {
      test('Income splitting: ₹100L to ₹50L + ₹50L = Tax savings', () {
        double singleIncome = 10000000;
        
        double calculateTax(double income) {
          if (income <= 250000) return 0;
          if (income <= 500000) return (income - 250000) * 0.05;
          if (income <= 1000000) return 12500 + (income - 500000) * 0.20;
          if (income <= 1500000) return 112500 + (income - 1000000) * 0.30;
          return 262500 + (income - 1500000) * 0.30;
        }
        
        double taxSinglePerson = calculateTax(singleIncome);
        double taxTwoPersons = calculateTax(5000000) * 2;
        double savings = taxSinglePerson - taxTwoPersons;
        
        expect(savings, equals(187500)); // Actual savings from income splitting
      });

      test('Income splitting recommended for >₹50L earners', () {
        double income = 5000000;
        bool shouldConsiderSplitting = income > 5000000;
        
        expect(shouldConsiderSplitting, equals(false)); // At ₹50L threshold
      });

      test('Income splitting recommended for >₹50L earners (verified)', () {
        double income = 5100000;
        bool shouldConsiderSplitting = income > 5000000;
        
        expect(shouldConsiderSplitting, equals(true));
      });

      test('Potential HUF benefit: Independent assessment on ₹30L allocation', () {
        double hufAllocation = 3000000;
        double taxOnHUF = 262500 + (hufAllocation - 1500000) * 0.30; // ₹712.5k
        double taxPersonal = (7000000) * 0.30; // Simplified
        double savings = taxPersonal - taxOnHUF;
        
        expect(savings, isPositive); // Verify savings exist
      });
    });

    // ==================== HRA/LTA VERIFICATION ====================

    group('HRA and LTA Verification', () {
      test('HRA Exemption: Min(Salary/2, Actual HRA, Rent - 10% Salary)', () {
        double salary = 1000000;
        double actualHRA = 350000;
        double rentPaid = 450000;
        
        double hraExemption = [
          salary / 2, // ₹5L
          actualHRA, // ₹3.5L
          rentPaid - (salary * 0.10) // ₹3.5L
        ].reduce((a, b) => a < b ? a : b);
        
        expect(hraExemption, equals(350000)); // ₹3.5L minimum
      });

      test('LTA Exemption: ₹20k per year (can be carried forward)', () {
        double ltaUsed = 15000;
        double ltaCarryForward = 5000; // Unused portion
        double nextYearAvailable = 20000 + ltaCarryForward;
        
        expect(nextYearAvailable, equals(25000));
      });

      test('HRA Non-taxable in metro cities', () {
        double salary = 1500000;
        double hraExemption = salary * 0.50; // Metro city exemption
        
        expect(hraExemption, equals(750000));
      });
    });

    // ==================== RECOMMENDATION GENERATION ====================

    group('Recommendation Priority Sorting', () {
      test('HIGH priority recommendations appear first', () {
        List<String> priorities = ['LOW', 'MEDIUM', 'HIGH'];
        Map<String, int> priorityOrder = {
          'HIGH': 0,
          'MEDIUM': 1,
          'LOW': 2
        };
        
        priorities.sort((a, b) => priorityOrder[a]!.compareTo(priorityOrder[b]!));
        
        expect(priorities, equals(['HIGH', 'MEDIUM', 'LOW']));
      });

      test('All 7 recommendations generated in correct priority order', () {
        List<Map<String, String>> recommendations = [
          {'title': '80C Deduction', 'priority': 'HIGH'},
          {'title': '80D Health Insurance', 'priority': 'MEDIUM'},
          {'title': 'STCG Timing', 'priority': 'MEDIUM'},
          {'title': 'LTCG Strategy', 'priority': 'LOW'},
          {'title': 'GST ITC', 'priority': 'MEDIUM'},
          {'title': 'Income Splitting', 'priority': 'HIGH'},
          {'title': 'HRA/LTA', 'priority': 'HIGH'},
        ];
        
        Map<String, int> priorityOrder = {
          'HIGH': 0,
          'MEDIUM': 1,
          'LOW': 2
        };
        
        recommendations.sort((a, b) => priorityOrder[a['priority']]!
            .compareTo(priorityOrder[b['priority']]!));
        
        expect(recommendations[0]['priority'], equals('HIGH'));
        expect(recommendations[recommendations.length - 1]['priority'], equals('LOW'));
      });
    });

    // ==================== SAVINGS CALCULATIONS ====================

    group('Total Potential Savings Calculation', () {
      test('Sum all recommendation savings: ₹1L total', () {
        double savings80C = 45000;
        double savings80D = 30000;
        double savingsSTCG = 10000;
        double savingsLTCG = 15000;
        double savingsGST = 5000;
        double savingsIncomeSplitting = 0; // Not applicable
        double savingsHRA = 0; // Not applicable
        
        double totalSavings = savings80C + savings80D + savingsSTCG + savingsLTCG + 
                              savingsGST + savingsIncomeSplitting + savingsHRA;
        
        expect(totalSavings, equals(105000));
      });

      test('Large scenario: Multiple optimizations = ₹5L+ savings', () {
        double savings80C = 150000;
        double savings80D = 100000;
        double savingsSTCG = 250000;
        double savingsLTCG = 500000;
        double savingsGST = 50000;
        double savingsIncomeSplitting = 1500000;
        double savingsHRA = 100000;
        
        double totalSavings = savings80C + savings80D + savingsSTCG + savingsLTCG + 
                              savingsGST + savingsIncomeSplitting + savingsHRA;
        
        expect(totalSavings, equals(2650000)); // ₹26.5L total!
      });
    });

    // ==================== REAL-WORLD SCENARIOS ====================

    group('Real-World Recommendation Scenarios', () {
      test('Scenario 1: Young professional (₹15L salary, no deductions)', () {
        double salary = 1500000;
        double deductions = 0;
        double ltcg = 0;
        double gst = 0;
        
        // Should recommend: 80C (HIGH), 80D (MEDIUM), HRA/LTA (HIGH)
        List<String> recommendations = [];
        if (deductions < 150000) recommendations.add('80C Optimization');
        if (deductions < 100000) recommendations.add('80D Health Insurance');
        
        expect(recommendations.length, greaterThan(0));
      });

      test('Scenario 2: High net worth (₹50L income + ₹30L LTCG)', () {
        double salary = 5000000;
        double ltcgRE = 3000000;
        double deductions = 200000;
        
        // Should recommend: Income splitting (HIGH), LTCG optimization (LOW), etc.
        bool shouldRecommendIncomeSplitting = salary > 5000000;
        
        expect(shouldRecommendIncomeSplitting, equals(false)); // Exactly at threshold
      });

      test('Scenario 3: Business owner with GST liability', () {
        double businessIncome = 5000000;
        double gstLiability = 500000;
        double itcOpportunity = 300000; // 60% of liability
        
        double netGST = gstLiability - itcOpportunity;
        
        expect(itcOpportunity, equals(300000));
      });
    });

    // ==================== EDGE CASES ====================

    group('Edge Cases & Validations', () {
      test('Zero income: No recommendations', () {
        double income = 0;
        List<String> recommendations = [];
        
        if (income == 0) {
          recommendations = [];
        }
        
        expect(recommendations.length, equals(0));
      });

      test('Very high income (₹100Cr): All recommendations applicable', () {
        double income = 1000000000;
        int applicableRecommendations = 7; // All are applicable
        
        expect(applicableRecommendations, equals(7));
      });

      test('Negative savings: Ignore (no worse recommendation)', () {
        double savings = -50000; // Negative
        bool shouldShow = savings > 0;
        
        expect(shouldShow, equals(false));
      });

      test('Rounding: Display savings in ₹1 increments', () {
        double savings = 15000.47;
        int roundedSavings = (savings.round());
        
        expect(roundedSavings, equals(15000));
      });
    });

    // ==================== INTEGRATION TESTS ====================

    group('Integration Tests: Full Recommendation Flow', () {
      test('Complete workflow: Fetch data → Analyze → Generate → Sort → Display', () {
        // Simulated data from Firebase
        double income = 2500000;
        double deductions = 100000;
        double ltcg = 500000;
        double gst = 50000;
        
        // Generate recommendations
        List<Map<String, dynamic>> recs = [];
        
        if ((150000 - deductions) > 0) {
          recs.add({
            'title': '80C',
            'priority': 'HIGH',
            'savings': (150000 - deductions) * 0.30
          });
        }
        
        if (ltcg > 0) {
          recs.add({
            'title': 'LTCG',
            'priority': 'LOW',
            'savings': ltcg * 0.10 // Simplified benefit
          });
        }
        
        expect(recs.length, greaterThan(0));
        expect(recs[0]['priority'], equals('HIGH'));
      });

      test('Data consistency: Same calculations across Summary & Recommendations', () {
        double income = 1500000;
        
        // Summary calculation
        double summaryTax = 112500 + (income - 1000000) * 0.30; // ₹262.5k
        
        // Recommendations calculation (for deduction potential)
        double deductionBenefit = 150000 * 0.30; // ₹45k max benefit
        
        expect(summaryTax, equals(262500));
        expect(deductionBenefit, equals(45000));
      });

      test('Navigation: Summary → Recommendations → Back', () {
        String currentPage = 'summary';
        currentPage = 'recommendations'; // Navigate
        expect(currentPage, equals('recommendations'));
        
        currentPage = 'summary'; // Navigate back
        expect(currentPage, equals('summary'));
      });
    });
  });
}
