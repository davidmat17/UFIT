import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ufit/core/datos/errores.dart';
import 'package:ufit/core/datos/puertos/repositorio_gimnasio.dart';
import 'package:ufit/core/datos/repositorios.dart';
import 'package:ufit/core/modelos/ejercicio.dart';
import 'package:ufit/core/modelos/maquina.dart';
import 'package:ufit/core/modelos/normativa.dart';
import 'package:ufit/core/modelos/zona.dart';
import 'package:ufit/features/gimnasio/pantallas/rf05_catalogo.dart';
import 'package:ufit/features/gimnasio/reglas_catalogo.dart';

// ---------------------------------------------------------------------
// Datos de prueba
// ---------------------------------------------------------------------

const List<Zona> _zonas = <Zona>[
  Zona(id: 1, nombre: 'Cardiovascular', descripcion: 'Trotadoras y elípticas.'),
  Zona(id: 2, nombre: 'Fuerza', descripcion: 'Peso libre y bancos.'),
  Zona(id: 3, nombre: 'Musculación', descripcion: 'Máquinas guiadas.'),
  Zona(id: 4, nombre: 'Zona cerrada', activa: false),
];

const Ejercicio _trote = Ejercicio(
  id: 1,
  nombre: 'Trote continuo',
  grupoMuscular: 'Cardiovascular',
  instrucciones: 'Calienta caminando y sube la velocidad poco a poco.',
);

const Ejercicio _pressDeBanca = Ejercicio(
  id: 2,
  nombre: 'Press de banca',
  grupoMuscular: 'Pecho',
  descripcion: 'Empuje de barra desde el pecho.',
  instrucciones: 'Acuéstate en el banco con los pies en el piso.',
);

const Ejercicio _prensaSinInstrucciones = Ejercicio(
  id: 3,
  nombre: 'Prensa de piernas',
  grupoMuscular: 'Piernas',
);

const List<Maquina> _maquinas = <Maquina>[
  Maquina(
    id: 1,
    zonaId: 1,
    nombre: 'Trotadora',
    descripcion: 'Banda para caminar y correr.',
    cantidad: 8,
    ejercicios: <Ejercicio>[_trote],
  ),
  Maquina(
    id: 2,
    zonaId: 1,
    nombre: 'Elíptica',
    estado: EstadoMaquina.mantenimiento,
  ),
  Maquina(
    id: 3,
    zonaId: 2,
    nombre: 'Banco plano',
    cantidad: 4,
    ejercicios: <Ejercicio>[_pressDeBanca],
  ),
  Maquina(
    id: 4,
    zonaId: 2,
    nombre: 'Rack viejo',
    estado: EstadoMaquina.retirada,
  ),
  Maquina(
    id: 5,
    zonaId: 3,
    nombre: 'Prensa de piernas',
    ejercicios: <Ejercicio>[_prensaSinInstrucciones],
  ),
  Maquina(id: 6, zonaId: 4, nombre: 'Máquina de zona cerrada'),
];

/// Repositorio falso del RF5: el catálogo en memoria, sin red.
class _GimnasioFalso implements RepositorioGimnasio {
  _GimnasioFalso({
    this.zonasDePrueba = _zonas,
    this.maquinasDePrueba = _maquinas,
    this.falla = false,
  });

  final List<Zona> zonasDePrueba;
  final List<Maquina> maquinasDePrueba;
  bool falla;

  void _quizasFallar() {
    if (falla) {
      throw const ErrorDeDatos(
        TipoDeError.sinConexion,
        'No se pudo cargar el catálogo de máquinas.',
      );
    }
  }

  @override
  Future<List<Zona>> zonas() async {
    _quizasFallar();
    return zonasDePrueba;
  }

  @override
  Future<List<Maquina>> maquinas({int? zonaId}) async {
    _quizasFallar();
    return maquinasDePrueba;
  }

  @override
  Future<Normativa?> normativaVigente() async => null;
}

