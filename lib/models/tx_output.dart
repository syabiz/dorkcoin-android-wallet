class TxOutput {
  final int amountSats;
  final String scriptHex;

  const TxOutput({
    required this.amountSats,
    required this.scriptHex,
  });
}