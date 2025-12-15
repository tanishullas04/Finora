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
  
  /// Save capital gains calculation
  Future<void> saveCapitalGains({
    required double buyPrice,
    required double sellPrice,
    required int holdingPeriodMonths,
    required double tax,
    required String type, // 'LTCG' or 'STCG'
  }) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
    // Add to subcollection to maintain history
    await _firestore
        .collection('capitalGains')
        .doc(currentUserId)
        .collection('transactions')
        .add({
      'buyPrice': buyPrice,
      'sellPrice': sellPrice,
      'holdingPeriodMonths': holdingPeriodMonths,
      'gain': sellPrice - buyPrice,
      'tax': tax,
      'type': type,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Get capital gains history
  Future<List<Map<String, dynamic>>> getCapitalGainsHistory() async {
    if (currentUserId == null) return [];
    
    final querySnapshot = await _firestore
        .collection('capitalGains')
        .doc(currentUserId)
        .collection('transactions')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();
    
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return data;
    }).toList();
  }

  // ==================== GST CALCULATIONS COLLECTION ====================
  
  /// Save GST calculation
  Future<void> saveGSTCalculation({
    required double amount,
    required double gstRate,
    required double gstAmount,
    required double finalAmount,
  }) async {
    if (currentUserId == null) throw Exception('User not logged in');
    
    await _firestore
        .collection('gstCalculations')
        .doc(currentUserId)
        .collection('calculations')
        .add({
      'amount': amount,
      'gstRate': gstRate,
      'gstAmount': gstAmount,
      'finalAmount': finalAmount,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ==================== AUTH HELPER ====================
  
  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
