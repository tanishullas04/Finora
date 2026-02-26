import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UnderstandingTaxScreen extends StatefulWidget {
  const UnderstandingTaxScreen({super.key});

  @override
  State<UnderstandingTaxScreen> createState() => _UnderstandingTaxScreenState();
}

class _UnderstandingTaxScreenState extends State<UnderstandingTaxScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String? _selectedLetter;

  final List<String> _alphabet =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZ".split("");

  // combined list of searchable terms
  final List<SimpleTerm> _allTerms = const [
    // income basics
    SimpleTerm(title: "Income Tax", description: "Tax paid on the income you earn from salary, business, rent, or investments."),
    SimpleTerm(title: "Financial Year (FY)", description: "The year in which you earn income. In India, it runs from April 1 to March 31."),
    SimpleTerm(title: "Assessment Year (AY)", description: "The year in which you file tax for the income earned in the previous financial year."),
    SimpleTerm(title: "PAN", description: "Permanent Account Number used to track your financial transactions for tax purposes."),
    SimpleTerm(title: "ITR", description: "Income Tax Return form used to declare your income and pay taxes."),
    // salary/payment
    SimpleTerm(title: "Gross Income", description: "Total income before any deductions or taxes are applied."),
    SimpleTerm(title: "Gross Salary", description: "Total salary earned before any deductions like tax, PF, or professional tax are applied."),
    SimpleTerm(title: "Net Income", description: "Income remaining after taxes and deductions are subtracted."),
    SimpleTerm(title: "Taxable Salary", description: "Portion of your salary on which tax is calculated after exemptions and deductions."),
    SimpleTerm(title: "TDS", description: "Tax Deducted at Source. Tax deducted before you receive your income."),
    SimpleTerm(title: "Form 16", description: "Certificate provided by employer showing salary paid and TDS deducted."),
    // deductions
    SimpleTerm(title: "Deduction", description: "Amount subtracted from your income before calculating tax."),
    SimpleTerm(title: "Section 80C", description: "Allows tax deduction for investments like PF, LIC, ELSS (up to ₹1.5 lakh)."),
    SimpleTerm(title: "Section 80D", description: "Deduction for health insurance premiums paid."),
    SimpleTerm(title: "Rebate", description: "Reduction in tax payable, usually under Section 87A for eligible individuals."),
    // capital gains
    SimpleTerm(title: "Capital Gains", description: "Profit earned from selling assets like shares, property, or gold."),
    SimpleTerm(title: "Purchase Price", description: "The price at which an asset (like shares or property) was originally bought."),
    SimpleTerm(title: "Selling Price", description: "The price at which an asset is sold."),
    SimpleTerm(title: "STCG", description: "Short-Term Capital Gain. Profit from assets sold within a short period."),
    SimpleTerm(title: "LTCG", description: "Long-Term Capital Gain. Profit from assets held for a longer duration."),
    SimpleTerm(title: "Dividend", description: "Income received from shares of a company."),
    SimpleTerm(title: "STT", description: "Securities Transaction Tax. Tax charged on buying or selling listed securities like shares on stock exchanges."),
    // gst
    SimpleTerm(title: "GST", description: "Goods and Services Tax charged on goods and services in India."),
    SimpleTerm(title: "CGST / SGST / IGST", description: "Different components of GST depending on whether the transaction is within a state or between states."),
    SimpleTerm(title: "IGST", description: "Integrated Goods and Services Tax charged on interstate supply of goods and services in India."),
    SimpleTerm(title: "Input Tax Credit", description: "Credit businesses can claim for GST paid on purchases."),
    // glossary
    SimpleTerm(title: "Advance Tax", description: "Tax paid in installments during the financial year."),
    SimpleTerm(title: "Rental Income", description: "Income earned from renting out property such as a house, apartment, or commercial space."),
    SimpleTerm(title: "Business Income", description: "Income earned from running a business or profession after deducting business expenses."),
    SimpleTerm(title: "Refund", description: "Excess tax returned by government."),
    // additional glossary terms
    SimpleTerm(title: "Surcharge", description: "Additional tax charged on high-income individuals over and above normal tax."),
    SimpleTerm(title: "Cess", description: "Extra tax collected for specific purposes like education or health."),
    SimpleTerm(title: "Tax Slab", description: "Income range taxed at a specific rate."),
    SimpleTerm(title: "Exemption", description: "Income that is not taxable under certain conditions."),
    SimpleTerm(title: "Standard Deduction", description: "Flat deduction allowed from salary income."),
    SimpleTerm(title: "Advance Ruling", description: "Official clarification on tax applicability for a transaction."),
    SimpleTerm(title: "Self-Assessment Tax", description: "Tax paid by an individual after calculating total liability."),
    SimpleTerm(title: "Taxable Income", description: "Income remaining after deductions and exemptions."),
    SimpleTerm(title: "Perquisite", description: "Extra benefits provided by employer in addition to salary."),
    SimpleTerm(title: "HRA", description: "House Rent Allowance provided by employer for rental accommodation."),
    SimpleTerm(title: "EPF", description: "Employees' Provident Fund – retirement savings scheme."),
    SimpleTerm(title: "ELSS", description: "Equity Linked Savings Scheme eligible for 80C deduction."),
    SimpleTerm(title: "Audit", description: "Review of financial records to ensure tax compliance."),
    SimpleTerm(title: "Due Date", description: "Last date to file tax return without penalty."),
    SimpleTerm(title: "Late Fee", description: "Penalty charged for filing return after due date."),
    SimpleTerm(title: "Notice", description: "Official communication from tax department."),
    SimpleTerm(title: "Capital Asset", description: "Property, shares, gold, or investments held by a person."),
    SimpleTerm(title: "Turnover", description: "Total sales or receipts of a business."),
    SimpleTerm(title: "Professional Tax", description: "State-level tax on salaried and self-employed individuals."),
    SimpleTerm(title: "Input Service Distributor", description: "Entity that distributes input tax credit within a company."),
  ];

  List<SimpleTerm> get _filteredTerms {
    List<SimpleTerm> list;

    if (_query.isNotEmpty) {
      list = _allTerms.where((t) =>
          t.title.toLowerCase().contains(_query.toLowerCase()) ||
          t.description.toLowerCase().contains(_query.toLowerCase())
      ).toList();
    } else if (_selectedLetter != null) {
      list = _allTerms.where((t) =>
          t.title.toUpperCase().startsWith(_selectedLetter!)
      ).toList();
    } else {
      list = List.from(_allTerms);
    }

    list.sort((a, b) => a.title.compareTo(b.title));
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Understanding Tax Terms",
          style: TextStyle(
            color: AppColors.widgetBackground,
            fontSize: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search terms...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (val) => setState(() {
                  _query = val;
                }),
              ),
            ),
            // alphabet selector when not searching
            if (_query.isEmpty)
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _alphabet.length + 1,
                  itemBuilder: (context, index) {
                    // "All" button
                    if (index == 0) {
                      final isSelected = _selectedLetter == null;
                      return _buildLetterChip("All", isSelected, null);
                    }

                    final letter = _alphabet[index - 1];
                    final isSelected = _selectedLetter == letter;

                    return _buildLetterChip(letter, isSelected, letter);
                  },
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: _buildContent(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent() {
    if (_query.isNotEmpty) {
      if (_filteredTerms.isEmpty) {
        return [
          const Center(
            child: Padding(
              padding: EdgeInsets.only(top: 40),
              child: Text(
                "No matching terms found.",
                style: TextStyle(fontSize: 16),
              ),
            ),
          )
        ];
      }
      return _filteredTerms
          .map((t) => _buildHighlightedTile(t))
          .toList();
    }

    // original static structure when no query
    // glossary replaced by dynamic filtered list
    return _filteredTerms.map((t) => ListTile(
      title: Text(
        t.title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(t.description),
    )).toList();
  }

  Widget _buildLetterChip(String label, bool isSelected, String? letter) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w600,
        ),
        onSelected: (_) {
          setState(() {
            _selectedLetter = letter;
          });
        },
      ),
    );
  }

  Widget _buildHighlightedTile(SimpleTerm term) {
    final query = _query.toLowerCase();

    TextSpan highlightText(String source) {
      if (query.isEmpty) {
        return TextSpan(text: source);
      }

      final matches = RegExp(query, caseSensitive: false);
      final spans = <TextSpan>[];
      int start = 0;

      for (final match in matches.allMatches(source)) {
        if (match.start > start) {
          spans.add(TextSpan(text: source.substring(start, match.start)));
        }

        spans.add(
          TextSpan(
            text: source.substring(match.start, match.end),
            style: const TextStyle(
              backgroundColor: Colors.yellow,
              fontWeight: FontWeight.bold,
            ),
          ),
        );

        start = match.end;
      }

      if (start < source.length) {
        spans.add(TextSpan(text: source.substring(start)));
      }

      return TextSpan(children: spans);
    }

    return ListTile(
      title: RichText(
        text: TextSpan(
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          children: [highlightText(term.title)],
        ),
      ),
      subtitle: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.black87),
          children: [highlightText(term.description)],
        ),
      ),
    );
  }
}

class TaxSection extends StatelessWidget {
  final String title;
  final List<TaxTerm> terms;

  const TaxSection({
    super.key,
    required this.title,
    required this.terms,
  });

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      children: terms,
    );
  }
}

class TaxTerm extends StatelessWidget {
  final String title;
  final String description;

  const TaxTerm({
    super.key,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(description),
    );
  }
}

class GlossaryItem extends StatelessWidget {
  final String title;
  final String definition;

  const GlossaryItem({
    super.key,
    required this.title,
    required this.definition,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.book, color: AppColors.primary),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(definition),
    );
  }
}

class SimpleTerm {
  final String title;
  final String description;
  const SimpleTerm({required this.title, required this.description});
}
