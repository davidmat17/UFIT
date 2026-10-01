import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/datos/errores.dart';
import '../../../core/datos/puertos/repositorio_perfiles.dart';
import '../../../core/modelos/medicion.dart';
import '../../../core/modelos/perfil.dart';
import '../../../core/modelos/sesion.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/supabase/traductor_errores.dart';

/// Adaptador del puerto de cuenta contra Supabase (RF1, RF8, RF10).
///
/// El ingreso usa el proveedor Azure de Supabase Auth, que es la cuenta
/// institucional de Microsoft 365 de la UIS.
class RepositorioPerfilesSupabase implements RepositorioPerfiles {
  const RepositorioPerfilesSupabase();

  /// Dirección a la que Supabase devuelve a la persona después de que
  /// Microsoft verifica su identidad. Tiene que coincidir con dos sitios:
  /// el intent-filter de android/app/src/main/AndroidManifest.xml y la
  /// lista de Redirect URLs del panel de Supabase (Authentication → URL
  /// Configuration).
  static const String direccionDeRetorno = 'io.supabase.ufit://login-callback';

  SupabaseClient get _bd => SupabaseConfig.cliente;

  Perfil _desdeFila(Map<String, dynamic> f) => Perfil(
        id: f['id'] as String,
        nombre: f['nombre'] as String,
        apellido: f['apellido'] as String,
        documento: f['documento'] as String,
        correo: f['correo'] as String,
        telefono: f['telefono'] as String?,
        rol: rolDesdeTexto(f['rol'] as String?),
        activo: (f['activo'] as bool?) ?? true,
      );

  @override
  Future<void> iniciarSesionInstitucional() async {
    try {
      final bool abierta = await _bd.auth.signInWithOAuth(
        OAuthProvider.azure,
        redirectTo: direccionDeRetorno,
        // Sin este permiso Microsoft no entrega el correo.
        scopes: 'email',
        // Muestra siempre el selector de cuentas. Si alguien entró con
        // una cuenta personal y fue rechazado, así puede elegir otra.
        queryParams: const <String, String>{'prompt': 'select_account'},
      );

      if (!abierta) {
        throw const ErrorDeDatos(
          TipoDeError.desconocido,
          'No se pudo abrir la página de Microsoft. Inténtalo de nuevo.',
        );
      }
    } catch (e) {
      throw traducirError(e, 'No se pudo abrir el ingreso con Microsoft');
    }
  }

  @override
  Stream<void> get cambiosDeSesion => _bd.auth.onAuthStateChange
      .where((AuthState s) =>
          s.event == AuthChangeEvent.signedIn ||
          s.event == AuthChangeEvent.signedOut)
      .map<void>((AuthState _) {});

  @override
  SesionActiva? sesionActual() {
    final User? usuario = _bd.auth.currentUser;
    if (usuario == null) return null;

    final Map<String, dynamic> datos =
        usuario.userMetadata ?? const <String, dynamic>{};

    final String correo =
        (usuario.email ?? datos['email'] as String? ?? '').trim().toLowerCase();

    // Microsoft entrega el nombre como full_name o como name, según la
    // configuración de la cuenta.
    final Object? nombre = datos['full_name'] ?? datos['name'];

    return SesionActiva(
      correo: correo,
      nombreCompleto: nombre is String ? nombre : null,
    );
  }

  @override
  Future<Perfil> completarRegistro({
    required String nombre,
    required String apellido,
    required String documento,
    String? telefono,
  }) async {
    final SesionActiva? sesion = sesionActual();
    final User? usuario = _bd.auth.currentUser;
    if (sesion == null || usuario == null) {
      throw const ErrorDeDatos(
        TipoDeError.sinPermiso,
        'La sesión se cerró. Vuelve a ingresar con tu correo institucional.',
      );
    }

    try {
      final Map<String, dynamic> fila = await _bd
          .from('perfiles')
          .insert(<String, dynamic>{
            'id': usuario.id,
            'nombre': nombre.trim(),
            'apellido': apellido.trim(),
            'documento': documento.trim(),
            'correo': sesion.correo,
            'telefono': _vacioANulo(telefono),
          })
          .select()
          .single();

      return _desdeFila(fila);
    } catch (e) {
      throw traducirError(e, 'No se pudo completar el registro');
    }
  }

  @override
  Future<void> cerrarSesion() async {
    try {
      await _bd.auth.signOut();
    } catch (e) {
      throw traducirError(e, 'No se pudo cerrar la sesión');
    }
  }

