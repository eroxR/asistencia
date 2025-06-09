import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; // Para formatear fechas

// IMPORTA TUS MODELOS Y LA CLASE DE BASE DE DATOS
import 'package:asistencia/models/model.dart'; // Ajusta la ruta si es diferente
import 'package:asistencia/database/asistencia_database.dart'; // Ajusta la ruta

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  List<Usuario> _usuarios = [];
  Map<int, Asistencia> _asistenciasSemanales = {}; // Clave: idUsuario
  Map<String, int> _valoresNotasBase = {}; // Clave: 'A', 'E', 'N', 'T'
  bool _isLoading = true;

  final List<String> _attendanceActivityOrder = [
    'Consagración Domingo',
    'Escuela Dominical',
    'Ensayo Martes',
    'Ensayo Miércoles',
    'Servicio Jueves',
  ];

  // Mapeo de etiquetas de UI a nombres de campo en el modelo Asistencia
  final Map<String, String> _activityToFieldMapping = {
    'Consagración Domingo': 'consagracionDomingo',
    'Escuela Dominical': 'escuelaDominical',
    'Ensayo Martes': 'ensayoMartes',
    'Ensayo Miércoles': 'ensayoMiercoles',
    'Servicio Jueves': 'servicioJueves',
  };

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _refreshUsuarios();
    await _loadValoresNotasBase(); // Cargar valores de notas para cálculos
  }

  Future<void> _loadValoresNotasBase() async {
    final notas = await AsistenciaDatabase.instance.readAllNotaAsistenciat();

    // El mapa temporal donde guardaremos los valores como enteros.
    Map<String, int> tempValores = {};

    for (var nota in notas) {
      if (nota.idNota != null) {
        int valorEntero = nota.valorNota ?? 0;
        tempValores[nota.idNota!] = valorEntero;
      }
    }

    // Actualiza el estado si el widget todavía está montado.
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

    // Determinar inicio y fin de la semana actual
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    for (var usuario in usuariosFromDB) {
      if (usuario.idUsuario != null) {
        // TODO: Implementar una consulta más eficiente para obtener la asistencia de la semana actual
        // por usuarioId y rango de fechas (inicioSemana, finSemana).
        // Por ahora, leemos todas y filtramos.
        final todasLasAsistencias =
            await AsistenciaDatabase.instance.readAllAsistencias();
        final asistenciaSemanal = todasLasAsistencias.firstWhere(
          (a) =>
              a.usuarioId == usuario.idUsuario &&
              !a.inicioSemana.isBefore(startOfWeek) &&
              !a.finSemana.isAfter(endOfWeek),
          orElse:
              () => _crearAsistenciaVaciaParaSemana(
                usuario.idUsuario!,
                startOfWeek,
                endOfWeek,
              ), // Devuelve un placeholder si no se encuentra
        );
        asistenciasTemp[usuario.idUsuario!] = asistenciaSemanal;
      }
    }

    if (mounted) {
      setState(() {
        _usuarios = usuariosFromDB;
        _asistenciasSemanales = asistenciasTemp;
        _isLoading = false;
      });
    }
  }

  // Helper para crear un objeto Asistencia vacío para la semana si no existe
  Asistencia _crearAsistenciaVaciaParaSemana(
    int usuarioId,
    DateTime inicioSemana,
    DateTime finSemana,
  ) {
    return Asistencia(
      usuarioId: usuarioId,
      consagracionDomingo: "", // O null si tu modelo y UI lo manejan
      fechaConsagracionD: inicioSemana, // O una fecha específica del día
      escuelaDominical: "",
      fechaEscuelaD: inicioSemana,
      ensayoMartes: "",
      fechaEnsayoMartes: inicioSemana,
      ensayoMiercoles: "",
      fechaEnsayoMiercoles: inicioSemana,
      servicioJueves: "",
      fechaServicioJueves: inicioSemana,
      totalAsistencia: 0,
      inicioSemana: inicioSemana,
      finSemana: finSemana,
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
        title: const Text('Lista de Usuarios'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
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
                          ? _asistenciasSemanales[usuario.idUsuario!]
                          : null;
                  return _buildUserListItem(usuario, asistencia);
                },
              ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openUserFormModal(null),
        tooltip: 'Agregar Usuario',
        child: const Icon(Icons.add),
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
                    color: Colors.green[900],
                  ),
                ),
              ],
            )
            : const SizedBox.shrink();

    final String name = usuario.nombreCompleto ?? 'Sin Nombre';
    final int? age = _calculateAge(usuario.fechaNacimiento);
    // Los campos de acudiente no están en el modelo Usuario.
    // Si los necesitas, debes añadirlos al modelo y la base de datos.
    // final String guardianPhone = "N/A"; // Placeholder

    return GestureDetector(
      onTap: () {
        if (usuario.idUsuario != null) {
          _showAttendanceDialog(
            usuario,
            asistencia ??
                _crearAsistenciaVaciaParaSemana(
                  usuario.idUsuario!,
                  DateTime.now().subtract(
                    Duration(days: DateTime.now().weekday - 1),
                  ),
                  DateTime.now()
                      .subtract(Duration(days: DateTime.now().weekday - 1))
                      .add(const Duration(days: 6)),
                ),
          );
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
                              Text(
                                age != null
                                    ? 'fecha y edad ${usuario.fechaNacimiento} $age'
                                    : 'Edad: N/A',
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
    // Copia de asistenciaActual para no modificar el estado directamente hasta guardar
    Asistencia asistenciaParaEditar = asistenciaActual.copyWith();

    List<String?> selectedAttendances = [
      asistenciaParaEditar.consagracionDomingo,
      asistenciaParaEditar.escuelaDominical,
      asistenciaParaEditar.ensayoMartes,
      asistenciaParaEditar.ensayoMiercoles,
      asistenciaParaEditar.servicioJueves,
    ];

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

    final attendanceOptions =
        _valoresNotasBase.keys.toList(); // ['A', 'E', 'N', 'T']

    await showDialog<void>(
      context: context,
      barrierDismissible: false, // Para evitar cierres accidentales
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialogInDialog) {
            // Renombrar setStateDialog
            return AlertDialog(
              title: Text('Registrar Asistencia: ${usuario.nombreCompleto}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Semana: ${DateFormat('dd/MM').format(asistenciaParaEditar.inicioSemana)} - ${DateFormat('dd/MM/yyyy').format(asistenciaParaEditar.finSemana)}',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    ...List.generate(_attendanceActivityOrder.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: _attendanceActivityOrder[index],
                            border: const OutlineInputBorder(),
                          ),
                          value:
                              selectedAttendances[index]?.isEmpty ?? true
                                  ? null
                                  : selectedAttendances[index], // Para mostrar hint si está vacío
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
                          onChanged: (String? newValue) {
                            setStateDialogInDialog(() {
                              selectedAttendances[index] = newValue;
                            });
                          },
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
                    if (_valoresNotasBase.isNotEmpty) {
                      for (int i = 0; i < selectedAttendances.length; i++) {
                        final status = selectedAttendances[i];
                        if (status != null && status.isNotEmpty) {
                          calculatedTotal += _valoresNotasBase[status] ?? 0;
                        }
                      }
                      calculatedTotal +=
                          (int.tryParse(valueController1.text) ?? 0);
                      calculatedTotal +=
                          (int.tryParse(valueController2.text) ?? 0);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Error: Valores base de notas no cargados.',
                          ),
                        ),
                      );
                      return; // Salir si no hay valores base
                    }

                    asistenciaParaEditar = asistenciaParaEditar.copyWith(
                      consagracionDomingo: selectedAttendances[0] ?? "",
                      escuelaDominical: selectedAttendances[1] ?? "",
                      ensayoMartes: selectedAttendances[2] ?? "",
                      ensayoMiercoles: selectedAttendances[3] ?? "",
                      servicioJueves: selectedAttendances[4] ?? "",
                      // Las fechas de cada actividad se podrían actualizar aquí si tuvieras DatePickers para ellas
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
                    );

                    try {
                      if (asistenciaParaEditar.idAsistencia != null) {
                        await AsistenciaDatabase.instance.updateAsistencia(
                          asistenciaParaEditar,
                        );
                      } else {
                        // Crear nueva asistencia, asegúrate que usuarioId y fechas de semana estén bien.
                        await AsistenciaDatabase.instance.createAsistencia(
                          asistenciaParaEditar,
                        );
                      }
                      Navigator.of(dialogContext).pop();
                      _refreshUsuarios(); // Recarga todo para reflejar cambios
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Asistencia guardada exitosamente'),
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
            );
          },
        );
      },
    );
  }
}


