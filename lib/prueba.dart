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







//___________________________________________________________________________________________________________________________________________________________________________________________________________________________________________


// // historial.dart
// import 'dart:io'; // Para File
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:intl/intl.dart';
// import 'package:asistencia/models/model.dart'; // Ajusta la ruta
// import 'package:asistencia/database/asistencia_database.dart'; // Ajusta la ruta
// import 'package:font_awesome_flutter/font_awesome_flutter.dart';
// import 'package:asistencia/models/model.dart';

// // Imports para PDF
// import 'package:pdf/pdf.dart';
// import 'package:pdf/widgets.dart' as pw; // Usar un alias
// // import 'package:path_provider/path_provider.dart';
// import 'package:open_file/open_file.dart';
// // import 'package:permission_handler/permission_handler.dart';
// import 'package:file_picker/file_picker.dart'; // Importar file_picker
// import 'package:excel/excel.dart'; // Importar el paquete excel

// class HistorialScreen extends StatefulWidget {
//   const HistorialScreen({super.key});

//   @override
//   State<HistorialScreen> createState() => _HistorialScreenState();
// }

// class _HistorialScreenState extends State<HistorialScreen> {
//   bool _isLoading = true;
//   List<Usuario> _todosLosUsuarios = [];
//   List<Map<String, dynamic>> _asistenciasConNombreCompletas = [];
//   List<Map<String, dynamic>> _asistenciasConNombreFiltradas = [];

//   Usuario? _selectedUsuarioFiltro;
//   String? _selectedActividadFiltroValue;
//   String? _selectedActividadFiltroDisplay;
//   DateTimeRange? _selectedDateRangeFiltro;

//   String? _filtroPorcentajeActivo;

//   final Map<String, String> _activityUIToDBFieldMapping = {
//     'Consagración Domingo': 'consagracionDomingo',
//     'Escuela Dominical': 'escuelaDominical',
//     'Ensayo Martes': 'ensayoMartes',
//     'Ensayo Miércoles': 'ensayoMiercoles',
//     'Servicio Jueves': 'servicioJueves',
//   };

//   Map<String, bool> _columnVisibility = {
//     'usuario': true,
//     'tipoSexo': false,
//     'fechaNacimiento': false,
//     'consagracionDomingo': true,
//     'escuelaDominical': true,
//     'ensayoMartes': true,
//     'ensayoMiercoles': true,
//     'servicioJueves': true,
//     'totalAsistencia': true,
//     'nombreExtraN1': false,
//     'extraN1': false,
//     'nombreExtraN2': false,
//     'extraN2': false,
//     'inicioSemana': true,
//     'finSemana': true,
//     'estado': false,
//   };

//   final List<Map<String, String>> _allPossibleColumns = [
//     {'key': 'usuario', 'label': 'Usuario', 'dataKey': 'nombreUsuario'},
//     {
//       'key': 'tipoSexo',
//       'label': 'Sexo',
//       'dataKey': 'tipoSexo',
//     }, // Corto, podría no necesitar \n
//     {
//       'key': 'fechaNacimiento',
//       'label': 'Fecha\nNac.',
//       'dataKey': 'fechaNacimiento',
//     }, // Salto de línea
//     {
//       'key': 'consagracionDomingo',
//       'label': 'Cons.\nDomingo',
//       'dataKey': 'consagracionDomingo',
//     }, // Ejemplo
//     // O podrías quererlo más explícito si el espacio lo permite:
//     // {'key': 'consagracionDomingo', 'label': 'Consagración\nDomingo', 'dataKey': 'consagracionDomingo'},
//     {
//       'key': 'escuelaDominical',
//       'label': 'Escuela\nDomingo.',
//       'dataKey': 'escuelaDominical',
//     },
//     {
//       'key': 'ensayoMartes',
//       'label': 'Ensayo\nMartes',
//       'dataKey': 'ensayoMartes',
//     },
//     {
//       'key': 'ensayoMiercoles',
//       'label': 'Ensayo\nMiérc.',
//       'dataKey': 'ensayoMiercoles',
//     },
//     {
//       'key': 'servicioJueves',
//       'label': 'Servicio\nJueves',
//       'dataKey': 'servicioJueves',
//     },
//     {
//       'key': 'totalAsistencia',
//       'label': 'Total(%)',
//       'dataKey': 'totalAsistencia',
//     }, // Añadir (%) para claridad
//     {
//       'key': 'nombreExtraN1',
//       'label': 'Adic. 1\nNombre',
//       'dataKey': 'nombreExtraN1',
//     },
//     {'key': 'extraN1', 'label': 'Adic. 1\nValor', 'dataKey': 'extraN1'},
//     {
//       'key': 'nombreExtraN2',
//       'label': 'Adic. 2\nNombre',
//       'dataKey': 'nombreExtraN2',
//     },
//     {'key': 'extraN2', 'label': 'Adic. 2\nValor', 'dataKey': 'extraN2'},
//     {
//       'key': 'inicioSemana',
//       'label': 'Inicio\nSemana',
//       'dataKey': 'inicioSemana',
//     },
//     {'key': 'finSemana', 'label': 'Fin\nSemana', 'dataKey': 'finSemana'},
//     {'key': 'estado', 'label': 'Estado', 'dataKey': 'estado'},
//   ];

//   final List<String> _mainActivityKeys = [
//     'consagracionDomingo',
//     'escuelaDominical',
//     'ensayoMartes',
//     'ensayoMiercoles',
//     'servicioJueves',
//   ];

//   // Variables para paginación
//   int _rowsPerPage =
//       PaginatedDataTable.defaultRowsPerPage; // Valor inicial (10 por defecto)
//   final List<int> _availableRowsPerPage = [
//     10,
//     20,
//     50,
//     100,
//     200,
//     500,
//   ]; // Opciones para el usuario
//   int? _sortColumnIndex; // Índice de la columna actualmente ordenada
//   bool _sortAscending = true; // Dirección de la ordenación
//   AsistenciaDataTableSource?
//   _dataSource; // Fuente de datos para PaginatedDataTable

//   @override
//   void initState() {
//     super.initState();
//     _loadDataForHistorial();
//   }

//   Future<void> _loadDataForHistorial() async {
//     if (!mounted) return;
//     setState(() => _isLoading = true);
//     _todosLosUsuarios = await AsistenciaDatabase.instance.readAllUsuarios();
//     _asistenciasConNombreCompletas =
//         await AsistenciaDatabase.instance
//             .readAllAsistenciasConNombresDeUsuario();
//     if (mounted) {
//       setState(() {
//         _asistenciasConNombreFiltradas = List.from(
//           _asistenciasConNombreCompletas,
//         );
//         _updateDataSource();
//         _isLoading = false;
//       });
//     }
//   }

