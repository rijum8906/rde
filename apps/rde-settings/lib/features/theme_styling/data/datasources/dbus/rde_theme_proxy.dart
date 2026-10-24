import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/dbus/dbus.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_color_scheme.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_palette.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/rde_theme_info.dart';
import 'package:rde_settings/features/theme_styling/domain/entities/theme_service_snapshot.dart';

/// Thin D-Bus client for the `org.rde.Theme` service.
///
/// The service owns the theme database, generates Material 3 palettes from a
/// single source color per theme, and exposes them on the session bus at
/// `/org/rde/Theme`. This proxy only translates D-Bus types into the feature's
/// domain entities; every domain error is surfaced as an [RdeError] of type
/// [RdeErrorType.dbus] so the UI can show the service message.
class RdeThemeProxy {
  RdeThemeProxy({DBusClient? client})
    : client = client ?? RdeDbus.sessionClient {
    _object = DBusRemoteObject(
      this.client,
      name: serviceName,
      path: objectPath,
    );
  }

  /// Well-known bus name owned by the theme service.
  static const String serviceName = 'org.rde.Theme';

  /// Object path exporting the `org.rde.Theme` interface.
  static final DBusObjectPath objectPath = DBusObjectPath('/org/rde/Theme');

  /// Interface carrying the theme properties, methods, and signals.
  static const String interfaceName = 'org.rde.Theme';

  /// Session bus connection used for every call.
  final DBusClient client;

  late final DBusRemoteObject _object;

  /// Stream of the property names the service reports as changed.
  ///
  /// The service emits the standard `PropertiesChanged` signal next to its own
  /// semantic signals, so a single subscription keeps the UI in sync with theme
  /// changes made by other RDE applications.
  Stream<Set<String>> get propertyChanges {
    return _object.propertiesChanged.map(
      (signal) => signal.changedProperties.keys.toSet(),
    );
  }

  /// Reads the read-only properties of the theme service in one round trip.
  ///
  /// # Returns
  /// A [ThemeServiceSnapshot] with the service version, active theme,
  /// installed theme identifiers, color scheme, and active source color.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or a property
  /// cannot be read.
  Future<Either<RdeError, ThemeServiceSnapshot>> fetchSnapshot() {
    return _read('read the theme service state', () async {
      // Step 1: Fetch every property at once to keep the UI in sync.
      final properties = await _object.getAllProperties(interfaceName);

      // Step 2: Decode the properties into the domain snapshot, defaulting
      // collections to empty so a partially populated object stays usable.
      return ThemeServiceSnapshot(
        version: _readString(properties, 'Version'),
        currentTheme: _readString(properties, 'CurrentTheme'),
        installedThemes:
            _readValue(
              properties['InstalledThemes'],
            )?.asStringArray().toList() ??
            const <String>[],
        colorScheme: RdeColorScheme.fromDbus(
          _readString(properties, 'ColorScheme'),
        ),
        sourceColor: _readString(properties, 'SourceColor'),
      );
    });
  }

  /// Reads the manifest metadata of one installed theme.
  ///
  /// # Parameters
  /// - [theme]: installed theme identifier
  ///
  /// # Returns
  /// The [RdeThemeInfo] parsed from the service reply.
  ///
  /// # Errors
  /// Returns an [RdeError] when the theme is unknown or the reply is malformed.
  Future<Either<RdeError, RdeThemeInfo>> fetchThemeInfo(String theme) {
    return _read('read the metadata of theme "$theme"', () async {
      final response = await _object.callMethod(interfaceName, 'GetThemeInfo', [
        DBusString(theme),
      ], replySignature: DBusSignature('a{ss}'));

      final info = RdeThemeInfo.fromMap(
        _decodeStringMap(response.returnValues.first),
      );
      if (info == null) {
        throw FormatException('GetThemeInfo returned no theme identifier');
      }
      return info;
    });
  }

  /// Reads the palette of [theme] for [scheme].
  ///
  /// # Parameters
  /// - [theme]: installed theme identifier
  /// - [scheme]: light or dark appearance to generate
  ///
  /// # Returns
  /// The [RdePalette] described by the service.
  ///
  /// # Errors
  /// Returns an [RdeError] when the theme or scheme is rejected or the reply is
  /// malformed.
  Future<Either<RdeError, RdePalette>> fetchPalette(
    String theme,
    RdeColorScheme scheme,
  ) {
    return _read(
      'read the ${scheme.dbusValue} palette of theme "$theme"',
      () async {
        final response = await _object.callMethod(interfaceName, 'GetPalette', [
          DBusString(theme),
          DBusString(scheme.dbusValue),
        ], replySignature: DBusSignature('a{ss}'));

        return RdePalette(
          theme: theme,
          scheme: scheme,
          roles: _decodeStringMap(response.returnValues.first),
        );
      },
    );
  }

