// historial.dart
import 'dart:io'; // Para File
import 'dart:typed_data'; // Para Uint8List
import 'package:flutter/material.dart';
// import 'package:flutter/services.dart'; // No se usa Flutter Services directamente aquí
import 'package:intl/intl.dart';
import 'package:asistencia/models/model.dart'; // Ajusta la ruta
import 'package:asistencia/database/asistencia_database.dart'; // Ajusta la ruta
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

// Imports para PDF
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Imports para Excel
import 'package:excel/excel.dart';

// Imports para manejo de archivos y permisos
// import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
// import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';

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
  String?
  _selectedActividadFiltroValue; // El nombreCampoDB de la actividad seleccionada
  String?
  _selectedActividadFiltroDisplay; // El nombreDisplay de la actividad seleccionada
  DateTimeRange? _selectedDateRangeFiltro;
  String? _filtroPorcentajeActivo;

  // Estas se llenarán dinámicamente
  List<ActividadDefinicion> _definicionesDeActividades = [];
  Map<String, String> _activityUIToDBFieldMapping = {};
  Map<String, bool> _columnVisibility = {};
  List<Map<String, String>> _allPossibleColumns = [];
  List<String> _mainActivityKeys =
      []; // Lista de nombreCampoDB para actividades principales

  // Columnas fijas que no dependen de las actividades dinámicas
  final List<Map<String, String>> _fixedPreActivityColumns = [
    {'key': 'usuario', 'label': 'Usuario', 'dataKey': 'nombreUsuario'},
    {'key': 'tipoSexo', 'label': 'Sexo', 'dataKey': 'tipoSexo'},
    {
      'key': 'fechaNacimiento',
      'label': 'Fecha\nNac.',
      'dataKey': 'fechaNacimiento',
    },
  ];
  final List<Map<String, String>> _fixedPostActivityColumns = [
    {
      'key': 'totalAsistencia',
      'label': 'Total(%)',
      'dataKey': 'totalAsistencia',
    },
    {
      'key': 'nombreExtraN1',
      'label': 'Adic. 1\nNombre',
      'dataKey': 'nombreExtraN1',
    },
    {'key': 'extraN1', 'label': 'Adic. 1\nValor', 'dataKey': 'extraN1'},
    {
      'key': 'nombreExtraN2',
      'label': 'Adic. 2\nNombre',
      'dataKey': 'nombreExtraN2',
    },
    {'key': 'extraN2', 'label': 'Adic. 2\nValor', 'dataKey': 'extraN2'},
    {
      'key': 'inicioSemana',
      'label': 'Inicio\nSemana',
      'dataKey': 'inicioSemana',
    },
    {'key': 'finSemana', 'label': 'Fin\nSemana', 'dataKey': 'finSemana'},
    {'key': 'estado', 'label': 'Estado', 'dataKey': 'estado'},
  ];

  int _rowsPerPage = PaginatedDataTable.defaultRowsPerPage;
  final List<int> _availableRowsPerPage = [10, 20, 50, 100, 200, 500];
  int? _sortColumnIndex;
  bool _sortAscending = true;
  AsistenciaDataTableSource? _dataSource;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (mounted) setState(() => _isLoading = true);
    await _loadActivityDefinitions(); // Cargar definiciones primero
    await _loadDataForHistorial(); // Luego el resto de los datos
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadActivityDefinitions() async {
    _definicionesDeActividades =
        await AsistenciaDatabase.instance.readAllActividadDefiniciones();

    Map<String, String> tempActivityMapping = {};
    List<String> tempMainActivityKeys = [];
    List<Map<String, String>> dynamicActivityColumns = [];
    Map<String, bool> tempColumnVisibility = {};

    // Visibilidad por defecto para columnas fijas
    for (var colDef in _fixedPreActivityColumns) {
      tempColumnVisibility[colDef['key']!] =
          _columnVisibility[colDef['key']!] ??
          true; // Mantener si ya existe, sino true
    }
    for (var colDef in _fixedPostActivityColumns) {
      tempColumnVisibility[colDef['key']!] =
          _columnVisibility[colDef['key']!] ?? true;
    }
    // Por defecto, ocultar extras y detalles de usuario si no estaban definidos antes
    tempColumnVisibility['tipoSexo'] = _columnVisibility['tipoSexo'] ?? false;
    tempColumnVisibility['fechaNacimiento'] =
        _columnVisibility['fechaNacimiento'] ?? false;
    tempColumnVisibility['nombreExtraN1'] =
        _columnVisibility['nombreExtraN1'] ?? false;
    tempColumnVisibility['extraN1'] = _columnVisibility['extraN1'] ?? false;
    tempColumnVisibility['nombreExtraN2'] =
        _columnVisibility['nombreExtraN2'] ?? false;
    tempColumnVisibility['extraN2'] = _columnVisibility['extraN2'] ?? false;
    tempColumnVisibility['estado'] =
        _columnVisibility['estado'] ?? false; // Mostrar estado por defecto

    for (var def in _definicionesDeActividades) {
      tempActivityMapping[def.nombreDisplay] = def.nombreCampoDB;
      tempMainActivityKeys.add(def.nombreCampoDB);
      dynamicActivityColumns.add({
        'key': def.nombreCampoDB,
        'label': def.etiquetaCorta,
        'dataKey': def.nombreCampoDB,
      });
      // Añadir visibilidad para esta actividad, por defecto true si no estaba antes
      tempColumnVisibility[def.nombreCampoDB] =
          _columnVisibility[def.nombreCampoDB] ?? true;
    }

    // Construir _allPossibleColumns en el orden deseado
    _allPossibleColumns = [
      ..._fixedPreActivityColumns,
      ...dynamicActivityColumns, // Actividades dinámicas en medio
      ..._fixedPostActivityColumns,
    ];

    // Actualizar el estado una vez con todos los datos generados
    if (mounted) {
      setState(() {
        _activityUIToDBFieldMapping = tempActivityMapping;
        _mainActivityKeys = tempMainActivityKeys;
        _columnVisibility = tempColumnVisibility;
        // _allPossibleColumns ya se asignó arriba
      });
    }
  }

  // String _generateShortActivityLabel(String fullName) {
  //   // Lógica simple para abreviar, puedes mejorarla
  //   if (fullName.contains("Domingo")) return "Consag.\nDomingo";
  //   if (fullName.contains("Escuela")) return "Escuela\nDominical";
  //   if (fullName.contains("Martes")) return "Mar";
  //   if (fullName.contains("Miércoles")) return "Mie";
  //   if (fullName.contains("Jueves")) return "Jue";
  //   var parts = fullName.split(" ");
  //   return parts.isNotEmpty && parts.first.length >= 3
  //       ? parts.first.substring(0, 3)
  //       : fullName;
  // }

  Future<void> _loadDataForHistorial() async {
    // Este método ahora solo carga usuarios y asistencias.
    // Las definiciones de actividad se cargan en _loadActivityDefinitions.
    if (!mounted) return;
    // No necesitamos setState isLoading aquí si _loadInitialData lo maneja

    _todosLosUsuarios = await AsistenciaDatabase.instance.readAllUsuarios();
    _asistenciasConNombreCompletas =
        await AsistenciaDatabase.instance
            .readAllAsistenciasConNombresDeUsuario();

    if (mounted) {
      setState(() {
        _asistenciasConNombreFiltradas = List.from(
          _asistenciasConNombreCompletas,
        );
        _updateDataSource(); // Asegúrate que esto se llama después de que _allPossibleColumns etc. estén listos
      });
    }
  }

  void _updateDataSource() {
    // Llamar a esto cada vez que _asistenciasConNombreFiltradas cambie (o los criterios de columna)
    if (!mounted) return;
    setState(() {
      _dataSource = AsistenciaDataTableSource(
        _asistenciasConNombreFiltradas,
        _allPossibleColumns, // Pasa la definición completa de columnas
        _columnVisibility,
        _selectedActividadFiltroValue,
        _mainActivityKeys,
      );
    });
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

    // Filtrar por usuario (sin cambios)
    if (_selectedUsuarioFiltro != null) {
      filtradas =
          filtradas
              .where(
                (itemMap) =>
                    itemMap['usuarioId'] == _selectedUsuarioFiltro!.idUsuario,
              )
              .toList();
    }

    // Filtrar por actividad seleccionada (sin cambios)
    if (_selectedActividadFiltroValue != null &&
        _selectedActividadFiltroValue!.isNotEmpty) {
      filtradas =
          filtradas.where((itemMap) {
            final value = itemMap[_selectedActividadFiltroValue!] as String?;
            return value != null && value.isNotEmpty;
          }).toList();
    }

    // Filtrar por rango de fechas (sin cambios)
    if (_selectedDateRangeFiltro != null) {
      // ... (lógica de filtro de fecha se mantiene)
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

    // --- NUEVO: Filtrar por Porcentaje ---
    if (_filtroPorcentajeActivo != null) {
      filtradas =
          filtradas.where((itemMap) {
            final totalAsistencia = itemMap['totalAsistencia'] as int?;
            if (totalAsistencia == null)
              return false; // O true si quieres incluir los que no tienen total

            if (_filtroPorcentajeActivo == '100%') {
              return totalAsistencia == 100;
            } else if (_filtroPorcentajeActivo == '<65%') {
              return totalAsistencia < 65;
            }
            return true; // No debería llegar aquí si _filtroPorcentajeActivo tiene uno de los dos valores
          }).toList();
    }

    setState(() {
      _asistenciasConNombreFiltradas = filtradas;
      _sortAndPaginateData(); // Llamar para reordenar y actualizar la fuente de datos
    });
  }

  // NUEVO: Método para manejar la ordenación y actualización de la fuente de datos
  void _sortAndPaginateData() {
    if (_sortColumnIndex != null) {
      final colMap = _getVisibleColumnDefinition(
        _sortColumnIndex!,
      ); // Obtener la definición de la columna visible
      if (colMap != null) {
        final dataKey = colMap['dataKey']!;
        _asistenciasConNombreFiltradas.sort((a, b) {
          dynamic valA = a[dataKey];
          dynamic valB = b[dataKey];

          // Manejar nulos para que no crashee la comparación
          if (valA == null && valB == null) return 0;
          if (valA == null) return _sortAscending ? -1 : 1;
          if (valB == null) return _sortAscending ? 1 : -1;

          // Lógica de comparación (puedes necesitar ajustarla según el tipo de dato)
          if (valA is String && valB is String) {
            return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
          } else if (valA is num && valB is num) {
            return _sortAscending ? valA.compareTo(valB) : valB.compareTo(valA);
          } else if (dataKey.toLowerCase().contains('fecha') ||
              dataKey == 'inicioSemana' ||
              dataKey == 'finSemana') {
            try {
              DateTime dateA = DateTime.parse(valA.toString());
              DateTime dateB = DateTime.parse(valB.toString());
              return _sortAscending
                  ? dateA.compareTo(dateB)
                  : dateB.compareTo(dateA);
            } catch (e) {
              return 0;
            } // No ordenar si el parseo falla
          }
          return 0;
        });
      }
    }
    _updateDataSource(); // Actualizar la fuente de datos para PaginatedDataTable
  }

  // Helper para obtener la definición de una columna visible por su índice actual en la tabla
  Map<String, String>? _getVisibleColumnDefinition(int visibleColumnIndex) {
    int currentIndex = -1;
    for (var colMap in _allPossibleColumns) {
      final columnKey = colMap['key']!;
      bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
      bool isVisibleThisTime = false;

      if (_columnVisibility[columnKey] == true) {
        if (_selectedActividadFiltroValue != null &&
            _selectedActividadFiltroValue!.isNotEmpty) {
          if (!isMainActivityColumn ||
              columnKey == _selectedActividadFiltroValue) {
            isVisibleThisTime = true;
          }
        } else {
          isVisibleThisTime = true;
        }
      }
      if (isVisibleThisTime) {
        currentIndex++;
        if (currentIndex == visibleColumnIndex) {
          return colMap;
        }
      }
    }
    return null;
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
              DataColumn(
                label: Center(
                  child: Text(columnLabel, textAlign: TextAlign.center),
                ),
              ),
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

  // List<DataCell> _getVisibleDataCells(Map<String, dynamic> itemMap) {
  //   List<DataCell> visibleCells = [];
  //   for (var colMap in _allPossibleColumns) {
  //     final columnKey = colMap['key']!;
  //     final dataKey = colMap['dataKey']!;
  //     bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
  //     bool shouldShowThisCell = false;
  //     if (_columnVisibility[columnKey] == true) {
  //       if (_selectedActividadFiltroValue != null &&
  //           _selectedActividadFiltroValue!.isNotEmpty) {
  //         if (!isMainActivityColumn) {
  //           shouldShowThisCell = true;
  //         } else {
  //           if (columnKey == _selectedActividadFiltroValue) {
  //             shouldShowThisCell = true;
  //           }
  //         }
  //       } else {
  //         shouldShowThisCell = true;
  //       }
  //     }
  //     if (shouldShowThisCell) {
  //       dynamic cellValue = itemMap[dataKey];
  //       String displayValue = "-";
  //       if (cellValue != null) {
  //         if (dataKey.toLowerCase().contains('fecha') ||
  //             dataKey == 'inicioSemana' ||
  //             dataKey == 'finSemana') {
  //           try {
  //             displayValue = DateFormat(
  //               'dd/MM/yy',
  //             ).format(DateTime.parse(cellValue.toString()).toLocal());
  //           } catch (e) {
  //             displayValue = cellValue.toString();
  //           }
  //         } else if (dataKey == 'totalAsistencia') {
  //           displayValue = '${cellValue}%';
  //         } else if (cellValue is String && cellValue.isEmpty) {
  //           displayValue = "-";
  //         } else {
  //           displayValue = cellValue.toString();
  //         }
  //       }
  //       Color? textColor;
  //       FontWeight? fontWeight;
  //       if (dataKey == 'totalAsistencia' && cellValue is int) {
  //         if (cellValue < 60)
  //           textColor = Colors.red.shade700;
  //         else if (cellValue < 65)
  //           textColor = Colors.yellow.shade800;
  //         else
  //           textColor = Colors.green.shade700;
  //         fontWeight = FontWeight.bold;
  //       }
  //       if (dataKey == 'estado' && cellValue is String) {
  //         textColor =
  //             cellValue == 'finalizado'
  //                 ? Colors.green.shade700
  //                 : Colors.orange.shade700;
  //       }
  //       bool shouldCenter = [
  //         'consagracionDomingo',
  //         'escuelaDominical',
  //         'ensayoMartes',
  //         'ensayoMiercoles',
  //         'servicioJueves',
  //         'totalAsistencia',
  //         'extraN1',
  //         'extraN2',
  //         'tipoSexo',
  //         'fechaNacimiento',
  //         'estado',
  //       ].contains(dataKey);
  //       Widget cellChild = Text(
  //         displayValue,
  //         style: TextStyle(
  //           fontSize: 12,
  //           color: textColor,
  //           fontWeight: fontWeight,
  //         ),
  //       );
  //       if (shouldCenter) cellChild = Center(child: cellChild);
  //       if (dataKey == 'nombreUsuario' ||
  //           dataKey == 'nombreExtraN1' ||
  //           dataKey == 'nombreExtraN2') {
  //         cellChild = SizedBox(
  //           width: dataKey == 'nombreUsuario' ? 120 : 80,
  //           child: Text(
  //             displayValue,
  //             overflow: TextOverflow.ellipsis,
  //             style: TextStyle(
  //               fontSize: 12,
  //               color: textColor,
  //               fontWeight: fontWeight,
  //             ),
  //           ),
  //         );
  //       }
  //       visibleCells.add(DataCell(cellChild));
  //     }
  //   }
  //   return visibleCells;
  // }

  Future<void> _exportToPdf() async {
    if (_asistenciasConNombreFiltradas.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pdf = pw.Document();

      // 1. Determinar las columnas visibles para el PDF (basado en filtros y _columnVisibility)
      // Esta lógica se mantiene igual.
      List<Map<String, String>> pdfColumnsDefinition =
          _allPossibleColumns
              .where((colMap) => _columnVisibility[colMap['key']!] == true)
              .toList();

      if (_selectedActividadFiltroValue != null &&
          _selectedActividadFiltroValue!.isNotEmpty) {
        pdfColumnsDefinition =
            pdfColumnsDefinition.where((colMap) {
              bool isMainActivityColumn = _mainActivityKeys.contains(
                colMap['key']!,
              );
              if (!isMainActivityColumn) return true;
              return colMap['key']! == _selectedActividadFiltroValue;
            }).toList();
      }

      // --- INICIO DE LA CONSTRUCCIÓN MANUAL DE LA TABLA PDF ---
      // 2. Crear las cabeceras para el PDF
      List<pw.Widget> pdfTableHeaders =
          pdfColumnsDefinition.map((col) {
            return pw.Container(
              alignment: pw.Alignment.centerLeft,
              padding: const pw.EdgeInsets.all(3.5),
              child: pw.Text(
                col['label']!,
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 7,
                ),
              ),
            );
          }).toList();

      // 3. Crear las filas de datos para el PDF con estilo condicional
      List<pw.TableRow> pdfTableRows = [];
      pdfTableRows.add(
        pw.TableRow(children: pdfTableHeaders),
      ); // Añadir la fila de cabeceras

      for (var itemMap in _asistenciasConNombreFiltradas) {
        List<pw.Widget> cells = [];
        for (var colMap in pdfColumnsDefinition) {
          final dataKey = colMap['dataKey']!;
          dynamic cellValue = itemMap[dataKey];
          String displayValue = "-";
          pw.TextStyle cellTextStyle = const pw.TextStyle(
            fontSize: 6,
          ); // Estilo base de celda

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
              if (cellValue is int) {
                if (cellValue < 60) {
                  cellTextStyle = cellTextStyle.copyWith(
                    color: PdfColors.red700,
                    fontWeight: pw.FontWeight.bold,
                  );
                } else if (cellValue < 65) {
                  cellTextStyle = cellTextStyle.copyWith(
                    color: PdfColors.orange700,
                    fontWeight: pw.FontWeight.bold,
                  ); // Usar orange para mejor visibilidad
                } else {
                  cellTextStyle = cellTextStyle.copyWith(
                    color: PdfColors.green700,
                    fontWeight: pw.FontWeight.bold,
                  );
                }
              }
            } else if (dataKey == 'estado' && cellValue is String) {
              displayValue = cellValue.toString();
              cellTextStyle = cellTextStyle.copyWith(
                fontStyle: pw.FontStyle.italic,
                color:
                    cellValue == 'finalizado'
                        ? PdfColors.green700
                        : PdfColors.orange700,
              );
            } else if (cellValue is String && cellValue.isEmpty) {
              displayValue = "-";
            } else {
              displayValue = cellValue.toString();
            }
          }

          pw.Alignment cellAlignment = pw.Alignment.centerLeft;
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
          if (shouldCenter) {
            cellAlignment = pw.Alignment.center;
          }

          cells.add(
            pw.Container(
              alignment: cellAlignment,
              padding: const pw.EdgeInsets.all(3.5),
              child: pw.Text(displayValue, style: cellTextStyle),
            ),
          );
        }
        pdfTableRows.add(pw.TableRow(children: cells));
      }
      // --- FIN DE LA CONSTRUCCIÓN MANUAL DE LA TABLA PDF ---

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context pdfBuilderContext) {
            // Renombrar context para evitar shadowing
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

              // Usar pw.Table con las filas construidas manualmente
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey600,
                  width: 0.5,
                ),
                children: pdfTableRows,
                // Aquí podrías añadir columnWidths si es necesario, basándote en pdfColumnsDefinition.length
                // Ejemplo: columnWidths: _generateColumnWidths(pdfColumnsDefinition.length)
              ),
            ];
          },
        ),
      );

      final Uint8List pdfBytes = await pdf.save();
      String? outputPath;
      final String suggestedFileName =
          'historial_asistencias_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

      if (Platform.isAndroid ||
          Platform.isIOS ||
          Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux) {
        String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
          dialogTitle: 'Seleccione una carpeta para guardar el PDF',
        );
        if (selectedDirectory != null) {
          outputPath = '$selectedDirectory/$suggestedFileName';
        }
      }

      if (outputPath != null) {
        final File file = File(outputPath);
        await file.writeAsBytes(pdfBytes);
        print('PDF Guardado en: $outputPath');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF guardado: $suggestedFileName'),
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () async {
                final openResult = await OpenFile.open(outputPath!);
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
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardado cancelado o no se seleccionó ruta.'),
          ),
        );
      }
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

  Future<void> _exportToExcel() async {
    if (_asistenciasConNombreFiltradas.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay datos para exportar a Excel.')),
      );
      return;
    }

    // No es estrictamente necesario pedir Permission.storage si usamos FilePicker,
    // pero lo mantenemos por si FilePicker lo necesita internamente en algunas plataformas/versiones.
    // var storageStatus = await Permission.storage.status;
    // if (!storageStatus.isGranted) {
    //   storageStatus = await Permission.storage.request();
    // }

    // if (!storageStatus.isGranted) {
    //   if (!mounted) return;
    //   ScaffoldMessenger.of(context).showSnackBar(
    //     SnackBar(
    //       content: Text(
    //         'Permiso de almacenamiento denegado para exportar. ${storageStatus.toString()}',
    //       ),
    //     ),
    //   );
    //   if (storageStatus.isPermanentlyDenied) {
    //     openAppSettings();
    //   }
    //   return;
    // }

    setState(() => _isLoading = true);

    try {
      // 1. Crear un nuevo libro de Excel
      var excel = Excel.createExcel(); // El objeto principal del paquete
      // Opcional: darle un nombre a la hoja por defecto o usar la que se crea
      Sheet sheetObject = excel['HistorialAsistencia']; // Obtener/crear la hoja

      // 2. Determinar las columnas visibles para el Excel (basado en filtros y _columnVisibility)
      List<Map<String, String>> excelColumnsDefinition =
          _allPossibleColumns
              .where((colMap) => _columnVisibility[colMap['key']!] == true)
              .toList();

      if (_selectedActividadFiltroValue != null &&
          _selectedActividadFiltroValue!.isNotEmpty) {
        excelColumnsDefinition =
            excelColumnsDefinition.where((colMap) {
              bool isMainActivityColumn = _mainActivityKeys.contains(
                colMap['key']!,
              );
              if (!isMainActivityColumn) return true;
              return colMap['key']! == _selectedActividadFiltroValue;
            }).toList();
      }

      // 3. Escribir las cabeceras
      List<CellValue> headerRow = []; // La API espera List<CellValue>
      for (var colDef in excelColumnsDefinition) {
        headerRow.add(
          TextCellValue(colDef['label']!), // Valor del texto
          // El estilo se aplica a la celda, no directamente al TextCellValue en versiones recientes
        );
      }
      sheetObject.appendRow(headerRow);

      // Aplicar estilo a la fila de cabeceras
      for (var i = 0; i < headerRow.length; i++) {
        var cell = sheetObject.cell(
          CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.cellStyle = CellStyle(
          bold: true,
          fontSize: 10,
          backgroundColorHex: ExcelColor.grey300, // Gris claro
          fontColorHex: ExcelColor.black, // Negro
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
        );
      }

      // 4. Escribir las filas de datos
      for (
        int rowIndex = 0;
        rowIndex < _asistenciasConNombreFiltradas.length;
        rowIndex++
      ) {
        final itemMap = _asistenciasConNombreFiltradas[rowIndex];
        List<CellValue> dataCells = []; // Lista para las celdas de esta fila

        for (
          int colIndex = 0;
          colIndex < excelColumnsDefinition.length;
          colIndex++
        ) {
          final colMap = excelColumnsDefinition[colIndex];
          final dataKey = colMap['dataKey']!;
          dynamic cellValue = itemMap[dataKey];
          CellValue cellValueToAdd;

          // Estilo base para la celda
          ExcelColor fontColorHex = ExcelColor.black; // Negro por defecto
          ExcelColor backgroundColorHex = ExcelColor.none; // Sin fondo
          bool isBold = false;
          bool isItalic = false;

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
              cellValueToAdd = TextCellValue(displayValue);
            } else if (dataKey == 'totalAsistencia') {
              if (cellValue is int) {
                displayValue = '$cellValue%';
                isBold = true;
                if (cellValue < 60)
                  fontColorHex = ExcelColor.redAccent; // Rojo
                else if (cellValue < 65)
                  fontColorHex = ExcelColor.orangeAccent; // Naranja
                else
                  fontColorHex = ExcelColor.green; // Verde
              } else {
                displayValue = cellValue.toString();
              }
              cellValueToAdd = TextCellValue(displayValue);
            } else if (dataKey == 'estado' && cellValue is String) {
              displayValue = cellValue;
              isItalic = true;
              fontColorHex =
                  cellValue == 'finalizado'
                      ? ExcelColor.greenAccent
                      : ExcelColor.orangeAccent; // Verde : Naranja
              cellValueToAdd = TextCellValue(displayValue);
            } else if (cellValue is String && cellValue.isEmpty) {
              displayValue = "-";
              cellValueToAdd = TextCellValue(displayValue);
            } else if (cellValue is int) {
              cellValueToAdd = IntCellValue(cellValue);
            } else if (cellValue is double) {
              cellValueToAdd = DoubleCellValue(cellValue);
            } else {
              displayValue = cellValue.toString();
              cellValueToAdd = TextCellValue(displayValue);
            }
          } else {
            cellValueToAdd = TextCellValue("-"); // Si cellValue es null
          }
          dataCells.add(cellValueToAdd);

          // Aplicar estilo a la celda recién añadida
          var cell = sheetObject.cell(
            CellIndex.indexByColumnRow(
              columnIndex: colIndex,
              rowIndex: rowIndex + 1, // +1 porque la fila 0 es la cabecera
            ),
          );
          cell.cellStyle = CellStyle(
            fontSize: 9,
            textWrapping: TextWrapping.WrapText,
            verticalAlign: VerticalAlign.Center,
            horizontalAlign:
                (cellValueToAdd is IntCellValue ||
                        cellValueToAdd is DoubleCellValue ||
                        dataKey == 'totalAsistencia')
                    ? HorizontalAlign
                        .Right // Alinear números a la derecha
                    : HorizontalAlign.Left,
            fontColorHex: fontColorHex, // Usar la clase HexColor del paquete
            backgroundColorHex: backgroundColorHex,
            bold: isBold,
            italic: isItalic,
          );
        }
        sheetObject.appendRow(dataCells);
      }

      // Autoajustar anchos de columna (opcional)
      for (var i = 0; i < excelColumnsDefinition.length; i++) {
        sheetObject.setColumnWidth(i, 15);
      }

      // 5. Obtener los bytes del archivo Excel
      var fileBytes = excel.save(fileName: "historial_asistencias_temp.xlsx");

      if (fileBytes == null) {
        throw Exception("No se pudieron generar los bytes del archivo Excel.");
      }

      // 6. GUARDAR EL ARCHIVO USANDO FILE PICKER (SAF) - Esta lógica se mantiene
      String? outputPath;
      final String suggestedFileName =
          'historial_asistencias_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';

      String? selectedDirectory = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Seleccione una carpeta para guardar el Excel',
      );

      if (selectedDirectory != null) {
        outputPath = '$selectedDirectory/$suggestedFileName';
      }

      if (outputPath != null) {
        final File file = File(outputPath);
        await file.writeAsBytes(fileBytes); // fileBytes es List<int>

        print('Excel Guardado en: $outputPath');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Excel guardado: $suggestedFileName'),
            duration: const Duration(seconds: 7),
            action: SnackBarAction(
              label: 'Abrir',
              onPressed: () async {
                final openResult = await OpenFile.open(outputPath!);
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
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Guardado cancelado o no se seleccionó ruta.'),
          ),
        );
      }
    } catch (e) {
      print('Error al exportar Excel: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al exportar Excel: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- _getVisibleDataCells (AHORA DENTRO DE AsistenciaDataTableSource) ---
  // --- build() (La lógica del DataTable usará los métodos _getVisible... que operan con las listas dinámicas) ---

  // Asegúrate que _loadValoresNotasBase también se llame en _loadInitialData si es necesario.
  // (Lo tenías, así que lo mantengo)
  // Future<void> _loadValoresNotasBase() async {
  //   final notas = await AsistenciaDatabase.instance.readAllNotaAsistenciat();
  //   Map<String, int> tempValores = {};
  //   for (var nota in notas) {
  //     if (nota.idNota != null) {
  //       tempValores[nota.idNota!] = nota.valorNota ?? 0;
  //     }
  //   }
  //   // if (mounted) {
  //   //   setState(() {
  //   //     _valoresNotasBase = tempValores;
  //   //   });
  //   // }
  // }

  @override
  Widget build(BuildContext context) {
    // La generación de visibleActivityOptions se hace aquí porque depende de _columnVisibility que se actualiza
    List<String> visibleActivityOptions = _getVisibleActivityDisplayNames();
    final List<DataColumn> currentVisibleColumns =
        _getVisibleDataColumns(); // Necesita _allPossibleColumns

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
                              ...visibleActivityOptions.map(
                                (String act) => DropdownMenuItem<String>(
                                  value: act,
                                  child: Text(
                                    act,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              // .toList(),
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
                          icon: const Icon(
                            Icons.view_column_outlined,
                            size: 20,
                          ),
                          label: const Text(
                            'Columnas',
                            style: TextStyle(fontSize: 13),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                          ),
                          onPressed: _showSelectColumnsDialog,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    _filtroPorcentajeActivo == '100%'
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.grey[700],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                '100%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed:
                                  () => setState(() {
                                    _filtroPorcentajeActivo =
                                        _filtroPorcentajeActivo == '100%'
                                            ? null
                                            : '100%';
                                    _applyFilters();
                                  }),
                            ),
                            const SizedBox(width: 4),
                            TextButton(
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    _filtroPorcentajeActivo == '<65%'
                                        ? Colors.red.shade700
                                        : Colors.grey[700],
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                '< 65%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onPressed:
                                  () => setState(() {
                                    _filtroPorcentajeActivo =
                                        _filtroPorcentajeActivo == '<65%'
                                            ? null
                                            : '<65%';
                                    _applyFilters();
                                  }),
                            ),
                          ],
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.picture_as_pdf_rounded),
                          iconSize: 30.0,
                          tooltip: 'Exportar PDF',
                          color: Colors.redAccent,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed:
                              _asistenciasConNombreFiltradas.isEmpty
                                  ? null
                                  : _exportToExcel,
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
                              child: PaginatedDataTable(
                                key: ValueKey(
                                  _asistenciasConNombreFiltradas.hashCode +
                                      _sortColumnIndex.hashCode +
                                      _sortAscending.hashCode +
                                      _columnVisibility.hashCode +
                                      (_selectedActividadFiltroValue
                                              ?.hashCode ??
                                          0),
                                ),
                                header: const Text('Historial de Asistencias'),
                                rowsPerPage: _rowsPerPage,
                                availableRowsPerPage: _availableRowsPerPage,
                                onRowsPerPageChanged: (int? value) {
                                  if (value != null)
                                    setState(() {
                                      _rowsPerPage = value;
                                      _updateDataSource();
                                    });
                                },
                                sortColumnIndex: _sortColumnIndex,
                                sortAscending: _sortAscending,
                                columns:
                                    currentVisibleColumns.map((DataColumn col) {
                                      String columnLabelText = '';
                                      if (col.label is Center &&
                                          (col.label as Center).child is Text)
                                        columnLabelText =
                                            ((col.label as Center).child
                                                    as Text)
                                                .data ??
                                            '';
                                      else if (col.label is Text)
                                        columnLabelText =
                                            (col.label as Text).data ?? '';

                                      // Encontrar la definición original para la key de ordenación
                                      _allPossibleColumns.firstWhere(
                                        (def) {
                                          // Comparamos el texto de la etiqueta del DataColumn con el label de _allPossibleColumns
                                          // Esto es un poco frágil si las etiquetas cambian mucho. Sería mejor un ID más robusto.
                                          // O, si currentVisibleColumns se genera manteniendo el 'key' original, usar eso.
                                          // Por ahora, asumimos que el texto del label es suficiente para encontrarlo.
                                          // La lógica de _getVisibleColumnDefinition era para mapear el ÍNDICE visible a la definición.
                                          // Aquí tenemos el DataColumn, así que podemos extraer su texto.
                                          return def['label'] ==
                                              columnLabelText;
                                        },
                                        orElse:
                                            () => {
                                              'key': 'desconocido',
                                              'label': 'Error',
                                              'dataKey': 'error',
                                            },
                                      );

                                      return DataColumn(
                                        label: col.label,
                                        onSort: (int colIdx, bool asc) {
                                          // colIdx aquí es el índice DENTRO de currentVisibleColumns
                                          // Necesitamos mapearlo al _sortColumnIndex global si es necesario,
                                          // o simplemente usarlo para encontrar la definición de columna correcta.
                                          // _getVisibleColumnDefinition ya hace esto.
                                          setState(() {
                                            _sortColumnIndex =
                                                colIdx; // El PaginatedDataTable devuelve el índice de la columna visible
                                            _sortAscending = asc;
                                            _sortAndPaginateData();
                                          });
                                        },
                                      );
                                    }).toList(),
                                source:
                                    _dataSource ??
                                    AsistenciaDataTableSource(
                                      [],
                                      [],
                                      {},
                                      null,
                                      [],
                                    ),
                              ),
                            ),
                  ),
                ],
              ),
    );
  }
}