//_____________________________________________prueba_______________________________________________________________________________________________________________________________________


// import 'package:flutter/material.dart';
// import 'package:uuid/uuid.dart'; // Añade esta dependencia en tu pubspec.yaml
// import 'package:flutter/services.dart';

// /// --- User Model ---
// class User {
//   final String id;
//   final String name;
//   final String gender;
//   final int? age;
//   final String guardianName;
//   final String guardianPhone;
//   final String? imageUrl;

//   // NUEVO: Mapa para almacenar la asistencia por materia/actividad
//   // La clave será el nombre de la actividad (ej: 'Consagración Domingo')
//   // El valor será la asistencia ('A', 'E', 'N', 'T', o null si no se ha registrado)
//   Map<String, String?>
//   attendanceData; // Ejemplo: {'Consagración Domingo': 'A', ...}
//   String? additionalInfo1;
//   double? valueInfo1;
//   String? additionalInfo2;
//   double? valueInfo2;

//   User({
//     required this.id,
//     required this.name,
//     required this.gender,
//     required this.age,
//     required this.guardianName,
//     required this.guardianPhone,
//     this.imageUrl,
//     Map<String, String?>?
//     attendanceData, // Hacerlo opcional y proveer un valor por defecto
//     this.additionalInfo1,
//     this.valueInfo1,
//     this.additionalInfo2,
//     this.valueInfo2,
//   }) : this.attendanceData =
//            attendanceData ?? {}; // Inicializar como mapa vacío si es null