//   void _updateDataSource() {
//     // Llamar a esto cada vez que _asistenciasConNombreFiltradas cambie (o los criterios de columna)
//     if (!mounted) return;
//     setState(() {
//       _dataSource = AsistenciaDataTableSource(
//         _asistenciasConNombreFiltradas,
//         _allPossibleColumns, // Pasa la definición completa de columnas
//         _columnVisibility,
//         _selectedActividadFiltroValue,
//         _mainActivityKeys,
//       );
//     });
//   }

//   List<String> _getVisibleActivityDisplayNames() {
//     List<String> visibleActivities = [];
//     _activityUIToDBFieldMapping.forEach((displayKey, dbFieldKey) {
//       if (_columnVisibility[dbFieldKey] == true) {
//         visibleActivities.add(displayKey);
//       }
//     });
//     return visibleActivities;
//   }

//   void _applyFilters() {
//     if (!mounted) return;
//     List<Map<String, dynamic>> filtradas = List.from(
//       _asistenciasConNombreCompletas,
//     );

//     // Filtrar por usuario (sin cambios)
//     if (_selectedUsuarioFiltro != null) {
//       filtradas =
//           filtradas
//               .where(
//                 (itemMap) =>
//                     itemMap['usuarioId'] == _selectedUsuarioFiltro!.idUsuario,
//               )
//               .toList();
//     }

//     // Filtrar por actividad seleccionada (sin cambios)
//     if (_selectedActividadFiltroValue != null &&
//         _selectedActividadFiltroValue!.isNotEmpty) {
//       filtradas =
//           filtradas.where((itemMap) {
//             final value = itemMap[_selectedActividadFiltroValue!] as String?;
//             return value != null && value.isNotEmpty;
//           }).toList();
//     }

//     // Filtrar por rango de fechas (sin cambios)
//     if (_selectedDateRangeFiltro != null) {
//       // ... (lógica de filtro de fecha se mantiene)
//       filtradas =
//           filtradas.where((itemMap) {
//             final inicioSemanaAsistenciaStr =
//                 itemMap['inicioSemana'] as String?;
//             if (inicioSemanaAsistenciaStr == null) return false;
//             try {
//               final inicioSemanaAsistencia =
//                   DateTime.parse(inicioSemanaAsistenciaStr).toLocal();
//               final filtroStart = DateTime(
//                 _selectedDateRangeFiltro!.start.year,
//                 _selectedDateRangeFiltro!.start.month,
//                 _selectedDateRangeFiltro!.start.day,
//               );
//               final filtroEnd = DateTime(
//                 _selectedDateRangeFiltro!.end.year,
//                 _selectedDateRangeFiltro!.end.month,
//                 _selectedDateRangeFiltro!.end.day,
//               );
//               final asistenciaDateOnly = DateTime(
//                 inicioSemanaAsistencia.year,
//                 inicioSemanaAsistencia.month,
//                 inicioSemanaAsistencia.day,
//               );
//               return !asistenciaDateOnly.isBefore(filtroStart) &&
//                   !asistenciaDateOnly.isAfter(filtroEnd);
//             } catch (e) {
//               return false;
//             }
//           }).toList();
//     }

//     // --- NUEVO: Filtrar por Porcentaje ---
//     if (_filtroPorcentajeActivo != null) {
//       filtradas =
//           filtradas.where((itemMap) {
//             final totalAsistencia = itemMap['totalAsistencia'] as int?;
//             if (totalAsistencia == null)
//               return false; // O true si quieres incluir los que no tienen total

//             if (_filtroPorcentajeActivo == '100%') {
//               return totalAsistencia == 100;
//             } else if (_filtroPorcentajeActivo == '<65%') {
//               return totalAsistencia < 65;
//             }
//             return true; // No debería llegar aquí si _filtroPorcentajeActivo tiene uno de los dos valores
//           }).toList();
//     }

//     setState(() {
//       _asistenciasConNombreFiltradas = filtradas;
//       _sortAndPaginateData(); // Llamar para reordenar y actualizar la fuente de datos
//     });
//   }

//   // NUEVO: Método para manejar la ordenación y actualización de la fuente de datos
//   void _sortAndPaginateData() {
//     if (_sortColumnIndex != null) {
//       final colMap = _getVisibleColumnDefinition(
//         _sortColumnIndex!,
//       ); // Obtener la definición de la columna visible
//       if (colMap != null) {
//         final dataKey = colMap['dataKey']!;
//         _asistenciasConNombreFiltradas.sort((a, b) {
//           dynamic valA = a[dataKey];
//           dynamic valB = b[dataKey];

//           // Manejar nulos para que no crashee la comparación
//           if (valA == null && valB == null) return 0;
//           if (valA == null) return _sortAscending ? -1 : 1;
//           if (valB == null) return _sortAscending ? 1 : -1;

//           // Lógica de comparación (puedes necesitar ajustarla según el tipo de dato)
//           if (valA is String && valB is String) {
//             return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
//           } else if (valA is num && valB is num) {
//             return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
//           } else if (dataKey.toLowerCase().contains('fecha') ||
//               dataKey == 'inicioSemana' ||
//               dataKey == 'finSemana') {
//             try {
//               DateTime dateA = DateTime.parse(valA.toString());
//               DateTime dateB = DateTime.parse(valB.toString());
//               return _sortAscending
//                   ? dateA.compareTo(dateB)
//                   : dateB.compareTo(dateA);
//             } catch (e) {
//               return 0;
//             } // No ordenar si el parseo falla
//           }
//           return 0;
//         });
//       }
//     }
//     _updateDataSource(); // Actualizar la fuente de datos para PaginatedDataTable
//   }

//   // Helper para obtener la definición de una columna visible por su índice actual en la tabla
//   Map<String, String>? _getVisibleColumnDefinition(int visibleColumnIndex) {
//     int currentIndex = -1;
//     for (var colMap in _allPossibleColumns) {
//       final columnKey = colMap['key']!;
//       bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
//       bool isVisibleThisTime = false;

//       if (_columnVisibility[columnKey] == true) {
//         if (_selectedActividadFiltroValue != null &&
//             _selectedActividadFiltroValue!.isNotEmpty) {
//           if (!isMainActivityColumn ||
//               columnKey == _selectedActividadFiltroValue) {
//             isVisibleThisTime = true;
//           }
//         } else {
//           isVisibleThisTime = true;
//         }
//       }
//       if (isVisibleThisTime) {
//         currentIndex++;
//         if (currentIndex == visibleColumnIndex) {
//           return colMap;
//         }
//       }
//     }
//     return null;
//   }

