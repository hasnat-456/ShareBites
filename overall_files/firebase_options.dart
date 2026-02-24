import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
              'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyDaGn17qRp-h0f92dpqYqBBVNT7UvtYJ-0',
    appId: '1:816352002695:web:7d2eb04346cc5264d2ae22',
    messagingSenderId: '816352002695',
    projectId: 'sharebites-d214c',
    authDomain: 'sharebites-d214c.firebaseapp.com',
    storageBucket: 'sharebites-d214c.firebasestorage.app',
    measurementId: 'G-4ZRDQ8L04S',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCvuqH1u58b9jiMbxMeA519X5ooxYHyqdM',
    appId: '1:816352002695:android:17566b26ed0fea44d2ae22',
    messagingSenderId: '816352002695',
    projectId: 'sharebites-d214c',
    storageBucket: 'sharebites-d214c.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyB9-jpxWgOcmFQooPlFGl-LzjDGgzrThSA',
    appId: '1:816352002695:ios:dbc22cafb6d671c9d2ae22',
    messagingSenderId: '816352002695',
    projectId: 'sharebites-d214c',
    storageBucket: 'sharebites-d214c.firebasestorage.app',
    iosBundleId: 'com.example.sharebites',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyB9-jpxWgOcmFQooPlFGl-LzjDGgzrThSA',
    appId: '1:816352002695:ios:dbc22cafb6d671c9d2ae22',
    messagingSenderId: '816352002695',
    projectId: 'sharebites-d214c',
    storageBucket: 'sharebites-d214c.firebasestorage.app',
    iosBundleId: 'com.example.sharebites',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyDaGn17qRp-h0f92dpqYqBBVNT7UvtYJ-0',
    appId: '1:816352002695:web:2b6aae3015cd9ab6d2ae22',
    messagingSenderId: '816352002695',
    projectId: 'sharebites-d214c',
    authDomain: 'sharebites-d214c.firebaseapp.com',
    storageBucket: 'sharebites-d214c.firebasestorage.app',
    measurementId: 'G-LSX34K3NV8',
  );
}