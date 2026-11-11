import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../navigation/househeld_navigation.dart';
import '../services/account_service.dart';
import '../services/household_service.dart';
import '../theme/app_theme.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../widgets/member_card.dart';
import '../widgets/account_dialogs.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.householdID});

  final String householdID;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final HouseholdService _householdService = HouseholdService();
  final AccountService _accountService = AccountService();

  late final Stream<Household?> _householdStream;
  late final Stream<List<HouseholdMember>> _membersStream;
  late final Stream<UserProfile?> _profileStream;

  bool _busy = false;

  String? get _currentUserID => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();

    _householdStream = _householdService.watchHousehold(widget.householdID);

    _membersStream = _householdService.watchMembers(widget.householdID);

    _profileStream = _accountService.watchCurrentProfile();

    _accountService.syncVerifiedEmail().catchError((Object error) {
      debugPrint('Email synchronization failed: $error');
    });
  }

  // Method to handle navigation:
  void _handleNav(int index) {
    if (_busy) return;

    HouseheldNavigation.navigate(
      context: context,
      householdID: widget.householdID,
      currentIndex: 5,
      destinationIndex: index,
    );
  }

  // Method to display messages:
  void _message(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // Error handling method:
  String _errorMessage(Object error) {
    if (error is StateError) {
      return error.message.toString();
    }

    if (error is ArgumentError) {
      return error.message?.toString() ?? 'Invalid information.';
    }

    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return 'You do not have permission to perform this action.';
      }

      return error.message ?? 'A database error occurred. Please try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  // Reusable method to execute actions:
  Future<bool> _runAction(
    Future<void> Function() action, {
    String? successMessage,
    bool returnHome = false,
  }) async {
    if (_busy) return false;

    setState(() {
      _busy = true;
    });

    try {
      await action();

      if (!mounted) return true;

      if (returnHome) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      } else if (successMessage != null) {
        _message(successMessage);
      }

      return true;
    } catch (error) {
      _message(_errorMessage(error));
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  // Reusable confirmation dialog method:
  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    bool destructive = false,
  }) async {
    if (!mounted) return false;

    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: Text(title),
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: destructive
                      ? FilledButton.styleFrom(backgroundColor: AppColors.clay)
                      : null,
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(confirmLabel),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  // Get member name:
  String _memberName(String userID, List<HouseholdMember> members) {
    for (final member in members) {
      if (member.userID == userID) {
        return member.displayName.isEmpty ? member.userID : member.displayName;
      }
    }

    return userID.isEmpty ? 'Not set' : userID;
  }

  // Widget for the household info card:
  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 3),
          SelectableText(
            value.trim().isEmpty ? 'Not set' : value,
            style: AppText.body,
          ),
        ],
      ),
    );
  }

  // Method for the rename household pop-up:
  Future<void> _renameHousehold(Household household) async {
    if (_busy) return;

    String newName = household.householdName;

    final submittedName = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename Household'),
          content: TextFormField(
            initialValue: household.householdName,
            autofocus: true,
            maxLength: 100,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Household Name',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              newName = value;
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, newName.trim());
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || submittedName == null) return;

    if (submittedName == household.householdName) return;

    await _runAction(
      () => _householdService.renameHousehold(
        householdID: widget.householdID,
        newName: submittedName,
      ),
      successMessage: 'Household name updated!',
    );
  }

  // Method for viewing member details (from options sub-menu):
  Future<void> _viewMember(HouseholdMember member) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Member Details'),
          content: FutureBuilder<UserProfile?>(
            future: _accountService.getMemberProfile(member.userID),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Unable to load member details.');
              }

              if (!snapshot.hasData) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 60,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                return const Text('Member profile not found.');
              }

              final profile = snapshot.data!;

              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow('Display Name', member.displayName),
                    _infoRow('Role', memberRoleLabel(member.memberRole)),
                    _infoRow('Username', profile.username),
                    _infoRow('Email', profile.email),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Method for the changing a member's role dialog (Managers only):
  Future<void> _changeRole(HouseholdMember member) async {
    if (_busy) return;

    String selectedRole = member.memberRole;

    final newRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Change Role — ${member.displayName}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current role: '
                    '${memberRoleLabel(member.memberRole)}',
                    style: AppText.bodySoft,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'manager',
                        child: Text('Manager'),
                      ),
                      DropdownMenuItem(value: 'member', child: Text('Member')),
                      DropdownMenuItem(value: 'child', child: Text('Child')),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          selectedRole = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, selectedRole),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || newRole == null || newRole == member.memberRole) {
      return;
    }

    // Additional error handling because sometimes it showed the wrong one:
    if (member.memberRole == 'manager' && newRole != 'manager') {
      try {
        final household = await _householdService.getHousehold(
          widget.householdID,
        );

        if (!mounted) return;

        if (household?.managerCount == 1) {
          _message(
            'A household must have at least one Manager! '
            'Please assign another Manager first.',
          );
          return;
        }
      } catch (_) {}
    }

    final confirmed = await _confirm(
      title: 'Confirm Role Change',
      message:
          'Change ${member.displayName} from '
          '${memberRoleLabel(member.memberRole)} to '
          '${memberRoleLabel(newRole)}?',
      confirmLabel: 'Change Role',
    );

    if (!mounted || !confirmed) return;

    final success = await _runAction(
      () => _householdService.changeMemberRole(
        householdID: widget.householdID,
        memberID: member.userID,
        newRole: newRole,
      ),
      successMessage: 'Member role updated!',
    );

    if (success &&
        mounted &&
        member.userID == _currentUserID &&
        newRole != 'manager') {
      // The current user no longer has Manager permissions.
      // The streams should update the UI automatically.
    }
  }

  // Method for the removing a member dialog (Managers only):
  Future<void> _removeMember(HouseholdMember member) async {
    if (_busy) return;

    final confirmed = await _confirm(
      title: 'Remove Household Member?',
      message:
          'Are you sure you want to remove ${member.displayName} '
          'from this household?\n\n'
          'Their account will remain active, but they '
          'will lose access to this household!',
      confirmLabel: 'Remove Member',
      destructive: true,
    );

    if (!mounted || !confirmed) return;

    await _runAction(
      () => _householdService.removeMember(
        householdID: widget.householdID,
        memberID: member.userID,
      ),
      successMessage: 'Member removed from household.',
    );
  }

  // Method for the leaving a household dialog:
  Future<void> _leaveHousehold() async {
    if (_busy) return;

    final confirmed = await _confirm(
      title: 'Leave Household?',
      message:
          'You will lose access to this household and '
          'and may need to join or create a new one.\n\n'
          'Your account will not be deleted.',
      confirmLabel: 'Leave Household',
      destructive: true,
    );

    if (!mounted || !confirmed) return;

    await _runAction(
      () => _householdService.leaveHousehold(householdID: widget.householdID),
      returnHome: true,
    );
  }

  // Method for the deleting household dialog:
  Future<void> _deleteHousehold(Household household) async {
    if (_busy) return;

    final confirmed = await _confirm(
      title: 'Delete Household?',
      message:
          'This will permanently delete "${household.householdName}" '
          'and its household data, including Grocery Lists, '
          'Pantry Items, Stuff, Tasks, and member records.\n\n'
          'All members will lose access to the household, '
          'but their accounts will not be deleted.\n\n'
          'This action cannot be undone!',
      confirmLabel: 'Continue',
      destructive: true,
    );

    if (!mounted || !confirmed) return;

    String confirmationText = '';

    final typedConfirmation = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Final Confirmation'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Type the exact household name '
                    'to confirm permanent deletion:',
                  ),
                  const SizedBox(height: 12),
                  Text(
                    household.householdName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Household Name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        confirmationText = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.clay,
                  ),
                  onPressed: confirmationText.trim() == household.householdName
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Delete Permanently'),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted || typedConfirmation != true) return;

    final success = await _runAction(
      () => _householdService.deleteHousehold(householdID: widget.householdID),
      returnHome: true,
    );

    if (!success && mounted) {
      _message(
        'Household deletion may be incomplete. '
        'Keep the app connected and use Delete Household '
        'again to retry. Do not create a replacement household '
        'until deletion finishes.',
      );
    }
  }

  void _showMemberMenu(HouseholdMember member) {
    if (_busy) return;

    final isSelf = member.userID == _currentUserID;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View Member Details'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _viewMember(member);
                },
              ),
              ListTile(
                leading: const Icon(Icons.swap_horiz),
                title: const Text('Change Role'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _changeRole(member);
                },
              ),
              if (!isSelf)
                ListTile(
                  leading: const Icon(
                    Icons.person_remove_outlined,
                    color: AppColors.clay,
                  ),
                  title: const Text('Remove Member'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _removeMember(member);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  // Widget for the 'Household' tab:
  Widget _buildHouseholdTab(
    Household household,
    List<HouseholdMember> members,
    HouseholdMember currentMember,
  ) {
    final isManager = currentMember.isManager;
    final canLeave = currentMember.isManager || currentMember.isMember;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceSunken,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HOUSEHOLD INFO', style: AppText.label),
              const SizedBox(height: 12),

              _infoRow('Household ID', household.householdID),
              _infoRow('Household Name', household.householdName),
              _infoRow(
                'Household Creator',
                _memberName(household.creatorID, members),
              ),

              if (isManager) ...[
                const SizedBox(height: 6),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _renameHousehold(household),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Rename Household'),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text('MEMBERS', style: AppText.label),
        const SizedBox(height: 10),

        for (var i = 0; i < members.length; i++)
          MemberCard(
            member: members[i],
            colorSeed: i,
            onMenu: isManager && !_busy
                ? () => _showMemberMenu(members[i])
                : null,
            onChangeRole: isManager && !_busy
                ? () => _changeRole(members[i])
                : null,
          ),

        const SizedBox(height: 20),

        if (canLeave)
          OutlinedButton.icon(
            onPressed: _busy ? null : _leaveHousehold,
            icon: const Icon(Icons.logout),
            label: const Text('Leave Household'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.clay),
          ),

        if (isManager) ...[
          const SizedBox(height: 12),

          OutlinedButton.icon(
            onPressed: _busy ? null : () => _deleteHousehold(household),
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Delete Household'),
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.clay),
          ),
        ],
      ],
    );
  }

  // Widget for displaying account info:
  Widget _accountField(String label, String value, VoidCallback onEdit) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppText.label),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    value.isEmpty ? 'Not set' : value,
                    style: AppText.body,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Change $label',
          ),
        ],
      ),
    );
  }

  // Widget for the 'Account' tab:
  Widget _buildAccountTab() {
    return StreamBuilder<UserProfile?>(
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(child: Text('Unable to load account data.'));
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final profile = snapshot.data!;

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          children: [
            _accountField(
              'Username',
              profile.username,
              () => AccountDialogs.editUsername(
                context,
                _accountService,
                profile,
              ),
            ),

            _accountField(
              'Display Name',
              profile.displayName,
              () => AccountDialogs.editDisplayName(
                context,
                _accountService,
                profile,
              ),
            ),

            _accountField(
              'Email',
              profile.email,
              () =>
                  AccountDialogs.changeEmail(context, _accountService, profile),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: () =>
                  AccountDialogs.changePassword(context, _accountService),
              icon: const Icon(Icons.lock_outline),
              label: const Text('Change Password'),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () => AccountDialogs.customizeAvatar(
                context,
                _accountService,
                profile,
              ),
              icon: const Icon(Icons.palette_outlined),
              label: const Text('Customize Avatar'),
            ),

            const SizedBox(height: 24),

            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _runAction(_accountService.signOut, returnHome: true),
              icon: const Icon(Icons.logout),
              label: const Text('Sign Out'),
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () =>
                        AccountDialogs.deleteAccount(context, _accountService),
              icon: const Icon(Icons.delete_forever_outlined),
              style: OutlinedButton.styleFrom(foregroundColor: AppColors.clay),
              label: const Text('Delete Account'),
            ),
          ],
        );
      },
    );
  }

  // Widget for displaying household info from the database:
  Widget _buildHouseholdContent() {
    return StreamBuilder<Household?>(
      stream: _householdStream,
      builder: (context, householdSnapshot) {
        if (householdSnapshot.hasError) {
          return const Center(child: Text('Unable to load household.'));
        }

        if (!householdSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final household = householdSnapshot.data!;

        return StreamBuilder<List<HouseholdMember>>(
          stream: _membersStream,
          builder: (context, membersSnapshot) {
            if (membersSnapshot.hasError) {
              return const Center(
                child: Text('Unable to load household members.'),
              );
            }

            if (!membersSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final members = membersSnapshot.data!;
            final uid = _currentUserID;

            if (uid == null) {
              return const Center(child: Text('Please sign in again.'));
            }

            HouseholdMember? currentMember;

            for (final member in members) {
              if (member.userID == uid) {
                currentMember = member;
                break;
              }
            }

            if (currentMember == null) {
              return const Center(
                child: Text('Your household membership was not found.'),
              );
            }

            return _buildHouseholdTab(household, members, currentMember);
          },
        );
      },
    );
  }

  // Actual Menu Screen UI:
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.forest,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            tooltip: 'Back to Home',
            onPressed: () => _handleNav(0),
          ),
          title: const Text('Menu'),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Color(0xFFC7D4C9),
            tabs: [
              Tab(text: 'Household'),
              Tab(text: 'Account'),
            ],
          ),
        ),
        body: Stack(
          children: [
            TabBarView(
              children: [_buildHouseholdContent(), _buildAccountTab()],
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
        bottomNavigationBar: HouseheldBottomNav(
          currentIndex: 5,
          onTap: _handleNav,
        ),
      ),
    );
  }
}
