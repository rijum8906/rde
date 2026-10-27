import 'package:dbus/dbus.dart';
import 'package:fpdart/fpdart.dart';
import 'package:rde_settings/core/dbus/dbus.dart';
import 'package:rde_settings/core/errors/rde_error.dart';

/// Reads the active wallpaper path from the KDE Plasma shell.
///
/// Plasma owns the wallpaper configuration, and the theme service no longer
/// stores it. The path is read through `org.kde.PlasmaShell.evaluateScript`,
/// which runs a short read-only script and returns what it prints.
class KdeWallpaperSource {
  /// Creates the source, defaulting to the shared session bus connection.
  KdeWallpaperSource({DBusClient? client})
    : _client = client ?? RdeDbus.sessionClient;

  /// Well-known name owned by the Plasma shell.
  static const String serviceName = 'org.kde.plasmashell';

  /// Object path carrying the Plasma scripting interface.
  static final DBusObjectPath objectPath = DBusObjectPath('/PlasmaShell');

  /// Interface that exposes `evaluateScript`.
  static const String interfaceName = 'org.kde.PlasmaShell';

  /// Read-only script reporting the first desktop's configured image.
  ///
  /// Only the `org.kde.image` plugin keeps a single image path; slideshow and
  /// picture-of-the-day plugins report an empty `Image`, which maps to a failure
  /// instead of a wrong path.
  static const String _wallpaperScript = '''
var image = '';
var desktopsList = desktops();
for (var i = 0; i < desktopsList.length; i++) {
  var desk = desktopsList[i];
  desk.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
  var candidate = String(desk.readConfig('Image') || '');
  if (candidate.length > 0) {
    image = candidate;
    break;
  }
}
print(image);
''';

  final DBusClient _client;

  /// Returns the absolute path of the wallpaper the Plasma shell reports.
  ///
  /// # Errors
  /// Returns an [RdeError] when the shell is not reachable or reports no image.
  Future<Either<RdeError, String>> fetchWallpaperPath() async {
    try {
      final object = DBusRemoteObject(
        _client,
        name: serviceName,
        path: objectPath,
      );
      final response = await object.callMethod(
        interfaceName,
        'evaluateScript',
        [DBusString(_wallpaperScript)],
        replySignature: DBusSignature('s'),
      );

      final path = parseWallpaperPath(response.returnValues.first.asString());
      if (path == null) {
        return const Left(
          RdeError(
            'the KDE shell reported no Image wallpaper',
            RdeErrorType.dbus,
          ),
        );
      }
      return Right(path);
    } catch (error) {
      return Left(
        RdeError('read the KDE wallpaper: $error', RdeErrorType.dbus),
      );
    }
  }

  /// Normalizes the value the Plasma script printed.
  ///
  /// Plasma can wrap the value in quotes and may report a `file://` URI, so the
  /// reply is trimmed, unquoted, and converted to a plain path.
  ///
  /// # Returns
  /// The absolute wallpaper path, or `null` when the reply is empty.
  static String? parseWallpaperPath(String reply) {
    // Step 1: Trim the printed output and drop the wrapping quotes.
    var value = reply.trim();
    final quoted =
        value.length >= 2 &&
        ((value.startsWith('"') && value.endsWith('"')) ||
            (value.startsWith("'") && value.endsWith("'")));
    if (quoted) {
      value = value.substring(1, value.length - 1).trim();
    }
    if (value.isEmpty) {
      return null;
    }

    // Step 2: Convert a file URI into a filesystem path.
    final uri = Uri.tryParse(value);
    if (uri != null && uri.scheme == 'file') {
      final path = uri.toFilePath();
      return path.isEmpty ? null : path;
    }

    return value;
  }
}