  /// Activates an installed theme, regenerating the toolkit color schemes.
  ///
  /// # Errors
  /// Returns an [RdeError] when the theme is not installed or the service
  /// cannot persist the registry.
  Future<Either<RdeError, void>> setTheme(String theme) {
    return _invoke('activate theme "$theme"', 'SetTheme', [DBusString(theme)]);
  }

  /// Creates a new theme from a source color without activating it.
  ///
  /// # Parameters
  /// - [name]: theme identifier (letters, digits, `-`, `_`, `.`)
  /// - [sourceColor]: seed color in any supported hexadecimal form
  ///
  /// # Errors
  /// Returns an [RdeError] when the identifier or color is invalid or the theme
  /// already exists.
  Future<Either<RdeError, void>> createTheme(String name, String sourceColor) {
    return _invoke('create theme "$name"', 'CreateTheme', [
      DBusString(name),
      DBusString(sourceColor),
    ]);
  }

  /// Deletes an installed, non-active theme.
  ///
  /// # Errors
  /// Returns an [RdeError] when the theme is unknown or is the active theme.
  Future<Either<RdeError, void>> deleteTheme(String theme) {
    return _invoke('delete theme "$theme"', 'DeleteTheme', [DBusString(theme)]);
  }

  /// Re-seeds the active theme and regenerates its palette.
  ///
  /// # Errors
  /// Returns an [RdeError] when the color is invalid or the manifest cannot be
  /// written.
  Future<Either<RdeError, void>> setSourceColor(String sourceColor) {
    return _invoke('re-seed the active theme', 'SetSourceColor', [
      DBusString(sourceColor),
    ]);
  }

  /// Writes the global light/dark preference.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service rejects the scheme or cannot
  /// persist it.
  Future<Either<RdeError, void>> setColorScheme(RdeColorScheme scheme) async {
    try {
      // Step 1: Write the property; the service persists it before replying
      // and mirrors it into the Qt/KDE color schemes.
      await _object.setProperty(
        interfaceName,
        'ColorScheme',
        DBusString(scheme.dbusValue),
      );
      return const Right(null);
    } catch (error) {
      return Left(
        _toRdeError('set the ${scheme.dbusValue} color scheme', error),
      );
    }
  }

  /// Asks the service to re-read its database after external changes.
  ///
  /// # Errors
  /// Returns an [RdeError] when the database cannot be read or repaired.
  Future<Either<RdeError, void>> reload() {
    return _invoke('reload the theme database', 'Reload');
  }

  /// Runs a read-only request and maps thrown exceptions to an [RdeError].
  Future<Either<RdeError, T>> _read<T>(
    String action,
    Future<T> Function() body,
  ) async {
    try {
      return Right(await body());
    } catch (error) {
      return Left(_toRdeError(action, error));
    }
  }

  /// Calls a void D-Bus method and maps thrown exceptions to an [RdeError].
  Future<Either<RdeError, void>> _invoke(
    String action,
    String method, [
    List<DBusValue> values = const [],
  ]) async {
    try {
      await _object.callMethod(interfaceName, method, values);
      return const Right(null);
    } catch (error) {
      return Left(_toRdeError(action, error));
    }
  }

  /// Builds a domain error carrying the service message and the failed action.
  RdeError _toRdeError(String action, Object error) {
    return RdeError('$action: $error', RdeErrorType.dbus);
  }

  /// Unwraps a variant returned by `Properties.GetAll`.
  DBusValue? _readValue(DBusValue? value) {
    if (value is DBusVariant) {
      return value.value;
    }
    return value;
  }

  /// Reads a string property, defaulting to an empty string when absent.
  String _readString(Map<String, DBusValue> properties, String name) {
    final value = _readValue(properties[name]);
    if (value == null) {
      return '';
    }
    return value.asString();
  }

  /// Decodes an `a{ss}` reply into a plain Dart map.
  Map<String, String> _decodeStringMap(DBusValue value) {
    final decoded = _readValue(value);
    if (decoded is! DBusDict) {
      throw FormatException(
        'expected a string dictionary, received ${decoded?.signature}',
      );
    }

    return {
      for (final entry in decoded.children.entries)
        entry.key.asString(): entry.value.asString(),
    };
  }
}
