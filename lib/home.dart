import 'package:asistencia/editor.dart';
import 'package:asistencia/historial.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Para formatear fechas

// IMPORTA TUS MODELOS Y LA CLASE DE BASE DE DATOS
import 'package:asistencia/models/model.dart'; // Ajusta la ruta si es diferente
import 'package:asistencia/database/asistencia_database.dart'; // Ajusta la ruta

import 'dart:convert'; // Para utf8.encode
import 'package:crypto/crypto.dart'; // Para md5

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<Usuario> _usuarios = [];
  Map<int, Asistencia> _asistenciasActivas = {}; // Clave: idUsuario
  Map<String, int> _valoresNotasBase = {}; // Clave: 'A', 'E', 'N', 'T'
  bool _isLoading = true;
  int _loginAttempts =
      0; // Para contar los intentos dentro de una sesión del diálogo
  final int _maxLoginAttempts = 3;

  final List<String> _attendanceActivityOrder = [
    'Consagración Domingo',
    'Escuela Dominical',
    'Ensayo Martes',
    'Ensayo Miércoles',
    'Servicio Jueves',
  ];

  // Mapeo de etiquetas de UI a nombres de campo en el modelo Asistencia
  // final Map<String, String> _activityToFieldMapping = {
  //   'Consagración Domingo': 'consagracionDomingo',
  //   'Escuela Dominical': 'escuelaDominical',
  //   'Ensayo Martes': 'ensayoMartes',
  //   'Ensayo Miércoles': 'ensayoMiercoles',
  //   'Servicio Jueves': 'servicioJueves',
  // };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadValoresNotasBase();
    await _refreshUsuarios(); // Cargar usuarios y su asistencia activa
  }

  Future<void> _loadValoresNotasBase() async {
    final notas = await AsistenciaDatabase.instance.readAllNotaAsistenciat();
    Map<String, int> tempValores = {};
    for (var nota in notas) {
      if (nota.idNota != null) {
        tempValores[nota.idNota!] = nota.valorNota ?? 0;
      }
    }
    if (mounted) {
      setState(() {
        _valoresNotasBase = tempValores;
      });
    }
  }

  Future<void> _refreshUsuarios() async {
    if (mounted) setState(() => _isLoading = true);
    final usuariosFromDB = await AsistenciaDatabase.instance.readAllUsuarios();
    Map<int, Asistencia> asistenciasTemp = {};

    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    for (var usuario in usuariosFromDB) {
      if (usuario.idUsuario != null) {
        final asistenciaExistente = await AsistenciaDatabase.instance
            .readActiveAsistenciaForUser(usuario.idUsuario!);

        asistenciasTemp[usuario.idUsuario!] =
            asistenciaExistente ??
            _crearNuevaAsistenciaActiva(
              usuario.idUsuario!,
              startOfWeek,
              endOfWeek,
            );
      }
    }

    if (mounted) {
      setState(() {
        _usuarios = usuariosFromDB;
        _asistenciasActivas = asistenciasTemp;
        _isLoading = false;
      });
    }
  }

  Asistencia _crearNuevaAsistenciaActiva(
    int usuarioId,
    DateTime inicioSemana,
    DateTime finSemana,
  ) {
    return Asistencia(
      usuarioId: usuarioId,
      consagracionDomingo: "", // Vacío significa no registrado aún
      fechaConsagracionD: null, // Inicia como null
      escuelaDominical: "",
      fechaEscuelaD: null, // Inicia como null
      ensayoMartes: "",
      fechaEnsayoMartes: null, // Inicia como null
      ensayoMiercoles: "",
      fechaEnsayoMiercoles: null, // Inicia como null
      servicioJueves: "",
      fechaServicioJueves: null, // Inicia como null
      totalAsistencia: 0,
      inicioSemana: inicioSemana,
      finSemana: finSemana,
      estado: 'activo',
    );
  }

  int? _calculateAge(String? birthDateString) {
    if (birthDateString == null || birthDateString.isEmpty) return null;
    try {
      DateTime birthDate;
      if (birthDateString.contains('/')) {
        birthDate = DateFormat('dd/MM/yyyy').parse(birthDateString);
      } else {
        // Intenta parsear como yyyy-MM-dd, y si falla, prueba otros formatos comunes o devuelve null
        try {
          birthDate = DateFormat('yyyy-MM-dd').parse(birthDateString);
        } catch (e) {
          print(
            "Formato de fecha no es yyyy-MM-dd, intentando como ISO8601: $e",
          );
          birthDate = DateTime.parse(
            birthDateString,
          ); // Asume ISO8601 completo si el anterior falla
        }
      }
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age < 0 ? 0 : age; // Evitar edad negativa si la fecha es futura
    } catch (e) {
      print("Error parseando fecha de nacimiento '$birthDateString': $e");
      return null;
    }
  }

  String _getInitials(String? name) {
    if (name == null || name.isEmpty) return '?';
    final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    } else if (parts.isNotEmpty) {
      return parts[0][0].toUpperCase();
    }
    return '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listado Usuarios Coro'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: Icon(Icons.edit_square), // Primer ícono a la derecha
            iconSize: 35.0,
            color: Colors.yellow[900],
            tooltip: 'Abrir Editor (Requiere Contraseña)',
            onPressed: () {
              _showAuthorizationDialog(context); // Pasa el context y el destino
            },
          ),
          IconButton(
            icon: Icon(
              Icons.manage_history_sharp,
            ), // Segundo ícono a la derecha
            iconSize: 35.0,
            tooltip: 'Ver Historial',
            // color: Colors.green, // Cambia el color del ícono a azul
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const HistorialScreen(),
                ), // Navegar a HistorialScreen
              );
            },
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _usuarios.isEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("No hay usuarios."),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh),
                      label: const Text("Recargar"),
                      onPressed: _refreshUsuarios,
                    ),
                  ],
                ),
              )
              : ListView.builder(
                itemCount: _usuarios.length,
                itemBuilder: (context, index) {
                  final usuario = _usuarios[index];
                  final asistencia =
                      (usuario.idUsuario != null)
                          ? _asistenciasActivas[usuario.idUsuario!]
                          : null;
                  return _buildUserListItem(usuario, asistencia);
                },
              ),
      floatingActionButton: SizedBox(
        // <--- ENVOLVER CON SIZEDBOX
        width: 38.0, // Ancho deseado (ejemplo)
        height: 38.0, // Alto deseado (ejemplo)
        child: FloatingActionButton(
          onPressed: () => _openUserFormModal(null),
          tooltip: 'Agregar Usuario',
          child: const Icon(
            Icons.add,
            size: 24.0,
          ), // Opcional: ajustar tamaño del icono también
          // elevation: 4.0, // Ajustar elevación si es necesario
          // materialTapTargetSize: MaterialTapTargetSize.padded, // Experimenta con esto
        ),
      ),
    );
  }

  Widget _buildUserListItem(Usuario usuario, Asistencia? asistencia) {
    Map<String, String?> currentAttendanceMapForUI = {};
    if (asistencia != null) {
      currentAttendanceMapForUI = {
        'Consagración Domingo':
            asistencia.consagracionDomingo.isEmpty
                ? null
                : asistencia.consagracionDomingo,
        'Escuela Dominical':
            asistencia.escuelaDominical.isEmpty
                ? null
                : asistencia.escuelaDominical,
        'Ensayo Martes':
            asistencia.ensayoMartes.isEmpty ? null : asistencia.ensayoMartes,
        'Ensayo Miércoles':
            asistencia.ensayoMiercoles.isEmpty
                ? null
                : asistencia.ensayoMiercoles,
        'Servicio Jueves':
            asistencia.servicioJueves.isEmpty
                ? null
                : asistencia.servicioJueves,
      };
    }

    int percentage = asistencia?.totalAsistencia ?? 0;
    bool hasAttendanceDataForDisplay = currentAttendanceMapForUI.values.any(
      (status) => status != null && status.isNotEmpty,
    );

    const double markerRowHeight = 60.0;
    // Determinar el color del porcentaje
    Color percentageColor;
    if (percentage < 60) {
      percentageColor = Colors.red.shade700; // Un rojo más oscuro
    } else if (percentage < 65) {
      percentageColor = Colors.yellow.shade700;
    } else {
      percentageColor =
          Colors.green.shade900; // El verde que ya tenías o uno similar
    }
    Widget percentageWidget =
        (hasAttendanceDataForDisplay ||
                (asistencia != null &&
                    asistencia.totalAsistencia !=
                        null && // <--- AÑADIR ESTA COMPROBACIÓN
                    asistencia.totalAsistencia! > 0))
            ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$percentage%',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                    color: percentageColor,
                  ),
                ),
              ],
            )
            : const SizedBox.shrink();

    final String name = usuario.nombreCompleto ?? 'Sin Nombre';
    final int? age = _calculateAge(usuario.fechaNacimiento);
    String birthDateFormatted = "N/A";
    // Los campos de acudiente no están en el modelo Usuario.
    // Si los necesitas, debes añadirlos al modelo y la base de datos.
    // final String guardianPhone = "N/A"; // Placeholder
    if (usuario.fechaNacimiento != null && usuario.fechaNacimiento.isNotEmpty) {
      try {
        // Asumimos que usuario.fechaNacimiento está en formato YYYY-MM-DD
        DateTime birthDate = DateFormat(
          'yyyy-MM-dd',
        ).parse(usuario.fechaNacimiento);
        birthDateFormatted = DateFormat('dd/MM/yyyy').format(birthDate);
      } catch (e) {
        print(
          "Error formateando fecha para UI: ${usuario.fechaNacimiento} - $e",
        );
        birthDateFormatted =
            usuario.fechaNacimiento; // Mostrar como está si no se puede parsear
      }
    }

    return GestureDetector(
      onTap: () {
        if (usuario.idUsuario != null) {
          Asistencia asistenciaParaDialogo =
              asistencia ??
              _crearNuevaAsistenciaActiva(
                usuario.idUsuario!,
                DateTime.now().subtract(
                  Duration(days: DateTime.now().weekday - 1),
                ),
                DateTime.now()
                    .subtract(Duration(days: DateTime.now().weekday - 1))
                    .add(const Duration(days: 6)),
              );
          _showAttendanceDialog(usuario, asistenciaParaDialogo);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error: ID de usuario no disponible."),
            ),
          );
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(
              top: hasAttendanceDataForDisplay ? markerRowHeight / 2.5 : 0,
            ),
            child: Card(
              margin: const EdgeInsets.symmetric(
                horizontal: 12.0,
                vertical: 8.0,
              ),
              elevation: 3.0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 12.0,
                  right: 12.0,
                  bottom: 12.0,
                  top:
                      hasAttendanceDataForDisplay
                          ? markerRowHeight / 2.8
                          : 12.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor:
                              Theme.of(context).colorScheme.secondaryContainer,
                          child: Text(
                            _getInitials(name),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(
                                    context,
                                  ).colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12.0),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2.0),
                              // Texto de Fecha de Nacimiento y Edad
                              Text(
                                age != null
                                    ? '$birthDateFormatted (Edad: $age)' // <--- NUEVO FORMATO
                                    : (usuario.fechaNacimiento.isNotEmpty
                                        ? '$birthDateFormatted (Edad: N/A)'
                                        : 'Edad: N/A'),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              Text(
                                'Sexo: ${usuario.tipoSexo}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                ),
                              ),
                              // Text('Teléfono Acudiente: $guardianPhone', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(
                                    Icons.edit,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 30,
                                  ),
                                  onPressed: () => _openUserFormModal(usuario),
                                  tooltip: 'Editar $name',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                                const SizedBox(width: 4),
                                if (usuario.idUsuario != null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.delete,
                                      color:
                                          Theme.of(context).colorScheme.error,
                                      size: 30,
                                    ),
                                    onPressed:
                                        () => _showDeleteConfirmationDialog(
                                          usuario.idUsuario!,
                                        ),
                                    tooltip: 'Eliminar $name',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasAttendanceDataForDisplay)
            Positioned(
              top: 0,
              left: 15.0,
              right: 15.0,
              height: markerRowHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children:
                        _attendanceActivityOrder.map((activityName) {
                          final status =
                              currentAttendanceMapForUI[activityName];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 2.0,
                            ),
                            child: _buildAttendanceMarker(status),
                          );
                        }).toList(),
                  ),
                  percentageWidget,
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAttendanceMarker(String? status) {
    Color textColor = Colors.white;
    String displayText = status ?? '-';
    switch (status) {
      case 'A':
        displayText = 'A';
        textColor = Colors.greenAccent;
        break;
      case 'E':
        displayText = 'E';
        textColor = Colors.yellowAccent;
        break;
      case 'N':
        displayText = 'N';
        textColor = Colors.redAccent;
        break;
      case 'T':
        displayText = 'T';
        textColor = Colors.lightBlueAccent;
        break;
      default:
        displayText = '-';
        textColor = Colors.grey[400]!;
    }
    return SizedBox(
      width: 50,
      height: 50,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Image.asset(
            'assets/hexagono.png',
            fit: BoxFit.contain,
          ), // Asegúrate que 'hexagono.png' exista
          Text(
            displayText,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
              shadows: const [
                Shadow(
                  offset: Offset(0.5, 0.5),
                  blurRadius: 1.0,
                  color: Color.fromARGB(150, 0, 0, 0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openUserFormModal(Usuario? usuarioToEdit) async {
    final bool isEditing = usuarioToEdit != null;
    final formKeyDialog = GlobalKey<FormState>();

    // Mueve la creación de los controladores aquí, fuera del builder
    final namesController = TextEditingController(
      text: isEditing ? usuarioToEdit.nombreCompleto : '',
    );
    final birthDateController = TextEditingController(
      text: isEditing ? usuarioToEdit.fechaNacimiento : '',
    );
    final List<String> genderOptions = ['Masculino', 'Femenino', 'Otro'];
    String? selectedGender = isEditing ? usuarioToEdit.tipoSexo : null;
    if (isEditing && !genderOptions.contains(selectedGender)) {
      selectedGender = null;
    }

    // El showDialog ahora no necesita devolver Usuario, ya que la acción se hace dentro
    // y luego se refresca.
    await showDialog<void>(
      // Cambiado a showDialog<void>
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Los controladores ya están creados fuera, los usamos aquí
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Editar Usuario' : 'Agregar Nuevo Usuario',
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: formKeyDialog,
                  child: Column(
                    // ... (tu contenido de Form con los TextFormFields usando namesController, birthDateController, etc.)
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: namesController,
                        decoration: const InputDecoration(
                          labelText: 'Nombres y Apellidos',
                        ),
                        validator:
                            (value) =>
                                (value == null || value.isEmpty)
                                    ? 'Campo requerido'
                                    : null,
                      ),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Sexo'),
                        value: selectedGender,
                        items:
                            genderOptions
                                .map(
                                  (String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (String? newValue) =>
                                setStateDialog(() => selectedGender = newValue),
                        validator:
                            (value) => value == null ? 'Campo requerido' : null,
                      ),
                      TextFormField(
                        controller: birthDateController,
                        decoration: const InputDecoration(
                          labelText: 'Fecha Nacimiento (YYYY-MM-DD)',
                          hintText: 'YYYY-MM-DD',
                        ),
                        readOnly: true,
                        onTap: () async {
                          FocusScope.of(context).requestFocus(FocusNode());
                          DateTime initial = DateTime.now();
                          if (birthDateController.text.isNotEmpty) {
                            try {
                              initial = DateFormat(
                                'yyyy-MM-dd',
                              ).parse(birthDateController.text);
                            } catch (_) {}
                          }
                          DateTime? pickedDate = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: DateTime(1900),
                            lastDate: DateTime.now(),
                          );
                          if (pickedDate != null) {
                            birthDateController.text = DateFormat(
                              'yyyy-MM-dd',
                            ).format(pickedDate);
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty)
                            return 'Campo requerido';
                          try {
                            DateFormat('yyyy-MM-dd').parseStrict(value);
                            return null;
                          } catch (e) {
                            return 'Formato: YYYY-MM-DD';
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () {
                    // No necesitas dispose aquí si se hace después del showDialog
                    Navigator.of(dialogContext).pop();
                  },
                ),
                TextButton(
                  child: Text(isEditing ? 'Guardar Cambios' : 'Crear Usuario'),
                  onPressed: () async {
                    if (formKeyDialog.currentState!.validate()) {
                      final usuario = Usuario(
                        idUsuario: isEditing ? usuarioToEdit!.idUsuario : null,
                        nombreCompleto: namesController.text.trim(),
                        tipoSexo: selectedGender!,
                        fechaNacimiento: birthDateController.text.trim(),
                      );
                      bool success = false;
                      try {
                        if (isEditing) {
                          await AsistenciaDatabase.instance.updateUsuario(
                            usuario,
                          );
                        } else {
                          await AsistenciaDatabase.instance.createUsuario(
                            usuario,
                          );
                        }
                        success = true; // Marcar como éxito
                        Navigator.of(
                          dialogContext,
                        ).pop(); // Cerrar diálogo ANTES de operaciones de UI

                        // Mostrar SnackBar y refrescar DESPUÉS de que el diálogo se cierre
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Usuario ${isEditing ? "actualizado" : "creado"}',
                            ),
                          ),
                        );
                        _refreshUsuarios(); // Refrescar la lista principal
                      } catch (e) {
                        Navigator.of(
                          dialogContext,
                        ).pop(); // Asegurarse de cerrar el diálogo en caso de error también
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error al guardar: $e')),
                        );
                      }
                      // El dispose se hará después de que showDialog se complete
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    ); // Fin de showDialog

    // Desechar los controladores DESPUÉS de que el diálogo se haya cerrado completamente.
    namesController.dispose();
    birthDateController.dispose();

    // Ya no necesitas manejar 'resultUser' porque el refresh y SnackBar se hacen dentro del onPressed
    // if (resultUser != null) { ... } // Esta parte ya no es necesaria
  }

  Future<void> _showDeleteConfirmationDialog(int usuarioId) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Eliminación'),
          content: const Text(
            '¿Estás seguro de que deseas eliminar este usuario? Esta acción no se puede deshacer.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(false),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('Eliminar'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // TODO: Considerar eliminar asistencias asociadas o manejar la restricción de clave foránea.
        await AsistenciaDatabase.instance.deleteUsuario(usuarioId);
        _refreshUsuarios();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Usuario eliminado')));
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      }
    }
  }

  Future<void> _showAttendanceDialog(
    Usuario usuario,
    Asistencia asistenciaActual,
  ) async {
    // asistenciaActual es el estado de la DB o uno nuevo vacío para la semana.
    // Hacemos una copia para trabajar sobre ella y detectar cambios.
    Asistencia asistenciaParaEditar = asistenciaActual.copyWith();

    // Estados iniciales de las asistencias al abrir el diálogo.
    // Estos no cambiarán durante la vida del diálogo.
    final List<String> initialAttendanceValuesOnDialogOpen = [
      asistenciaActual
          .consagracionDomingo, // Usar asistenciaActual para los valores originales
      asistenciaActual.escuelaDominical,
      asistenciaActual.ensayoMartes,
      asistenciaActual.ensayoMiercoles,
      asistenciaActual.servicioJueves,
    ];

    // Estados que el usuario puede modificar DENTRO del diálogo.
    // Se inicializan con los valores actuales de asistenciaParaEditar.
    List<String?> selectedAttendances = [
      asistenciaParaEditar.consagracionDomingo,
      asistenciaParaEditar.escuelaDominical,
      asistenciaParaEditar.ensayoMartes,
      asistenciaParaEditar.ensayoMiercoles,
      asistenciaParaEditar.servicioJueves,
    ];

    // Convertir strings vacíos a null para la lógica del Dropdown (mostrar hint)
    for (int i = 0; i < selectedAttendances.length; i++) {
      if (selectedAttendances[i] != null && selectedAttendances[i]!.isEmpty) {
        selectedAttendances[i] = null;
      }
    }

    final additionalController1 = TextEditingController(
      text: asistenciaParaEditar.nombreExtraN1 ?? '',
    );
    final valueController1 = TextEditingController(
      text: asistenciaParaEditar.extraN1?.toString() ?? '',
    );
    final additionalController2 = TextEditingController(
      text: asistenciaParaEditar.nombreExtraN2 ?? '',
    );
    final valueController2 = TextEditingController(
      text: asistenciaParaEditar.extraN2?.toString() ?? '',
    );

    final attendanceOptions = _valoresNotasBase.keys.toList();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialogInDialog) {
            return AlertDialog(
              title: Text('Asistencia: ${usuario.nombreCompleto?.trim()}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Semana: ${DateFormat('dd/MM').format(asistenciaParaEditar.inicioSemana)} - ${DateFormat('dd/MM/yyyy').format(asistenciaParaEditar.finSemana)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_attendanceActivityOrder.length, (index) {
                      // Determinar si este campo específico es editable:
                      // Es editable si su valor original al abrir el diálogo estaba vacío.
                      bool isEditableThisField =
                          initialAttendanceValuesOnDialogOpen[index].isEmpty;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: _attendanceActivityOrder[index],
                            border: const OutlineInputBorder(),
                            filled:
                                !isEditableThisField, // Color de fondo si no es editable
                            fillColor:
                                !isEditableThisField ? Colors.grey[200] : null,
                          ),
                          // El valor actual del dropdown viene de selectedAttendances
                          value: selectedAttendances[index],
                          hint: const Text('Seleccionar'),
                          items:
                              attendanceOptions
                                  .map(
                                    (String option) => DropdownMenuItem<String>(
                                      value: option,
                                      child: Text(option),
                                    ),
                                  )
                                  .toList(),
                          onChanged:
                              isEditableThisField // Solo permitir cambios si es editable
                                  ? (String? newValue) {
                                    setStateDialogInDialog(() {
                                      selectedAttendances[index] = newValue;
                                    });
                                  }
                                  : null, // Deshabilitado si no es editable
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: additionalController1,
                      decoration: const InputDecoration(
                        labelText: 'Adicional 1 (Nombre)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextFormField(
                      controller: valueController1,
                      decoration: const InputDecoration(
                        labelText: 'Adicional 1 (Valor Nota)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: additionalController2,
                      decoration: const InputDecoration(
                        labelText: 'Adicional 2 (Nombre)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    TextFormField(
                      controller: valueController2,
                      decoration: const InputDecoration(
                        labelText: 'Adicional 2 (Valor Nota)',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment
                          .end, // Para alinear los botones a la derecha del diálogozzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
                  children: [
                    TextButton(
                      child: const Text('Cancelar'),
                      onPressed: () {
                        additionalController1.dispose();
                        valueController1.dispose();
                        additionalController2.dispose();
                        valueController2.dispose();
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                    TextButton(
                      child: const Text('Guardar Asistencia'),
                      onPressed: () async {
                        int calculatedTotal = 0;
                        bool allMainActivitiesFilled = true;

                        if (_valoresNotasBase.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Error: Valores base de notas no cargados.',
                              ),
                            ),
                          );
                          return;
                        }

                        // Variables para las nuevas fechas que se van a establecer
                        DateTime? nuevaFechaConsagracionD =
                            asistenciaParaEditar.fechaConsagracionD;
                        DateTime? nuevaFechaEscuelaD =
                            asistenciaParaEditar.fechaEscuelaD;
                        DateTime? nuevaFechaEnsayoMartes =
                            asistenciaParaEditar.fechaEnsayoMartes;
                        DateTime? nuevaFechaEnsayoMiercoles =
                            asistenciaParaEditar.fechaEnsayoMiercoles;
                        DateTime? nuevaFechaServicioJueves =
                            asistenciaParaEditar.fechaServicioJueves;

                        final now = DateTime.now();

                        // Mapeo para acceder a las fechas fácilmente
                        List<Function(DateTime?)> dateSetters = [
                          (dt) => nuevaFechaConsagracionD = dt,
                          (dt) => nuevaFechaEscuelaD = dt,
                          (dt) => nuevaFechaEnsayoMartes = dt,
                          (dt) => nuevaFechaEnsayoMiercoles = dt,
                          (dt) => nuevaFechaServicioJueves = dt,
                        ];
                        List<DateTime?> currentDates = [
                          asistenciaParaEditar.fechaConsagracionD,
                          asistenciaParaEditar.fechaEscuelaD,
                          asistenciaParaEditar.fechaEnsayoMartes,
                          asistenciaParaEditar.fechaEnsayoMiercoles,
                          asistenciaParaEditar.fechaServicioJueves,
                        ];

                        for (int i = 0; i < selectedAttendances.length; i++) {
                          final status = selectedAttendances[i];
                          if (status != null && status.isNotEmpty) {
                            calculatedTotal += _valoresNotasBase[status] ?? 0;
                            // Si este campo de asistencia tiene un valor Y su fecha correspondiente aún no estaba establecida,
                            // establece la fecha a DateTime.now().
                            if (currentDates[i] == null) {
                              // Solo establece la fecha si era null (primera vez que se registra esta actividad)
                              dateSetters[i](now);
                            }
                          } else {
                            allMainActivitiesFilled = false;
                            // Opcional: si se borra un valor de asistencia, ¿quieres borrar también la fecha?
                            // dateSetters[i](null);
                          }
                        }
                        calculatedTotal +=
                            (int.tryParse(valueController1.text) ?? 0);
                        calculatedTotal +=
                            (int.tryParse(valueController2.text) ?? 0);

                        String nuevoEstado =
                            allMainActivitiesFilled ? 'finalizado' : 'activo';

                        asistenciaParaEditar = asistenciaParaEditar.copyWith(
                          consagracionDomingo: selectedAttendances[0] ?? "",
                          fechaConsagracionD:
                              nuevaFechaConsagracionD, // Usar la fecha actualizada
                          escuelaDominical: selectedAttendances[1] ?? "",
                          fechaEscuelaD: nuevaFechaEscuelaD,
                          ensayoMartes: selectedAttendances[2] ?? "",
                          fechaEnsayoMartes: nuevaFechaEnsayoMartes,
                          ensayoMiercoles: selectedAttendances[3] ?? "",
                          fechaEnsayoMiercoles: nuevaFechaEnsayoMiercoles,
                          servicioJueves: selectedAttendances[4] ?? "",
                          fechaServicioJueves: nuevaFechaServicioJueves,
                          totalAsistencia: calculatedTotal,
                          nombreExtraN1:
                              additionalController1.text.trim().isNotEmpty
                                  ? additionalController1.text.trim()
                                  : null,
                          extraN1: int.tryParse(valueController1.text),
                          nombreExtraN2:
                              additionalController2.text.trim().isNotEmpty
                                  ? additionalController2.text.trim()
                                  : null,
                          extraN2: int.tryParse(valueController2.text),
                          estado: nuevoEstado,
                        );

                        try {
                          if (asistenciaParaEditar.idAsistencia != null) {
                            await AsistenciaDatabase.instance.updateAsistencia(
                              asistenciaParaEditar,
                            );
                          } else {
                            await AsistenciaDatabase.instance.createAsistencia(
                              asistenciaParaEditar,
                            );
                          }
                          Navigator.of(dialogContext).pop();
                          _refreshUsuarios();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Asistencia guardada para ${usuario.nombreCompleto}',
                              ),
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error al guardar asistencia: $e'),
                            ),
                          );
                        } finally {
                          additionalController1.dispose();
                          valueController1.dispose();
                          additionalController2.dispose();
                          valueController2.dispose();
                        }
                      },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- NUEVO MÉTODO PARA EL DIÁLOGO DE AUTORIZACIÓN ---
  Future<void> _showAuthorizationDialog(BuildContext scaffoldContext) async {
    final TextEditingController passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isPasswordBlocked = _loginAttempts >= _maxLoginAttempts;
    bool passwordIsVisible =
        false; // Variable para controlar la visibilidad de la contraseña

    _loginAttempts = 0;
    try {
      final autorizaciones =
          await AsistenciaDatabase.instance.readAllAutorizaciones();
      if (autorizaciones.isNotEmpty) {
        Autorizaciones authToUpdate = autorizaciones.first.copyWith(
          intentos: 0,
        );
        await AsistenciaDatabase.instance.updateAutorizacion(authToUpdate);
        print(
          "Intentos en DB reseteados a 0 al abrir diálogo de autorización en home.",
        );
      }
    } catch (e) {
      print("Error reseteando intentos en DB (home auth): $e");
    }

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            isPasswordBlocked = _loginAttempts >= _maxLoginAttempts;

            return AlertDialog(
              title: const Text('Autorización Requerida'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      if (isPasswordBlocked)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10.0),
                          child: Text(
                            'Demasiados intentos fallidos.',
                            style: TextStyle(
                              color: Theme.of(dialogContext).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      TextFormField(
                        controller: passwordController,
                        obscureText:
                            !passwordIsVisible, // <--- USA LA VARIABLE DE VISIBILIDAD
                        decoration: InputDecoration(
                          labelText: 'Contraseña',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            // <--- AÑADIR SUFFIX ICON
                            icon: Icon(
                              passwordIsVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                // Usa el setState del StatefulBuilder del diálogo
                                passwordIsVisible = !passwordIsVisible;
                              });
                            },
                          ),
                        ),
                        enabled: !isPasswordBlocked,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingrese la contraseña';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      child: const Text('Cancelar'),
                      onPressed: () {
                        passwordController.dispose();
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      child: const Text('Verificar'),
                      onPressed:
                          isPasswordBlocked
                              ? null
                              : () async {
                                if (formKey.currentState!.validate()) {
                                  final enteredPassword =
                                      passwordController.text;
                                  final bytes = utf8.encode(enteredPassword);
                                  final digest = md5.convert(bytes);
                                  final enteredPasswordMd5 = digest.toString();

                                  final autorizaciones =
                                      await AsistenciaDatabase.instance
                                          .readAllAutorizaciones();
                                  final navigatorInstanceDialog = Navigator.of(
                                    dialogContext,
                                  ); // Capturar
                                  final scaffoldMessengerInstance =
                                      ScaffoldMessenger.of(
                                        scaffoldContext,
                                      ); // Capturar

                                  if (autorizaciones.isEmpty) {
                                    if (!mounted) return;
                                    scaffoldMessengerInstance.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Error: No hay contraseñas configuradas.',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  final storedAuth = autorizaciones.first;

                                  if (enteredPasswordMd5 ==
                                      storedAuth.contrasena) {
                                    passwordController.dispose();
                                    if (!mounted) return;
                                    navigatorInstanceDialog.pop();

                                    try {
                                      Autorizaciones authToUpdate = storedAuth
                                          .copyWith(intentos: 0);
                                      await AsistenciaDatabase.instance
                                          .updateAutorizacion(authToUpdate);
                                    } catch (e) {
                                      print(
                                        "Error reseteando intentos en DB (login exitoso home): $e",
                                      );
                                    }

                                    if (!mounted) return;
                                    final result = await Navigator.push<bool>(
                                      // Espera un booleano
                                      scaffoldContext,
                                      MaterialPageRoute(
                                        builder: (_) => const EditorScreen(),
                                      ),
                                    );

                                    // Si EditorScreen devolvió true (o cualquier valor que uses para indicar cambios), refresca.
                                    if (result == true) {
                                      if (mounted) {
                                        // Verificar mounted de _UserListScreenState
                                        _refreshUsuarios();
                                      }
                                    }
                                  } else {
                                    _loginAttempts++;
                                    try {
                                      Autorizaciones authToUpdate = storedAuth
                                          .copyWith(
                                            intentos: storedAuth.intentos + 1,
                                          );
                                      await AsistenciaDatabase.instance
                                          .updateAutorizacion(authToUpdate);
                                    } catch (e) {
                                      print(
                                        "Error actualizando intentos en DB (home): $e",
                                      );
                                    }

                                    setStateDialog(() {
                                      isPasswordBlocked =
                                          _loginAttempts >= _maxLoginAttempts;
                                    });
                                    if (!mounted) return;
                                    scaffoldMessengerInstance.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Contraseña incorrecta. Intentos restantes: ${_maxLoginAttempts - _loginAttempts}',
                                        ),
                                      ),
                                    );
                                    if (isPasswordBlocked) {
                                      if (!mounted) return;
                                      scaffoldMessengerInstance.showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Campo de contraseña bloqueado.',
                                            style: TextStyle(
                                              color:
                                                  Theme.of(
                                                    dialogContext,
                                                  ).colorScheme.error,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                }
                              },
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}
