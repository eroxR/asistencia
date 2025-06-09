// historial.dart
import 'dart:io'; // Para File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:asistencia/models/model.dart'; // Ajusta la ruta
import 'package:asistencia/database/asistencia_database.dart'; // Ajusta la ruta
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Imports para PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw; // Usar un alias
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  bool _isLoading = true;
  List<Usuario> _todosLosUsuarios = [];
  List<Map<String, dynamic>> _asistenciasConNombreCompletas = [];
  List<Map<String, dynamic>> _asistenciasConNombreFiltradas = [];

  Usuario? _selectedUsuarioFiltro;
  String? _selectedActividadFiltroValue;
  String? _selectedActividadFiltroDisplay;
  DateTimeRange? _selectedDateRangeFiltro;

  final Map<String, String> _activityUIToDBFieldMapping = {
    'Consagración Domingo': 'consagracionDomingo',
    'Escuela Dominical': 'escuelaDominical',
    'Ensayo Martes': 'ensayoMartes',
    'Ensayo Miércoles': 'ensayoMiercoles',
    'Servicio Jueves': 'servicioJueves',
  };

  Map<String, bool> _columnVisibility = {
    'usuario': true,
    'tipoSexo': false,
    'fechaNacimiento': false,
    'consagracionDomingo': true,
    'escuelaDominical': true,
    'ensayoMartes': true,
    'ensayoMiercoles': true,
    'servicioJueves': true,
    'totalAsistencia': true,
    'nombreExtraN1': false,
    'extraN1': false,
    'nombreExtraN2': false,
    'extraN2': false,
    'inicioSemana': true,
    'finSemana': true,
    'estado': false,
  };

  final List<Map<String, String>> _allPossibleColumns = [
    {'key': 'usuario', 'label': 'Usuario', 'dataKey': 'nombreUsuario'},
    {'key': 'tipoSexo', 'label': 'Sexo', 'dataKey': 'tipoSexo'},
    {
      'key': 'fechaNacimiento',
      'label': 'Fecha Nac.',
      'dataKey': 'fechaNacimiento',
    },
    {
      'key': 'consagracionDomingo',
      'label': 'Dom',
      'dataKey': 'consagracionDomingo',
    },
    {'key': 'escuelaDominical', 'label': 'Esc', 'dataKey': 'escuelaDominical'},
    {'key': 'ensayoMartes', 'label': 'Mar', 'dataKey': 'ensayoMartes'},
    {'key': 'ensayoMiercoles', 'label': 'Mie', 'dataKey': 'ensayoMiercoles'},
    {'key': 'servicioJueves', 'label': 'Jue', 'dataKey': 'servicioJueves'},
    {'key': 'totalAsistencia', 'label': 'Total', 'dataKey': 'totalAsistencia'},
    {'key': 'nombreExtraN1', 'label': 'Ad.1 N', 'dataKey': 'nombreExtraN1'},
    {'key': 'extraN1', 'label': 'Ad.1 V', 'dataKey': 'extraN1'},
    {'key': 'nombreExtraN2', 'label': 'Ad.2 N', 'dataKey': 'nombreExtraN2'},
    {'key': 'extraN2', 'label': 'Ad.2 V', 'dataKey': 'extraN2'},
    {'key': 'inicioSemana', 'label': 'Inicio Sem.', 'dataKey': 'inicioSemana'},
    {'key': 'finSemana', 'label': 'Fin Sem.', 'dataKey': 'finSemana'},
    {'key': 'estado', 'label': 'Estado', 'dataKey': 'estado'},
  ];

  final List<String> _mainActivityKeys = [
    'consagracionDomingo',
    'escuelaDominical',
    'ensayoMartes',
    'ensayoMiercoles',
    'servicioJueves',
  ];

  @override
  void initState() {
    super.initState();
    _loadDataForHistorial();
  }

  Future<void> _loadDataForHistorial() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    _todosLosUsuarios = await AsistenciaDatabase.instance.readAllUsuarios();
    _asistenciasConNombreCompletas =
        await AsistenciaDatabase.instance
            .readAllAsistenciasConNombresDeUsuario();
    if (mounted) {
      setState(() {
        _asistenciasConNombreFiltradas = List.from(
          _asistenciasConNombreCompletas,
        );
        _isLoading = false;
      });
    }
  }

  List<String> _getVisibleActivityDisplayNames() {
    List<String> visibleActivities = [];
    _activityUIToDBFieldMapping.forEach((displayKey, dbFieldKey) {
      if (_columnVisibility[dbFieldKey] == true) {
        visibleActivities.add(displayKey);
      }
    });
    return visibleActivities;
  }

  void _applyFilters() {
    if (!mounted) return;
    List<Map<String, dynamic>> filtradas = List.from(
      _asistenciasConNombreCompletas,
    );
    if (_selectedUsuarioFiltro != null) {
      filtradas =
          filtradas
              .where(
                (itemMap) =>
                    itemMap['usuarioId'] == _selectedUsuarioFiltro!.idUsuario,
              )
              .toList();
    }
    if (_selectedActividadFiltroValue != null &&
        _selectedActividadFiltroValue!.isNotEmpty) {
      filtradas =
          filtradas.where((itemMap) {
            final value = itemMap[_selectedActividadFiltroValue!] as String?;
            return value != null && value.isNotEmpty;
          }).toList();
    }
    if (_selectedDateRangeFiltro != null) {
      filtradas =
          filtradas.where((itemMap) {
            final inicioSemanaAsistenciaStr =
                itemMap['inicioSemana'] as String?;
            if (inicioSemanaAsistenciaStr == null) return false;
            try {
              final inicioSemanaAsistencia =
                  DateTime.parse(inicioSemanaAsistenciaStr).toLocal();
              final filtroStart = DateTime(
                _selectedDateRangeFiltro!.start.year,
                _selectedDateRangeFiltro!.start.month,
                _selectedDateRangeFiltro!.start.day,
              );
              final filtroEnd = DateTime(
                _selectedDateRangeFiltro!.end.year,
                _selectedDateRangeFiltro!.end.month,
                _selectedDateRangeFiltro!.end.day,
              );
              final asistenciaDateOnly = DateTime(
                inicioSemanaAsistencia.year,
                inicioSemanaAsistencia.month,
                inicioSemanaAsistencia.day,
              );
              return !asistenciaDateOnly.isBefore(filtroStart) &&
                  !asistenciaDateOnly.isAfter(filtroEnd);
            } catch (e) {
              return false;
            }
          }).toList();
    }
    setState(() => _asistenciasConNombreFiltradas = filtradas);
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedDateRangeFiltro,
      helpText: 'Seleccione Rango de Fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
      errorFormatText: 'Formato de fecha inválido',
      errorInvalidText: 'Fecha inválida',
      errorInvalidRangeText: 'Rango inválido',
      fieldStartHintText: 'Fecha de inicio',
      fieldEndHintText: 'Fecha de fin',
    );
    if (picked != null && picked != _selectedDateRangeFiltro) {
      setState(() {
        _selectedDateRangeFiltro = picked;
        _applyFilters();
      });
    }
  }

  Future<void> _showSelectColumnsDialog() async {
    Map<String, bool> tempVisibility = Map.from(_columnVisibility);
    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, StateSetter setStateDialog) {
            return AlertDialog(
              title: const Text('Seleccionar Columnas Visibles'),
              content: SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _allPossibleColumns.length,
                  itemBuilder: (BuildContext context, int index) {
                    final columnMap = _allPossibleColumns[index];
                    final columnKey = columnMap['key']!;
                    final columnLabel = columnMap['label']!;
                    return CheckboxListTile(
                      title: Text(columnLabel),
                      value: tempVisibility[columnKey],
                      onChanged:
                          (bool? newValue) => setStateDialog(
                            () => tempVisibility[columnKey] = newValue!,
                          ),
                    );
                  },
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancelar'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  child: const Text('Aplicar'),
                  onPressed: () {
                    setState(() {
                      _columnVisibility = tempVisibility;
                      if (_selectedActividadFiltroValue != null &&
                          _columnVisibility[_selectedActividadFiltroValue!] ==
                              false) {
                        _selectedActividadFiltroDisplay = null;
                        _selectedActividadFiltroValue = null;
                      }
                    });
                    _applyFilters();
                    Navigator.of(dialogContext).pop();
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<DataColumn> _getVisibleDataColumns() {
    List<DataColumn> visibleColumns = [];
    for (var colMap in _allPossibleColumns) {
      final columnKey = colMap['key']!;
      final columnLabel = colMap['label']!;
      bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
      if (_columnVisibility[columnKey] == true) {
        if (_selectedActividadFiltroValue != null &&
            _selectedActividadFiltroValue!.isNotEmpty) {
          if (!isMainActivityColumn) {
            visibleColumns.add(
              DataColumn(label: Center(child: Text(columnLabel))),
            );
          } else {
            if (columnKey == _selectedActividadFiltroValue) {
              visibleColumns.add(
                DataColumn(label: Center(child: Text(columnLabel))),
              );
            }
          }
        } else {
          visibleColumns.add(
            DataColumn(label: Center(child: Text(columnLabel))),
          );
        }
      }
    }
    return visibleColumns;
  }

  List<DataCell> _getVisibleDataCells(Map<String, dynamic> itemMap) {
    List<DataCell> visibleCells = [];
    for (var colMap in _allPossibleColumns) {
      final columnKey = colMap['key']!;
      final dataKey = colMap['dataKey']!;
      bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
      bool shouldShowThisCell = false;
      if (_columnVisibility[columnKey] == true) {
        if (_selectedActividadFiltroValue != null &&
            _selectedActividadFiltroValue!.isNotEmpty) {
          if (!isMainActivityColumn) {
            shouldShowThisCell = true;
          } else {
            if (columnKey == _selectedActividadFiltroValue) {
              shouldShowThisCell = true;
            }
          }
        } else {
          shouldShowThisCell = true;
        }
      }
      if (shouldShowThisCell) {
        dynamic cellValue = itemMap[dataKey];
        String displayValue = "-";
        if (cellValue != null) {
          if (dataKey.toLowerCase().contains('fecha') ||
              dataKey == 'inicioSemana' ||
              dataKey == 'finSemana') {
            try {
              displayValue = DateFormat(
                'dd/MM/yy',
              ).format(DateTime.parse(cellValue.toString()).toLocal());
            } catch (e) {
              displayValue = cellValue.toString();
            }
          } else if (dataKey == 'totalAsistencia') {
            displayValue = '${cellValue}%';
          } else if (cellValue is String && cellValue.isEmpty) {
            displayValue = "-";
          } else {
            displayValue = cellValue.toString();
          }
        }
        Color? textColor;
        FontWeight? fontWeight;
        if (dataKey == 'totalAsistencia' && cellValue is int) {
          if (cellValue < 60)
            textColor = Colors.red.shade700;
          else if (cellValue < 65)
            textColor = Colors.yellow.shade800;
          else
            textColor = Colors.green.shade700;
          fontWeight = FontWeight.bold;
        }
        if (dataKey == 'estado' && cellValue is String) {
          textColor =
              cellValue == 'finalizado'
                  ? Colors.green.shade700
                  : Colors.orange.shade700;
        }
        bool shouldCenter = [
          'consagracionDomingo',
          'escuelaDominical',
          'ensayoMartes',
          'ensayoMiercoles',
          'servicioJueves',
          'totalAsistencia',
          'extraN1',
          'extraN2',
          'tipoSexo',
          'fechaNacimiento',
          'estado',
        ].contains(dataKey);
        Widget cellChild = Text(
          displayValue,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
            fontWeight: fontWeight,
          ),
        );
        if (shouldCenter) cellChild = Center(child: cellChild);
        if (dataKey == 'nombreUsuario' ||
            dataKey == 'nombreExtraN1' ||
            dataKey == 'nombreExtraN2') {
          cellChild = SizedBox(
            width: dataKey == 'nombreUsuario' ? 120 : 80,
            child: Text(
              displayValue,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: textColor,
                fontWeight: fontWeight,
              ),
            ),
          );
        }
        visibleCells.add(DataCell(cellChild));
      }
    }
    return visibleCells;
  }

  Future<void> _exportToPdf() async {
    if (_asistenciasConNombreFiltradas.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar.')),
      );
      return;
    }

    // 1. Lógica de Permisos Mejorada
    bool hasPermission = false;
    TargetPlatform? platform =
        Theme.of(
          context,
        ).platform; // O usa import 'dart:io'; Platform.isAndroid etc.

    if (platform == TargetPlatform.android) {
      // Para Android, necesitamos el permiso de almacenamiento
      var status = await Permission.storage.status;
      print("Storage permission status: $status");
      if (!status.isGranted) {
        status = await Permission.storage.request();
        print("Storage permission after request: $status");
      }
      if (status.isGranted) {
        hasPermission = true;
      } else if (status.isPermanentlyDenied) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Permiso denegado permanentemente. Habilítelo en la configuración.',
            ),
          ),
        );
        openAppSettings();
        return;
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permiso de almacenamiento denegado.')),
        );
        return;
      }
    } else {
      // Para otras plataformas como iOS o Desktop, el acceso a directorios de app suele estar permitido.
      hasPermission = true;
    }

    if (!hasPermission) {
      return; // No continuar si no hay permiso
    }

    // Si llegamos aquí, tenemos permiso (o no se requiere explícitamente para la plataforma/directorio)
    setState(() => _isLoading = true); // Mostrar indicador de carga

    try {
      final pdf = pw.Document();
      // ... (TU LÓGICA PARA CONSTRUIR EL PDF CON pdfData y pdfColumns SE MANTIENE IGUAL)
      // Aquí va la sección donde creas List<Map<String, String>> pdfColumns y List<List<String>> pdfData
      // y luego pdf.addPage(...)
      List<Map<String, String>> pdfColumns =
          _allPossibleColumns
              .where((colMap) => _columnVisibility[colMap['key']!] == true)
              .toList();
      if (_selectedActividadFiltroValue != null &&
          _selectedActividadFiltroValue!.isNotEmpty) {
        pdfColumns =
            pdfColumns.where((colMap) {
              bool isMainActivityColumn = _mainActivityKeys.contains(
                colMap['key']!,
              );
              if (!isMainActivityColumn) return true;
              return colMap['key']! == _selectedActividadFiltroValue;
            }).toList();
      }
      List<List<String>> pdfData = [];
      pdfData.add(pdfColumns.map((col) => col['label']!).toList()); // Cabeceras
      for (var itemMap in _asistenciasConNombreFiltradas) {
        // Usar los datos filtrados
        List<String> row = [];
        for (var colMap in pdfColumns) {
          final dataKey = colMap['dataKey']!;
          dynamic cellValue = itemMap[dataKey];
          String displayValue = "-";
          if (cellValue != null) {
            if (dataKey.toLowerCase().contains('fecha') ||
                dataKey == 'inicioSemana' ||
                dataKey == 'finSemana') {
              try {
                displayValue = DateFormat(
                  'dd/MM/yyyy',
                ).format(DateTime.parse(cellValue.toString()).toLocal());
              } catch (e) {
                displayValue = cellValue.toString();
              }
            } else if (dataKey == 'totalAsistencia') {
              displayValue = '${cellValue}%';
            } else if (cellValue is String && cellValue.isEmpty) {
              displayValue = "-";
            } else {
              displayValue = cellValue.toString();
            }
          }
          row.add(displayValue);
        }
        pdfData.add(row);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context pdfContext) {
            return [
              pw.Header(
                level: 0,
                child: pw.Text(
                  'Historial de Asistencias Coro',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 15),
              if (_selectedUsuarioFiltro != null)
                pw.Text(
                  'Filtro Usuario: ${_selectedUsuarioFiltro!.nombreCompleto}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              if (_selectedActividadFiltroDisplay != null)
                pw.Text(
                  'Filtro Actividad: $_selectedActividadFiltroDisplay',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              if (_selectedDateRangeFiltro != null)
                pw.Text(
                  'Filtro Rango: ${DateFormat('dd/MM/yyyy').format(_selectedDateRangeFiltro!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRangeFiltro!.end)}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                  ),
                ),
              if (_selectedUsuarioFiltro != null ||
                  _selectedActividadFiltroDisplay != null ||
                  _selectedDateRangeFiltro != null)
                pw.SizedBox(height: 8),
              pw.Table.fromTextArray(
                headers: pdfData.first,
                data: pdfData.sublist(1),
                border: pw.TableBorder.all(
                  color: PdfColors.grey600,
                  width: 0.5,
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
                ),
                cellStyle: const pw.TextStyle(fontSize: 6),
                cellAlignment: pw.Alignment.centerLeft,
                headerAlignment: pw.Alignment.centerLeft,
              ),
            ];
          },
        ),
      );
      // FIN DE LA CONSTRUCCIÓN DEL PDF

      Directory? directory;
      String dirPathDescription = "Documentos de la app";

      if (Platform.isAndroid) {
        // Guardar en el directorio externo específico de la app (Android/data/...)
        // Este directorio no requiere permisos especiales más allá de los que otorga el sistema a la app
        // para su propio almacenamiento externo.
        directory = await getExternalStorageDirectory();
        if (directory != null) {
          final pdfsPath = Directory("${directory.path}/PDFs");
          if (!await pdfsPath.exists()) {
            await pdfsPath.create(recursive: true);
          }
          directory = pdfsPath; // Guardar en la subcarpeta PDFs
          dirPathDescription = "Almacenamiento de la App/PDFs";
        } else {
          // Fallback si getExternalStorageDirectory es null
          directory = await getApplicationDocumentsDirectory();
          dirPathDescription = "Documentos de la App (fallback)";
        }
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
        dirPathDescription = "Documentos (iOS)";
      } else {
        // Desktop
        directory =
            await getDownloadsDirectory(); // Intenta usar la carpeta de descargas del sistema
        if (directory == null) {
          // Fallback para desktop
          directory = await getApplicationDocumentsDirectory();
          dirPathDescription = "Documentos de la App (Desktop fallback)";
        } else {
          dirPathDescription = "Descargas (Desktop)";
        }
      }

      if (directory == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener un directorio de guardado.'),
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      final String fileName =
          'historial_asistencias_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final String filePath = '${directory.path}/$fileName';
      final File file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      print('PDF Guardado en: $filePath');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF guardado en $dirPathDescription: $fileName'),
          duration: const Duration(seconds: 7), // Más tiempo
          action: SnackBarAction(
            label: 'Abrir',
            onPressed: () async {
              final openResult = await OpenFile.open(filePath);
              print("OpenFile result: ${openResult.message}");
              if (openResult.type != ResultType.done) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'No se pudo abrir el archivo: ${openResult.message}',
                      ),
                    ),
                  );
                }
              }
            },
          ),
        ),
      );
    } catch (e) {
      print('Error al exportar PDF: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar PDF: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> visibleActivityOptions = _getVisibleActivityDisplayNames();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial Usuarios Coro'),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<Usuario>(
                            /* ... Dropdown Usuario ... */
                            decoration: const InputDecoration(
                              labelText: 'Usuario',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            value: _selectedUsuarioFiltro,
                            hint: const Text('Todos'),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<Usuario>(
                                value: null,
                                child: Text('Todos los Usuarios'),
                              ),
                              ..._todosLosUsuarios
                                  .map(
                                    (Usuario u) => DropdownMenuItem<Usuario>(
                                      value: u,
                                      child: Text(
                                        u.nombreCompleto ?? 'N/A',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                            onChanged:
                                (Usuario? newVal) => setState(() {
                                  _selectedUsuarioFiltro = newVal;
                                  _applyFilters();
                                }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            /* ... Dropdown Actividad ... */
                            decoration: const InputDecoration(
                              labelText: 'Actividad',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                            ),
                            value: _selectedActividadFiltroDisplay,
                            hint: const Text('Todas'),
                            isExpanded: true,
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('Todas las Actividades'),
                              ),
                              ...visibleActivityOptions
                                  .map(
                                    (String act) => DropdownMenuItem<String>(
                                      value: act,
                                      child: Text(
                                        act,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ],
                            onChanged:
                                (String? newDispVal) => setState(() {
                                  _selectedActividadFiltroDisplay = newDispVal;
                                  _selectedActividadFiltroValue =
                                      newDispVal != null
                                          ? _activityUIToDBFieldMapping[newDispVal]
                                          : null;
                                  _applyFilters();
                                }),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Tooltip(
                          message: 'Rango de Fechas',
                          child: IconButton(
                            icon: const Icon(Icons.calendar_today),
                            onPressed: _pickDateRange,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (_selectedDateRangeFiltro != null)
                          Tooltip(
                            message: 'Limpiar Fecha',
                            child: IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed:
                                  () => setState(() {
                                    _selectedDateRangeFiltro = null;
                                    _applyFilters();
                                  }),
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_selectedDateRangeFiltro != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Rango: ${DateFormat('dd/MM/yy').format(_selectedDateRangeFiltro!.start)} - ${DateFormat('dd/MM/yy').format(_selectedDateRangeFiltro!.end)}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8.0,
                      vertical: 4.0,
                    ),
                    child: Row(
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.view_column_outlined),
                          label: const Text('Columnas'),
                          onPressed: _showSelectColumnsDialog,
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          iconSize: 30.0,
                          tooltip: 'Exportar PDF',
                          color: Colors.redAccent,
                          onPressed:
                              _asistenciasConNombreFiltradas.isEmpty
                                  ? null
                                  : _exportToPdf,
                        ),
                        IconButton(
                          icon: const FaIcon(FontAwesomeIcons.solidFileExcel),
                          iconSize: 28.0,
                          tooltip: 'Exportar Excel',
                          color: Colors.green,
                          onPressed:
                              () => ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Exportar Excel (Pendiente)'),
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  Expanded(
                    child:
                        _asistenciasConNombreFiltradas.isEmpty
                            ? const Center(
                              child: Text(
                                'No hay asistencias que coincidan con los filtros.',
                              ),
                            )
                            : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(8.0),
                                child: DataTable(
                                  columnSpacing: 12.0,
                                  headingRowHeight: 48,
                                  dataRowMinHeight: 40,
                                  dataRowMaxHeight: 48,
                                  border: TableBorder.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                  headingTextStyle: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  columns: _getVisibleDataColumns(),
                                  rows:
                                      _asistenciasConNombreFiltradas
                                          .map(
                                            (itemMap) => DataRow(
                                              cells: _getVisibleDataCells(
                                                itemMap,
                                              ),
                                            ),
                                          )
                                          .toList(),
                                ),
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}
