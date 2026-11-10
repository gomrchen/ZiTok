import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

/// 便捷取文案：`context.l10n.tabHome`
extension L10nX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
