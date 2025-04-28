import 'package:flutter/material.dart';
import '../models/village_crossing.dart';

class VillageCrossingLog extends StatelessWidget {
  final List<VillageCrossing> crossings;
  final VoidCallback onClose;

  const VillageCrossingLog({
    Key? key,
    required this.crossings,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.location_city, color: Colors.blue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Villages Crossed',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          
          // List of crossings
          if (crossings.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'No villages crossed yet',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: crossings.length,
                itemBuilder: (context, index) {
                  final crossing = crossings[crossings.length - 1 - index]; // Reverse order (newest first)
                  return ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.green,
                      radius: 16,
                      child: Icon(
                        Icons.flag,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    title: Text(
                      crossing.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      'Crossed at ${crossing.formattedTime}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    dense: true,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}