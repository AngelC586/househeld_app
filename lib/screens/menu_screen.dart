import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_theme.dart';
import '../widgets/member_card.dart';
import '../widgets/househeld_bottom_nav.dart';
import '../navigation/househeld_navigation.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key, required this.householdID});

  final String householdID;

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  final String _currentUserID = '';

  late final Household _household = Household(
    householdID: widget.householdID,
    householdName: '',
    creatorID: '',
  );

  final List<HouseholdMember> _members = const [];

  final Map<String, (String username, String email)> _sampleContactInfo =
      const {};

  String _memberName(String uid) {
    if (uid.isEmpty) return 'Not set';
    for (final m in _members) {
      if (m.userID == uid) return m.displayName;
    }
    return uid;
  }

  void _handleNav(int index) {
    HouseheldNavigation.navigate(
      context: context,
      householdID: widget.householdID,
      currentIndex: 5,
      destinationIndex: index,
    );
  }

  void _showMemberMenu(HouseholdMember member) {
    final isSelf = member.userID == _currentUserID;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.visibility_outlined,
                color: AppColors.forest,
              ),
              title: const Text('View Member'),
              onTap: () {
                Navigator.pop(context);
                _showViewMember(member);
              },
            ),
            if (!isSelf) ...[
              ListTile(
                leading: const Icon(Icons.swap_horiz, color: AppColors.forest),
                title: const Text('Change Role'),
                onTap: () {
                  Navigator.pop(context);
                  _showChangeRole(member);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_remove_outlined,
                  color: AppColors.clay,
                ),
                title: const Text('Remove Member'),
                onTap: () {
                  Navigator.pop(context);
                  _showRemoveMember(member);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showViewMember(HouseholdMember member) {
    final contact = _sampleContactInfo[member.userID];
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Member Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Display Name', member.displayName),
            _infoRow('Role', memberRoleLabel(member.memberRole)),
            _infoRow('Username', contact?.$1 ?? 'Not available yet'),
            _infoRow('Email', contact?.$2 ?? 'Not available yet'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label),
          const SizedBox(height: 2),
          Text(value.isEmpty ? 'Not set' : value, style: AppText.body),
        ],
      ),
    );
  }

  Future<void> _showChangeRole(HouseholdMember member) async {
    String selectedRole = member.memberRole;

    final newRole = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('Change Role — ${member.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current role: ${memberRoleLabel(member.memberRole)}',
                style: AppText.bodySoft,
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: selectedRole,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'manager', child: Text('Manager')),
                  DropdownMenuItem(value: 'member', child: Text('Member')),
                  DropdownMenuItem(value: 'child', child: Text('Child')),
                ],
                onChanged: (v) =>
                    setDialogState(() => selectedRole = v ?? selectedRole),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedRole),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );

    if (newRole == null || newRole == member.memberRole || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${member.displayName}\'s role changed to ${memberRoleLabel(newRole)}.',
        ),
      ),
    );
  }

  Future<void> _showRemoveMember(HouseholdMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(member.displayName),
        content: const Text('Are you sure you want to remove this member?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${member.displayName} removed.')));
  }

  Widget _buildHouseholdTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        // Household Info Card
        Container(
          width: double.infinity,
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
              _infoRow('Household ID', _household.householdID),
              _infoRow('Household Name', _household.householdName),
              _infoRow('Household Creator', _memberName(_household.creatorID)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('MEMBERS', style: AppText.label),
        const SizedBox(height: 10),
        if (_members.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text('No members yet.', style: AppText.bodySoft),
          )
        else
          for (var i = 0; i < _members.length; i++)
            MemberCard(
              member: _members[i],
              colorSeed: i,
              onMenu: () => _showMemberMenu(_members[i]),
            ),
      ],
    );
  }

  Widget _buildAccountTab() {
    final HouseholdMember? me = _members.isEmpty
        ? null
        : _members.firstWhere(
            (m) => m.userID == _currentUserID,
            orElse: () => _members.first,
          );
    final contact = me == null ? null : _sampleContactInfo[me.userID];

    void notBuiltYet() {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Not wired up yet.')));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        _accountField('Username', contact?.$1 ?? 'Not set', notBuiltYet),
        _accountField(
          'Display Name',
          me?.displayName ?? 'Not set',
          notBuiltYet,
        ),
        _accountField('Email', contact?.$2 ?? 'Not set', notBuiltYet),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: notBuiltYet,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: const BorderSide(color: AppColors.line),
          ),
          child: Text('Change Password', style: AppText.body),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: () => _confirmDeleteAccount(),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          child: const Text('Delete Account'),
        ),
      ],
    );
  }

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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(value, style: AppText.body),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: AppColors.forestDeep),
            onPressed: onEdit,
            tooltip: 'Change $label',
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount() async {
    final firstOkay = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This will permanently delete your account and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );

    if (firstOkay != true || !mounted) return;

    final typeController = TextEditingController();
    final finalOkay = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Are you absolutely sure?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Type DELETE to confirm.'),
              const SizedBox(height: 10),
              TextField(
                controller: typeController,
                onChanged: (_) => setDialogState(() {}),
                decoration: const InputDecoration(border: OutlineInputBorder()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: typeController.text.trim() == 'DELETE'
                  ? () => Navigator.pop(context, true)
                  : null,
              child: const Text('Delete Account'),
            ),
          ],
        ),
      ),
    );

    if (finalOkay == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account deletion is not wired up yet.')),
      );
    }
  }

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
        body: SafeArea(
          child: TabBarView(
            children: [_buildHouseholdTab(), _buildAccountTab()],
          ),
        ),
        bottomNavigationBar: HouseheldBottomNav(
          currentIndex: 5,
          onTap: _handleNav,
        ),
      ),
    );
  }
}
