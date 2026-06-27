import 'package:localsend_app/provider/persistence_provider.dart';
import 'package:refena_flutter/refena_flutter.dart';

/// Holds the user-picked custom theme seed color as an ARGB int.
///
/// `null` means "use the default" (teal). This exists because Android < 12
/// (incl. Android 4.4 / KitKat) cannot read the system accent color
/// (Material You / dynamic color), so the user picks a color manually here.
final customColorProvider = NotifierProvider<CustomColorService, int?>((ref) {
  return CustomColorService(ref.read(persistenceProvider));
});

class CustomColorService extends PureNotifier<int?> {
  final PersistenceService _persistence;

  CustomColorService(this._persistence);

  @override
  int? init() => _persistence.getCustomColor();

  Future<void> setColor(int? color) async {
    await _persistence.setCustomColor(color);
    state = color;
  }
}