//   Future<void> _pickDateRange() async {
//     final DateTimeRange? picked = await showDateRangePicker(
//       context: context,
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       initialDateRange: _selectedDateRangeFiltro,
//       helpText: 'Seleccione Rango de Fechas',
//       cancelText: 'Cancelar',
//       confirmText: 'Aplicar',
//       errorFormatText: 'Formato de fecha inválido',
//       errorInvalidText: 'Fecha inválida',
//       errorInvalidRangeText: 'Rango inválido',
//       fieldStartHintText: 'Fecha de inicio',
//       fieldEndHintText: 'Fecha de fin',
//     );
//     if (picked != null && picked != _selectedDateRangeFiltro) {
//       setState(() {
//         _selectedDateRangeFiltro = picked;
//         _applyFilters();
//       });
//     }
//   }

//   Future<void> _showSelectColumnsDialog() async {
//     Map<String, bool> tempVisibility = Map.from(_columnVisibility);
//     await showDialog<void>(
//       context: context,
//       builder: (BuildContext dialogContext) {
//         return StatefulBuilder(
//           builder: (context, StateSetter setStateDialog) {
//             return AlertDialog(
//               title: const Text('Seleccionar Columnas Visibles'),
//               content: SizedBox(
//                 width: double.maxFinite,
//                 child: ListView.builder(
//                   shrinkWrap: true,
//                   itemCount: _allPossibleColumns.length,
//                   itemBuilder: (BuildContext context, int index) {
//                     final columnMap = _allPossibleColumns[index];
//                     final columnKey = columnMap['key']!;
//                     final columnLabel = columnMap['label']!;
//                     return CheckboxListTile(
//                       title: Text(columnLabel),
//                       value: tempVisibility[columnKey],
//                       onChanged:
//                           (bool? newValue) => setStateDialog(
//                             () => tempVisibility[columnKey] = newValue!,
//                           ),
//                     );
//                   },
//                 ),
//               ),
//               actions: <Widget>[
//                 TextButton(
//                   child: const Text('Cancelar'),
//                   onPressed: () => Navigator.of(dialogContext).pop(),
//                 ),
//                 TextButton(
//                   child: const Text('Aplicar'),
//                   onPressed: () {
//                     setState(() {
//                       _columnVisibility = tempVisibility;
//                       if (_selectedActividadFiltroValue != null &&
//                           _columnVisibility[_selectedActividadFiltroValue!] ==
//                               false) {
//                         _selectedActividadFiltroDisplay = null;
//                         _selectedActividadFiltroValue = null;
//                       }
//                     });
//                     _applyFilters();
//                     Navigator.of(dialogContext).pop();
//                   },
//                 ),
//               ],
//             );
//           },
//         );
//       },
//     );
//   }

//   List<DataColumn> _getVisibleDataColumns() {
//     List<DataColumn> visibleColumns = [];
//     for (var colMap in _allPossibleColumns) {
//       final columnKey = colMap['key']!;
//       final columnLabel = colMap['label']!;
//       bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
//       if (_columnVisibility[columnKey] == true) {
//         if (_selectedActividadFiltroValue != null &&
//             _selectedActividadFiltroValue!.isNotEmpty) {
//           if (!isMainActivityColumn) {
//             visibleColumns.add(
//               DataColumn(
//                 label: Center(
//                   child: Text(columnLabel, textAlign: TextAlign.center),
//                 ),
//               ),
//             );
//           } else {
//             if (columnKey == _selectedActividadFiltroValue) {
//               visibleColumns.add(
//                 DataColumn(label: Center(child: Text(columnLabel))),
//               );
//             }
//           }
//         } else {
//           visibleColumns.add(
//             DataColumn(label: Center(child: Text(columnLabel))),
//           );
//         }
//       }
//     }
//     return visibleColumns;
//   }

//   List<DataCell> _getVisibleDataCells(Map<String, dynamic> itemMap) {
//     List<DataCell> visibleCells = [];
//     for (var colMap in _allPossibleColumns) {
//       final columnKey = colMap['key']!;
//       final dataKey = colMap['dataKey']!;
//       bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
//       bool shouldShowThisCell = false;
//       if (_columnVisibility[columnKey] == true) {
//         if (_selectedActividadFiltroValue != null &&
//             _selectedActividadFiltroValue!.isNotEmpty) {
//           if (!isMainActivityColumn) {
//             shouldShowThisCell = true;
//           } else {
//             if (columnKey == _selectedActividadFiltroValue) {
//               shouldShowThisCell = true;
//             }
//           }
//         } else {
//           shouldShowThisCell = true;
//         }
//       }
//       if (shouldShowThisCell) {
//         dynamic cellValue = itemMap[dataKey];
//         String displayValue = "-";
//         if (cellValue != null) {
//           if (dataKey.toLowerCase().contains('fecha') ||
//               dataKey == 'inicioSemana' ||
//               dataKey == 'finSemana') {
//             try {
//               displayValue = DateFormat(
//                 'dd/MM/yy',
//               ).format(DateTime.parse(cellValue.toString()).toLocal());
//             } catch (e) {
//               displayValue = cellValue.toString();
//             }
//           } else if (dataKey == 'totalAsistencia') {
//             displayValue = '${cellValue}%';
//           } else if (cellValue is String && cellValue.isEmpty) {
//             displayValue = "-";
//           } else {
//             displayValue = cellValue.toString();
//           }
//         }
//         Color? textColor;
//         FontWeight? fontWeight;
//         if (dataKey == 'totalAsistencia' && cellValue is int) {
//           if (cellValue < 60)
//             textColor = Colors.red.shade700;
//           else if (cellValue < 65)
//             textColor = Colors.yellow.shade800;
//           else
//             textColor = Colors.green.shade700;
//           fontWeight = FontWeight.bold;
//         }
//         if (dataKey == 'estado' && cellValue is String) {
//           textColor =
//               cellValue == 'finalizado'
//                   ? Colors.green.shade700
//                   : Colors.orange.shade700;
//         }
//         bool shouldCenter = [
//           'consagracionDomingo',
//           'escuelaDominical',
//           'ensayoMartes',
//           'ensayoMiercoles',
//           'servicioJueves',
//           'totalAsistencia',
//           'extraN1',
//           'extraN2',
//           'tipoSexo',
//           'fechaNacimiento',
//           'estado',
//         ].contains(dataKey);
//         Widget cellChild = Text(
//           displayValue,
//           style: TextStyle(
//             fontSize: 12,
//             color: textColor,
//             fontWeight: fontWeight,
//           ),
//         );
//         if (shouldCenter) cellChild = Center(child: cellChild);
//         if (dataKey == 'nombreUsuario' ||
//             dataKey == 'nombreExtraN1' ||
//             dataKey == 'nombreExtraN2') {
//           cellChild = SizedBox(
//             width: dataKey == 'nombreUsuario' ? 120 : 80,
//             child: Text(
//               displayValue,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: textColor,
//                 fontWeight: fontWeight,
//               ),
//             ),
//           );
//         }
//         visibleCells.add(DataCell(cellChild));
//       }
//     }
//     return visibleCells;
//   }

