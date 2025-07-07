import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/college.dart';
import '../services/college_service.dart';
import 'college_form_screen.dart';
import '../widgets/expandable_college_tile.dart';
import 'college_detail_screen.dart';
import '../../routes/services/route_service.dart';

class CollegeListScreen extends StatefulWidget {
  const CollegeListScreen({Key? key}) : super(key: key);

  @override
  State<CollegeListScreen> createState() => _CollegeListScreenState();
}

class _CollegeListScreenState extends State<CollegeListScreen> {
  final CollegeService _collegeService = CollegeService();
  List<College> _colleges = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadColleges();
  }

  Future<void> _loadColleges() async {
    setState(() { _loading = true; _error = null; });
    try {
      await _collegeService.loadColleges();
      setState(() { _colleges = _collegeService.colleges; });
    } catch (e) {
      setState(() { _error = 'Failed to load colleges: $e'; });
    } finally {
      setState(() { _loading = false; });
    }
  }

  void _onAddCollege() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CollegeFormScreen()),
    );
    if (result == true) _loadColleges();
  }

  void _onEditCollege(College college) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CollegeFormScreen(college: college)),
    );
    if (result == true) _loadColleges();
  }

  void _onDeleteCollege(College college) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete College'),
        content: Text('Are you sure you want to delete ${college.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _collegeService.deleteCollege(college.id);
        _loadColleges();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete college: $e')),
        );
      }
    }
  }

void _navigateToCollegeDetail(College college) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CollegeDetailScreen(college: college),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Colleges')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : ListView.builder(
                  itemCount: _colleges.length,
                  itemBuilder: (context, index) {
                    final college = _colleges[index];
                    return ExpandableCollegeTile(
                      college: college,
                      onEdit: () => _onEditCollege(college),
                      onDelete: () => _onDeleteCollege(college),
                      onTap: () => _navigateToCollegeDetail(college),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _onAddCollege,
        child: const Icon(Icons.add),
        tooltip: 'Add College',
      ),
    );
  }
} 