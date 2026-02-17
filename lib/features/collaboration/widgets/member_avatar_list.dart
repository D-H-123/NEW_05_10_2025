import 'package:flutter/material.dart';
import '../../../core/models/shared_budget.dart';

/// ✅ Optimized: Extracted member avatar list widget
/// Shows avatars of budget members in a row
class MemberAvatarList extends StatelessWidget {
  final List<BudgetMember> members;
  final double? size;
  final int? maxVisible;

  const MemberAvatarList({
    super.key,
    required this.members,
    this.size = 40,
    this.maxVisible = 5,
  });

  @override
  Widget build(BuildContext context) {
    final visibleMembers = maxVisible != null && members.length > maxVisible!
        ? members.sublist(0, maxVisible!)
        : members;
    final remainingCount = maxVisible != null && members.length > maxVisible!
        ? members.length - maxVisible!
        : 0;

    if (members.isEmpty) {
      return const SizedBox.shrink();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...visibleMembers.map((member) => Container(
          margin: const EdgeInsets.only(right: -8),
          child: CircleAvatar(
            radius: size! / 2,
            backgroundColor: Colors.grey[300],
            backgroundImage: member.photoUrl != null
                ? NetworkImage(member.photoUrl!)
                : null,
            child: member.photoUrl == null
                ? Text(
                    member.name.isNotEmpty ? member.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: size! * 0.4,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  )
                : null,
          ),
        )),
        if (remainingCount > 0)
          Container(
            margin: const EdgeInsets.only(left: 4),
            child: CircleAvatar(
              radius: size! / 2,
              backgroundColor: Colors.grey[400],
              child: Text(
                '+$remainingCount',
                style: TextStyle(
                  fontSize: size! * 0.35,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