//   Future<void> _exportToPdf() async {
//     if (_asistenciasConNombreFiltradas.isEmpty) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No hay datos para exportar.')),
//       );
//       return;
//     }

//     setState(() => _isLoading = true);

//     try {
//       final pdf = pw.Document();

//       // 1. Determinar las columnas visibles para el PDF (basado en filtros y _columnVisibility)
//       // Esta lógica se mantiene igual.
//       List<Map<String, String>> pdfColumnsDefinition =
//           _allPossibleColumns
//               .where((colMap) => _columnVisibility[colMap['key']!] == true)
//               .toList();

//       if (_selectedActividadFiltroValue != null &&
//           _selectedActividadFiltroValue!.isNotEmpty) {
//         pdfColumnsDefinition =
//             pdfColumnsDefinition.where((colMap) {
//               bool isMainActivityColumn = _mainActivityKeys.contains(
//                 colMap['key']!,
//               );
//               if (!isMainActivityColumn) return true;
//               return colMap['key']! == _selectedActividadFiltroValue;
//             }).toList();
//       }

//       // --- INICIO DE LA CONSTRUCCIÓN MANUAL DE LA TABLA PDF ---
//       // 2. Crear las cabeceras para el PDF
//       List<pw.Widget> pdfTableHeaders =
//           pdfColumnsDefinition.map((col) {
//             return pw.Container(
//               alignment: pw.Alignment.centerLeft,
//               padding: const pw.EdgeInsets.all(3.5),
//               child: pw.Text(
//                 col['label']!,
//                 style: pw.TextStyle(
//                   fontWeight: pw.FontWeight.bold,
//                   fontSize: 7,
//                 ),
//               ),
//             );
//           }).toList();

//       // 3. Crear las filas de datos para el PDF con estilo condicional
//       List<pw.TableRow> pdfTableRows = [];
//       pdfTableRows.add(
//         pw.TableRow(children: pdfTableHeaders),
//       ); // Añadir la fila de cabeceras

//       for (var itemMap in _asistenciasConNombreFiltradas) {
//         List<pw.Widget> cells = [];
//         for (var colMap in pdfColumnsDefinition) {
//           final dataKey = colMap['dataKey']!;
//           dynamic cellValue = itemMap[dataKey];
//           String displayValue = "-";
//           pw.TextStyle cellTextStyle = const pw.TextStyle(
//             fontSize: 6,
//           ); // Estilo base de celda

//           if (cellValue != null) {
//             if (dataKey.toLowerCase().contains('fecha') ||
//                 dataKey == 'inicioSemana' ||
//                 dataKey == 'finSemana') {
//               try {
//                 displayValue = DateFormat(
//                   'dd/MM/yyyy',
//                 ).format(DateTime.parse(cellValue.toString()).toLocal());
//               } catch (e) {
//                 displayValue = cellValue.toString();
//               }
//             } else if (dataKey == 'totalAsistencia') {
//               displayValue = '${cellValue}%';
//               if (cellValue is int) {
//                 if (cellValue < 60) {
//                   cellTextStyle = cellTextStyle.copyWith(
//                     color: PdfColors.red700,
//                     fontWeight: pw.FontWeight.bold,
//                   );
//                 } else if (cellValue < 65) {
//                   cellTextStyle = cellTextStyle.copyWith(
//                     color: PdfColors.orange700,
//                     fontWeight: pw.FontWeight.bold,
//                   ); // Usar orange para mejor visibilidad
//                 } else {
//                   cellTextStyle = cellTextStyle.copyWith(
//                     color: PdfColors.green700,
//                     fontWeight: pw.FontWeight.bold,
//                   );
//                 }
//               }
//             } else if (dataKey == 'estado' && cellValue is String) {
//               displayValue = cellValue.toString();
//               cellTextStyle = cellTextStyle.copyWith(
//                 fontStyle: pw.FontStyle.italic,
//                 color:
//                     cellValue == 'finalizado'
//                         ? PdfColors.green700
//                         : PdfColors.orange700,
//               );
//             } else if (cellValue is String && cellValue.isEmpty) {
//               displayValue = "-";
//             } else {
//               displayValue = cellValue.toString();
//             }
//           }

//           pw.Alignment cellAlignment = pw.Alignment.centerLeft;
//           bool shouldCenter = [
//             'consagracionDomingo',
//             'escuelaDominical',
//             'ensayoMartes',
//             'ensayoMiercoles',
//             'servicioJueves',
//             'totalAsistencia',
//             'extraN1',
//             'extraN2',
//             'tipoSexo',
//             'fechaNacimiento',
//             'estado',
//           ].contains(dataKey);
//           if (shouldCenter) {
//             cellAlignment = pw.Alignment.center;
//           }

//           cells.add(
//             pw.Container(
//               alignment: cellAlignment,
//               padding: const pw.EdgeInsets.all(3.5),
//               child: pw.Text(displayValue, style: cellTextStyle),
//             ),
//           );
//         }
//         pdfTableRows.add(pw.TableRow(children: cells));
//       }
//       // --- FIN DE LA CONSTRUCCIÓN MANUAL DE LA TABLA PDF ---

//       pdf.addPage(
//         pw.MultiPage(
//           pageFormat: PdfPageFormat.a4.landscape,
//           margin: const pw.EdgeInsets.all(20),
//           build: (pw.Context pdfBuilderContext) {
//             // Renombrar context para evitar shadowing
//             return [
//               pw.Header(
//                 level: 0,
//                 child: pw.Text(
//                   'Historial de Asistencias Coro',
//                   style: pw.TextStyle(
//                     fontSize: 18,
//                     fontWeight: pw.FontWeight.bold,
//                   ),
//                 ),
//               ),
//               pw.SizedBox(height: 15),
//               if (_selectedUsuarioFiltro != null)
//                 pw.Text(
//                   'Filtro Usuario: ${_selectedUsuarioFiltro!.nombreCompleto}',
//                   style: pw.TextStyle(
//                     fontSize: 9,
//                     fontStyle: pw.FontStyle.italic,
//                   ),
//                 ),
//               if (_selectedActividadFiltroDisplay != null)
//                 pw.Text(
//                   'Filtro Actividad: $_selectedActividadFiltroDisplay',
//                   style: pw.TextStyle(
//                     fontSize: 9,
//                     fontStyle: pw.FontStyle.italic,
//                   ),
//                 ),
//               if (_selectedDateRangeFiltro != null)
//                 pw.Text(
//                   'Filtro Rango: ${DateFormat('dd/MM/yyyy').format(_selectedDateRangeFiltro!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRangeFiltro!.end)}',
//                   style: pw.TextStyle(
//                     fontSize: 9,
//                     fontStyle: pw.FontStyle.italic,
//                   ),
//                 ),
//               if (_selectedUsuarioFiltro != null ||
//                   _selectedActividadFiltroDisplay != null ||
//                   _selectedDateRangeFiltro != null)
//                 pw.SizedBox(height: 8),