Future<void> _abrir(WidgetTester tester, _GimnasioFalso repo) async {
  await tester.binding.setSurfaceSize(const Size(800, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  Repositorios.gimnasio = repo;
  await tester.pumpWidget(const MaterialApp(home: PantallaCatalogo()));
  await tester.pumpAndSettle();
}

Future<void> _tocar(WidgetTester tester, Finder objetivo) async {
  await tester.ensureVisible(objetivo);
  await tester.pumpAndSettle();
  await tester.tap(objetivo);
  await tester.pumpAndSettle();
}

Finder _categoria(String nombre) => find.widgetWithText(ChoiceChip, nombre);

void main() {
  // -------------------------------------------------------------------
  // Reglas
  // -------------------------------------------------------------------

  group('reglas del catálogo', () {
    test('normaliza mayúsculas y tildes', () {
      expect(normalizar('  Musculación '), 'musculacion');
      expect(normalizar('BÍCEPS'), 'biceps');
    });

    test('busca por nombre, ejercicio y grupo muscular', () {
      final Maquina banco = _maquinas[2];
      expect(coincideConBusqueda(banco, 'banco'), isTrue);
      expect(coincideConBusqueda(banco, 'press'), isTrue);
      expect(coincideConBusqueda(banco, 'pecho'), isTrue);
      expect(coincideConBusqueda(banco, 'piernas'), isFalse);
      expect(coincideConBusqueda(banco, '   '), isTrue);
    });

    test('las máquinas retiradas no se muestran', () {
      final List<String> nombres =
          maquinasVisibles(_maquinas).map((Maquina m) => m.nombre).toList();
      expect(nombres, isNot(contains('Rack viejo')));
      expect(nombres, contains('Elíptica'));
    });

    test('agrupa por categoría en el orden de las zonas', () {
      final List<GrupoDeCatalogo> grupos =
          agruparPorCategoria(zonas: _zonas, maquinas: _maquinas);

      expect(
        grupos.map((GrupoDeCatalogo g) => g.zona.nombre).toList(),
        <String>['Cardiovascular', 'Fuerza', 'Musculación'],
      );
      expect(
        grupos.first.maquinas.map((Maquina m) => m.nombre).toList(),
        <String>['Elíptica', 'Trotadora'],
      );
    });

    test('filtra por categoría y omite las que quedan vacías', () {
      final List<GrupoDeCatalogo> soloFuerza = agruparPorCategoria(
        zonas: _zonas,
        maquinas: _maquinas,
        zonaElegida: 2,
      );
      expect(soloFuerza, hasLength(1));
      expect(soloFuerza.single.maquinas.single.nombre, 'Banco plano');

      final List<GrupoDeCatalogo> piernas = agruparPorCategoria(
        zonas: _zonas,
        maquinas: _maquinas,
        busqueda: 'piernas',
      );
      expect(piernas.single.zona.nombre, 'Musculación');
    });
  });

  // -------------------------------------------------------------------
  // Pantalla del catálogo (HU12)
  // -------------------------------------------------------------------

  testWidgets('muestra las máquinas agrupadas por categoría',
      (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    expect(find.text('Catálogo de máquinas'), findsOneWidget);
    expect(find.text('Trotadoras y elípticas.'), findsOneWidget);
    expect(find.text('Peso libre y bancos.'), findsOneWidget);
    expect(find.text('Máquinas guiadas.'), findsOneWidget);

    expect(find.text('Trotadora'), findsOneWidget);
    expect(find.text('Banco plano'), findsOneWidget);
    expect(find.text('Prensa de piernas'), findsOneWidget);

    // Ni las retiradas ni las de zonas inactivas.
    expect(find.text('Rack viejo'), findsNothing);
    expect(find.text('Máquina de zona cerrada'), findsNothing);
    expect(_categoria('Zona cerrada'), findsNothing);
  });

  testWidgets('cada máquina muestra su estado', (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    expect(find.text('Fuera de servicio'), findsOneWidget);
    expect(find.text('Disponible'), findsNWidgets(3));
    expect(find.text('1 ejercicio'), findsNWidgets(3));
    expect(find.text('0 ejercicios'), findsOneWidget);
  });

  testWidgets('filtra por categoría', (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    await _tocar(tester, _categoria('Fuerza'));
    expect(find.text('Banco plano'), findsOneWidget);
    expect(find.text('Trotadora'), findsNothing);
    expect(find.text('Prensa de piernas'), findsNothing);

    await _tocar(tester, _categoria('Todas'));
    expect(find.text('Trotadora'), findsOneWidget);
  });

  testWidgets('busca por grupo muscular sin importar tildes ni mayúsculas',
      (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    await tester.enterText(find.byType(TextField), 'PECHO');
    await tester.pumpAndSettle();

    expect(find.text('Banco plano'), findsOneWidget);
    expect(find.text('Trotadora'), findsNothing);
  });

  testWidgets('si la búsqueda no encuentra nada, lo dice',
      (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();

    expect(find.text('No encontramos máquinas'), findsOneWidget);

    await _tocar(tester, find.byTooltip('Borrar búsqueda'));
    expect(find.text('Trotadora'), findsOneWidget);
  });

  testWidgets('sin máquinas cargadas avisa que el catálogo no está disponible',
      (WidgetTester tester) async {
    await _abrir(
      tester,
      _GimnasioFalso(maquinasDePrueba: const <Maquina>[]),
    );

    expect(find.text('El catálogo no está disponible'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('si falla al cargar, avisa y deja reintentar',
      (WidgetTester tester) async {
    final _GimnasioFalso repo = _GimnasioFalso(falla: true);
    await _abrir(tester, repo);

    expect(find.text('No se pudo cargar el catálogo de máquinas.'),
        findsOneWidget);

    repo.falla = false;
    await _tocar(tester, find.text('Reintentar'));

    expect(find.text('Trotadora'), findsOneWidget);
  });

  // -------------------------------------------------------------------
  // Ficha de la máquina (HU13)
  // -------------------------------------------------------------------

  testWidgets('la ficha muestra los ejercicios con sus instrucciones',
      (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    await _tocar(tester, find.text('Banco plano'));

    expect(find.text('Ejercicios (1)'), findsOneWidget);
    expect(find.text('Press de banca'), findsOneWidget);
    expect(find.text('Grupo muscular: Pecho'), findsOneWidget);
    expect(find.text('Empuje de barra desde el pecho.'), findsOneWidget);
    expect(find.text('Acuéstate en el banco con los pies en el piso.'),
        findsOneWidget);
    expect(find.text('4'), findsOneWidget); // unidades
  });

  testWidgets('la ficha de una máquina fuera de servicio lo advierte',
      (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    await _tocar(tester, find.text('Elíptica'));

    expect(find.text('Fuera de servicio'), findsOneWidget);
    expect(find.textContaining('fuera de servicio por ahora'), findsOneWidget);
    expect(
      find.text('Esta máquina todavía no tiene ejercicios registrados.'),
      findsOneWidget,
    );
  });

  testWidgets('un ejercicio sin instrucciones lo indica',
      (WidgetTester tester) async {
    await _abrir(tester, _GimnasioFalso());

    await _tocar(tester, find.text('Prensa de piernas'));

    expect(
      find.text(
          'Las instrucciones de este ejercicio todavía no están registradas.'),
      findsOneWidget,
    );
  });
}
