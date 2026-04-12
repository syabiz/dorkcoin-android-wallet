import 'dart:typed_data';

import 'package:convert/convert.dart';

import '../models/tx_input.dart';
import '../models/tx_output.dart';
import '../models/unsigned_transaction_preview.dart';
import '../models/utxo.dart';
import 'wallet_service.dart';

class TxBuilderService {
  final WalletService walletService;

  const TxBuilderService({required this.walletService});

  UnsignedTransactionPreview buildUnsignedTransaction({
    required List<Utxo> availableUtxos,
    required String toAddress,
    required String changeAddress,
    required int sendAmountSats,
    required int feeSats,
  }) {
    if (sendAmountSats <= 0) {
      throw Exception('Amount must be greater than zero.');
    }
    if (feeSats < 0) {
      throw Exception('Fee must not be negative.');
    }

    final needed = sendAmountSats + feeSats;
    final selected = _selectUtxos(availableUtxos, needed);
    final selectedTotal = selected.fold<int>(0, (sum, item) => sum + _coinToSats(item.amount));

    if (selectedTotal < needed) {
      throw Exception('Insufficient funds.');
    }

    final changeSats = selectedTotal - needed;

    final inputs = selected
        .map(
          (u) => TxInput(
            txid: u.txid,
            vout: u.vout,
            amountSats: _coinToSats(u.amount),
            scriptHex: u.scriptHex,
          ),
        )
        .toList();

    final outputs = <TxOutput>[
      TxOutput(
        amountSats: sendAmountSats,
        scriptHex: walletService.addressToP2pkhScriptHex(toAddress),
      ),
    ];

    if (changeSats > 0) {
      outputs.add(
        TxOutput(
          amountSats: changeSats,
          scriptHex: walletService.addressToP2pkhScriptHex(changeAddress),
        ),
      );
    }

    final unsignedHex = serializeUnsignedTransaction(inputs: inputs, outputs: outputs);

    return UnsignedTransactionPreview(
      inputs: inputs,
      outputs: outputs,
      sendAmountSats: sendAmountSats,
      feeSats: feeSats,
      changeSats: changeSats,
      selectedInputTotalSats: selectedTotal,
      toAddress: toAddress,
      changeAddress: changeAddress,
      unsignedHex: unsignedHex,
    );
  }

  List<Utxo> _selectUtxos(List<Utxo> utxos, int neededSats) {
    final sorted = [...utxos]
      ..sort((a, b) => _coinToSats(b.amount).compareTo(_coinToSats(a.amount)));

    final selected = <Utxo>[];
    var total = 0;
    for (final utxo in sorted) {
      if ((utxo.scriptHex).isEmpty) {
        continue;
      }
      selected.add(utxo);
      total += _coinToSats(utxo.amount);
      if (total >= neededSats) {
        break;
      }
    }

    if (total < neededSats) {
      throw Exception('Not enough spendable UTXOs for amount + fee.');
    }
    return selected;
  }

  int _coinToSats(double value) {
    return (value * 100000000).round();
  }

  Uint8List buildLegacySighashPreimage({
    required List<TxInput> inputs,
    required List<TxOutput> outputs,
    required int inputIndex,
    required String scriptPubKeyHex,
    int sighashType = 0x01,
  }) {
    if (inputIndex < 0 || inputIndex >= inputs.length) {
      throw Exception('Input index out of range.');
    }

    final scriptSigs = List<String>.filled(inputs.length, '');
    scriptSigs[inputIndex] = scriptPubKeyHex;

    final txBytes = _serializeTransactionBytes(
      inputs: inputs,
      outputs: outputs,
      scriptSigsHex: scriptSigs,
    );

    final out = BytesBuilder();
    out.add(txBytes);
    out.add(_uint32LE(sighashType));
    return out.toBytes();
  }

  Uint8List legacySighashDigest({
    required List<TxInput> inputs,
    required List<TxOutput> outputs,
    required int inputIndex,
    required String scriptPubKeyHex,
    int sighashType = 0x01,
  }) {
    final preimage = buildLegacySighashPreimage(
      inputs: inputs,
      outputs: outputs,
      inputIndex: inputIndex,
      scriptPubKeyHex: scriptPubKeyHex,
      sighashType: sighashType,
    );
    return walletService.doubleSha256(preimage);
  }

