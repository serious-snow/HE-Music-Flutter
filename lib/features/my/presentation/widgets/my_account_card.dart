import 'package:flutter/material.dart';

import '../../../../shared/widgets/glass_panel.dart';
import '../../domain/entities/my_profile.dart';

class MyAccountCard extends StatelessWidget {
  const MyAccountCard({
    required this.profile,
    required this.tokenSet,
    super.key,
  });

  final MyProfile profile;
  final bool tokenSet;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassPanel(
      borderRadius: BorderRadius.circular(32),
      blurSigma: 0,
      tintColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 34,
            backgroundColor: theme.colorScheme.primaryContainer,
            backgroundImage: profile.avatarUrl.isEmpty
                ? null
                : NetworkImage(profile.avatarUrl),
            child: profile.avatarUrl.isEmpty
                ? const Icon(Icons.person, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'PROFILE',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.nickname.isEmpty
                      ? profile.username
                      : profile.nickname,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '@${profile.username}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    _ProfileMetaChip(label: 'ID ${profile.id}'),
                    _ProfileMetaChip(label: '状态 ${profile.status}'),
                    _ProfileMetaChip(
                      label: tokenSet ? 'Token 已配置' : 'Token 未配置',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileMetaChip extends StatelessWidget {
  const _ProfileMetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.66),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
