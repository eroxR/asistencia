// import 'package:asistencia/editor.dart';
import 'package:flutter/material.dart';
import 'home.dart'; // Import the new home.dart file
import 'package:asistencia/database/asistencia_database.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  // Asegúrate de que los bindings de Flutter estén inicializados
  // Esto es crucial para usar plugins como sqflite antes de runApp
  WidgetsFlutterBinding.ensureInitialized();

  // --- INICIALIZACIÓN DE LA BASE DE DATOS Y PRUEBA ---
  try {
    await AsistenciaDatabase.instance.database;
  } catch (e) {
    // Manejo de errores, por ejemplo, si la base de datos no se pudo abrir
    debugPrint('Error al inicializar la base de datos: $e');
  }
  // --- FIN DE INICIALIZACIÓN Y PRUEBA ---

  runApp(const MyApp());
}

// void main() {
//   runApp(const MyApp());
// }

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'User List Demo', // Updated title

      theme: ThemeData(
        // Using a color scheme based on a seed color.
        // You can change Colors.blue to any color you prefer.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true, // Recommended for new Flutter projects
      ),
      // Set UserListScreen as the home screen
      // --- CONFIGURACIÓN DE LOCALIZACIÓN ---
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate, // Para widgets de Material Design
        GlobalWidgetsLocalizations
            .delegate, // Para la dirección del texto en widgets generales
        GlobalCupertinoLocalizations
            .delegate, // Para widgets de Cupertino (iOS-style)
      ],
      supportedLocales: const [
        Locale('en', ''), // Inglés, sin código de país
        Locale('es', ''), // Español, sin código de país
        // Locale('es', 'ES'), // Español de España (opcional, si necesitas variantes)
        // Locale('es', 'MX'), // Español de México (opcional)
        // ... puedes añadir más locales que tu app soporte ...
      ],
      // Opcional: Establecer un locale por defecto si no se encuentra uno compatible
      locale: Locale('es', ''),
      // --- FIN DE CONFIGURACIÓN DE LOCALIZACIÓN ---
      home: const UserListScreen(),
      // home: const EditorScreen(),
      debugShowCheckedModeBanner: false, // Optional: removes the debug banner
    );
  }
}
