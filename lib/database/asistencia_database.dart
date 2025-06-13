import 'package:asistencia/models/model.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AsistenciaDatabase {
  static final AsistenciaDatabase instance = AsistenciaDatabase._init();

  static Database? _database;

  AsistenciaDatabase._init();

  final String tableNotaAsistencia = 'nota_asistencias';
  final String tableUsuario = 'usuarios';
  final String tableAsistencia = 'asistencias';
  final String tableAutorizacion = 'autorizaciones';
  final String tableActividadDefiniciones = 'actividad_definiciones';

  Future<Database> get database async {
    if (_database != null) return _database!;

    _database = await _initDB('asistencia.db');

    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();

    final path = join(dbPath, filePath);

    await deleteDatabase(path);
    return await openDatabase(path, version: 1, onCreate: _onCreateDB);
  }

  Future _onCreateDB(Database db, int version) async {
    // Usaremos un batch para eficiencia si son múltiples inserciones
    Batch batch = db.batch();

    batch.execute('''
      CREATE TABLE $tableNotaAsistencia(
        idNota TEXT PRIMARY KEY NOT NULL,
        valorNota INTEGER DEFAULT 0.0,
        descripcionNota TEXT
      )''');

    _seedNotaAsistencia(batch);

    batch.execute('''
  CREATE TABLE $tableActividadDefiniciones(
    idActividad TEXT PRIMARY KEY NOT NULL, 
    nombreDisplay TEXT UNIQUE NOT NULL,
    nombreCampoDB TEXT UNIQUE NOT NULL,
    etiquetaCorta TEXT NOT NULL,
    ordenDisplay INTEGER DEFAULT 0
  )''');

    _seedActividades(batch);

    batch.execute('''
      CREATE TABLE $tableUsuario(
        idUsuario INTEGER PRIMARY KEY AUTOINCREMENT,
        nombreCompleto TEXT,
        tipoSexo TEXT,
        fechaNacimiento TEXT
      )''');

    _seedUsuarios(batch);

    batch.execute('''
      CREATE TABLE $tableAsistencia(
        idAsistencia INTEGER PRIMARY KEY AUTOINCREMENT,
        usuarioId INTEGER,
        consagracionDomingo TEXT,
        fechaConsagracionD TEXT,
        escuelaDominical TEXT,
        fechaEscuelaD TEXT,
        ensayoMartes TEXT,
        fechaEnsayoMartes,
        ensayoMiercoles TEXT,
        fechaEnsayoMiercoles,
        servicioJueves TEXT,
        fechaServicioJueves,
        totalAsistencia INTEGER,
        inicioSemana TEXT,
        finSemana TEXT,
        nombreExtraN1 TEXT,
        extraN1 INTEGER,
        nombreExtraN2 TEXT,
        extraN2 INTEGER,
        nombreExtraN3 TEXT,
        extraN3 INTEGER,
        nombreExtraN4 TEXT,
        extraN4 INTEGER,
        nombreExtraN5 TEXT,
        extraN5 INTEGER, 
        estado TEXT
      )''');

    _seedAsistencias(batch);

    batch.execute('''
      CREATE TABLE $tableAutorizacion(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        contrasena TEXT NOT NULL,
        repetirContrasena TEXT NOT NULL,
        intentos INTEGER DEFAULT 0
      )''');

    _seedAutorizaciones(batch);

    await batch.commit(noResult: true);
  }

  //-------------------------------tableNotaAsistencia = 'nota_asistencias' -------------------------------------------------------------------------------------------------------------------------------------------

  //insertar un Nota Asistencia
  Future<NotaAsistencia> createNotaAsistencia(
    NotaAsistencia notaAsistencia,
  ) async {
    final db = await instance.database;
    // section.idSection debe ser null aquí
    final id = await db.insert(
      tableNotaAsistencia,
      notaAsistencia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    return notaAsistencia.copyWith(
      idNota: id.toString(),
    ); // Devuelve la sección con el ID
  }

  // Leer una Nota Asistencia por ID
  Future<NotaAsistencia?> readNotaAsistencia(String id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableNotaAsistencia,
      columns: [
        'idNota',
        'valorNota',
        'descripcionNota',
      ], // Especifica columnas o null para todas
      where: 'idNota = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return NotaAsistencia.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Leer todas las Notas Asistencias
  Future<List<NotaAsistencia>> readAllNotaAsistenciat() async {
    final db = await instance.database;
    final orderBy = 'idNota ASC'; // Opcional: ordenar
    // final result = await db.rawQuery('SELECT * FROM $tableProductSections ORDER BY $orderBy');
    final result = await db.query(tableNotaAsistencia, orderBy: orderBy);
    return result.map((json) => NotaAsistencia.fromMap(json)).toList();
  }

  // Actualizar Nota Asistencia
  Future<int> updateNotaAsistencia(NotaAsistencia notaAsistencia) async {
    final db = await instance.database;
    return db.update(
      tableNotaAsistencia,
      notaAsistencia.toMap(),
      where: 'idNota = ?',
      whereArgs: [notaAsistencia.idNota],
    );
  }

  // Eliminar Nota Asistencia
  Future<int> deleteNotaAsistencia(String id) async {
    final db = await instance.database;
    return await db.delete(
      tableNotaAsistencia,
      where: 'idNota = ?',
      whereArgs: [id],
    );
  }

  //-------------------------------tableUsuario = 'usuarios' -------------------------------------------------------------------------------------------------------------------------------------------

  // Insertar un Usuario
  Future<Usuario> createUsuario(Usuario usuario) async {
    final db = await instance.database;
    final id = await db.insert(
      tableUsuario,
      usuario.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    return usuario.copyWith(idUsuario: id);
  }

  // Leer un Usuario por ID
  Future<Usuario?> readUsuario(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableUsuario,
      columns: ['idUsuario', 'nombreCompleto', 'tipoSexo', 'fechaNacimiento'],
      where: 'idUsuario = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Leer todos los Usuarios
  Future<List<Usuario>> readAllUsuarios() async {
    final db = await instance.database;
    final orderBy = 'idUsuario ASC'; // Opcional: ordenar
    final result = await db.query(tableUsuario, orderBy: orderBy);
    return result.map((json) => Usuario.fromMap(json)).toList();
  }

  // Actualizar Usuario
  Future<int> updateUsuario(Usuario usuario) async {
    final db = await instance.database;
    return db.update(
      tableUsuario,
      usuario.toMap(),
      where: 'idUsuario = ?',
      whereArgs: [usuario.idUsuario],
    );
  }

  // Eliminar Usuario
  Future<int> deleteUsuario(int id) async {
    final db = await instance.database;
    return await db.delete(
      tableUsuario,
      where: 'idUsuario = ?',
      whereArgs: [id],
    );
  }

  //-------------------------------tableAsistencia = 'asistencias' -------------------------------------------------------------------------------------------------------------------------------------------
  // Insertar una Asistencia
  Future<Asistencia> createAsistencia(Asistencia asistencia) async {
    final db = await instance.database;
    final id = await db.insert(
      tableAsistencia,
      asistencia.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    return asistencia.copyWith(idAsistencia: id);
  }

  // Leer una Asistencia por ID
  Future<Asistencia?> readAsistencia(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableAsistencia,
      columns: [
        'idAsistencia',
        'usuarioId',
        'consagracionDomingo',
        'fechaConsagracionD',
        'escuelaDominical',
        'fechaEscuelaD',
        'ensayoMartes',
        'fechaEnsayoMartes',
        'ensayoMiercoles',
        'fechaEnsayoMiercoles',
        'servicioJueves',
        'fechaServicioJueves',
        'totalAsistencia',
        'inicioSemana',
        'finSemana',
        'nombreExtraN1',
        'extraN1',
        'nombreExtraN2',
        'extraN2',
        'nombreExtraN3',
        'extraN3',
        'nombreExtraN4',
        'extraN4',
        'nombreExtraN5',
        'extraN5',
        'estado',
      ],
      where: 'idAsistencia = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Asistencia.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Leer todas las Asistencias
  Future<List<Asistencia>> readAllAsistencias() async {
    final db = await instance.database;
    final orderBy = 'idAsistencia ASC'; // Opcional: ordenar
    final result = await db.query(tableAsistencia, orderBy: orderBy);
    return result.map((json) => Asistencia.fromMap(json)).toList();
  }

  // Actualizar Asistencia
  Future<int> updateAsistencia(Asistencia asistencia) async {
    final db = await instance.database;
    return db.update(
      tableAsistencia,
      asistencia.toMap(),
      where: 'idAsistencia = ?',
      whereArgs: [asistencia.idAsistencia],
    );
  }

  // Eliminar Asistencia
  Future<int> deleteAsistencia(int id) async {
    final db = await instance.database;
    return await db.delete(
      tableAsistencia,
      where: 'idAsistencia = ?',
      whereArgs: [id],
    );
  }

  //-------------------------------tableAutorizacion = 'autorizaciones' -------------------------------------------------------------------------------------------------------------------------------------------

  Future<Autorizaciones> createAutorizacion(Autorizaciones autorizacion) async {
    final db = await instance.database;
    final id = await db.insert(
      tableAutorizacion,
      autorizacion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    return autorizacion.copyWith(id: id);
  }

  // Leer una Autorización por ID
  Future<Autorizaciones?> readAutorizacion(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      tableAutorizacion,
      columns: ['id', 'contrasena', 'repetirContrasena'],
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return Autorizaciones.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // Leer todas las Autorizaciones
  Future<List<Autorizaciones>> readAllAutorizaciones() async {
    final db = await instance.database;
    final orderBy = 'id ASC'; // Opcional: ordenar
    final result = await db.query(tableAutorizacion, orderBy: orderBy);
    return result.map((json) => Autorizaciones.fromMap(json)).toList();
  }

  // Actualizar Autorización
  Future<int> updateAutorizacion(Autorizaciones autorizacion) async {
    final db = await instance.database;
    return db.update(
      tableAutorizacion,
      autorizacion.toMap(),
      where: 'id = ?',
      whereArgs: [autorizacion.id],
    );
  }

  // Eliminar Autorización
  Future<int> deleteAutorizacion(int id) async {
    final db = await instance.database;
    return await db.delete(tableAutorizacion, where: 'id = ?', whereArgs: [id]);
  }

  //-------------------------------variadas = 'variadas' -------------------------------------------------------------------------------------------------------------------------------------------

  //insertar un Nota Asistencia
  Future<ActividadDefinicion> createActividadDefiniciones(
    ActividadDefinicion actividadDefinicion,
  ) async {
    final db = await instance.database;
    // section.idSection debe ser null aquí
    final id = await db.insert(
      tableNotaAsistencia,
      actividadDefinicion.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
    return actividadDefinicion.copyWith(
      idActividad: id.toString(),
    ); // Devuelve la sección con el ID
  }

  Future<List<ActividadDefinicion>> readAllActividadDefiniciones() async {
    final db = await instance.database;
    final orderBy = 'ordenDisplay ASC, nombreDisplay ASC'; // Ordenar
    final result = await db.query(tableActividadDefiniciones, orderBy: orderBy);
    return result.map((json) => ActividadDefinicion.fromMap(json)).toList();
  }

  //-------------------------------variadas = 'variadas' -------------------------------------------------------------------------------------------------------------------------------------------

  Future<Asistencia?> readActiveAsistenciaForUser(int usuarioId) async {
    final db = await instance.database;
    final maps = await db.query(
      tableAsistencia,
      where: 'usuarioId = ? AND estado = ?',
      whereArgs: [usuarioId, 'activo'], // Busca un registro activo
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Asistencia.fromMap(maps.first);
    } else {
      return null;
    }
  }

  // NUEVO MÉTODO PARA OBTENER ASISTENCIAS CON INFORMACIÓN DEL USUARIO------------------------------------------------------------------------------------------------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>>
  readAllAsistenciasConNombresDeUsuario() async {
    final db = await instance.database;

    // Construir la consulta SQL con INNER JOIN
    // Seleccionamos las columnas que necesitamos de ambas tablas.
    // Es buena práctica usar alias para las tablas (u y a) para claridad,
    // especialmente si hay columnas con el mismo nombre (aunque aquí no es el caso principal).
    final String sql = '''
    SELECT
      u.nombreCompleto AS nombreUsuario, 
      u.tipoSexo,
      u.fechaNacimiento,
      a.idAsistencia,
      a.usuarioId,
      a.consagracionDomingo,
      a.fechaConsagracionD,
      a.escuelaDominical,
      a.fechaEscuelaD,
      a.ensayoMartes,
      a.fechaEnsayoMartes,
      a.ensayoMiercoles,
      a.fechaEnsayoMiercoles,
      a.servicioJueves,
      a.fechaServicioJueves,
      a.totalAsistencia,
      a.inicioSemana,
      a.finSemana,
      a.nombreExtraN1,
      a.extraN1,
      a.nombreExtraN2,
      a.extraN2,
      a.estado
    FROM $tableAsistencia a 
    INNER JOIN $tableUsuario u ON a.usuarioId = u.idUsuario
    ORDER BY a.inicioSemana DESC, u.nombreCompleto ASC 
  ''';
    // Ordenar por inicioSemana descendente (más recientes primero) y luego por nombre

    final result = await db.rawQuery(sql);
    return result; // Devuelve una List<Map<String, dynamic>> directamente
  }

  // ----------------------------- INICIO SEEDING ------------------------------------------------------------------------------------------------------------------------------------------------------

  // ----- SEEDING PARA tableNotaAsistencia -----
  void _seedNotaAsistencia(Batch batch) {
    final List<Map<String, dynamic>> defaultNotaAsistencia = [
      {
        'idNota': 'A',
        'valorNota': 20,
        'descripcionNota':
            'Asistencia, ensayo y servicio consagración y dominical',
      },
      {
        'idNota': 'E',
        'valorNota': 5,
        'descripcionNota': 'No asistencia con excusa',
      },
      {'idNota': 'N', 'valorNota': 0, 'descripcionNota': 'No asistencia'},
      {
        'idNota': 'T',
        'valorNota': 15,
        'descripcionNota': 'LLegada tarde a ensayos (maximo 15 minutos)',
      },
    ];

    for (final notaData in defaultNotaAsistencia) {
      batch.insert(tableNotaAsistencia, notaData);
    }
  }
  // ----- FIN DEL SEEDING -----

  void _seedUsuarios(Batch batch) {
    // ----- SEEDING PARA tableNotaAsistencia -----
    final List<Map<String, dynamic>> defaultUsuario = [
      {
        'idUsuario': '1',
        'nombreCompleto': 'Jorge Osorio',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1992-01-01',
      },
      {
        'idUsuario': '2',
        'nombreCompleto': 'Ana Pérez',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1995-05-15',
      },
      {
        'idUsuario': '3',
        'nombreCompleto': 'Luis García',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1988-10-20',
      },
      {
        'idUsuario': '4',
        'nombreCompleto': 'María López',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1990-03-30',
      },
      {
        'idUsuario': '5',
        'nombreCompleto': 'Carlos Fernández',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1985-07-25',
      },
      {
        'idUsuario': '6',
        'nombreCompleto': 'Laura Martínez',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1993-12-12',
      },
      {
        'idUsuario': '7',
        'nombreCompleto': 'Pedro Sánchez',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1987-08-08',
      },
      {
        'idUsuario': '8',
        'nombreCompleto': 'Sofía Torres',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1991-11-11',
      },
      {
        'idUsuario': '9',
        'nombreCompleto': 'Andrés Ramírez',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1989-02-14',
      },
      {
        'idUsuario': '10',
        'nombreCompleto': 'Isabel Díaz',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1994-06-06',
      },
      {
        'idUsuario': '11',
        'nombreCompleto': 'Miguel Ángel',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1990-04-04',
      },
      {
        'idUsuario': '12',
        'nombreCompleto': 'Claudia Ruiz',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1992-09-09',
      },
      {
        'idUsuario': '13',
        'nombreCompleto': 'Fernando Castro',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1988-01-01',
      },
      {
        'idUsuario': '14',
        'nombreCompleto': 'Patricia Gómez',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1995-05-05',
      },
      {
        'idUsuario': '15',
        'nombreCompleto': 'Roberto Herrera',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1986-10-10',
      },
      {
        'idUsuario': '16',
        'nombreCompleto': 'Verónica Jiménez',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1993-03-03',
      },
      {
        'idUsuario': '17',
        'nombreCompleto': 'Diego Morales',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1989-07-07',
      },
      {
        'idUsuario': '18',
        'nombreCompleto': 'Lucía Pérez',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1991-12-12',
      },
      {
        'idUsuario': '19',
        'nombreCompleto': 'Javier Torres',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1987-08-08',
      },
      {
        'idUsuario': '20',
        'nombreCompleto': 'Ana María López',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1990-11-11',
      },
      {
        'idUsuario': '21',
        'nombreCompleto': 'Carlos Alberto',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1992-02-02',
      },
      {
        'idUsuario': '22',
        'nombreCompleto': 'María Fernanda',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1994-06-06',
      },
      {
        'idUsuario': '23',
        'nombreCompleto': 'Luis Miguel',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1988-01-01',
      },
      {
        'idUsuario': '24',
        'nombreCompleto': 'Sofía Elena',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1995-05-05',
      },
      {
        'idUsuario': '25',
        'nombreCompleto': 'Pedro Pablo',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1986-10-10',
      },
      {
        'idUsuario': '26',
        'nombreCompleto': 'Claudia Isabel',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1993-03-03',
      },
      {
        'idUsuario': '27',
        'nombreCompleto': 'Fernando Javier',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1989-07-07',
      },
      {
        'idUsuario': '28',
        'nombreCompleto': 'Verónica Ana',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1991-12-12',
      },
      {
        'idUsuario': '29',
        'nombreCompleto': 'Diego Andrés',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1987-08-08',
      },
      {
        'idUsuario': '30',
        'nombreCompleto': "Lucía María",
        'tipoSexo': "Femenino",
        'fechaNacimiento': "1990-11-11",
      },
      {
        'idUsuario': '31',
        'nombreCompleto': 'Javier Alejandro',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1992-02-02',
      },
      {
        'idUsuario': '32',
        'nombreCompleto': 'Ana Sofía',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1994-06-06',
      },
      {
        'idUsuario': '33',
        'nombreCompleto': 'Carlos Eduardo',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1988-01-01',
      },
      {
        'idUsuario': '34',
        'nombreCompleto': 'María José',
        'tipoSexo': 'Femenino',
        'fechaNacimiento': '1995-05-05',
      },
      {
        'idUsuario': '35',
        'nombreCompleto': 'Luis Fernando',
        'tipoSexo': 'Masculino',
        'fechaNacimiento': '1986-10-10',
      },
      {
        'idUsuario': '36',
        'nombreCompleto': "Sofía Elena",
        'tipoSexo': "Femenino",
        'fechaNacimiento': "1993-03-03",
      },
    ];

    for (final userData in defaultUsuario) {
      // No incluimos idWeight porque es AUTOINCREMENT
      batch.insert(tableUsuario, userData);
    }
  }
  // ----- FIN DEL SEEDING -----

  // ----- SEEDING PARA tableAsistencia -----

  void _seedAsistencias(Batch batch) {
    // CORRECCIÓN: Se eliminó 'idAsistencia' para que AUTOINCREMENT funcione.
    final List<Map<String, dynamic>> defaultAsistencia = [
      {
        'usuarioId': 1,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 85,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 2,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 90,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 3,
        'consagracionDomingo': 'T',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'N',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 95,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 4,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 80,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 5,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 75,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 6,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 70,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 7,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 65,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 8,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 60,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 9,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 55,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 10,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 50,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 11,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 45,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 12,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 40,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 13,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 35,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 14,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 30,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 15,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 25,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 16,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 20,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 17,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 15,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 18,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 10,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 19,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 5,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 20,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 0,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 21,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 85,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 22,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 90,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 23,
        'consagracionDomingo': 'T',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': "A",
        "fechaEscuelaD": "2023-10-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-10-02",
        "ensayoMiercoles": "N",
        "fechaEnsayoMiercoles": "2023-10-03",
        "servicioJueves": "E",
        "fechaServicioJueves": "2023-10-04",
        "totalAsistencia": 95,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 24,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 80,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 25,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 75,
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 26,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-10-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-10-04',
        'totalAsistencia': 70,
        'inicioSemana': "2023-09-30",
        "finSemana": "2023-10-06",
      },
      {
        "usuarioId": 27,
        "consagracionDomingo": "A",
        "fechaConsagracionD": "2023-10-01",
        "escuelaDominical": "A",
        "fechaEscuelaD": "2023-10-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-10-02",
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        "usuarioId": 28,
        "consagracionDomingo": "A",
        "fechaConsagracionD": "2023-10-01",
        "escuelaDominical": "A",
        "fechaEscuelaD": "2023-10-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-10-02",
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 29,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 30,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-10-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-10-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-10-02',
        'inicioSemana': '2023-09-30',
        'finSemana': '2023-10-06',
      },
      {
        'usuarioId': 1,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 85,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 2,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 90,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 3,
        'consagracionDomingo': 'T',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'N',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 95,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 4,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 80,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 5,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 75,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 6,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 70,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 7,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 65,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 8,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 60,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 9,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 55,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 10,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 50,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 11,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 45,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 12,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 40,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 13,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 35,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 14,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 30,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 15,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 25,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 16,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 20,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 17,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 15,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 18,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 10,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 19,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 5,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 20,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 0,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 21,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 85,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 22,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 90,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 23,
        'consagracionDomingo': 'T',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': "A",
        "fechaEscuelaD": "2023-11-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-11-02",
        "ensayoMiercoles": "N",
        "fechaEnsayoMiercoles": "2023-11-03",
        "servicioJueves": "E",
        "fechaServicioJueves": "2023-11-04",
        "totalAsistencia": 95,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 24,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 80,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 25,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 75,
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 26,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-11-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-11-04',
        'totalAsistencia': 70,
        'inicioSemana': "2023-10-30",
        "finSemana": "2023-11-06",
      },
      {
        "usuarioId": 27,
        "consagracionDomingo": "A",
        "fechaConsagracionD": "2023-11-01",
        "escuelaDominical": "A",
        "fechaEscuelaD": "2023-11-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-11-02",
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        "usuarioId": 28,
        "consagracionDomingo": "A",
        "fechaConsagracionD": "2023-11-01",
        "escuelaDominical": "A",
        "fechaEscuelaD": "2023-11-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-11-02",
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 29,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 30,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-11-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-11-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-11-02',
        'inicioSemana': '2023-10-30',
        'finSemana': '2023-11-06',
      },
      {
        'usuarioId': 1,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 85,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 2,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 90,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 3,
        'consagracionDomingo': 'T',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'N',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 95,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 4,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 80,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 5,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 75,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 6,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 70,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 7,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 65,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 8,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 60,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 9,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 55,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 10,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 50,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 11,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 45,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 12,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 40,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 13,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 35,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 14,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 30,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 15,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 25,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 16,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 20,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 17,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 15,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 18,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 10,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 19,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 5,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 20,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 0,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 21,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 85,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 22,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 90,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 23,
        'consagracionDomingo': 'T',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': "A",
        "fechaEscuelaD": "2023-12-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-12-02",
        "ensayoMiercoles": "N",
        "fechaEnsayoMiercoles": "2023-12-03",
        "servicioJueves": "E",
        "fechaServicioJueves": "2023-12-04",
        "totalAsistencia": 95,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 24,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 80,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 25,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 75,
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 26,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'ensayoMiercoles': 'A',
        'fechaEnsayoMiercoles': '2023-12-03',
        'servicioJueves': 'E',
        'fechaServicioJueves': '2023-12-04',
        'totalAsistencia': 70,
        'inicioSemana': "2023-11-30",
        "finSemana": "2023-12-06",
      },
      {
        "usuarioId": 27,
        "consagracionDomingo": "A",
        "fechaConsagracionD": "2023-12-01",
        "escuelaDominical": "A",
        "fechaEscuelaD": "2023-12-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-12-02",
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        "usuarioId": 28,
        "consagracionDomingo": "A",
        "fechaConsagracionD": "2023-12-01",
        "escuelaDominical": "A",
        "fechaEscuelaD": "2023-12-01",
        "ensayoMartes": "A",
        "fechaEnsayoMartes": "2023-12-02",
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 29,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
      {
        'usuarioId': 30,
        'consagracionDomingo': 'A',
        'fechaConsagracionD': '2023-12-01',
        'escuelaDominical': 'A',
        'fechaEscuelaD': '2023-12-01',
        'ensayoMartes': 'A',
        'fechaEnsayoMartes': '2023-12-02',
        'inicioSemana': '2023-11-30',
        'finSemana': '2023-12-06',
      },
    ];

    for (final asistenciaData in defaultAsistencia) {
      batch.insert(tableAsistencia, asistenciaData);
    }
  }

  // ----- FIN tableAsistencia DEL SEEDING -----

  // ----- SEEDING PARA tableNotaAsistencia -----
  void _seedAutorizaciones(Batch batch) {
    // CORRECCIÓN: Se eliminó 'id' para que AUTOINCREMENT funcione.
    final List<Map<String, dynamic>> defaultAutorizaciones = [
      {
        'contrasena': 'ff54857e9ce4f7b9f95048178fcdc663',
        'repetirContrasena': 'ff54857e9ce4f7b9f95048178fcdc663',
      },
    ];

    for (final autorizarData in defaultAutorizaciones) {
      batch.insert(tableAutorizacion, autorizarData);
    }
  }
  // ----- FIN tableNotaAsistencia DEL SEEDING -----

  // ----- SEEDING PARA tableNotaAsistencia -----
  void _seedActividades(Batch batch) {
    final List<Map<String, dynamic>> defaultActividades = [
      {
        'idActividad': 'cons_dom',
        'nombreDisplay': 'Consagración Domingo',
        'nombreCampoDB': 'consagracionDomingo',
        'etiquetaCorta': 'Consagración\nDomingo',
        'ordenDisplay': 1,
      },
      {
        'idActividad': 'esc_dom',
        'nombreDisplay': 'Escuela Dominical',
        'nombreCampoDB': 'escuelaDominical',
        'etiquetaCorta': 'Escuela\nDominical',
        'ordenDisplay': 2,
      },
      {
        'idActividad': 'ens_mar',
        'nombreDisplay': 'Ensayo Martes',
        'nombreCampoDB': 'ensayoMartes',
        'etiquetaCorta': 'Ensayo\nMartes',
        'ordenDisplay': 3,
      }, // 'label' era un typo aquí antes
      {
        'idActividad': 'ens_mie',
        'nombreDisplay': 'Ensayo Miércoles',
        'nombreCampoDB': 'ensayoMiercoles',
        'etiquetaCorta': 'Ensayo\nMiércoles',
        'ordenDisplay': 4,
      },
      {
        'idActividad': 'ser_jue',
        'nombreDisplay': 'Servicio Jueves',
        'nombreCampoDB': 'servicioJueves',
        'etiquetaCorta': 'Servicio\nJueves',
        'ordenDisplay': 5,
      },
    ];
    for (final actividadData in defaultActividades) {
      batch.insert(tableActividadDefiniciones, actividadData);
    }
  }
  // ----- FIN tableNotaAsistencia DEL SEEDING -----

  // ----------------------------- FIN DEL SEEDING ------------------------------------------------------------------------------------------------------------------------------------------------

  // Cerrar la base de datos
  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