//               // Usar pw.Table con las filas construidas manualmente
//               pw.Table(
//                 border: pw.TableBorder.all(
//                   color: PdfColors.grey600,
//                   width: 0.5,
//                 ),
//                 children: pdfTableRows,
//                 // Aquí podrías añadir columnWidths si es necesario, basándote en pdfColumnsDefinition.length
//                 // Ejemplo: columnWidths: _generateColumnWidths(pdfColumnsDefinition.length)
//               ),
//             ];
//           },
//         ),
//       );

//       final Uint8List pdfBytes = await pdf.save();
//       String? outputPath;
//       final String suggestedFileName =
//           'historial_asistencias_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

//       if (Platform.isAndroid ||
//           Platform.isIOS ||
//           Platform.isMacOS ||
//           Platform.isWindows ||
//           Platform.isLinux) {
//         String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
//           dialogTitle: 'Seleccione una carpeta para guardar el PDF',
//         );
//         if (selectedDirectory != null) {
//           outputPath = '$selectedDirectory/$suggestedFileName';
//         }
//       }

//       if (outputPath != null) {
//         final File file = File(outputPath);
//         await file.writeAsBytes(pdfBytes);
//         print('PDF Guardado en: $outputPath');
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('PDF guardado: $suggestedFileName'),
//             duration: const Duration(seconds: 7),
//             action: SnackBarAction(
//               label: 'Abrir',
//               onPressed: () async {
//                 final openResult = await OpenFile.open(outputPath!);
//                 if (openResult.type != ResultType.done) {
//                   if (mounted) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(
//                           'No se pudo abrir el archivo: ${openResult.message}',
//                         ),
//                       ),
//                     );
//                   }
//                 }
//               },
//             ),
//           ),
//         );
//       } else {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Guardado cancelado o no se seleccionó ruta.'),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error al exportar PDF: $e');
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error al exportar PDF: ${e.toString()}')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   Future<void> _exportToExcel() async {
//     if (_asistenciasConNombreFiltradas.isEmpty) {
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('No hay datos para exportar a Excel.')),
//       );
//       return;
//     }

//     // No es estrictamente necesario pedir Permission.storage si usamos FilePicker,
//     // pero lo mantenemos por si FilePicker lo necesita internamente en algunas plataformas/versiones.
//     // var storageStatus = await Permission.storage.status;
//     // if (!storageStatus.isGranted) {
//     //   storageStatus = await Permission.storage.request();
//     // }

//     // if (!storageStatus.isGranted) {
//     //   if (!mounted) return;
//     //   ScaffoldMessenger.of(context).showSnackBar(
//     //     SnackBar(
//     //       content: Text(
//     //         'Permiso de almacenamiento denegado para exportar. ${storageStatus.toString()}',
//     //       ),
//     //     ),
//     //   );
//     //   if (storageStatus.isPermanentlyDenied) {
//     //     openAppSettings();
//     //   }
//     //   return;
//     // }

//     setState(() => _isLoading = true);

//     try {
//       // 1. Crear un nuevo libro de Excel
//       var excel = Excel.createExcel(); // El objeto principal del paquete
//       // Opcional: darle un nombre a la hoja por defecto o usar la que se crea
//       Sheet sheetObject = excel['HistorialAsistencia']; // Obtener/crear la hoja

//       // 2. Determinar las columnas visibles para el Excel (basado en filtros y _columnVisibility)
//       List<Map<String, String>> excelColumnsDefinition =
//           _allPossibleColumns
//               .where((colMap) => _columnVisibility[colMap['key']!] == true)
//               .toList();

//       if (_selectedActividadFiltroValue != null &&
//           _selectedActividadFiltroValue!.isNotEmpty) {
//         excelColumnsDefinition =
//             excelColumnsDefinition.where((colMap) {
//               bool isMainActivityColumn = _mainActivityKeys.contains(
//                 colMap['key']!,
//               );
//               if (!isMainActivityColumn) return true;
//               return colMap['key']! == _selectedActividadFiltroValue;
//             }).toList();
//       }

//       // 3. Escribir las cabeceras
//       List<CellValue> headerRow = []; // La API espera List<CellValue>
//       for (var colDef in excelColumnsDefinition) {
//         headerRow.add(
//           TextCellValue(colDef['label']!), // Valor del texto
//           // El estilo se aplica a la celda, no directamente al TextCellValue en versiones recientes
//         );
//       }
//       sheetObject.appendRow(headerRow);

//       // Aplicar estilo a la fila de cabeceras
//       for (var i = 0; i < headerRow.length; i++) {
//         var cell = sheetObject.cell(
//           CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
//         );
//         cell.cellStyle = CellStyle(
//           bold: true,
//           fontSize: 10,
//           backgroundColorHex: ExcelColor.grey300, // Gris claro
//           fontColorHex: ExcelColor.black, // Negro
//           horizontalAlign: HorizontalAlign.Center,
//           verticalAlign: VerticalAlign.Center,
//         );
//       }

//       // 4. Escribir las filas de datos
//       for (
//         int rowIndex = 0;
//         rowIndex < _asistenciasConNombreFiltradas.length;
//         rowIndex++
//       ) {
//         final itemMap = _asistenciasConNombreFiltradas[rowIndex];
//         List<CellValue> dataCells = []; // Lista para las celdas de esta fila

//         for (
//           int colIndex = 0;
//           colIndex < excelColumnsDefinition.length;
//           colIndex++
//         ) {
//           final colMap = excelColumnsDefinition[colIndex];
//           final dataKey = colMap['dataKey']!;
//           dynamic cellValue = itemMap[dataKey];
//           CellValue cellValueToAdd;

//           // Estilo base para la celda
//           ExcelColor fontColorHex = ExcelColor.black; // Negro por defecto
//           ExcelColor backgroundColorHex = ExcelColor.none; // Sin fondo
//           bool isBold = false;
//           bool isItalic = false;

//           String displayValue = "-";

