import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/models.dart';

/// Web client ID (OAuth 2.0) for Google Sign-In so Firebase Auth can verify the id token.
/// From Firebase Console → Authentication → Sign-in method → Google → Web SDK config.
const String _kGoogleSignInWebClientId =
    '50353404265-2aa9g24u220u5i5pmbt64gjtj4sq13na.apps.googleusercontent.com';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: _kGoogleSignInWebClientId,
  );

  // ============ AUTH ============

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email & Password Sign Up
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return credential;
  }

  // Email & Password Sign In
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    // Clear any cached sign-in so we get a fresh token (avoids stale-state failures).
    await _googleSignIn.signOut();
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;

    // Firebase Auth requires idToken when using GoogleAuthProvider.credential.
    // serverClientId on GoogleSignIn ensures idToken is present.
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;
    if (idToken == null) {
      throw Exception(
        'Google Sign-In could not get an ID token. '
        'Ensure the Web client ID is set and Google Sign-In is enabled in Firebase Console.',
      );
    }

    final credential = GoogleAuthProvider.credential(
      accessToken: accessToken,
      idToken: idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // Sign Out
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  // Password Reset
  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }






  // ============ USER PROFILE ============

  // Create or update user profile in Firestore
  Future<void> saveUserProfile({
    required String uid,
    required String name,
    required String email,
    String? nickname,
    String? householdId,
    String role = 'Member',
    String avatar = '👤',
    bool? isAdmin,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'nickname': nickname,
      'email': email,
      'householdId': householdId,
      'role': role,
      'avatar': avatar,
      'createdAt': FieldValue.serverTimestamp(),
    };
    if (isAdmin != null) {
      data['isAdmin'] = isAdmin;
    }
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  // Get user profile
  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // ============ HOUSEHOLD ============

  // Create new household
  Future<String> createHousehold({
    required String name,
    required String ownerId,
    required double monthlyIncome,
  }) async {
    final docRef = await _db.collection('households').add({
      'name': name,
      'ownerId': ownerId,
      'members': [ownerId],
      'monthlyIncome': monthlyIncome,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Get household data
  Future<Map<String, dynamic>?> getHousehold(String householdId) async {
    final doc = await _db.collection('households').doc(householdId).get();
    return doc.data();
  }

  // Update household
  Future<void> updateHousehold(
      String householdId, Map<String, dynamic> data) async {
    await _db.collection('households').doc(householdId).update(data);
  }

  // Join household by invite code (householdId)
  Future<bool> joinHousehold({
    required String householdId,
    required String userId,
  }) async {
    final doc = await _db.collection('households').doc(householdId).get();
    if (!doc.exists) return false;

    await _db.collection('households').doc(householdId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
    return true;
  }

  // Remove member from household
  Future<void> removeMemberFromHousehold({
    required String householdId,
    required String userId,
  }) async {
    await _db.collection('households').doc(householdId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
    // Clear the user's householdId so they're no longer linked
    await _db.collection('users').doc(userId).update({
      'householdId': FieldValue.delete(),
      'role': 'Member',
    });
  }

  // ============ GENERIC FIRESTORE CRUD ============

  // Get collection path for household subcollection
  String _collectionPath(String householdId, String collection) =>
      'households/$householdId/$collection';

  // Add document
  Future<String> addDocument({
    required String householdId,
    required String collection,
    required Map<String, dynamic> data,
  }) async {
    final Map<String, dynamic> docData = Map.from(data)..remove('id');
    final docRef = await _db
        .collection(_collectionPath(householdId, collection))
        .add({...docData, 'createdAt': FieldValue.serverTimestamp()});
    return docRef.id;
  }

  // Update document
  Future<void> updateDocument({
    required String householdId,
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    await _db
        .collection(_collectionPath(householdId, collection))
        .doc(docId)
        .update(data);
  }

  // Delete document
  Future<void> deleteDocument({
    required String householdId,
    required String collection,
    required String docId,
  }) async {
    await _db
        .collection(_collectionPath(householdId, collection))
        .doc(docId)
        .delete();
  }

  // Get all documents in collection (one-time)
  Future<List<Map<String, dynamic>>> getDocuments({
    required String householdId,
    required String collection,
  }) async {
    final snapshot = await _db
        .collection(_collectionPath(householdId, collection))
        .get();
    return snapshot.docs
        .map((doc) => {...doc.data(), 'id': doc.id})
        .toList();
  }

  // Stream documents (real-time updates)
  Stream<List<Map<String, dynamic>>> streamDocuments({
    required String householdId,
    required String collection,
  }) {
    return _db
        .collection(_collectionPath(householdId, collection))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {...doc.data(), 'id': doc.id})
            .toList());
  }

  // ============ TYPED HELPER METHODS ============

  // Maintenance Tasks
  Future<void> saveMaintenanceTask(
      String householdId, MaintenanceTask task) async {
    final data = task.toJson();
    if (task.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'maintenanceTasks',
        data: data,
      );
      task.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'maintenanceTasks',
        docId: task.id,
        data: data,
      );
    }
  }

  Future<List<MaintenanceTask>> getMaintenanceTasks(
      String householdId) async {
    final docs = await getDocuments(
      householdId: householdId,
      collection: 'maintenanceTasks',
    );
    return docs.map((d) => MaintenanceTask.fromJson(d)).toList();
  }

  Stream<List<MaintenanceTask>> streamMaintenanceTasks(
      String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'maintenanceTasks',
    ).map((docs) => docs.map((d) => MaintenanceTask.fromJson(d)).toList());
  }

  // Household Tasks
  Future<void> saveHouseholdTask(
      String householdId, HouseholdTask task) async {
    final data = task.toJson();
    if (task.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'householdTasks',
        data: data,
      );
      task.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'householdTasks',
        docId: task.id,
        data: data,
      );
    }
  }

  Stream<List<HouseholdTask>> streamHouseholdTasks(String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'householdTasks',
    ).map((docs) => docs.map((d) => HouseholdTask.fromJson(d)).toList());
  }

  // Grocery Items
  Future<void> saveGroceryItem(
      String householdId, GroceryItem item) async {
    final data = item.toJson();
    if (item.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'groceryItems',
        data: data,
      );
      item.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'groceryItems',
        docId: item.id,
        data: data,
      );
    }
  }

  Stream<List<GroceryItem>> streamGroceryItems(String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'groceryItems',
    ).map((docs) => docs.map((d) => GroceryItem.fromJson(d)).toList());
  }

  // Expenses
  Future<void> saveExpense(String householdId, Expense expense) async {
    final data = expense.toJson();
    if (expense.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'expenses',
        data: data,
      );
      expense.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'expenses',
        docId: expense.id,
        data: data,
      );
    }
  }

  Stream<List<Expense>> streamExpenses(String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'expenses',
    ).map((docs) => docs.map((d) => Expense.fromJson(d)).toList());
  }

  // Debts
  Future<void> saveDebt(String householdId, Debt debt) async {
    final data = debt.toJson();
    if (debt.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'debts',
        data: data,
      );
      debt.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'debts',
        docId: debt.id,
        data: data,
      );
    }
  }

  Stream<List<Debt>> streamDebts(String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'debts',
    ).map((docs) => docs.map((d) => Debt.fromJson(d)).toList());
  }

  // Savings Goals
  Future<void> saveSavingsGoal(
      String householdId, SavingsGoal goal) async {
    final data = goal.toJson();
    if (goal.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'savingsGoals',
        data: data,
      );
      goal.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'savingsGoals',
        docId: goal.id,
        data: data,
      );
    }
  }

  Stream<List<SavingsGoal>> streamSavingsGoals(String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'savingsGoals',
    ).map((docs) => docs.map((d) => SavingsGoal.fromJson(d)).toList());
  }

  // Utility Bills
  Future<void> saveUtilityBill(
      String householdId, UtilityBill bill) async {
    final data = bill.toJson();
    if (bill.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'utilityBills',
        data: data,
      );
      bill.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'utilityBills',
        docId: bill.id,
        data: data,
      );
    }
  }

  Stream<List<UtilityBill>> streamUtilityBills(String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'utilityBills',
    ).map((docs) => docs.map((d) => UtilityBill.fromJson(d)).toList());
  }

  // Family Members (stored in household doc + users collection)
  Future<List<FamilyMember>> getFamilyMembers(String householdId) async {
    final household = await getHousehold(householdId);
    if (household == null) return [];

    final memberIds = List<String>.from(household['members'] ?? []);
    final ownerId = household['ownerId'] as String?;
    List<FamilyMember> members = [];

    for (var uid in memberIds) {
      final profile = await getUserProfile(uid);
      if (profile != null) {
        // The household owner is always admin
        final profileIsAdmin = (profile['isAdmin'] == true) || (uid == ownerId);
        members.add(FamilyMember(
          id: uid,
          name: profile['name'] ?? 'Unknown',
          email: profile['email'] ?? '',
          role: profile['role'] ?? 'Member',
          avatar: profile['avatar'] ?? '👤',
          isAdmin: profileIsAdmin,
        ));
      }
    }
    return members;
  }

  // Emergency Contacts
  Future<void> saveEmergencyContact(
      String householdId, EmergencyContact contact) async {
    final data = contact.toJson();
    if (contact.id.isEmpty) {
      final id = await addDocument(
        householdId: householdId,
        collection: 'emergencyContacts',
        data: data,
      );
      contact.id = id;
    } else {
      await updateDocument(
        householdId: householdId,
        collection: 'emergencyContacts',
        docId: contact.id,
        data: data,
      );
    }
  }

  Stream<List<EmergencyContact>> streamEmergencyContacts(
      String householdId) {
    return streamDocuments(
      householdId: householdId,
      collection: 'emergencyContacts',
    ).map((docs) => docs.map((d) => EmergencyContact.fromJson(d)).toList());
  }

  // Chat Messages
  Future<void> saveChatMessage(
      String householdId, ChatMessage msg) async {
    await addDocument(
      householdId: householdId,
      collection: 'chatMessages',
      data: msg.toJson(),
    );
  }

  Stream<List<ChatMessage>> streamChatMessages(String householdId) {
    return _db
        .collection(_collectionPath(householdId, 'chatMessages'))
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
            final msgs = snapshot.docs
                .map((doc) => ChatMessage.fromJson({
                      'id': doc.id,
                      ...doc.data(),
                    }))
                .toList();
            // Reverse so oldest is first (chronological order)
            return msgs.reversed.toList();
        });
  }

  /// Deletes all AI chat messages for the given household.
  Future<void> clearChatMessages(String householdId) async {
    final path = _collectionPath(householdId, 'chatMessages');
    final snapshot = await _db.collection(path).get();
    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  // Family Chat Messages
  Future<void> saveFamilyChatMessage(
      String householdId, FamilyChatMessage msg) async {
    await addDocument(
      householdId: householdId,
      collection: 'familyChatMessages',
      data: msg.toJson(),
    );
  }

  Stream<List<FamilyChatMessage>> streamFamilyChatMessages(String householdId) {
    return _db
        .collection(_collectionPath(householdId, 'familyChatMessages'))
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => FamilyChatMessage.fromJson({
                  'id': doc.id,
                  ...doc.data(),
                }))
            .toList());
  }
}
