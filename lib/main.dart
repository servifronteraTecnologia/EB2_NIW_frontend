import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // --- TEMA DE MARCA PERSONALIZADO ---
    final ThemeData theme = ThemeData(
      fontFamily: 'Playfair Display', // <-- 1. Tipografía personalizada
      useMaterial3: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
      // --- 2. Paleta de colores de BORDERS GROUP ---
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF5A3D25), // Color primario de la marca
        primary: const Color(0xFF5A3D25),
        secondary: const Color(0xFF9E938D),
        surface: const Color(0xFFF8F8F8),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: const Color(0xFF121315),
        error: Colors.red.shade700,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: Color(0xFF121315)),
        titleTextStyle: TextStyle(
          fontFamily: 'Playfair Display',
          color: Color(0xFF121315),
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF5A3D25), // Color primario
          foregroundColor: Colors.white, // Color del texto
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );

    return MaterialApp(
      title: 'BORDERS GROUP - Formulario EB2-NIW',
      theme: theme,
      home: const RegistroFormulario(),
    );
  }
}

class ArchivoSeleccionado {
  final String nombreCampo;
  final PlatformFile archivo;
  ArchivoSeleccionado(this.nombreCampo, this.archivo);
}

class RegistroFormulario extends StatefulWidget {
  const RegistroFormulario({super.key});

  @override
  State<RegistroFormulario> createState() => _RegistroFormularioState();
}

class _RegistroFormularioState extends State<RegistroFormulario> {
  // ... (Toda la lógica y variables de estado no cambian)
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _numeroIdController = TextEditingController();
  String? _tipoIdSeleccionado = 'Cédula de Ciudadanía';
  bool _aceptaPoliticas = false;
  bool _estaCargando = false;
  double _uploadProgress = 0.0;
  final Set<String> _camposConError = {};
  final List<ArchivoSeleccionado> _archivos = [];
  final List<String> _opcionesTipoId = ['Cédula de Ciudadanía', 'Pasaporte'];
  final List<String> _documentosPersonales = [
    'Partida de Nacimiento',
    'Pasaporte',
    'Visa',
    'Hoja de vida',
  ];
  final List<String> _documentosAcademicos = [
    'Diploma',
    'Acta de Grado',
    'Calificaciones',
  ];