// La clase AsistenciaDataTableSource se mantiene igual, pero ahora recibirá
// _allPossibleColumns y _mainActivityKeys generados dinámicamente.
// Su método _getVisibleDataCellsForRow usará estas listas para construir las celdas.
class AsistenciaDataTableSource extends DataTableSource {
  final List<Map<String, dynamic>> _data;
  final List<Map<String, String>>
  _columnDefinitions; // Esta será _allPossibleColumns
  final Map<String, bool> _columnVisibility;
  final String? _selectedActivityFiltroValue;
  final List<String> _mainActivityKeys;

  AsistenciaDataTableSource(
    this._data,
    this._columnDefinitions,
    this._columnVisibility,
    this._selectedActivityFiltroValue,
    this._mainActivityKeys,
  );

  List<DataCell> _getVisibleDataCellsForRow(Map<String, dynamic> itemMap) {
    List<DataCell> visibleCells = [];
    for (var colMap in _columnDefinitions) {
      // Iterar sobre todas las posibles para mantener el orden
      final columnKey = colMap['key']!;
      final dataKey = colMap['dataKey']!;
      bool isMainActivityColumn = _mainActivityKeys.contains(columnKey);
      bool shouldShowThisCell = false;

      if (_columnVisibility[columnKey] == true) {
        // Primero, la columna debe ser visible globalmente
        if (_selectedActivityFiltroValue != null &&
            _selectedActivityFiltroValue!.isNotEmpty) {
          // Si hay filtro de actividad
          if (!isMainActivityColumn) {
            // Si no es una actividad principal, se muestra
            shouldShowThisCell = true;
          } else {
            // Si es una actividad principal
            if (columnKey == _selectedActivityFiltroValue) {
              // Solo se muestra si es la seleccionada
              shouldShowThisCell = true;
            }
          }
        } else {
          // No hay filtro de actividad, mostrar si es visible globalmente
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
        Widget cellChild = Text(
          displayValue,
          style: TextStyle(
            fontSize: 12,
            color: textColor,
            fontWeight: fontWeight,
          ),
        );
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

  @override
  DataRow? getRow(int index) {
    if (index >= _data.length) return null;
    final itemMap = _data[index];
    return DataRow(cells: _getVisibleDataCellsForRow(itemMap));
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get rowCount => _data.length;
  @override
  int get selectedRowCount => 0;
}