  @override
  Future<Perfil?> perfilActual() async {
    final User? usuario = _bd.auth.currentUser;
    if (usuario == null) return null;

    try {
      final Map<String, dynamic>? fila = await _bd
          .from('perfiles')
          .select()
          .eq('id', usuario.id)
          .maybeSingle();

      return fila == null ? null : _desdeFila(fila);
    } catch (e) {
      throw traducirError(e, 'No se pudo cargar tu perfil');
    }
  }

  @override
  Future<Perfil> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    final User? usuario = _bd.auth.currentUser;
    if (usuario == null) {
      throw const ErrorDeDatos(
        TipoDeError.sinPermiso,
        'Debes iniciar sesión para actualizar tus datos.',
      );
    }

    try {
      final Map<String, dynamic> fila = await _bd
          .from('perfiles')
          .update(<String, dynamic>{
            'nombre': nombre.trim(),
            'apellido': apellido.trim(),
            'telefono': _vacioANulo(telefono),
          })
          .eq('id', usuario.id)
          .select()
          .single();

      return _desdeFila(fila);
    } catch (e) {
      throw traducirError(e, 'No se pudieron guardar tus datos');
    }
  }

  // ---------------------------------------------------------------
  // RF8: medidas antropométricas
  // ---------------------------------------------------------------

  static const String _tablaMedidas = 'medidas_antropometricas';

  MedicionAntropometrica _medicionDesdeFila(Map<String, dynamic> f) =>
      MedicionAntropometrica(
        id: (f['id'] as num).toInt(),
        registradaEn: DateTime.parse(f['registrada_en'] as String).toLocal(),
        // PostgreSQL entrega numeric como número JSON: puede llegar como
        // int (70) o como double (70.5).
        pesoKg: (f['peso_kg'] as num).toDouble(),
        estaturaCm: (f['estatura_cm'] as num).toDouble(),
        cinturaCm: (f['circ_cintura_cm'] as num?)?.toDouble(),
        caderaCm: (f['circ_cadera_cm'] as num?)?.toDouble(),
        pechoCm: (f['circ_pecho_cm'] as num?)?.toDouble(),
        brazoCm: (f['circ_brazo_cm'] as num?)?.toDouble(),
        musloCm: (f['circ_muslo_cm'] as num?)?.toDouble(),
      );

  String _idSesion(String accion) {
    final User? usuario = _bd.auth.currentUser;
    if (usuario == null) {
      throw ErrorDeDatos(
        TipoDeError.sinPermiso,
        'Debes iniciar sesión para $accion.',
      );
    }
    return usuario.id;
  }

  @override
  Future<List<MedicionAntropometrica>> misMediciones() async {
    final String id = _idSesion('ver tus medidas');
    try {
      final List<Map<String, dynamic>> filas = await _bd
          .from(_tablaMedidas)
          .select()
          .eq('perfil_id', id)
          .order('registrada_en', ascending: false);

      return filas.map(_medicionDesdeFila).toList();
    } catch (e) {
      throw traducirError(e, 'No se pudieron cargar tus medidas');
    }
  }

  @override
  Future<MedicionAntropometrica> registrarMedicion({
    required double pesoKg,
    required double estaturaCm,
    double? cinturaCm,
    double? caderaCm,
    double? pechoCm,
    double? brazoCm,
    double? musloCm,
  }) async {
    final String id = _idSesion('registrar tus medidas');
    try {
      // Sin id ni fecha: los pone la base.
      final Map<String, dynamic> fila = await _bd
          .from(_tablaMedidas)
          .insert(<String, dynamic>{
            'perfil_id': id,
            'peso_kg': pesoKg,
            'estatura_cm': estaturaCm,
            'circ_cintura_cm': cinturaCm,
            'circ_cadera_cm': caderaCm,
            'circ_pecho_cm': pechoCm,
            'circ_brazo_cm': brazoCm,
            'circ_muslo_cm': musloCm,
          })
          .select()
          .single();

      return _medicionDesdeFila(fila);
    } catch (e) {
      throw traducirError(e, 'No se pudo guardar la medición');
    }
  }

  @override
  Future<void> borrarMedicion(int id) async {
    _idSesion('borrar una medición');
    try {
      // La política de fila ya impide borrar mediciones ajenas.
      await _bd.from(_tablaMedidas).delete().eq('id', id);
    } catch (e) {
      throw traducirError(e, 'No se pudo borrar la medición');
    }
  }

  static String? _vacioANulo(String? valor) {
    final String v = (valor ?? '').trim();
    return v.isEmpty ? null : v;
  }
}
