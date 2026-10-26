import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/dbus/dbus.dart';
import 'package:rde_settings/core/errors/rde_error.dart';
import 'package:rde_settings/core/theme/domain/entities/appearance_mode.dart';
import 'package:rde_settings/core/theme/domain/entities/resolved_theme.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_manifest.dart';
import 'package:rde_settings/core/theme/domain/entities/theme_snapshot.dart';

/// Payload of the `ThemeChanged` signal.
class ThemeChangedSignal {
  const ThemeChangedSignal({
    required this.resolvedJson,
    required this.generation,
  });

  /// JSON encoded [ResolvedTheme] that was just published.
  final String resolvedJson;

  /// Generation the published payload reached.
  final int generation;
}

/// Thin D-Bus client for the `org.rde.Theme` service.
///
/// The service owns author manifests, the installed-theme registry, user
/// settings, and the resolved theme it publishes for every themed application.
/// This proxy only translates D-Bus types into the core domain entities; every
/// failure is surfaced as an [RdeError] of type [RdeErrorType.dbus] so callers
/// can show the service message.
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

  /// Signature of the struct returned by `GetResolvedTheme`.
  static final DBusSignature _resolvedSignature = DBusSignature(
    '(ussu(${'s' * ColorRoles.roleCount})(ss)(ddddd)(uuuss))',
  );

  /// Signature of the struct returned by `GetThemeManifest`.
  static final DBusSignature _manifestSignature = DBusSignature(
    '(ussssssa{s(uusss)}s)',
  );

  /// Session bus connection used for every call.
  final DBusClient client;

  late final DBusRemoteObject _object;

  /// Reads the read-only properties of the theme service in one round trip.
  ///
  /// # Returns
  /// A [ThemeSnapshot] with the contract version, active theme, appearance,
  /// registry list, and generation.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is not running or a property
  /// cannot be read.
  Future<Either<RdeError, ThemeSnapshot>> fetchSnapshot() {
    return _read('read the theme service state', () async {
      // Step 1: Fetch every property at once to keep the UI in sync.
      final properties = await _object.getAllProperties(interfaceName);

      // Step 2: Decode the properties into the domain snapshot, defaulting
      // collections to empty so a partially populated object stays usable.
      return ThemeSnapshot(
        version: _readUint32(properties, 'Version'),
        activeTheme: _readString(properties, 'ActiveTheme'),
        mode: AppearanceMode.fromDbus(_readString(properties, 'Mode')),
        availableThemes:
            _readValue(
              properties['AvailableThemes'],
            )?.asStringArray().toList() ??
            const <String>[],
        generation: _readUint32(properties, 'Generation'),
      );
    });
  }

  /// Reads the appearance the desktop currently renders.
  ///
  /// # Errors
  /// Returns an [RdeError] when the property cannot be read.
  Future<Either<RdeError, AppearanceMode>> fetchMode() {
    return _read('read the appearance mode', () async {
      final value = await _object.getProperty(interfaceName, 'Mode');
      return AppearanceMode.fromDbus(_readValue(value)?.asString() ?? '');
    });
  }

  /// Reads the theme the service currently publishes.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service is unavailable or the reply is
  /// malformed.
  Future<Either<RdeError, ResolvedTheme>> fetchResolvedTheme() {
    return _read('read the resolved theme', () async {
      final response = await _object.callMethod(
        interfaceName,
        'GetResolvedTheme',
        const [],
        replySignature: _resolvedSignature,
      );
      return ResolvedTheme.fromDbus(response.returnValues.first);
    });
  }

  /// Reads the author manifest of one installed theme.
  ///
  /// # Parameters
  /// - [id]: theme identifier, including `rde-dynamic` for the built-in theme
  ///
  /// # Errors
  /// Returns an [RdeError] when the theme is unknown or the reply is malformed.
  Future<Either<RdeError, ThemeManifest>> fetchThemeManifest(String id) {
    return _read('read the manifest of theme "$id"', () async {
      final response = await _object.callMethod(
        interfaceName,
        'GetThemeManifest',
        [DBusString(id)],
        replySignature: _manifestSignature,
      );
      return ThemeManifest.fromDbus(response.returnValues.first);
    });
  }

  /// Lists the identifiers of every theme in the registry.
  ///
  /// # Errors
  /// Returns an [RdeError] when the registry cannot be read.
  Future<Either<RdeError, List<String>>> listThemes() {
    return _read('list the installed themes', () async {
      final response = await _object.callMethod(
        interfaceName,
        'ListThemes',
        const [],
        replySignature: DBusSignature('as'),
      );
      return response.returnValues.first.asStringArray().toList();
    });
  }

  /// Activates an installed theme.
  ///
  /// Use `rde-dynamic` to switch back to the wallpaper-derived theme.
  ///
  /// # Errors
  /// Returns an [RdeError] when the theme is not installed or the service
  /// cannot publish the new payload.
  Future<Either<RdeError, void>> setActiveTheme(String id) {
    return _invoke('activate theme "$id"', 'SetActiveTheme', [DBusString(id)]);
  }

  /// Switches the desktop appearance between light and dark.
  ///
  /// # Errors
  /// Returns an [RdeError] when the mode is rejected or cannot be persisted.
  Future<Either<RdeError, void>> setMode(AppearanceMode mode) {
    return _invoke('set the ${mode.dbusValue} appearance', 'SetMode', [
      DBusString(mode.dbusValue),
    ]);
  }

  /// Updates the seed colors of the built-in dynamic theme.
  ///
  /// # Parameters
  /// - [primary]: `#RRGGBB` seed of the primary family and neutral surfaces;
  ///   an empty string keeps the stored seed
  /// - [secondary]: `#RRGGBB` secondary seed; an empty string keeps the stored seed
  /// - [tertiary]: `#RRGGBB` tertiary seed; an empty string keeps the stored seed
  /// - [error]: `#RRGGBB` error seed; an empty string keeps the stored seed
  ///
  /// # Errors
  /// Returns an [RdeError] when a seed is rejected or cannot be persisted.
  Future<Either<RdeError, void>> updateDynamicTheme({
    String primary = '',
    String secondary = '',
    String tertiary = '',
    String error = '',
  }) {
    return _invoke('update the dynamic theme seeds', 'UpdateDynamicTheme', [
      DBusString(primary),
      DBusString(secondary),
      DBusString(tertiary),
      DBusString(error),
    ]);
  }

  /// Asks the service to re-read manifests, variant files, and settings.
  ///
  /// # Errors
  /// Returns an [RdeError] when the service cannot resolve the active theme.
  Future<Either<RdeError, void>> reload() {
    return _invoke('reload the theme database', 'Reload');
  }

  /// Computes a theme preview without committing it.
  ///
  /// # Parameters
  /// - [themeId]: theme to render, including `rde-dynamic`
  /// - [mode]: light or dark appearance to render
  /// - [contrast]: contrast level to render
  ///
  /// # Errors
  /// Returns an [RdeError] when the theme, mode, or contrast is rejected or
  /// the preview payload is malformed.
  Future<Either<RdeError, ResolvedTheme>> preview({
    required String themeId,
    required AppearanceMode mode,
    ContrastLevel contrast = ContrastLevel.normal,
  }) {
    return _read('preview theme "$themeId"', () async {
      final response = await _object.callMethod(interfaceName, 'Preview', [
        DBusString(themeId),
        DBusString(mode.dbusValue),
        DBusString(contrast.dbusValue),
      ], replySignature: DBusSignature('s'));

      final resolved = ResolvedTheme.tryFromJsonString(
        response.returnValues.first.asString(),
      );
      if (resolved == null) {
        throw const FormatException('Preview returned invalid theme JSON');
      }
      return resolved;
    });
  }

  /// Emits the freshly published theme whenever the desktop appearance changes.
  ///
  /// The service writes the payload to disk before signalling, so a listener
  /// that reacts to a change always observes a durable state.
  Stream<ThemeChangedSignal> watchThemeChanges() {
    return DBusRemoteObjectSignalStream(
      object: _object,
      interface: interfaceName,
      name: 'ThemeChanged',
      signature: DBusSignature('su'),
    ).map((signal) {
      return ThemeChangedSignal(
        resolvedJson: signal.values[0].asString(),
        generation: signal.values[1].asUint32(),
      );
    });
  }

  /// Emits the registry identifiers whenever an installed theme appears or
  /// disappears.
  Stream<List<String>> watchThemeListChanges() {
    return DBusRemoteObjectSignalStream(
      object: _object,
      interface: interfaceName,
      name: 'ThemeListChanged',
      signature: DBusSignature('as'),
    ).map((signal) => signal.values.first.asStringArray().toList());
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

  /// Unwraps a variant returned by a property read.
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

  /// Reads an unsigned integer property, defaulting to zero when absent.
  int _readUint32(Map<String, DBusValue> properties, String name) {
    final value = _readValue(properties[name]);
    if (value == null) {
      return 0;
    }
    return value.asUint32();
  }
}