//           if (cellValue != null) {
//             if (dataKey.toLowerCase().contains('fecha') ||
//                 dataKey == 'inicioSemana' ||
//                 dataKey == 'finSemana') {
//               try {
//                 displayValue = DateFormat(
//                   'dd/MM/yyyy',
//                 ).format(DateTime.parse(cellValue.toString()).toLocal());
//               } catch (e) {
//                 displayValue = cellValue.toString();
//               }
//               cellValueToAdd = TextCellValue(displayValue);
//             } else if (dataKey == 'totalAsistencia') {
//               if (cellValue is int) {
//                 displayValue = '$cellValue%';
//                 isBold = true;
//                 if (cellValue < 60)
//                   fontColorHex = ExcelColor.redAccent; // Rojo
//                 else if (cellValue < 65)
//                   fontColorHex = ExcelColor.orangeAccent; // Naranja
//                 else
//                   fontColorHex = ExcelColor.green; // Verde
//               } else {
//                 displayValue = cellValue.toString();
//               }
//               cellValueToAdd = TextCellValue(displayValue);
//             } else if (dataKey == 'estado' && cellValue is String) {
//               displayValue = cellValue;
//               isItalic = true;
//               fontColorHex =
//                   cellValue == 'finalizado'
//                       ? ExcelColor.greenAccent
//                       : ExcelColor.orangeAccent; // Verde : Naranja
//               cellValueToAdd = TextCellValue(displayValue);
//             } else if (cellValue is String && cellValue.isEmpty) {
//               displayValue = "-";
//               cellValueToAdd = TextCellValue(displayValue);
//             } else if (cellValue is int) {
//               cellValueToAdd = IntCellValue(cellValue);
//             } else if (cellValue is double) {
//               cellValueToAdd = DoubleCellValue(cellValue);
//             } else {
//               displayValue = cellValue.toString();
//               cellValueToAdd = TextCellValue(displayValue);
//             }
//           } else {
//             cellValueToAdd = TextCellValue("-"); // Si cellValue es null
//           }
//           dataCells.add(cellValueToAdd);

//           // Aplicar estilo a la celda recién añadida
//           var cell = sheetObject.cell(
//             CellIndex.indexByColumnRow(
//               columnIndex: colIndex,
//               rowIndex: rowIndex + 1, // +1 porque la fila 0 es la cabecera
//             ),
//           );
//           cell.cellStyle = CellStyle(
//             fontSize: 9,
//             textWrapping: TextWrapping.WrapText,
//             verticalAlign: VerticalAlign.Center,
//             horizontalAlign:
//                 (cellValueToAdd is IntCellValue ||
//                         cellValueToAdd is DoubleCellValue ||
//                         dataKey == 'totalAsistencia')
//                     ? HorizontalAlign
//                         .Right // Alinear números a la derecha
//                     : HorizontalAlign.Left,
//             fontColorHex: fontColorHex, // Usar la clase HexColor del paquete
//             backgroundColorHex: backgroundColorHex,
//             bold: isBold,
//             italic: isItalic,
//           );
//         }
//         sheetObject.appendRow(dataCells);
//       }

//       // Autoajustar anchos de columna (opcional)
//       for (var i = 0; i < excelColumnsDefinition.length; i++) {
//         sheetObject.setColumnWidth(i, 15);
//       }

//       // 5. Obtener los bytes del archivo Excel
//       var fileBytes = excel.save(fileName: "historial_asistencias_temp.xlsx");

//       if (fileBytes == null) {
//         throw Exception("No se pudieron generar los bytes del archivo Excel.");
//       }

//       // 6. GUARDAR EL ARCHIVO USANDO FILE PICKER (SAF) - Esta lógica se mantiene
//       String? outputPath;
//       final String suggestedFileName =
//           'historial_asistencias_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

//       String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
//         dialogTitle: 'Seleccione una carpeta para guardar el Excel',
//       );

//       if (selectedDirectory != null) {
//         outputPath = '$selectedDirectory/$suggestedFileName';
//       }

//       if (outputPath != null) {
//         final File file = File(outputPath);
//         await file.writeAsBytes(fileBytes); // fileBytes es List<int>

