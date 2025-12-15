# Sample Tax Calculations – Finora RAG Dataset

This file provides simple, common tax calculation examples that your RAG model can use to answer user queries.

---

## 1. New Regime — Salary Example (FY 2025–26)

**Gross Salary:** ₹10,50,000  
**Standard Deduction:** ₹75,000  
**Taxable Income:** ₹9,75,000

**Slab-Wise Tax:**
- 0–4,00,000 → 0  
- 4–8,00,000 → 5% = ₹20,000  
- 8–9.75 lakh → 10% = ₹17,500  

**Total Tax:** ₹37,500  
**Rebate (income < ₹12L):** ₹37,500  
**Final Tax:** **₹0**

---

## 2. Old Regime — Salary Example

**Gross Salary:** ₹10,50,000  
**Deductions:**  
- 80C: ₹1,50,000  
- 80D: ₹25,000  
- HRA/others: ₹50,000  

**Total Deductions:** ₹2,25,000  
**Taxable Income:** ₹8,25,000  

**Final Tax:** **₹77,500**

---

## 3. Short-Term Capital Gain (STCG)

**Equity STCG (111A)**  
Profit: ₹40,000  
Tax @15% = **₹6,000**

---

## 4. Long-Term Capital Gain (LTCG)

**Equity LTCG (112A)**  
Profit: ₹1,50,000  
Exemption: ₹1,00,000  
Taxable = ₹50,000  
Tax @10% = **₹5,000**

---

## 5. GST Calculation Example

**Base Price:** ₹10,000  
**GST @18%:** ₹1,800  
**Final Price:** **₹11,800**

---

## 6. Presumptive Taxation Example (44AD)

**Business Turnover:** ₹40,00,000  
**Presumptive Profit @8%:** ₹3,20,000  
Tax computed on ₹3,20,000 as per chosen regime.