  String signLegacyP2pkhTransaction({
    required String privateKeyHex,
    required List<TxInput> inputs,
    required List<TxOutput> outputs,
    int sighashType = 0x01,
  }) {
    final privateKey = Uint8List.fromList(hex.decode(privateKeyHex.trim()));
    final compressedPubKey = walletService.privateKeyToCompressedPublicKey(privateKey);

    final scriptSigs = <String>[];

    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      if (input.scriptHex.trim().isEmpty) {
        throw Exception('Missing prevout scriptPubKey for input $i.');
      }

      final digest = legacySighashDigest(
        inputs: inputs,
        outputs: outputs,
        inputIndex: i,
        scriptPubKeyHex: input.scriptHex,
        sighashType: sighashType,
      );

      final derSignature = walletService.signDigest(privateKey, digest);
      final scriptSigHex = walletService.buildP2pkhScriptSigHex(
        derSignature: derSignature,
        sighashType: sighashType,
        compressedPubKey: compressedPubKey,
      );
      scriptSigs.add(scriptSigHex);
    }

    return hex.encode(
      _serializeTransactionBytes(
        inputs: inputs,
        outputs: outputs,
        scriptSigsHex: scriptSigs,
      ),
    );
  }

  String serializeUnsignedTransaction({
    required List<TxInput> inputs,
    required List<TxOutput> outputs,
  }) {
    return hex.encode(
      _serializeTransactionBytes(
        inputs: inputs,
        outputs: outputs,
        scriptSigsHex: List<String>.filled(inputs.length, ''),
      ),
    );
  }

  Uint8List _serializeTransactionBytes({
    required List<TxInput> inputs,
    required List<TxOutput> outputs,
    required List<String> scriptSigsHex,
  }) {
    if (scriptSigsHex.length != inputs.length) {
      throw Exception('scriptSigsHex length must match number of inputs.');
    }

    final bytes = BytesBuilder();

    bytes.add(_uint32LE(2)); // version
    bytes.add(_encodeVarInt(inputs.length));

    for (int i = 0; i < inputs.length; i++) {
      final input = inputs[i];
      final scriptHex = scriptSigsHex[i].trim();

      bytes.add(_txidHexToBytesLE(input.txid));
      bytes.add(_uint32LE(input.vout));

      if (scriptHex.isEmpty) {
        bytes.addByte(0x00);
      } else {
        final scriptBytes = Uint8List.fromList(hex.decode(scriptHex));
        bytes.add(_encodeVarInt(scriptBytes.length));
        bytes.add(scriptBytes);
      }

      bytes.add(_uint32LE(0xffffffff)); // sequence
    }

    bytes.add(_encodeVarInt(outputs.length));

    for (final output in outputs) {
      bytes.add(_uint64LE(output.amountSats));
      final scriptBytes = Uint8List.fromList(hex.decode(output.scriptHex));
      bytes.add(_encodeVarInt(scriptBytes.length));
      bytes.add(scriptBytes);
    }

    bytes.add(_uint32LE(0)); // locktime
    return bytes.toBytes();
  }

  Uint8List _txidHexToBytesLE(String txid) {
    final bytes = Uint8List.fromList(hex.decode(txid));
    return Uint8List.fromList(bytes.reversed.toList());
  }

  Uint8List _uint32LE(int value) {
    final b = ByteData(4);
    b.setUint32(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  Uint8List _uint64LE(int value) {
    final b = ByteData(8);
    b.setUint64(0, value, Endian.little);
    return b.buffer.asUint8List();
  }

  Uint8List _encodeVarInt(int value) {
    if (value < 0xfd) {
      return Uint8List.fromList([value]);
    }
    if (value <= 0xffff) {
      final b = ByteData(3);
      b.setUint8(0, 0xfd);
      b.setUint16(1, value, Endian.little);
      return b.buffer.asUint8List();
    }
    if (value <= 0xffffffff) {
      final b = ByteData(5);
      b.setUint8(0, 0xfe);
      b.setUint32(1, value, Endian.little);
      return b.buffer.asUint8List();
    }
    final b = ByteData(9);
    b.setUint8(0, 0xff);
    b.setUint64(1, value, Endian.little);
    return b.buffer.asUint8List();
  }
}