//   String get initials {
//     if (name.isEmpty) return '?';
//     final parts = name.split(' ').where((part) => part.isNotEmpty).toList();
//     if (parts.length >= 2) {
//       return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
//     } else if (parts.isNotEmpty) {
//       return parts[0][0].toUpperCase();
//     }
//     return '?';
//   }

//   // Helper para crear una copia con valores actualizados (inmutable)
//   User copyWith({
//     String? id,
//     String? name,
//     String? gender,
//     int? age,
//     String? guardianName,
//     String? guardianPhone,
//     String? imageUrl,
//     Map<String, String?>? attendanceData,
//     String? additionalInfo1,
//     double? valueInfo1,
//     String? additionalInfo2,
//     double? valueInfo2,
//   }) {
//     return User(
//       id: id ?? this.id,
//       name: name ?? this.name,
//       gender: gender ?? this.gender,
//       age: age ?? this.age,
//       guardianName: guardianName ?? this.guardianName,
//       guardianPhone: guardianPhone ?? this.guardianPhone,
//       imageUrl: imageUrl ?? this.imageUrl,
//       attendanceData: attendanceData ?? this.attendanceData,
//       additionalInfo1: additionalInfo1 ?? this.additionalInfo1,
//       valueInfo1: valueInfo1 ?? this.valueInfo1,
//       additionalInfo2: additionalInfo2 ?? this.additionalInfo2,
//       valueInfo2: valueInfo2 ?? this.valueInfo2,
//     );
//   }
// }

// // --- User List Screen Widget ---
// // This is the main screen that displays the list of users.
// class UserListScreen extends StatefulWidget {
//   const UserListScreen({super.key});

//   @override
//   State<UserListScreen> createState() => _UserListScreenState();
// }

// class _UserListScreenState extends State<UserListScreen> {
//   // Sample list of users. Updated to include new fields.
//   final List<User> _users = [
//     User(
//       id: '1',
//       name: 'Jose Galdamez',
//       gender: 'Masculino',
//       age: 25,
//       guardianName: 'Maria Rodriguez',
//       guardianPhone: '1234567',
//       // imageUrl: 'https://via.placeholder.com/150/FF0000/FFFFFF?Text=JG',
//     ),
//     User(
//       id: '2',
//       name: 'Martin Garcia',
//       gender: 'Masculino',
//       age: 30,
//       guardianName: 'Ana Perez',
//       guardianPhone: '9876543',
//     ),
//     User(
//       id: '3',
//       name: 'Mariela Perez',
//       gender: 'Femenino',
//       age: 22,
//       guardianName: 'Pedro Gomez',
//       guardianPhone: '4567890',
//       // imageUrl: 'https://via.placeholder.com/150/00FF00/FFFFFF?Text=MP',
//     ),
//     User(
//       id: '4',
//       name: 'Emilio Borjas',
//       gender: 'Masculino',
//       age: 18,
//       guardianName: 'Laura Torres',
//       guardianPhone: '3210987',
//     ),
//     User(
//       id: '5',
//       name: 'Jennifer Ramos',
//       gender: 'Femenino',
//       age: 28,
//       guardianName: 'Andres Castro',
//       guardianPhone: '6543210',
//     ),
//     User(
//       id: '6',
//       name: 'Carlos Acosta',
//       gender: 'Masculino',
//       age: 35,
//       guardianName: 'Sofia Vargas',
//       guardianPhone: '0987654',
//       // imageUrl: 'https://via.placeholder.com/150/0000FF/FFFFFF?Text=CA',
//     ),
//     User(
//       id: '7',
//       name: 'Ana Lopez',
//       gender: 'Femenino',
//       age: 20,
//       guardianName: 'David Herrera',
//       guardianPhone: '7654321',
//     ),
//   ];

//   // --- Build Method ---
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Lista de Usuarios'),
//         backgroundColor: Theme.of(context).colorScheme.primaryContainer,
//       ),
//       body: ListView.builder(
//         itemCount: _users.length,
//         itemBuilder: (context, index) {
//           final user = _users[index];
//           return _buildUserListItem(user);
//         },
//       ),
//       floatingActionButton: FloatingActionButton(
//         onPressed: () => _openUserFormModal(), // Llamada para AGREGAR
//         tooltip: 'Agregar Usuario',
//         child: const Icon(Icons.add),
//       ),
//     );
//   }

//   // ... (dentro de _UserListScreenState)

//   Widget _buildUserListItem(User user) {
//     final List<String> attendanceActivityOrder = [
//       'Consagración Domingo',
//       'Escuela Dominical',
//       'Ensayo Martes',
//       'Ensayo Miércoles',
//       'Servicio Jueves',
//     ];

