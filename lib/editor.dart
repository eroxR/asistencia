// editor.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// IMPORTA TUS MODELOS Y LA CLASE DE BASE DE DATOS
import 'package:asistencia/models/model.dart'; // Ajusta la ruta si es diferente
import 'package:asistencia/database/asistencia_database.dart'; // Ajusta la ruta

import 'dart:convert'; // Para utf8.encode
import 'package:crypto/crypto.dart'; // Para md5

class EditorScreen extends StatefulWidget {
  // Renombrado a EditorScreen para claridad
  const EditorScreen({super.key});

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  List<Usuario> _usuarios = [];
  Map<int, Asistencia> _asistenciasActivas = {};
  Map<String, int> _valoresNotasBase = {};
  bool _isLoading = true;
  // Variables para controlar la visibilidad de la contraseña en el nuevo diálogo
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;

  final List<String> _attendanceActivityOrder = [
    'Consagración Domingo',
    'Escuela Dominical',
    'Ensayo Martes',
    'Ensayo Miércoles',
    'Servicio Jueves',
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await _loadValoresNotasBase();
    await _refreshUsuarios();
  }

  Future<void> _loadValoresNotasBase() async {
    // (Este método es idéntico al de home.dart)
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
    // (Este método es idéntico al de home.dart)
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
              // Usaremos el mismo helper
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
    // (Este método es idéntico al de home.dart)
    int usuarioId,
    DateTime inicioSemana,
    DateTime finSemana,
  ) {
    return Asistencia(
      usuarioId: usuarioId,
      consagracionDomingo: "",
      fechaConsagracionD: null,
      escuelaDominical: "",
      fechaEscuelaD: null,
      ensayoMartes: "",
      fechaEnsayoMartes: null,
      ensayoMiercoles: "",
      fechaEnsayoMiercoles: null,
      servicioJueves: "",
      fechaServicioJueves: null,
      totalAsistencia: 0,
      inicioSemana: inicioSemana,
      finSemana: finSemana,
      estado: 'activo',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editor Usuarios Coro'), // Nuevo título
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: Icon(
              Icons.arrow_circle_left_outlined,
            ), // Primer ícono a la derecha
            iconSize: 35.0,
            color: Colors.redAccent,
            tooltip: 'Volver',
            onPressed: () {
              Navigator.of(
                context,
              ).pop(true); // Acción para volver a la pantalla anterior
            },
          ),
          IconButton(
            icon: Icon(Icons.lock_reset_outlined), // Segundo ícono a la derecha
            iconSize: 35.0,
            tooltip: 'cambio de contraseña',
            color: Colors.green, // Cambia el color del ícono a azul
            onPressed: () {
              _showChangePasswordDialog(context); // Llama al nuevo diálogo
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
                    const Text("No hay usuarios para editar."),
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
                  // Usaremos un nuevo _buildEditorUserListItem
                  return _buildEditorUserListItem(usuario, asistencia);
                },
              ),
    );
  }

  // NUEVO: Widget para construir cada ítem de la lista en modo editor
  Widget _buildEditorUserListItem(Usuario usuario, Asistencia? asistencia) {
    final String name = usuario.nombreCompleto ?? 'Sin Nombre';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
      child: ListTile(
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
        ),
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
            // Llamaremos a una versión modificada del diálogo de asistencia
            _showEditorAttendanceDialog(usuario, asistenciaParaDialogo);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Error: ID de usuario no disponible."),
              ),
            );
          }
        },
      ),
    );
  }

  // NUEVO: Diálogo de asistencia para el editor (campos siempre editables)
  Future<void> _showEditorAttendanceDialog(
    Usuario usuario,
    Asistencia asistenciaActual,
  ) async {
    Asistencia asistenciaParaEditar = asistenciaActual.copyWith();

    List<String?> selectedAttendances = [
      asistenciaParaEditar.consagracionDomingo,
      asistenciaParaEditar.escuelaDominical,
      asistenciaParaEditar.ensayoMartes,
      asistenciaParaEditar.ensayoMiercoles,
      asistenciaParaEditar.servicioJueves,
    ];
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

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      context: context, // Usar el context de _EditorScreenState
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialogInDialog) {
            return AlertDialog(
              title: Text(
                'Editor Asistencia: ${usuario.nombreCompleto?.trim()}',
              ),
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
                      // bool isEditableThisField = true; // <--- SIEMPRE EDITABLE EN ESTE DIÁLOGO

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          decoration: InputDecoration(
                            labelText: _attendanceActivityOrder[index],
                            border: const OutlineInputBorder(),
                          ),
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
                          onChanged: (String? newValue) {
                            // <--- SIEMPRE HABILITADO
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
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
                    const SizedBox(width: 8),
                    TextButton(
                      child: const Text(
                        'Guardar Cambios',
                      ), // Cambiar texto del botón si se desea
                      onPressed: () async {
                        // --- INICIO LÓGICA DE GUARDADO (IDÉNTICA A home.dart _showAttendanceDialog) ---
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
                            if (currentDates[i] == null &&
                                (asistenciaActual.idAsistencia == null ||
                                    asistenciaActual.estado == 'activo')) {
                              // Solo setea fecha si es la primera vez o el registro original era activo
                              dateSetters[i](now);
                            }
                          } else {
                            allMainActivitiesFilled = false;
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
                          fechaConsagracionD: nuevaFechaConsagracionD,
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

                        final navigatorInstanceDialog = Navigator.of(
                          dialogContext,
                        ); // Capturar antes de await
                        final scaffoldMessengerInstance = ScaffoldMessenger.of(
                          context,
                        ); // Capturar antes de await

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

                          if (!mounted)
                            return; // Verificar mounted del State principal
                          navigatorInstanceDialog.pop(true);
                          _refreshUsuarios();
                          scaffoldMessengerInstance.showSnackBar(
                            const SnackBar(
                              content: Text('Asistencia actualizada'),
                            ),
                          );
                        } catch (e) {
                          print("Error al guardar asistencia en editor: $e");
                          if (!mounted) return;
                          if (navigatorInstanceDialog.canPop()) {
                            navigatorInstanceDialog.pop();
                          }
                          scaffoldMessengerInstance.showSnackBar(
                            SnackBar(
                              content: Text(
                                'Error al actualizar asistencia: $e',
                              ),
                            ),
                          );
                        } finally {
                          additionalController1.dispose();
                          valueController1.dispose();
                          additionalController2.dispose();
                          valueController2.dispose();
                        }
                        // --- FIN LÓGICA DE GUARDADO ---
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

  Future<void> _showChangePasswordDialog(BuildContext scaffoldContext) async {
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final TextEditingController newPasswordController = TextEditingController();
    final TextEditingController confirmPasswordController =
        TextEditingController();

    // Resetea la visibilidad al abrir el diálogo
    _newPasswordVisible = false;
    _confirmPasswordVisible = false;

    // ignore: use_build_context_synchronously
    await showDialog<void>(
      context: scaffoldContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        // Usamos un StatefulBuilder para manejar el estado de visibilidad de la contraseña
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Cambiar Contraseña'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        controller: newPasswordController,
                        obscureText:
                            !_newPasswordVisible, // Controla la visibilidad
                        decoration: InputDecoration(
                          labelText: 'Nueva Contraseña',
                          border: const OutlineInputBorder(),
                          // prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _newPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                _newPasswordVisible = !_newPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, ingrese la nueva contraseña';
                          }
                          if (value.length < 8) {
                            return 'Mínimo 8 caracteres';
                          }
                          // Validación de complejidad: al menos una letra, un número y un carácter especial
                          final hasLetter = RegExp(r'[a-zA-Z]').hasMatch(value);
                          final hasDigit = RegExp(r'[0-9]').hasMatch(value);
                          final hasSpecialChar = RegExp(
                            r'[!@#$%^&*(),.?":{}|<>]',
                          ).hasMatch(value);
                          if (!hasLetter || !hasDigit || !hasSpecialChar) {
                            return 'Debe incluir letras, números y símbolos';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText:
                            !_confirmPasswordVisible, // Controla la visibilidad
                        decoration: InputDecoration(
                          labelText: 'Confirmar',
                          border: const OutlineInputBorder(),
                          // prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _confirmPasswordVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            onPressed: () {
                              setStateDialog(() {
                                _confirmPasswordVisible =
                                    !_confirmPasswordVisible;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor, confirme la contraseña';
                          }
                          if (value != newPasswordController.text) {
                            return 'Las contraseñas no coinciden';
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
                        newPasswordController.dispose();
                        confirmPasswordController.dispose();
                        Navigator.of(dialogContext).pop();
                      },
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      child: const Text('Guardar'),
                      onPressed: () async {
                        if (formKey.currentState!.validate()) {
                          final newPassword = newPasswordController.text;
                          // Encriptar la nueva contraseña a MD5
                          final bytes = utf8.encode(newPassword);
                          final digest = md5.convert(bytes);
                          final newPasswordMd5 = digest.toString();

                          // Asumimos que hay un solo registro de autorización o actualizamos el primero.
                          final autorizaciones =
                              await AsistenciaDatabase.instance
                                  .readAllAutorizaciones();
                          if (autorizaciones.isEmpty) {
                            // ignore: use_build_context_synchronously
                            ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Error: No hay registro de autorización para actualizar.',
                                ),
                              ),
                            );
                            return;
                          }
                          final authToUpdate = autorizaciones.first.copyWith(
                            contrasena: newPasswordMd5,
                            repetirContrasena:
                                newPasswordMd5, // Guardar el mismo hash en ambos campos
                            intentos:
                                0, // Resetea los intentos al cambiar la contraseña
                          );

                          final navigatorInstanceDialog = Navigator.of(
                            dialogContext,
                          ); // Capturar antes de await
                          final scaffoldMessengerInstance =
                              ScaffoldMessenger.of(
                                scaffoldContext,
                              ); // Capturar antes de await

                          try {
                            await AsistenciaDatabase.instance
                                .updateAutorizacion(authToUpdate);

                            if (!mounted)
                              return; // Verificar mounted del State principal
                            navigatorInstanceDialog.pop();
                            scaffoldMessengerInstance.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Contraseña actualizada exitosamente.',
                                ),
                              ),
                            );
                          } catch (e) {
                            print("Error actualizando contraseña: $e");
                            if (!mounted) return;
                            if (navigatorInstanceDialog.canPop()) {
                              navigatorInstanceDialog.pop();
                            }
                            scaffoldMessengerInstance.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Error al actualizar contraseña: $e',
                                ),
                              ),
                            );
                          } finally {
                            newPasswordController.dispose();
                            confirmPasswordController.dispose();
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
