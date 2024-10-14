import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class WasteCollectionRequestsScreen extends StatefulWidget {
  const WasteCollectionRequestsScreen({super.key});

  @override
  _WasteCollectionRequestsScreenState createState() => _WasteCollectionRequestsScreenState();
}

class _WasteCollectionRequestsScreenState extends State<WasteCollectionRequestsScreen> {
  bool _showCollected = false;

  // Fetch waste collection requests
  Stream<QuerySnapshot> _fetchRequests() {
    return FirebaseFirestore.instance
        .collection('wasteCollectionRequests')
        .where('isCollected', isEqualTo: _showCollected)
        .snapshots();
  }

  // Fetch user details by userId
  Future<Map<String, dynamic>?> _fetchUserDetails(String userId) async {
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (userDoc.exists) {
      return userDoc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  // Fetch bin details by binId
  Future<Map<String, dynamic>?> _fetchBinDetails(String binId) async {
    DocumentSnapshot binDoc = await FirebaseFirestore.instance.collection('bins').doc(binId).get();
    if (binDoc.exists) {
      return binDoc.data() as Map<String, dynamic>?;
    }
    return null;
  }

  // Method to mark a request as collected
  Future<void> _markAsCollected(String requestId, String binId) async {
    try {
      // Update waste collection request to mark as collected
      await FirebaseFirestore.instance.collection('wasteCollectionRequests').doc(requestId).update({
        'isCollected': true,
      });

      // Update the bin: set collectionRequestSent to false and filledPercentage to 0
      await FirebaseFirestore.instance.collection('bins').doc(binId).update({
        'collectionRequestSent': false,
        'filledPercentage': 0,
      });

      // Show a snackbar confirming the update
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked as collected.')),
      );
    } catch (e) {
      print('Error marking as collected: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to mark as collected.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Waste Collection Requests'),
        actions: [
          IconButton(
            icon: Icon(_showCollected ? Icons.unarchive : Icons.archive),
            onPressed: () {
              setState(() {
                _showCollected = !_showCollected;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _fetchRequests(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final requests = snapshot.data!.docs;

          if (requests.isEmpty) {
            return Center(child: Text(_showCollected ? 'No collected requests.' : 'No pending requests.'));
          }

          return ListView.builder(
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final requestData = requests[index].data() as Map<String, dynamic>;
              final requestId = requests[index].id;
              final binId = requestData['binId'];
              final userId = requestData['userId'];
              final requestedTime = requestData['requestedTime']?.toDate() ?? DateTime.now();

              return FutureBuilder<Map<String, dynamic>?>(
                future: Future.wait([
                  _fetchUserDetails(userId), // Fetch user details
                  _fetchBinDetails(binId)    // Fetch bin details
                ]).then((responses) => {
                      'user': responses[0],
                      'bin': responses[1],
                    }),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return ListTile(title: Text('Loading...'));
                  }

                  final userData = snapshot.data!['user'] as Map<String, dynamic>?;
                  final binData = snapshot.data!['bin'] as Map<String, dynamic>?;

                  if (userData == null || binData == null) {
                    return ListTile(title: Text('Error loading user or bin data.'));
                  }

                  final userName = userData['name'] ?? 'Unknown Name';
                  final userEmail = userData['email'] ?? 'Unknown Email';
                  final binType = binData['type'] ?? 'Unknown Type';
                  final binWeight = binData['weight']?.toString() ?? 'Unknown Weight';

                  return Card(
                    margin: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: ListTile(
                      title: Text('User: $userName\nEmail: $userEmail'),
                      subtitle: Text('Bin Type: $binType\nWeight: $binWeight\nRequested on: ${requestedTime.toString()}'),
                      trailing: !_showCollected
                          ? ElevatedButton(
                              onPressed: () => _markAsCollected(requestId, binId),
                              child: Text('Mark as Collected'),
                            )
                          : null,
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
