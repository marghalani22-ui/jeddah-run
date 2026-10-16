import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

/// Phase 1: the approved prototype (assets/web/index.html) runs inside a
/// native shell, so the app looks exactly like the design. Native features
/// (real map, GPS, notifications, widget) are bridged in step by step.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: _bg,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: _bg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const JeddahRunApp());
}

const _bg = Color(0xFF0B3B4F);

class JeddahRunApp extends StatelessWidget {
  const JeddahRunApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'جري جدة',
        debugShowCheckedModeBanner: false,
        home: Shell(),
      );
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  late final WebViewController _web;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(_bg)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => setState(() => _ready = true),
      ))
      ..loadFlutterAsset('assets/web/index.html');

    final android = _web.platform;
    if (android is AndroidWebViewController) {
      // Lets the profile "add photo" button open the gallery.
      android.setOnShowFileSelector(_pickFile);
      android.setMediaPlaybackRequiresUserGesture(false);
    }
  }

  Future<List<String>> _pickFile(FileSelectorParams params) async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1024, imageQuality: 88);
    return img == null ? [] : [Uri.file(img.path).toString()];
  }

  Future<void> _back() async {
    if (await _web.canGoBack()) {
      await _web.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: Stack(children: [
            WebViewWidget(controller: _web),
            if (!_ready)
              const ColoredBox(
                color: _bg,
                child: Center(child: CircularProgressIndicator(color: Color(0xFFF25C2C))),
              ),
          ]),
        ),
      ),
    );
  }
}
