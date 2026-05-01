import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:basic_utils/basic_utils.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'dart:developer' as dev;
import 'package:crypto/crypto.dart';

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;
  SecurityService._internal();

  SecurityContext? _serverContext;
  SecurityContext? _clientContext;

  Future<SecurityContext> getServerContext() async {
    if (_serverContext != null) return _serverContext!;
    
    final certData = await _getOrCreateCertificate();
    _serverContext = SecurityContext()
      ..useCertificateChainBytes(certData.certificate)
      ..usePrivateKeyBytes(certData.privateKey);
    
    return _serverContext!;
  }

  Future<SecurityContext> getClientContext() async {
    if (_clientContext != null) return _clientContext!;
    
    // For clients, we just need a context that can handle our self-signed certs
    // The actual trust logic will be in the onBadCertificate callback
    _clientContext = SecurityContext(withTrustedRoots: true);
    return _clientContext!;
  }

  Future<CertificateData> _getOrCreateCertificate() async {
    final directory = await getApplicationSupportDirectory();
    final certFile = File('${directory.path}/server.crt');
    final keyFile = File('${directory.path}/server.key');

    if (await certFile.exists() && await keyFile.exists()) {
      return CertificateData(
        await certFile.readAsBytes(),
        await keyFile.readAsBytes(),
      );
    }

    dev.log('Generating new self-signed certificate...', name: 'SecurityService');
    
    // Generate RSA Key Pair
    final pair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privKey = pair.privateKey as RSAPrivateKey;
    final pubKey = pair.publicKey as RSAPublicKey;

    // Define the Distinguished Name (DN)
    final dn = {
      'CN': 'HotDrop Mobile Node',
      'O': 'HotDrop',
      'OU': 'P2P Storage',
      'C': 'US'
    };

    // 1. Generate CSR (Certificate Signing Request)
    final csrPem = X509Utils.generateRsaCsrPem(dn, privKey, pubKey);

    // 2. Generate Self-Signed Certificate using the CSR
    final certPem = X509Utils.generateSelfSignedCertificate(
      privKey,
      csrPem,
      365, // days
    );

    final keyPem = CryptoUtils.encodeRSAPrivateKeyToPem(privKey);

    await certFile.writeAsString(certPem);
    await keyFile.writeAsString(keyPem);

    return CertificateData(
      Uint8List.fromList(certPem.codeUnits),
      Uint8List.fromList(keyPem.codeUnits),
    );
  }

  /// Encrypts BLE payload using a 4-digit PIN
  String encryptBleData(Map<String, dynamic> data, String pin) {
    final key = _deriveKeyFromPin(pin);
    final iv = enc.IV.fromLength(16);
    final encrypter = enc.Encrypter(enc.AES(key));

    final encrypted = encrypter.encrypt(jsonEncode(data), iv: iv);
    // Format: IV(base64):EncryptedData(base64)
    return "HP:${iv.base64}:${encrypted.base64}";
  }

  /// Decrypts BLE payload using a 4-digit PIN
  Map<String, dynamic>? decryptBleData(String encryptedPayload, String pin) {
    try {
      if (!encryptedPayload.startsWith("HP:")) return null;

      final parts = encryptedPayload.substring(3).split(':');
      if (parts.length != 2) return null;

      final iv = enc.IV.fromBase64(parts[0]);
      final encryptedData = parts[1];

      final key = _deriveKeyFromPin(pin);
      final encrypter = enc.Encrypter(enc.AES(key));

      final decrypted = encrypter.decrypt64(encryptedData, iv: iv);
      return jsonDecode(decrypted) as Map<String, dynamic>;
    } catch (e) {
      dev.log("BLE Decryption Error", name: "SecurityService", error: e);
      return null;
    }
  }

  enc.Key _deriveKeyFromPin(String pin) {
    // Hash the PIN to create a 32-byte (256-bit) key
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return enc.Key(Uint8List.fromList(digest.bytes));
  }
}

class CertificateData {
  final Uint8List certificate;
  final Uint8List privateKey;

  CertificateData(this.certificate, this.privateKey);
}
