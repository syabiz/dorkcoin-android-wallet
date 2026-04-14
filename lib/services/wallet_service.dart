// =========================
// lib/services/wallet_service.dart
// Updated for Dorkcoin (DORK)
// =========================
import 'dart:math';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import '../models/wallet_info.dart';

class WalletService {
  // Dorkcoin MainNet Prefixes
  static const int pubkeyPrefix = 30;  // 0x1e (Address starts with 'D')
  static const int wifPrefix = 158;    // 0x9e (WIF starts with 'Q')
  static const int compressedFlag = 0x01;
  static const String _base58Alphabet = '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz';

  final Random _random = Random.secure();
  final ECDomainParameters _domain = ECDomainParameters('secp256k1');

  WalletInfo generateWallet() {
    final priv = _randomPrivateKey();
    return _walletFromPrivateKey(priv);
  }

  WalletInfo importWallet(String input) {
    final cleaned = input.trim();
    if (cleaned.isEmpty) {
      throw Exception('Please enter a private key hex or compressed WIF.');
    }

    final maybeHex = cleaned.toLowerCase();
    final hexRegex = RegExp(r'^[0-9a-f]{64}$');
    if (hexRegex.hasMatch(maybeHex)) {
      final priv = Uint8List.fromList(hex.decode(maybeHex));
      _validatePrivateKey(priv);
      return _walletFromPrivateKey(priv);
    }

    final priv = privateKeyFromCompressedWif(cleaned);
    return _walletFromPrivateKey(priv);
  }

  WalletInfo importFromPrivateKeyHex(String privateKeyHex) {
    return importWallet(privateKeyHex);
  }

  WalletInfo _walletFromPrivateKey(Uint8List priv) {
    _validatePrivateKey(priv);
    final pub = privateKeyToCompressedPublicKey(priv);
    final address = publicKeyToAddress(pub);
    final wif = privateKeyToCompressedWif(priv);

    return WalletInfo(
      address: address,
      wif: wif,
      privateKeyHex: hex.encode(priv),
      publicKeyHex: hex.encode(pub),
    );
  }

  void _validatePrivateKey(Uint8List priv) {
    if (priv.length != 32) {
      throw Exception('Private key must be exactly 32 bytes.');
    }

    final d = _bytesToBigInt(priv);
    if (d <= BigInt.zero || d >= _domain.n) {
      throw Exception('Invalid secp256k1 private key.');
    }
  }

  Uint8List _randomPrivateKey() {
    while (true) {
      final priv = Uint8List.fromList(List<int>.generate(32, (_) => _random.nextInt(256)));
      final d = _bytesToBigInt(priv);
      if (d > BigInt.zero && d < _domain.n) {
        return priv;
      }
    }
  }

  Uint8List privateKeyToCompressedPublicKey(Uint8List priv) {
    final d = _bytesToBigInt(priv);
    final point = _domain.G * d;
    if (point == null || point.isInfinity || point.x == null || point.y == null) {
      throw Exception('Failed to derive public key.');
    }

    final x = _bigIntToFixedBytes(point.x!.toBigInteger()!, 32);
    final y = point.y!.toBigInteger()!;
    final prefix = y.isEven ? 0x02 : 0x03;
    return Uint8List.fromList([prefix, ...x]);
  }

  String privateKeyToCompressedWif(Uint8List priv) {
    final payload = Uint8List.fromList([
      wifPrefix,
      ...priv,
      compressedFlag,
    ]);
    return base58CheckEncode(payload);
  }

  Uint8List privateKeyFromCompressedWif(String wif) {
    final payload = base58CheckDecode(wif.trim());
    if (payload.length < 33) {
       throw Exception('Invalid WIF length.');
    }
    if (payload[0] != wifPrefix) {
      throw Exception('Invalid WIF network prefix. Expected $wifPrefix.');
    }

    // Support both compressed (34 bytes) and uncompressed (33 bytes) if needed,
    // though we primarily use compressed (34).
    final priv = Uint8List.fromList(payload.sublist(1, 33));
    _validatePrivateKey(priv);
    return priv;
  }