//         print('Excel Guardado en: $outputPath');
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text('Excel guardado: $suggestedFileName'),
//             duration: const Duration(seconds: 7),
//             action: SnackBarAction(
//               label: 'Abrir',
//               onPressed: () async {
//                 final openResult = await OpenFile.open(outputPath!);
//                 if (openResult.type != ResultType.done) {
//                   if (mounted) {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       SnackBar(
//                         content: Text(
//                           'No se pudo abrir el archivo: ${openResult.message}',
//                         ),
//                       ),
//                     );
//                   }
//                 }
//               },
//             ),
//           ),
//         );
//       } else {
//         if (!mounted) return;
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Guardado cancelado o no se seleccionó ruta.'),
//           ),
//         );
//       }
//     } catch (e) {
//       print('Error al exportar Excel: $e');
//       if (!mounted) return;
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error al exportar Excel: ${e.toString()}')),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     List<String> visibleActivityOptions = _getVisibleActivityDisplayNames();
//     final List<DataColumn> currentVisibleColumns = _getVisibleDataColumns();

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Historial Usuarios Coro'),
//         backgroundColor: Theme.of(context).colorScheme.primaryContainer,
//       ),
//       body:
//           _isLoading
//               ? const Center(child: CircularProgressIndicator())
//               : Column(
//                 children: [
//                   Padding(
//                     padding: const EdgeInsets.all(8.0),
//                     child: Row(
//                       children: <Widget>[
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButtonFormField<Usuario>(
//                             /* ... Dropdown Usuario ... */
//                             decoration: const InputDecoration(
//                               labelText: 'Usuario',
//                               border: OutlineInputBorder(),
//                               contentPadding: EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 8,
//                               ),
//                             ),
//                             value: _selectedUsuarioFiltro,
//                             hint: const Text('Todos'),
//                             isExpanded: true,
//                             items: [
//                               const DropdownMenuItem<Usuario>(
//                                 value: null,
//                                 child: Text('Todos los Usuarios'),
//                               ),
//                               ..._todosLosUsuarios
//                                   .map(
//                                     (Usuario u) => DropdownMenuItem<Usuario>(
//                                       value: u,
//                                       child: Text(
//                                         u.nombreCompleto ?? 'N/A',
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                   )
//                                   .toList(),
//                             ],
//                             onChanged:
//                                 (Usuario? newVal) => setState(() {
//                                   _selectedUsuarioFiltro = newVal;
//                                   _applyFilters();
//                                 }),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           flex: 2,
//                           child: DropdownButtonFormField<String>(
//                             /* ... Dropdown Actividad ... */
//                             decoration: const InputDecoration(
//                               labelText: 'Actividad',
//                               border: OutlineInputBorder(),
//                               contentPadding: EdgeInsets.symmetric(
//                                 horizontal: 10,
//                                 vertical: 8,
//                               ),
//                             ),
//                             value: _selectedActividadFiltroDisplay,
//                             hint: const Text('Todas'),
//                             isExpanded: true,
//                             items: [
//                               const DropdownMenuItem<String>(
//                                 value: null,
//                                 child: Text('Todas las Actividades'),
//                               ),
//                               ...visibleActivityOptions
//                                   .map(
//                                     (String act) => DropdownMenuItem<String>(
//                                       value: act,
//                                       child: Text(
//                                         act,
//                                         overflow: TextOverflow.ellipsis,
//                                       ),
//                                     ),
//                                   )
//                                   .toList(),
//                             ],
//                             onChanged:
//                                 (String? newDispVal) => setState(() {
//                                   _selectedActividadFiltroDisplay = newDispVal;
//                                   _selectedActividadFiltroValue =
//                                       newDispVal != null
//                                           ? _activityUIToDBFieldMapping[newDispVal]
//                                           : null;
//                                   _applyFilters();
//                                 }),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Tooltip(
//                           message: 'Rango de Fechas',
//                           child: IconButton(
//                             icon: const Icon(Icons.calendar_today),
//                             onPressed: _pickDateRange,
//                             color: Theme.of(context).colorScheme.primary,
//                           ),
//                         ),
//                         if (_selectedDateRangeFiltro != null)
//                           Tooltip(
//                             message: 'Limpiar Fecha',
//                             child: IconButton(
//                               icon: const Icon(Icons.clear),
//                               onPressed:
//                                   () => setState(() {
//                                     _selectedDateRangeFiltro = null;
//                                     _applyFilters();
//                                   }),
//                               color: Theme.of(context).colorScheme.error,
//                             ),
//                           ),
//                       ],
//                     ),
//                   ),
//                   if (_selectedDateRangeFiltro != null)
//                     Padding(
//                       padding: const EdgeInsets.symmetric(horizontal: 16.0),
//                       child: Align(
//                         alignment: Alignment.centerLeft,
//                         child: Text(
//                           "Rango: ${DateFormat('dd/MM/yy').format(_selectedDateRangeFiltro!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRangeFiltro!.end)}",
//                           style: const TextStyle(
//                             fontSize: 12,
//                             fontStyle: FontStyle.italic,
//                           ),
//                         ),
//                       ),
//                     ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 8.0,
//                       vertical: 4.0,
//                     ),
//                     child: Row(
//                       children: [
//                         TextButton.icon(
//                           icon: const Icon(Icons.view_column_outlined),
//                           label: const Text('Columnas'),
//                           onPressed: _showSelectColumnsDialog,
//                         ),
//                         Row(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             TextButton(
//                               style: TextButton.styleFrom(
//                                 foregroundColor:
//                                     _filtroPorcentajeActivo == '100%'
//                                         ? Theme.of(context).colorScheme.primary
//                                         : Colors
//                                             .green[700], // Color condicional
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 4,
//                                 ),
//                                 minimumSize: Size.zero,
//                               ),
//                               child: const Text(
//                                 '100%',
//                                 style: TextStyle(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               onPressed: () {
//                                 setState(() {
//                                   // Si ya está activo, lo desactiva. Si no, lo activa.
//                                   if (_filtroPorcentajeActivo == '100%') {
//                                     _filtroPorcentajeActivo = null;
//                                   } else {
//                                     _filtroPorcentajeActivo = '100%';
//                                   }
//                                   _applyFilters();
//                                 });
//                               },
//                             ),
//                             const SizedBox(width: 4), // Pequeño espacio
//                             TextButton(
//                               style: TextButton.styleFrom(
//                                 foregroundColor:
//                                     _filtroPorcentajeActivo == '<65%'
//                                         ? Colors.grey[700]
//                                         : Colors
//                                             .red
//                                             .shade700, // Color condicional
//                                 padding: const EdgeInsets.symmetric(
//                                   horizontal: 8,
//                                   vertical: 4,
//                                 ),
//                                 minimumSize: Size.zero,
//                               ),
//                               child: const Text(
//                                 '< 65%',
//                                 style: TextStyle(
//                                   fontSize: 18,
//                                   fontWeight: FontWeight.bold,
//                                 ),
//                               ),
//                               onPressed: () {
//                                 setState(() {
//                                   if (_filtroPorcentajeActivo == '<65%') {
//                                     _filtroPorcentajeActivo = null;
//                                   } else {
//                                     _filtroPorcentajeActivo = '<65%';
//                                   }
//                                   _applyFilters();
//                                 });
//                               },
//                             ),
//                           ],
//                         ),
//                         const Spacer(),
//                         IconButton(
//                           icon: const Icon(Icons.picture_as_pdf_rounded),
//                           iconSize: 30.0,
//                           tooltip: 'Exportar PDF',
//                           color: Colors.redAccent,
//                           onPressed:
//                               _asistenciasConNombreFiltradas.isEmpty
//                                   ? null
//                                   : _exportToPdf,
//                         ),
//                         IconButton(
//                           icon: const FaIcon(FontAwesomeIcons.solidFileExcel),
//                           iconSize: 28.0,
//                           tooltip: 'Exportar Excel',
//                           color: Colors.green,
//                           onPressed:
//                               _asistenciasConNombreFiltradas.isEmpty
//                                   ? null
//                                   : _exportToExcel, // Deshabilitar si no hay datos
//                         ),
//                       ],
//                     ),
//                   ),
//                   const Divider(),
//                   Expanded(
//                     child:
//                         _asistenciasConNombreFiltradas.isEmpty
//                             ? const Center(
//                               child: Text(
//                                 'No hay asistencias que coincidan con los filtros.',
//                               ),
//                             )
//                             : SingleChildScrollView(
//                               child: PaginatedDataTable(
//                                 key: ValueKey(
//                                   _asistenciasConNombreFiltradas.hashCode +
//                                       _sortColumnIndex.hashCode +
//                                       _sortAscending.hashCode,
//                                 ), // Para forzar reconstrucción si los datos o el sort cambian
//                                 header: const Text(
//                                   'Historial de Asistencias',
//                                 ), // Título opcional para la tabla
//                                 rowsPerPage: _rowsPerPage,
//                                 availableRowsPerPage: _availableRowsPerPage,
//                                 onRowsPerPageChanged: (int? value) {
//                                   if (value != null) {
//                                     setState(() {
//                                       _rowsPerPage = value;
//                                       _updateDataSource(); // Actualizar fuente para reflejar cambio de página
//                                     });
//                                   }
//                                 },
//                                 sortColumnIndex: _sortColumnIndex,
//                                 sortAscending: _sortAscending,
//                                 columns:
//                                     currentVisibleColumns.map((DataColumn col) {
//                                       // Especificar el tipo de 'col'
//                                       String columnLabelText = '';
//                                       if (col.label is Center) {
//                                         // Verificar si es un Center
//                                         final centerWidget =
//                                             col.label as Center;
//                                         if (centerWidget.child is Text) {
//                                           // Verificar si el hijo del Center es un Text
//                                           columnLabelText =
//                                               (centerWidget.child as Text)
//                                                   .data ??
//                                               '';
//                                         }
//                                       } else if (col.label is Text) {
//                                         // Por si acaso en algún momento el label es solo Text
//                                         columnLabelText =
//                                             (col.label as Text).data ?? '';
//                                       }

