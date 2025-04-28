import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/bus_info.dart';

class BusService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'buses';

  Stream<List<BusInfo>> getActiveBuses() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => BusInfo.fromFirestore(doc))
          .toList();
    });
  }

  Future<BusInfo?> getBusById(String busId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(busId).get();
      if (doc.exists) {
        return BusInfo.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting bus: $e');
      return null;
    }
  }
} 