//     double attendedScore = 0;
//     int activitiesWithData = 0;
//     if (user.attendanceData != null) {
//       for (String activityName in attendanceActivityOrder) {
//         final status = user.attendanceData[activityName];
//         if (status != null) {
//           activitiesWithData++;
//           if (status == 'A' || status == 'T') {
//             attendedScore += 1.0;
//           }
//         }
//       }
//     }
//     int percentage =
//         (activitiesWithData > 0)
//             ? ((attendedScore / activitiesWithData) * 100).round()
//             : 0;

//     const double markerRowHeight = 60.0;

//     // Widget para el porcentaje, para no repetirlo
//     Widget percentageWidget =
//         (activitiesWithData > 0)
//             ? Column(
//               mainAxisSize:
//                   MainAxisSize
//                       .min, // Para que no ocupe más espacio vertical del necesario
//               mainAxisAlignment:
//                   MainAxisAlignment
//                       .center, // Centrar verticalmente dentro de su espacio
//               crossAxisAlignment:
//                   CrossAxisAlignment.end, // Alinear texto a la derecha
//               children: [
//                 const Text(
//                   'Total',
//                   style: TextStyle(
//                     fontSize: 10,
//                     color: Colors.black,
//                     fontWeight: FontWeight.w700,
//                   ),
//                 ),
//                 Text(
//                   '$percentage%',
//                   style: TextStyle(
//                     fontWeight: FontWeight.bold,
//                     fontSize:
//                         22, // Podrías necesitar reducir esto un poco si el espacio es muy justo
//                     color: Colors.green[900],
//                   ),
//                 ),
//               ],
//             )
//             : const SizedBox.shrink(); // Si no hay datos, no mostrar nada

//     return GestureDetector(
//       onTap: () => _showAttendanceDialog(user),
//       child: Stack(
//         clipBehavior: Clip.none,
//         children: [
//           Padding(
//             padding: EdgeInsets.only(
//               top:
//                   (user.attendanceData != null &&
//                           user.attendanceData.isNotEmpty)
//                       ? markerRowHeight / 2.5
//                       : 0,
//             ),
//             child: Card(
//               margin: const EdgeInsets.symmetric(
//                 horizontal: 12.0,
//                 vertical: 8.0,
//               ),
//               elevation: 3.0,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(12.0),
//               ),
//               child: Padding(
//                 padding: EdgeInsets.only(
//                   left: 12.0,
//                   right: 12.0,
//                   bottom: 12.0,
//                   top:
//                       (user.attendanceData != null &&
//                               user.attendanceData.isNotEmpty)
//                           ? markerRowHeight /
//                               2.8 // Ajustado un poco para dar más espacio arriba si es necesario
//                           : 12.0,
//                 ),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     Row(
//                       crossAxisAlignment: CrossAxisAlignment.start,
//                       children: [
//                         CircleAvatar(
//                           radius: 28,
//                           backgroundColor:
//                               user.imageUrl == null
//                                   ? Theme.of(
//                                     context,
//                                   ).colorScheme.secondaryContainer
//                                   : Colors.transparent,
//                           backgroundImage:
//                               user.imageUrl != null
//                                   ? NetworkImage(user.imageUrl!)
//                                   : null,
//                           child:
//                               user.imageUrl == null
//                                   ? Text(
//                                     user.initials,
//                                     style: TextStyle(
//                                       fontSize: 18,
//                                       fontWeight: FontWeight.bold,
//                                       color:
//                                           Theme.of(
//                                             context,
//                                           ).colorScheme.onSecondaryContainer,
//                                     ),
//                                   )
//                                   : null,
//                         ),
//                         const SizedBox(width: 12.0),
//                         Expanded(
//                           child: Column(
//                             crossAxisAlignment: CrossAxisAlignment.start,
//                             children: [
//                               Text(
//                                 user.name,
//                                 style: const TextStyle(
//                                   fontWeight: FontWeight.bold,
//                                   fontSize: 15,
//                                 ),
//                               ),
//                               const SizedBox(height: 2.0),
//                               Text(
//                                 'Edad: ${user.age}',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[700],
//                                 ),
//                               ),
//                               Text(
//                                 'Teléfono Acudiente:',
//                                 style: TextStyle(
//                                   fontSize: 12,
//                                   color: Colors.grey[700],
//                                 ),
//                               ),
//                             ],
//                           ),
//                         ),
//                         const SizedBox(width: 8.0),
//                         // El porcentaje ya no va aquí, se movió a la fila de marcadores
//                         Column(
//                           // Esta columna ahora solo tiene los botones de acción
//                           mainAxisAlignment: MainAxisAlignment.start,
//                           crossAxisAlignment: CrossAxisAlignment.end,
//                           children: [
//                             // const SizedBox(height: markerRowHeight / 3), // Espacio si el porcentaje estaba aquí
//                             Row(
//                               mainAxisSize: MainAxisSize.min,
//                               children: [
//                                 IconButton(
//                                   icon: Icon(
//                                     Icons.edit,
//                                     color:
//                                         Theme.of(context).colorScheme.primary,
//                                     size: 30,
//                                   ),
//                                   onPressed:
//                                       () =>
//                                           _openUserFormModal(userToEdit: user),
//                                   tooltip: 'Editar ${user.name}',
//                                   padding: EdgeInsets.zero,
//                                   constraints: const BoxConstraints(),
//                                 ),
//                                 const SizedBox(width: 4),
//                                 IconButton(
//                                   icon: Icon(
//                                     Icons.delete,
//                                     color: Theme.of(context).colorScheme.error,
//                                     size: 30,
//                                   ),
//                                   onPressed:
//                                       () => _showDeleteConfirmationDialog(user),
//                                   tooltip: 'Eliminar ${user.name}',
//                                   padding: EdgeInsets.zero,
//                                   constraints: const BoxConstraints(),
//                                 ),
//                               ],
//                             ),
//                           ],
//                         ),
//                       ],
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ),

