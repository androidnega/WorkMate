import 'package:flutter/material.dart';
import 'package:workmate_gh/services/time_tracking_service.dart';
import 'package:workmate_gh/core/theme/app_theme.dart';

class BreakButton extends StatefulWidget {
  final bool isOnBreak;
  final bool isClockedIn;
  final String? currentTimeEntryId;
  final String? currentBreakId;
  final VoidCallback onBreakStateChanged;

  const BreakButton({
    super.key,
    required this.isOnBreak,
    required this.isClockedIn,
    this.currentTimeEntryId,
    this.currentBreakId,
    required this.onBreakStateChanged,
  });

  @override
  State<BreakButton> createState() => _BreakButtonState();
}

class _BreakButtonState extends State<BreakButton> {
  final TimeTrackingService _timeTrackingService = TimeTrackingService();
  bool _isLoading = false;

  Future<void> _toggleBreak() async {
    if (!widget.isClockedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be clocked in to take a break'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (widget.currentTimeEntryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No active time entry found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (widget.isOnBreak) {
        // End break
        if (widget.currentBreakId != null) {
          await _timeTrackingService.endBreak(
            timeEntryId: widget.currentTimeEntryId!,
            breakId: widget.currentBreakId!,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Break ended'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        }
      } else {
        // Start break - show break type dialog
        final result = await _showBreakTypeDialog();
        if (result != null) {
          await _timeTrackingService.startBreak(
            timeEntryId: widget.currentTimeEntryId!,
            isPaidBreak: result['isPaid'] as bool,
            notes: result['notes'] as String?,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${result['isPaid'] ? 'Paid' : 'Unpaid'} break started',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }

      widget.onBreakStateChanged();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<Map<String, dynamic>?> _showBreakTypeDialog() async {
    bool isPaidBreak = false;
    final notesController = TextEditingController();

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder:
          (context) => StatefulBuilder(
            builder:
                (context, setDialogState) => AlertDialog(
                  title: const Text('Start Break'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select break type:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 12),

                      // Break type selection
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.borderLight),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              value: true,
                              groupValue: isPaidBreak,
                              onChanged: (value) {
                                setDialogState(() => isPaidBreak = value!);
                              },
                              title: const Text('Paid Break'),
                              subtitle: const Text(
                                'Lunch break, rest break, etc.',
                              ),
                              dense: true,
                            ),
                            const Divider(height: 1),
                            RadioListTile<bool>(
                              value: false,
                              groupValue: isPaidBreak,
                              onChanged: (value) {
                                setDialogState(() => isPaidBreak = value!);
                              },
                              title: const Text('Unpaid Break'),
                              subtitle: const Text(
                                'Personal time, extended break',
                              ),
                              dense: true,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Optional notes
                      TextField(
                        controller: notesController,
                        decoration: const InputDecoration(
                          labelText: 'Notes (optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'isPaid': isPaidBreak,
                          'notes':
                              notesController.text.trim().isEmpty
                                  ? null
                                  : notesController.text.trim(),
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Start Break'),
                    ),
                  ],
                ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton.icon(
        onPressed: _isLoading || !widget.isClockedIn ? null : _toggleBreak,
        icon:
            _isLoading
                ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
                : Icon(
                  widget.isOnBreak ? Icons.play_arrow : Icons.pause,
                  size: 18,
                ),
        label: Text(
          _isLoading
              ? 'Processing...'
              : widget.isOnBreak
              ? 'End Break'
              : 'Start Break',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              widget.isOnBreak ? Colors.blue.shade500 : Colors.orange.shade500,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: AppTheme.textLight,
        ),
      ),
    );
  }
}
