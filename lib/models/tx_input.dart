class TxInput {
  final String txid;
  final int vout;
  final int amountSats;
  final String scriptHex;

  const TxInput({
    required this.txid,
    required this.vout,
    required this.amountSats,
    required this.scriptHex,
  });
}