  String publicKeyToAddress(Uint8List compressedPubKey) {
    final pubKeyHash = hash160(compressedPubKey);
    final payload = Uint8List.fromList([pubkeyPrefix, ...pubKeyHash]);
    return base58CheckEncode(payload);
  }

  Uint8List addressToPubKeyHash(String address) {
    final cleaned = address.trim();
    if (cleaned.isEmpty) throw Exception('Address cannot be empty.');

    final payload = base58CheckDecode(cleaned);
    if (payload.length != 21) {
      throw Exception('Invalid address length. Must be a valid DORK address.');
    }
    if (payload[0] != pubkeyPrefix) {
      throw Exception('Invalid Dorkcoin address prefix. Must start with D.');
    }
    return Uint8List.fromList(payload.sublist(1));
  }

  String addressToP2pkhScriptHex(String address) {
    final pubKeyHash = addressToPubKeyHash(address);
    final script = Uint8List.fromList([
      0x76, // OP_DUP
      0xa9, // OP_HASH160
      0x14, // push 20 bytes
      ...pubKeyHash,
      0x88, // OP_EQUALVERIFY
      0xac, // OP_CHECKSIG
    ]);
    return hex.encode(script);
  }

  Uint8List hash160(Uint8List input) {
    final sha = Uint8List.fromList(sha256.convert(input).bytes);
    final ripemd = RIPEMD160Digest().process(sha);
    return Uint8List.fromList(ripemd);
  }

  Uint8List doubleSha256(Uint8List data) {
    final first = sha256.convert(data).bytes;
    final second = sha256.convert(first).bytes;
    return Uint8List.fromList(second);
  }

  String base58CheckEncode(Uint8List payload) {
    final checksum = doubleSha256(payload).sublist(0, 4);
    final full = Uint8List.fromList([...payload, ...checksum]);
    return _base58Encode(full);
  }

  Uint8List base58CheckDecode(String encoded) {
    final full = _base58Decode(encoded);
    if (full.length < 5) {
      throw Exception('Invalid Base58Check payload.');
    }

    final payload = Uint8List.fromList(full.sublist(0, full.length - 4));
    final checksum = full.sublist(full.length - 4);
    final expected = doubleSha256(payload).sublist(0, 4);
    for (int i = 0; i < 4; i++) {
      if (checksum[i] != expected[i]) {
        throw Exception('Invalid Base58Check checksum.');
      }
    }
    return payload;
  }

  String _base58Encode(Uint8List bytes) {
    int zeros = 0;
    while (zeros < bytes.length && bytes[zeros] == 0) {
      zeros++;
    }

    BigInt value = BigInt.zero;
    for (final b in bytes) {
      value = (value << 8) | BigInt.from(b);
    }

    final out = StringBuffer();
    while (value > BigInt.zero) {
      final div = value ~/ BigInt.from(58);
      final mod = value % BigInt.from(58);
      out.write(_base58Alphabet[mod.toInt()]);
      value = div;
    }

    final encoded = out.toString().split('').reversed.join();
    return ('1' * zeros) + (encoded.isEmpty ? '' : encoded);
  }

  Uint8List _base58Decode(String encoded) {
    if (encoded.isEmpty) {
      throw Exception('Empty Base58 string.');
    }

    BigInt value = BigInt.zero;
    for (final codePoint in encoded.runes) {
      final ch = String.fromCharCode(codePoint);
      final index = _base58Alphabet.indexOf(ch);
      if (index < 0) {
        throw Exception('Invalid Base58 character: $ch');
      }
      value = value * BigInt.from(58) + BigInt.from(index);
    }

    final bytes = <int>[];
    while (value > BigInt.zero) {
      bytes.add((value & BigInt.from(0xff)).toInt());
      value = value >> 8;
    }
    final decoded = bytes.reversed.toList();

    int leadingOnes = 0;
    while (leadingOnes < encoded.length && encoded[leadingOnes] == '1') {
      leadingOnes++;
    }

    return Uint8List.fromList([
      ...List<int>.filled(leadingOnes, 0),
      ...decoded,
    ]);
  }

