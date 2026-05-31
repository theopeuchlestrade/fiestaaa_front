part of '../pages/auth_page.dart';

extension _AuthPageAlphaBanner on _AuthPageState {
  Widget _buildAlphaBanner({required bool compact}) {
    final l10n = S.of(context);
    final theme = Theme.of(context);
    final warningStyle = theme.colorScheme.fiestaaaStatus(
      FiestaaaStatusTone.warning,
    );
    final bannerBackground = warningStyle.background;
    final bannerBorder = warningStyle.border;
    final bannerShadow = warningStyle.foreground.withValues(alpha: 0.18);
    final bannerTitle = warningStyle.foreground;
    final bannerText = warningStyle.foreground;
    final bannerIconBackground = warningStyle.foreground.withValues(
      alpha: 0.14,
    );
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: compact ? 12 : 14,
        horizontal: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: bannerBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: bannerBorder),
        boxShadow: [
          BoxShadow(
            color: bannerShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: bannerIconBackground,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.science_outlined,
                  color: bannerText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.alphaVersionBanner,
                  style: TextStyle(
                    color: bannerTitle,
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 14 : 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: SelectableText(
                  l10n.reportBugsTo(_AuthPageState._feedbackEmail),
                  style: TextStyle(
                    color: bannerText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.copyAddress,
                onPressed: _copyFeedbackEmail,
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: bannerText,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _copyBugTemplate,
                icon: const Icon(Icons.article_outlined, size: 18),
                label: Text(l10n.copyBugTemplate),
                style: OutlinedButton.styleFrom(
                  foregroundColor: bannerText,
                  side: BorderSide(color: bannerBorder),
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 10 : 12,
                    horizontal: compact ? 10 : 12,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _copyFeedbackEmail,
                icon: const Icon(Icons.alternate_email, size: 18),
                label: Text(l10n.copyAddress),
                style: OutlinedButton.styleFrom(
                  foregroundColor: bannerText,
                  side: BorderSide(color: bannerBorder),
                  padding: EdgeInsets.symmetric(
                    vertical: compact ? 10 : 12,
                    horizontal: compact ? 10 : 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
