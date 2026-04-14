import 'tx_input.dart';
import 'tx_output.dart';

class UnsignedTransactionPreview {
  final List<TxInput> inputs;
  final List<TxOutput> outputs;
  final int sendAmountSats;
  final int feeSats;
  final int changeSats;
  final int selectedInputTotalSats;
  final String toAddress;
  final String changeAddress;
  final String unsignedHex;

  const UnsignedTransactionPreview({
    required this.inputs,
    required this.outputs,
    required this.sendAmountSats,
    required this.feeSats,
    required this.changeSats,
    required this.selectedInputTotalSats,
    required this.toAddress,
    required this.changeAddress,
    required this.unsignedHex,
  });
}