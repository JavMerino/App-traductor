import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Proveedor del índice de la pestaña activa en el MainShell.
///
/// Permite que cualquier widget (ej: HomeScreen) cambie de pestaña
/// sin necesidad de Navigator.push ni jerarquía de widgets.
final tabIndexProvider = StateProvider<int>((ref) => 0);