//           // --- FILA DE MARCADORES DE ASISTENCIA Y PORCENTAJE POSICIONADA ---
//           if (user.attendanceData != null && user.attendanceData.isNotEmpty)
//             Positioned(
//               top: 0,
//               left:
//                   15.0, // Ajusta para el inicio de toda la fila (marcadores + porcentaje)
//               right: 15.0, // Ajusta para el final de toda la fila
//               height: markerRowHeight,
//               child: Row(
//                 mainAxisAlignment:
//                     MainAxisAlignment
//                         .spaceBetween, // Para empujar el porcentaje al final
//                 crossAxisAlignment:
//                     CrossAxisAlignment.center, // Para alinear verticalmente
//                 children: [
//                   // Fila interna para los marcadores de asistencia
//                   Row(
//                     mainAxisSize:
//                         MainAxisSize
//                             .min, // Para que no ocupe más de lo necesario
//                     children:
//                         attendanceActivityOrder.map((activityName) {
//                           final status = user.attendanceData[activityName];
//                           // Podrías necesitar reducir el padding horizontal si el espacio es muy justo
//                           const double horizontalMarkerPadding =
//                               2.0; // Reduce si es necesario
//                           return Padding(
//                             padding: const EdgeInsets.symmetric(
//                               horizontal: horizontalMarkerPadding,
//                             ),
//                             child: _buildAttendanceMarker(status),
//                           );
//                         }).toList(),
//                   ),

//                   // Espaciador si es necesario, o deja que spaceBetween haga el trabajo
//                   // const Spacer(), // Descomenta si quieres empujar el porcentaje aún más

//                   // Widget del porcentaje
//                   percentageWidget,
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // _buildAttendanceMarker se mantiene igual
//   Widget _buildAttendanceMarker(String? status) {
//     Color textColor = Colors.white;
//     String displayText = status ?? '-';

//     switch (status) {
//       case 'A':
//         displayText = 'A';
//         textColor = Colors.greenAccent;
//         break;
//       case 'E':
//         displayText = 'E';
//         textColor = Colors.yellowAccent;
//         break;
//       case 'N':
//         displayText = 'N';
//         textColor = Colors.redAccent;
//         break;
//       case 'T':
//         displayText = 'T';
//         textColor = Colors.lightBlueAccent;
//         break;
//       default:
//         displayText = '-';
//         textColor = Colors.grey[400]!;
//     }

//     return SizedBox(
//       width: 50, // Podrías necesitar reducir el tamaño de los marcadores
//       height: 50, // Podrías necesitar reducir el tamaño de los marcadores
//       child: Stack(
//         alignment: Alignment.center,
//         children: <Widget>[
//           Image.asset('assets/hexagono.png', fit: BoxFit.contain),
//           Text(
//             displayText,
//             style: TextStyle(
//               color: textColor,
//               fontWeight: FontWeight.bold,
//               fontSize: 18, // Podrías necesitar reducir esto
//               shadows: const <Shadow>[
//                 Shadow(
//                   offset: Offset(0.5, 0.5),
//                   blurRadius: 1.0,
//                   color: Color.fromARGB(150, 0, 0, 0),
//                 ),
//               ],
//             ),
//             textAlign: TextAlign.center,
//           ),
//         ],
//       ),
//     );
//   }

//   // --- Method to open the User Form Modal (for Add or Edit) ---
//   Future<void> _openUserFormModal({User? userToEdit}) async {
//     final bool isEditing = userToEdit != null;

//     final List<String> _genderOptions = ['Masculino', 'Femenino', 'Otro'];

//     // El showDialog ahora devuelve el usuario creado o editado, o null si se cancela.
//     final User? resultUser = await showDialog<User>(
//       context: context,
//       barrierDismissible: false,
//       builder: (BuildContext dialogContext) {
//         // Clave del formulario, controladores y estado del género para ESTA instancia del diálogo
//         final formKeyDialog = GlobalKey<FormState>();
//         // Inicializar controladores con datos existentes si estamos editando
//         final namesControllerDialog = TextEditingController(
//           text: isEditing ? userToEdit.name : '',
//         );
//         final ageControllerDialog = TextEditingController(
//           text: isEditing ? userToEdit.age.toString() : '',
//         );
//         final guardianNameControllerDialog = TextEditingController(
//           text: isEditing ? userToEdit.guardianName : '',
//         );
//         final guardianPhoneControllerDialog = TextEditingController(
//           text: isEditing ? userToEdit.guardianPhone : '',
//         );
//         String? selectedGenderDialog = isEditing ? userToEdit.gender : null;

