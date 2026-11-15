import 'main.dart' as app;

// RWFit uses the original Picnique UI with a separate local health database.
Future<void> main() => app.runPicnique(useRwfit: true);
