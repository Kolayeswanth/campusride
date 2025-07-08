import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';

class DriverRequestsManagementScreen extends StatefulWidget {
  const DriverRequestsManagementScreen({Key? key}) : super(key: key);

  @override
  State<DriverRequestsManagementScreen> createState() => _DriverRequestsManagementScreenState();
}

class _DriverRequestsManagementScreenState extends State<DriverRequestsManagementScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final requests = await authService.getAllDriverRequests();
      
      setState(() {
        _requests = requests;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading requests: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleRequest(String requestId, String action) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.handleDriverRequest(requestId, action);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Driver request $action successfully!'),
            backgroundColor: action == 'approved' ? Colors.green : Colors.orange,
          ),
        );
        _loadRequests(); // Reload to update the list
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ${action.replaceAll('ed', 'ing')} request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver Requests'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRequests,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 64,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No driver requests found',
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Driver applications will appear here',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _requests.length,
                  itemBuilder: (context, index) {
                    final request = _requests[index];
                    return _DriverRequestCard(
                      request: request,
                      onApprove: () => _handleRequest(request['id'], 'approved'),
                      onReject: () => _handleRequest(request['id'], 'rejected'),
                    );
                  },
                ),
    );
  }
}

class _DriverRequestCard extends StatelessWidget {
  final Map<String, dynamic> request;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _DriverRequestCard({
    required this.request,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final status = request['status'] as String;
    final isActionsEnabled = status == 'pending';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with applicant info and status
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  child: Text(
                    (request['profiles']?['full_name'] ?? 'U')[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['profiles']?['full_name'] ?? 'Unknown User',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        request['profiles']?['email'] ?? '',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 16),

            // Driver information
            _InfoSection(
              title: 'License Information',
              children: [
                _InfoRow(
                  icon: Icons.credit_card,
                  label: 'License Number',
                  value: request['license_number'] ?? 'N/A',
                ),
                _InfoRow(
                  icon: Icons.timer,
                  label: 'Driving Experience',
                  value: '${request['driving_experience_years'] ?? 0} years',
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Vehicle information
            // Request date
            Text(
              'Submitted: ${_formatDate(request['created_at'])}',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            // Action buttons for pending requests
            if (isActionsEnabled) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: CustomButton.outlined(
                      text: 'Reject',
                      onPressed: onReject,
                      prefixIcon: Icons.close,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CustomButton.primary(
                      text: 'Approve',
                      onPressed: onApprove,
                      prefixIcon: Icons.check,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic dateString) {
    if (dateString == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateString.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'approved':
        backgroundColor = Colors.green.shade100;
        textColor = Colors.green.shade700;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        backgroundColor = Colors.red.shade100;
        textColor = Colors.red.shade700;
        icon = Icons.cancel;
        break;
      case 'pending':
      default:
        backgroundColor = Colors.orange.shade100;
        textColor = Colors.orange.shade700;
        icon = Icons.pending;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.labelMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        ...children,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodySmall.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