//         return StatefulBuilder(
//           builder: (BuildContext context, StateSetter setStateDialog) {
//             return AlertDialog(
//               title: Text(
//                 isEditing ? 'Editar Usuario' : 'Agregar Nuevo Usuario',
//               ),
//               content: SingleChildScrollView(
//                 child: Form(
//                   key: formKeyDialog,
//                   child: Column(
//                     mainAxisSize: MainAxisSize.min,
//                     children: <Widget>[
//                       TextFormField(
//                         controller: namesControllerDialog,
//                         decoration: const InputDecoration(
//                           labelText: 'Nombres y Apellidos',
//                         ),
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'Por favor, ingresa nombres y apellidos';
//                           }
//                           return null;
//                         },
//                       ),
//                       DropdownButtonFormField<String>(
//                         decoration: const InputDecoration(
//                           labelText: 'Tipo de Sexo',
//                         ),
//                         value: selectedGenderDialog,
//                         items:
//                             _genderOptions.map((String gender) {
//                               return DropdownMenuItem<String>(
//                                 value: gender,
//                                 child: Text(gender),
//                               );
//                             }).toList(),
//                         onChanged: (String? newValue) {
//                           setStateDialog(() {
//                             selectedGenderDialog = newValue;
//                           });
//                         },
//                         validator: (value) {
//                           if (value == null) {
//                             return 'Por favor, selecciona el sexo';
//                           }
//                           return null;
//                         },
//                       ),
//                       TextFormField(
//                         controller: ageControllerDialog,
//                         decoration: const InputDecoration(labelText: 'Edad'),
//                         keyboardType: TextInputType.number,
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'Por favor, ingresa la edad';
//                           }
//                           final age = int.tryParse(value);
//                           if (age == null || age <= 0) {
//                             return 'Ingresa una edad válida';
//                           }
//                           return null;
//                         },
//                       ),
//                       TextFormField(
//                         controller: guardianNameControllerDialog,
//                         decoration: const InputDecoration(
//                           labelText: 'Nombre Acudiente',
//                         ),
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'Por favor, ingresa el nombre del acudiente';
//                           }
//                           return null;
//                         },
//                       ),
//                       TextFormField(
//                         controller: guardianPhoneControllerDialog,
//                         decoration: const InputDecoration(
//                           labelText: 'Teléfono Acudiente',
//                         ),
//                         keyboardType: TextInputType.phone,
//                         validator: (value) {
//                           if (value == null || value.isEmpty) {
//                             return 'Por favor, ingresa el teléfono del acudiente';
//                           }
//                           return null;
//                         },
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//               actions: <Widget>[
//                 TextButton(
//                   child: const Text('Cancelar'),
//                   onPressed: () {
//                     namesControllerDialog.dispose();
//                     ageControllerDialog.dispose();
//                     guardianNameControllerDialog.dispose();
//                     guardianPhoneControllerDialog.dispose();
//                     Navigator.of(dialogContext).pop(); // No devuelve datos
//                   },
//                 ),
//                 TextButton(
//                   child: Text(isEditing ? 'Guardar Cambios' : 'Crear Usuario'),
//                   onPressed: () {
//                     if (formKeyDialog.currentState!.validate()) {
//                       final user = User(
//                         // Si estamos editando, usamos el ID existente. Sino, uno nuevo.
//                         id: isEditing ? userToEdit.id : const Uuid().v4(),
//                         name: namesControllerDialog.text.trim(),
//                         gender: selectedGenderDialog!,
//                         age: int.parse(ageControllerDialog.text.trim()),
//                         guardianName: guardianNameControllerDialog.text.trim(),
//                         guardianPhone:
//                             guardianPhoneControllerDialog.text.trim(),
//                         // Si estamos editando, conservamos la URL de la imagen existente.
//                         // Si quisieras editar la imagen, necesitarías un campo para eso.
//                         imageUrl: isEditing ? userToEdit.imageUrl : null,
//                       );
//                       namesControllerDialog.dispose();
//                       ageControllerDialog.dispose();
//                       guardianNameControllerDialog.dispose();
//                       guardianPhoneControllerDialog.dispose();
//                       Navigator.of(
//                         dialogContext,
//                       ).pop(user); // Devolver el usuario creado/actualizado
//                     }
//                   },
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );

//     // Manejar el resultado del diálogo
//     if (resultUser != null) {
//       if (!mounted) return;

//       setState(() {
//         if (isEditing) {
//           // Si estábamos editando, encontrar y reemplazar el usuario en la lista
//           final index = _users.indexWhere((u) => u.id == resultUser.id);
//           if (index != -1) {
//             _users[index] = resultUser;
//           }
//         } else {
//           // Si no, es un nuevo usuario, así que lo agregamos
//           _users.add(resultUser);
//         }
//       });

