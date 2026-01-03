import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  // ==================== USER COLLECTION ====================
  
  /// Create user profile in Firestore
  Future<void> createUserProfile({
    required String userId,
    required String name,
    required String email,
  }) async {
    await _firestore.collection('users').doc(userId).set({
      'name': name,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final doc = await _firestore.collection('users').doc(userId).get();
    return doc.data();
  }

  // ==================== INCOME COLLECTION ====================
  
  /// Save income data
  Future<void> saveIncome({
    required double salary,
    required double otherIncome,
    required double rentalIncome,
    required double businessIncome,
  }) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
    await _firestore.collection('income').doc(currentUserId).set({
      'userId': currentUserId,
      'salary': salary,
      'otherIncome': otherIncome,
      'rentalIncome': rentalIncome,
      'businessIncome': businessIncome,
      'totalIncome': salary + otherIncome + rentalIncome + businessIncome,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true)); // merge: true updates existing data
  }

  /// Get income data
  Future<Map<String, dynamic>?> getIncome() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('income').doc(currentUserId).get();
    return doc.data();
  }

  // ==================== DEDUCTIONS COLLECTION ====================
  
  /// Save deductions data
  Future<void> saveDeductions({
    required double section80c,
    required double section80d,
    required double section80ccd,
    required double section24,
  }) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
    await _firestore.collection('deductions').doc(currentUserId).set({
      'userId': currentUserId,
      'section80c': section80c,
      'section80d': section80d,
      'section80ccd': section80ccd,
      'section24': section24,
      'totalDeductions': section80c + section80d + section80ccd + section24,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get deductions data
  Future<Map<String, dynamic>?> getDeductions() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('deductions').doc(currentUserId).get();
    return doc.data();
  }

  // ==================== TAX DATA COLLECTION ====================
  
  /// Save complete tax calculation
  Future<void> saveTaxData({
    required double totalIncome,
    required double totalDeductions,
    required double taxableIncome,
    required double oldRegimeTax,
    required double newRegimeTax,
    required String recommendedRegime,
  }) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
    await _firestore.collection('taxData').doc(currentUserId).set({
      'userId': currentUserId,
      'totalIncome': totalIncome,
      'totalDeductions': totalDeductions,
      'taxableIncome': taxableIncome,
      'oldRegimeTax': oldRegimeTax,
      'newRegimeTax': newRegimeTax,
      'recommendedRegime': recommendedRegime,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get tax data
  Future<Map<String, dynamic>?> getTaxData() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('taxData').doc(currentUserId).get();
    return doc.data();
  }

  // ==================== CAPITAL GAINS COLLECTION ====================
  
  /// Save capital gains data
  Future<void> saveCapitalGains({
    required double stcgRealEstate,
    required double stcgStocks,
    required double stcgMutualFunds,
    required double stcgOther,
    required double ltcgRealEstate,
    required double ltcgStocks,
    required double ltcgMutualFunds,
    required double ltcgOther,
  }) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
    // Calculate totals
    double totalSTCG = stcgRealEstate + stcgStocks + stcgMutualFunds + stcgOther;
    double totalLTCG = ltcgRealEstate + ltcgStocks + ltcgMutualFunds + ltcgOther;
    
    await _firestore.collection('capitalGains').doc(currentUserId).set({
      'userId': currentUserId,
      'stcgRealEstate': stcgRealEstate,
      'stcgStocks': stcgStocks,
      'stcgMutualFunds': stcgMutualFunds,
      'stcgOther': stcgOther,
      'totalSTCG': totalSTCG,
      'ltcgRealEstate': ltcgRealEstate,
      'ltcgStocks': ltcgStocks,
      'ltcgMutualFunds': ltcgMutualFunds,
      'ltcgOther': ltcgOther,
      'totalLTCG': totalLTCG,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get capital gains data
  Future<Map<String, dynamic>?> getCapitalGains() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('capitalGains').doc(currentUserId).get();
    return doc.data();
  }

  // ==================== GST COLLECTION ====================
  
  /// Save GST data
  Future<void> saveGST({
    required double gst0Quantity,
    required double gst0Price,
    required String gst0HSN,
    required double gst5Quantity,
    required double gst5Price,
    required String gst5HSN,
    required double gst12Quantity,
    required double gst12Price,
    required String gst12HSN,
    required double gst18Quantity,
    required double gst18Price,
    required String gst18HSN,
    required double gst28Quantity,
    required double gst28Price,
    required String gst28HSN,
    required double itcAmount,
  }) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
    final gst0Value = gst0Quantity * gst0Price;
    final gst5Value = gst5Quantity * gst5Price;
    final gst12Value = gst12Quantity * gst12Price;
    final gst18Value = gst18Quantity * gst18Price;
    final gst28Value = gst28Quantity * gst28Price;
    
    final gst5Tax = gst5Value * 0.05;
    final gst12Tax = gst12Value * 0.12;
    final gst18Tax = gst18Value * 0.18;
    final gst28Tax = gst28Value * 0.28;
    
    final totalGSTTax = gst5Tax + gst12Tax + gst18Tax + gst28Tax;
    final gstAfterITC = totalGSTTax - itcAmount;
    
    await _firestore.collection('gstData').doc(currentUserId).set({
      'userId': currentUserId,
      'gst0Quantity': gst0Quantity,
      'gst0Price': gst0Price,
      'gst0HSN': gst0HSN,
      'gst0Value': gst0Value,
      'gst5Quantity': gst5Quantity,
      'gst5Price': gst5Price,
      'gst5HSN': gst5HSN,
      'gst5Value': gst5Value,
      'gst5Tax': gst5Tax,
      'gst12Quantity': gst12Quantity,
      'gst12Price': gst12Price,
      'gst12HSN': gst12HSN,
      'gst12Value': gst12Value,
      'gst12Tax': gst12Tax,
      'gst18Quantity': gst18Quantity,
      'gst18Price': gst18Price,
      'gst18HSN': gst18HSN,
      'gst18Value': gst18Value,
      'gst18Tax': gst18Tax,
      'gst28Quantity': gst28Quantity,
      'gst28Price': gst28Price,
      'gst28HSN': gst28HSN,
      'gst28Value': gst28Value,
      'gst28Tax': gst28Tax,
      'totalGSTValue': gst0Value + gst5Value + gst12Value + gst18Value + gst28Value,
      'totalGSTTax': totalGSTTax,
      'itcAmount': itcAmount,
      'gstAfterITC': gstAfterITC,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Get GST data
  Future<Map<String, dynamic>?> getGST() async {
    if (currentUserId == null) return null;
    
    final doc = await _firestore.collection('gstData').doc(currentUserId).get();
    return doc.data();
  }

  // ==================== AUTH HELPER ====================
  
  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