  @override
  void dispose() {
    _nombreController.dispose();
    _numeroIdController.dispose();
    super.dispose();
  }

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      _mostrarDialogo('Error', 'No se pudo abrir el enlace.', esExito: false);
    }
  }

  bool _validarArchivos() {
    _camposConError.clear();
    final todosLosDocumentos = [
      ..._documentosPersonales,
      ..._documentosAcademicos,
    ];
    final nombresArchivosSubidos = _archivos.map((a) => a.nombreCampo).toSet();
    for (var doc in todosLosDocumentos) {
      if (doc == 'Visa') continue;
      if (!nombresArchivosSubidos.contains(doc)) {
        _camposConError.add(doc);
      }
    }
    return _camposConError.isEmpty;
  }

  Widget _buildFileUploadList(List<String> documentos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: documentos.map((nombreDoc) {
        final archivoCargado = _archivos
            .where((a) => a.nombreCampo == nombreDoc)
            .firstOrNull;
        final tieneError = _camposConError.contains(nombreDoc);
        return Card(
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: tieneError
                  ? Theme.of(context).colorScheme.error
                  : Colors.transparent,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                leading: const Icon(Icons.file_upload_outlined),
                title: Text(nombreDoc),
                subtitle: Text(
                  archivoCargado?.archivo.name ??
                      'No se ha seleccionado archivo',
                  style: TextStyle(
                    color: archivoCargado != null
                        ? Colors.green.shade700
                        : Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: archivoCargado != null
                    ? IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () => setState(
                          () => _archivos.removeWhere(
                            (a) => a.nombreCampo == nombreDoc,
                          ),
                        ),
                      )
                    : ElevatedButton(
                        child: const Text('Cargar'),
                        onPressed: () => _seleccionarArchivo(nombreDoc),
                      ),
              ),
              if (tieneError)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Text(
                    'Este documento es obligatorio.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _seleccionarArchivo(String nombreCampo) async {
    final resultado = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
    );
    if (!mounted) return;
    if (resultado != null && resultado.files.single.bytes != null) {
      const maxSizeInBytes = 8 * 1024 * 1024;
      final fileSize = resultado.files.single.size;
      if (fileSize > maxSizeInBytes) {
        _mostrarDialogo(
          'Archivo Demasiado Grande',
          'El tamaño del archivo no puede superar los 8 MB.',
          esExito: false,
        );
      } else {
        setState(() {
          _archivos.removeWhere((a) => a.nombreCampo == nombreCampo);
          _archivos.add(
            ArchivoSeleccionado(nombreCampo, resultado.files.single),
          );
        });
      }
    }
  }

  Future<void> _mostrarDialogo(
    String titulo,
    String mensaje, {
    bool esExito = true,
  }) async {
    if (!mounted) return;
    if (esExito) {
      _formKey.currentState?.reset();
      _nombreController.clear();
      _numeroIdController.clear();
      setState(() {
        _archivos.clear();
        _aceptaPoliticas = false;
        _tipoIdSeleccionado = 'Cédula de Ciudadanía';
      });
    }
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                esExito ? Icons.check_circle : Icons.error,
                color: esExito ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 10),
              Text(titulo),
            ],
          ),
          content: SingleChildScrollView(child: Text(mensaje)),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _enviarFormulario() async {
    final camposDeTextoValidos = _formKey.currentState!.validate();
    final archivosValidos = _validarArchivos();
    if (!camposDeTextoValidos || !archivosValidos) {
      setState(() {});
      return;
    }
    if (!_aceptaPoliticas) {
      _mostrarDialogo(
        'Atención',
        'Debes aceptar las políticas de tratamiento de datos.',
        esExito: false,
      );
      return;
    }
    setState(() {
      _estaCargando = true;
      _uploadProgress = 0.0;
    });
    final dio = Dio();
    final url =
        'https://drive-uploader-service-40645518490.us-central1.run.app/upload';
    final Map<String, dynamic> formFields = {
      'procesoMigracion': 'EB2-NIW',
      'tipoId': _tipoIdSeleccionado!,
      'numeroId': _numeroIdController.text,
      'nombreCompleto': _nombreController.text,
    };
    for (var archivoSeleccionado in _archivos) {
      formFields[archivoSeleccionado.nombreCampo] = MultipartFile.fromBytes(
        archivoSeleccionado.archivo.bytes!,
        filename: archivoSeleccionado.archivo.name,
      );
    }
    final formData = FormData.fromMap(formFields);
    try {
      final response = await dio.post(
        url,
        data: formData,
        onSendProgress: (int sent, int total) {
          if (total != 0) {
            setState(() {
              _uploadProgress = sent / total;
            });
          }
        },
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        _mostrarDialogo('¡Enviado con Éxito!', response.data.toString());
      } else {
        _mostrarDialogo(
          'Error Inesperado',
          'El servidor respondió con un error.\n\n(Código: ${response.statusCode})',
          esExito: false,
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      String mensajeAmigable;
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          mensajeAmigable =
              "La conexión tardó demasiado. Revisa tu conexión a internet.";
          break;
        case DioExceptionType.unknown:
          mensajeAmigable =
              "No se pudo conectar con el servidor. Verifica tu conexión.";
          break;
        case DioExceptionType.badResponse:
          mensajeAmigable =
              "El servidor devolvió una respuesta inesperada. Contacta a soporte.";
          break;
        default:
          mensajeAmigable = "Ocurrió un error de comunicación inesperado.";
      }
      _mostrarDialogo('Error de Red', mensajeAmigable, esExito: false);
    } finally {
      if (mounted) {
        setState(() {
          _estaCargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // 1. Aumentamos la altura total de la barra de navegación.
        // El valor por defecto es 56. Puedes experimentar con 70, 80, etc.
        toolbarHeight: 110,

        title: Padding(
          // 2. Añadimos un padding vertical para que el logo no toque los bordes.
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Image.asset(
            'assets/logo.png',
            // 3. Ahora la altura de la imagen tiene más espacio para crecer sin cortarse.
            // Asegúrate de que este valor sea menor que el toolbarHeight.
            height: 170,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool esEscritorio = constraints.maxWidth >= 900;
          return Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: 10, // <-- Reducimos el espacio superior
                bottom: 50, // Mantenemos el espacio inferior
                left: esEscritorio ? constraints.maxWidth * 0.15 : 16.0,
                right: esEscritorio ? constraints.maxWidth * 0.15 : 16.0,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Proceso de Migración: EB2-NIW',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),

                    if (esEscritorio)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: _nombreController,
                                  decoration: const InputDecoration(
                                    labelText: 'Nombre Completo',
                                    border: OutlineInputBorder(),
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z ]'),
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Ingresa tu nombre completo.';
                                    }
                                    final nameRegExp = RegExp(r'^[a-zA-Z ]+$');
                                    if (!nameRegExp.hasMatch(value)) {
                                      return 'Solo se permiten letras y espacios.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                DropdownButtonFormField<String>(
                                  initialValue: _tipoIdSeleccionado,
                                  items: _opcionesTipoId
                                      .map(
                                        (String value) =>
                                            DropdownMenuItem<String>(
                                              value: value,
                                              child: Text(value),
                                            ),
                                      )
                                      .toList(),
                                  onChanged: (newValue) => setState(
                                    () => _tipoIdSeleccionado = newValue,
                                  ),
                                  decoration: const InputDecoration(
                                    labelText: 'Tipo de Identificación',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _numeroIdController,
                                  decoration: const InputDecoration(
                                    labelText: 'Número de Identificación',
                                    border: OutlineInputBorder(),
                                  ),
                                  inputFormatters: [
                                    LengthLimitingTextInputFormatter(12),
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[a-zA-Z0-9]'),
                                    ),
                                  ],
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Este campo es obligatorio.';
                                    }
                                    if (value.length < 4) {
                                      return 'Debe tener entre 4 y 12 caracteres.';
                                    }
                                    final alphanumeric = RegExp(
                                      r'^[a-zA-Z0-9]+$',
                                    );
                                    if (!alphanumeric.hasMatch(value)) {
                                      return 'Solo se permiten letras y números.';
                                    }
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Documentos personales',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                _buildFileUploadList(_documentosPersonales),
                                const SizedBox(height: 16),
                                Text(
                                  'Documentos académicos',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                _buildFileUploadList(_documentosAcademicos),
                              ],
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nombreController,
                            decoration: const InputDecoration(
                              labelText: 'Nombre Completo',
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z ]'),
                              ),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Ingresa tu nombre completo.';
                              }
                              final nameRegExp = RegExp(r'^[a-zA-Z ]+$');
                              if (!nameRegExp.hasMatch(value)) {
                                return 'Solo se permiten letras y espacios.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _tipoIdSeleccionado,
                            items: _opcionesTipoId
                                .map(
                                  (String value) => DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  ),
                                )
                                .toList(),
                            onChanged: (newValue) =>
                                setState(() => _tipoIdSeleccionado = newValue),
                            decoration: const InputDecoration(
                              labelText: 'Tipo de Identificación',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _numeroIdController,
                            decoration: const InputDecoration(
                              labelText: 'Número de Identificación',
                              border: OutlineInputBorder(),
                            ),
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(12),
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[a-zA-Z0-9]'),
                              ),
                            ],
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Este campo es obligatorio.';
                              }
                              if (value.length < 4) {
                                return 'Debe tener entre 4 y 12 caracteres.';
                              }
                              final alphanumeric = RegExp(r'^[a-zA-Z0-9]+$');
                              if (!alphanumeric.hasMatch(value)) {
                                return 'Solo se permiten letras y números.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Documentos personales',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildFileUploadList(_documentosPersonales),
                          const SizedBox(height: 24),
                          Text(
                            'Documentos académicos',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildFileUploadList(_documentosAcademicos),
                        ],
                      ),

                    const SizedBox(height: 24),
                    CheckboxListTile(
                      value: _aceptaPoliticas,
                      onChanged: (newValue) =>
                          setState(() => _aceptaPoliticas = newValue!),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: RichText(
                        text: TextSpan(
                          style: Theme.of(context).textTheme.bodyLarge,
                          children: [
                            const TextSpan(text: 'He leído y acepto las '),
                            TextSpan(
                              text: 'Políticas de Tratamiento de Datos.',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  _launchURL(
                                    'https://drive.google.com/file/d/10kS169Ve4Lg1NeCLC1pGtqo359Mo17vA/view?usp=sharing',
                                  );
                                },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    if (_estaCargando)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: _uploadProgress < 1.0
                            ? Column(
                                children: [
                                  LinearProgressIndicator(
                                    value: _uploadProgress,
                                    minHeight: 12,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Subiendo... ${(_uploadProgress * 100).toStringAsFixed(0)}%',
                                  ),
                                ],
                              )
                            : const Padding(
                                padding: EdgeInsets.symmetric(vertical: 10.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                      ),
                                    ),
                                    SizedBox(width: 16),
                                    Text('Procesando en el servidor...'),
                                  ],
                                ),
                              ),
                      ),

                    SizedBox(
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _estaCargando ? null : _enviarFormulario,
                        child: const Text(
                          'Enviar Registro',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