  Uint8List signDigest(Uint8List privateKey, Uint8List digest) {
    _validatePrivateKey(privateKey);
    if (digest.length != 32) {
      throw Exception('Digest must be exactly 32 bytes.');
    }

    final d = _bytesToBigInt(privateKey);
    final privateParams = PrivateKeyParameter<ECPrivateKey>(
      ECPrivateKey(d, _domain),
    );

    final signer = ECDSASigner(
      null,
      HMac(SHA256Digest(), 64),
    );
    signer.init(true, privateParams);
    final signature = signer.generateSignature(digest);

    if (signature is! ECSignature) {
      throw Exception('Failed to generate EC signature.');
    }

    final normalizedS = normalizeLowS(signature.s);
    return derEncodeSignature(signature.r, normalizedS);
  }

  BigInt normalizeLowS(BigInt s) {
    final halfOrder = _domain.n >> 1;
    if (s > halfOrder) {
      return _domain.n - s;
    }
    return s;
  }

  Uint8List derEncodeSignature(BigInt r, BigInt s) {
    Uint8List encodeInteger(BigInt value) {
      if (value < BigInt.zero) {
        throw Exception('DER integer must not be negative.');
      }

      var bytes = _bigIntToMinimalBytes(value);
      if (bytes.isEmpty) {
        bytes = Uint8List.fromList([0x00]);
      }

      if ((bytes[0] & 0x80) != 0) {
        bytes = Uint8List.fromList([0x00, ...bytes]);
      }

      return Uint8List.fromList([
        0x02,
        bytes.length,
        ...bytes,
      ]);
    }

    final rEncoded = encodeInteger(r);
    final sEncoded = encodeInteger(s);
    final sequenceBody = Uint8List.fromList([...rEncoded, ...sEncoded]);

    return Uint8List.fromList([
      0x30,
      sequenceBody.length,
      ...sequenceBody,
    ]);
  }

  String buildP2pkhScriptSigHex({
    required Uint8List derSignature,
    required int sighashType,
    required Uint8List compressedPubKey,
  }) {
    if (sighashType < 0 || sighashType > 255) {
      throw Exception('Sighash type must fit into one byte.');
    }
    if (compressedPubKey.length != 33) {
      throw Exception('Compressed public key must be 33 bytes.');
    }

    final sigWithHashType = Uint8List.fromList([
      ...derSignature,
      sighashType,
    ]);

    final script = Uint8List.fromList([
      ..._encodePushData(sigWithHashType),
      ..._encodePushData(compressedPubKey),
    ]);

    return hex.encode(script);
  }

  Uint8List _bigIntToMinimalBytes(BigInt value) {
    if (value == BigInt.zero) {
      return Uint8List(0);
    }

    final bytes = <int>[];
    var tmp = value;
    while (tmp > BigInt.zero) {
      bytes.add((tmp & BigInt.from(0xff)).toInt());
      tmp = tmp >> 8;
    }
    return Uint8List.fromList(bytes.reversed.toList());
  }

  Uint8List _encodePushData(Uint8List data) {
    final len = data.length;
    if (len < 0x4c) {
      return Uint8List.fromList([len, ...data]);
    }
    if (len <= 0xff) {
      return Uint8List.fromList([0x4c, len, ...data]);
    }
    if (len <= 0xffff) {
      final out = BytesBuilder();
      out.addByte(0x4d);
      final b = ByteData(2);
      b.setUint16(0, len, Endian.little);
      out.add(b.buffer.asUint8List());
      out.add(data);
      return out.toBytes();
    }
    throw Exception('Pushdata too large for P2PKH scriptSig.');
  }

  BigInt _bytesToBigInt(Uint8List bytes) {
    BigInt result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b);
    }
    return result;
  }

  Uint8List _bigIntToFixedBytes(BigInt value, int length) {
    final out = Uint8List(length);
    BigInt tmp = value;
    for (int i = length - 1; i >= 0; i--) {
      out[i] = (tmp & BigInt.from(0xff)).toInt();
      tmp = tmp >> 8;
    }
    return out;
  }
}