//                                       final originalColDef = _allPossibleColumns
//                                           .firstWhere(
//                                             (def) =>
//                                                 def['label'] ==
//                                                 columnLabelText, // Comparar con el texto extraído
//                                             orElse:
//                                                 () => {
//                                                   'key': 'desconocido',
//                                                   'label': 'Error',
//                                                   'dataKey': 'error',
//                                                 },
//                                           );
//                                       return DataColumn(
//                                         label:
//                                             col.label, // Mantener el widget original (Center(child: Text(...)))
//                                         onSort: (
//                                           int columnIndex,
//                                           bool ascending,
//                                         ) {
//                                           setState(() {
//                                             _sortColumnIndex =
//                                                 columnIndex; // El columnIndex aquí es el índice de la columna VISIBLE
//                                             _sortAscending = ascending;
//                                             _sortAndPaginateData();
//                                           });
//                                         },
//                                       );
//                                     }).toList(),
//                                 source:
//                                     _dataSource ??
//                                     AsistenciaDataTableSource(
//                                       [],
//                                       [],
//                                       {},
//                                       null,
//                                       [],
//                                     ), // Usar la fuente de datos
//                                 // columnSpacing: 10.0, // Ya no se usa aquí, DataTableSource lo maneja si es necesario
//                                 headingRowHeight: 56.0,
//                                 // dataRowHeight: 45, // PaginatedDataTable usa dataRowMinHeight y dataRowMaxHeight en la fuente
//                                 // showCheckboxColumn: false, // Si no necesitas checkboxes
//                               ),
//                             ),
//                   ),
//                 ],
//               ),
//     );
//   }
// }

// // En historial.dart (puede ser fuera de la clase _HistorialScreenState, pero dentro del archivo)

// class AsistenciaDataTableSource extends DataTableSource {
//   // Los datos filtrados que se mostrarán
//   final List<Map<String, dynamic>> _data;
//   // Definición de las columnas que se van a mostrar (para construir las celdas)
//   final List<Map<String, String>> _columnDefinitions;
//   // Mapa de visibilidad de columnas
//   final Map<String, bool> _columnVisibility;
//   // Filtro de actividad para saber qué columnas de actividad mostrar
//   final String? _selectedActivityFiltroValue;
//   final List<String> _mainActivityKeys;

//   AsistenciaDataTableSource(
//     this._data,
//     this._columnDefinitions,
//     this._columnVisibility,
//     this._selectedActivityFiltroValue,
//     this._mainActivityKeys,
//   );

//   // Helper para obtener las celdas visibles para una fila
//   List<DataCell> _getVisibleDataCellsForRow(Map<String, dynamic> itemMap) {
//     List<DataCell> visibleCells = [];
//     for (var colMap in _columnDefinitions) {
//       final columnKey = colMap['key']!;
//       final dataKey = colMap['dataKey']!;
//       bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
//       bool shouldShowThisCell = false;

//       if (_columnVisibility[columnKey] == true) {
//         if (_selectedActivityFiltroValue != null &&
//             _selectedActivityFiltroValue!.isNotEmpty) {
//           if (!isMainActivityColumn) {
//             shouldShowThisCell = true;
//           } else {
//             if (columnKey == _selectedActivityFiltroValue) {
//               shouldShowThisCell = true;
//             }
//           }
//         } else {
//           shouldShowThisCell = true;
//         }
//       }

//       if (shouldShowThisCell) {
//         dynamic cellValue = itemMap[dataKey];
//         String displayValue = "-";
//         if (cellValue != null) {
//           if (dataKey.toLowerCase().contains('fecha') ||
//               dataKey == 'inicioSemana' ||
//               dataKey == 'finSemana') {
//             try {
//               displayValue = DateFormat(
//                 'dd/MM/yy',
//               ).format(DateTime.parse(cellValue.toString()).toLocal());
//             } catch (e) {
//               displayValue = cellValue.toString();
//             }
//           } else if (dataKey == 'totalAsistencia') {
//             displayValue = '${cellValue}%';
//           } else if (cellValue is String && cellValue.isEmpty) {
//             displayValue = "-";
//           } else {
//             displayValue = cellValue.toString();
//           }
//         }
//         Color? textColor;
//         FontWeight? fontWeight;
//         if (dataKey == 'totalAsistencia' && cellValue is int) {
//           if (cellValue < 60)
//             textColor = Colors.red.shade700;
//           else if (cellValue < 65)
//             textColor = Colors.yellow.shade800;
//           else
//             textColor = Colors.green.shade700;
//           fontWeight = FontWeight.bold;
//         }
//         if (dataKey == 'estado' && cellValue is String) {
//           textColor =
//               cellValue == 'finalizado'
//                   ? Colors.green.shade700
//                   : Colors.orange.shade700;
//         }

//         Widget cellChild = Text(
//           displayValue,
//           style: TextStyle(
//             fontSize: 12,
//             color: textColor,
//             fontWeight: fontWeight,
//           ),
//         );
//         bool shouldCenter = [
//           'consagracionDomingo',
//           'escuelaDominical',
//           'ensayoMartes',
//           'ensayoMiercoles',
//           'servicioJueves',
//           'totalAsistencia',
//           'extraN1',
//           'extraN2',
//           'tipoSexo',
//           'fechaNacimiento',
//           'estado',
//         ].contains(dataKey);
//         if (shouldCenter) cellChild = Center(child: cellChild);
//         if (dataKey == 'nombreUsuario' ||
//             dataKey == 'nombreExtraN1' ||
//             dataKey == 'nombreExtraN2') {
//           cellChild = SizedBox(
//             width: dataKey == 'nombreUsuario' ? 120 : 80,
//             child: Text(
//               displayValue,
//               overflow: TextOverflow.ellipsis,
//               style: TextStyle(
//                 fontSize: 12,
//                 color: textColor,
//                 fontWeight: fontWeight,
//               ),
//             ),
//           );
//         }
//         visibleCells.add(DataCell(cellChild));
//       }
//     }
//     return visibleCells;
//   }

//   @override
//   DataRow? getRow(int index) {
//     if (index >= _data.length) {
//       return null; // Índice fuera de rango
//     }
//     final itemMap = _data[index];
//     return DataRow(cells: _getVisibleDataCellsForRow(itemMap));
//   }

//   @override
//   bool get isRowCountApproximate => false; // Sabemos el número exacto de filas

//   @override
//   int get rowCount => _data.length; // Número total de filas en los datos (filtrados)

//   @override
//   int get selectedRowCount => 0; // No estamos usando selección de filas aquí
// }

