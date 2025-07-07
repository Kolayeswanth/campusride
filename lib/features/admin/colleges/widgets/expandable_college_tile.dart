import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/college.dart';
import '../../drivers/services/driver_service.dart';
import '../../routes/services/route_service.dart';
import '../../drivers/screens/driver_form_screen.dart';

class ExpandableCollegeTile extends StatelessWidget {
  final College college;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const ExpandableCollegeTile({
    Key? key,
    required this.college,
    required this.onEdit,
    required this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ListTile(
        title: Text(college.name),
        subtitle: Text(college.address),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: onEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
            ),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
} 