//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(
//             isEditing
//                 ? 'Usuario "${resultUser.name}" actualizado exitosamente'
//                 : 'Usuario "${resultUser.name}" creado exitosamente',
//           ),
//           duration: const Duration(seconds: 2),
//         ),
//       );
//     }
//   }

//   // --- Helper Method to Show Delete Confirmation ---
//   Future<void> _showDeleteConfirmationDialog(User user) async {
//     return showDialog<void>(
//       context: context,
//       barrierDismissible: false, // User must tap button!
//       builder: (BuildContext dialogContext) {
//         return AlertDialog(
//           title: const Text('Confirmar Eliminación'),
//           content: SingleChildScrollView(
//             child: ListBody(
//               children: <Widget>[
//                 Text('¿Estás seguro de que deseas eliminar a ${user.name}?'),
//               ],
//             ),
//           ),
//           actions: <Widget>[
//             TextButton(
//               child: const Text('Cancelar'),
//               onPressed: () {
//                 Navigator.of(dialogContext).pop();
//               },
//             ),
//             TextButton(
//               style: TextButton.styleFrom(
//                 foregroundColor: Theme.of(context).colorScheme.error,
//               ),
//               child: const Text('Eliminar'),
//               onPressed: () {
//                 if (!mounted) return;
//                 setState(() {
//                   _users.removeWhere((u) => u.id == user.id);
//                 });
//                 Navigator.of(dialogContext).pop();
//                 if (!mounted) return;
//                 ScaffoldMessenger.of(context).showSnackBar(
//                   SnackBar(content: Text('${user.name} eliminado')),
//                 );
//               },
//             ),
//           ],
//         );
//       },
//     );
//   }

//   // ... (resto de la clase _UserListScreenState)

//   // ----- MÉTODO MODIFICADO PARA MOSTRAR EL DIÁLOGO DE ASISTENCIA -----
//   Future<void> _showAttendanceDialog(User user) async {
//     final List<String> attendanceOptions = ['A', 'E', 'N', 'T'];
//     final List<String> attendanceLabels = [
//       'Consagración Domingo',
//       'Escuela Dominical',
//       'Ensayo Martes',
//       'Ensayo Miércoles',
//       'Servicio Jueves',
//     ];

//     // Cargar asistencia existente y datos adicionales
//     List<String?> selectedAttendances = List.generate(
//       attendanceLabels.length,
//       (index) => user.attendanceData[attendanceLabels[index]],
//     );

//     final TextEditingController additionalController1 = TextEditingController(
//       text: user.additionalInfo1 ?? '',
//     );
//     final TextEditingController valueController1 = TextEditingController(
//       text: user.valueInfo1?.toString() ?? '',
//     );
//     final TextEditingController additionalController2 = TextEditingController(
//       text: user.additionalInfo2 ?? '',
//     );
//     final TextEditingController valueController2 = TextEditingController(
//       text: user.valueInfo2?.toString() ?? '',
//     );

//     await showDialog<void>(
//       context: context,
//       barrierDismissible: true,
//       builder: (BuildContext dialogContext) {
//         return StatefulBuilder(
//           builder: (context, StateSetter setStateDialog) {
//             return AlertDialog(
//               title: Text('Asistencia para ${user.name}'),
//               content: SingleChildScrollView(
//                 child: Column(
//                   mainAxisSize: MainAxisSize.min,
//                   children: <Widget>[
//                     ...List.generate(attendanceLabels.length, (index) {
//                       return Padding(
//                         padding: const EdgeInsets.symmetric(vertical: 8.0),
//                         child: DropdownButtonFormField<String>(
//                           decoration: InputDecoration(
//                             labelText: attendanceLabels[index],
//                             border: const OutlineInputBorder(),
//                           ),
//                           value: selectedAttendances[index],
//                           hint: const Text('Seleccionar'),
//                           items:
//                               attendanceOptions.map((String option) {
//                                 return DropdownMenuItem<String>(
//                                   value: option,
//                                   child: Text(option),
//                                 );
//                               }).toList(),
//                           onChanged: (String? newValue) {
//                             setStateDialog(() {
//                               selectedAttendances[index] = newValue;
//                             });
//                           },
//                         ),
//                       );
//                     }),
//                     const SizedBox(height: 16),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8.0),
//                       child: TextFormField(
//                         controller: additionalController1,
//                         decoration: const InputDecoration(
//                           labelText: 'Adicional',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.text,
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8.0),
//                       child: TextFormField(
//                         controller: valueController1,
//                         decoration: const InputDecoration(
//                           labelText: 'Valor',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.number,
//                         inputFormatters: <TextInputFormatter>[
//                           FilteringTextInputFormatter.allow(
//                             RegExp(r'^\d+\.?\d{0,2}'),
//                           ),
//                         ],
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8.0),
//                       child: TextFormField(
//                         controller: additionalController2,
//                         decoration: const InputDecoration(
//                           labelText: 'Adicional',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.text,
//                       ),
//                     ),
//                     Padding(
//                       padding: const EdgeInsets.symmetric(vertical: 8.0),
//                       child: TextFormField(
//                         controller: valueController2,
//                         decoration: const InputDecoration(
//                           labelText: 'Valor',
//                           border: OutlineInputBorder(),
//                         ),
//                         keyboardType: TextInputType.number,
//                         inputFormatters: <TextInputFormatter>[
//                           FilteringTextInputFormatter.allow(
//                             RegExp(r'^\d+\.?\d{0,2}'),
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               actions: <Widget>[
//                 TextButton(
//                   child: const Text('Cancelar'),
//                   onPressed: () {
//                     additionalController1.dispose();
//                     valueController1.dispose();
//                     additionalController2.dispose();
//                     valueController2.dispose();
//                     Navigator.of(dialogContext).pop();
//                   },
//                 ),
//                 TextButton(
//                   child: const Text('Guardar'),
//                   onPressed: () {
//                     final String ad1 = additionalController1.text;
//                     final String val1Str = valueController1.text;
//                     final String ad2 = additionalController2.text;
//                     final String val2Str = valueController2.text;
//                     final double? val1 = double.tryParse(val1Str);
//                     final double? val2 = double.tryParse(val2Str);

//                     // Crear el nuevo mapa de asistencia
//                     Map<String, String?> newAttendanceData = {};
//                     for (int i = 0; i < attendanceLabels.length; i++) {
//                       newAttendanceData[attendanceLabels[i]] =
//                           selectedAttendances[i];
//                     }

//                     // Actualizar el usuario en la lista _users
//                     final userIndex = _users.indexWhere((u) => u.id == user.id);
//                     if (userIndex != -1) {
//                       // Usar setState del _UserListScreenState para actualizar la UI de la lista
//                       setState(() {
//                         _users[userIndex] = _users[userIndex].copyWith(
//                           attendanceData: newAttendanceData,
//                           additionalInfo1: ad1.isNotEmpty ? ad1 : null,
//                           valueInfo1: val1,
//                           additionalInfo2: ad2.isNotEmpty ? ad2 : null,
//                           valueInfo2: val2,
//                         );
//                       });
//                     }

//                     additionalController1.dispose();
//                     valueController1.dispose();
//                     additionalController2.dispose();
//                     valueController2.dispose();
//                     Navigator.of(dialogContext).pop();

//                     if (!mounted) return;
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text('Datos para ${user.name} guardados.'),
//                         duration: const Duration(seconds: 2),
//                       ),
//                     );
//                   },
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }
// }



      // {
      //   'usuarioId': 1,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 85,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 2,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 90,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 3,
      //   'consagracionDomingo': 'T',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'N',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 95,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 4,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 80,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 5,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 75,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 6,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 70,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 7,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 65,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 8,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 60,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 9,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 55,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 10,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 50,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 11,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 45,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 12,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 40,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 13,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 35,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 14,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 30,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 15,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 25,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 16,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 20,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 17,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 15,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 18,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 10,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 19,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 5,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 20,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 0,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 21,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 85,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 22,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 90,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 23,
      //   'consagracionDomingo': 'T',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': "A",
      //   "fechaEscuelaD": "2023-12-01",
      //   "ensayoMartes": "A",
      //   "fechaEnsayoMartes": "2023-12-02",
      //   "ensayoMiercoles": "N",
      //   "fechaEnsayoMiercoles": "2023-12-03",
      //   "servicioJueves": "E",
      //   "fechaServicioJueves": "2023-12-04",
      //   "totalAsistencia": 95,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 24,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 80,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 25,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 75,
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 26,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'ensayoMiercoles': 'A',
      //   'fechaEnsayoMiercoles': '2023-12-03',
      //   'servicioJueves': 'E',
      //   'fechaServicioJueves': '2023-12-04',
      //   'totalAsistencia': 70,
      //   'inicioSemana': "2023-11-30",
      //   "finSemana": "2023-12-06",
      // },
      // {
      //   "usuarioId": 27,
      //   "consagracionDomingo": "A",
      //   "fechaConsagracionD": "2023-12-01",
      //   "escuelaDominical": "A",
      //   "fechaEscuelaD": "2023-12-01",
      //   "ensayoMartes": "A",
      //   "fechaEnsayoMartes": "2023-12-02",
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   "usuarioId": 28,
      //   "consagracionDomingo": "A",
      //   "fechaConsagracionD": "2023-12-01",
      //   "escuelaDominical": "A",
      //   "fechaEscuelaD": "2023-12-01",
      //   "ensayoMartes": "A",
      //   "fechaEnsayoMartes": "2023-12-02",
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 29,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },
      // {
      //   'usuarioId': 30,
      //   'consagracionDomingo': 'A',
      //   'fechaConsagracionD': '2023-12-01',
      //   'escuelaDominical': 'A',
      //   'fechaEscuelaD': '2023-12-01',
      //   'ensayoMartes': 'A',
      //   'fechaEnsayoMartes': '2023-12-02',
      //   'inicioSemana': '2023-11-30',
      //   'finSemana': '2023-12-06',
      // },