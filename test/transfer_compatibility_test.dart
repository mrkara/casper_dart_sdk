import 'package:casper_dart_sdk/casper_dart_sdk.dart';
import 'package:test/test.dart';

const _blockHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _deployHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _transactionHash =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _publicKey =
    '01d9bf2148748a85c89da5aad8ee0b0fc2d105fd39d41a4c796536354f0ae2900c';
const _source =
    'uref-54fd72455872082a254b0160e94a86245acd0c441f526688bda1261d0969057a-007';

Map<String, dynamic> _version1Transfer(String accountHash) => {
      'amount': '1000000000000',
      'deploy_hash': _deployHash,
      'from': accountHash,
      'gas': '2500000000',
      'id': 999,
      'source': _source,
      'target': _source,
      'to': accountHash,
    };

Map<String, dynamic> _version2Transfer({
  required Map<String, dynamic> transactionHash,
  required Map<String, dynamic> from,
}) =>
    {
      'transaction_hash': transactionHash,
      'from': from,
      'to': null,
      'source': _source,
      'target': _source,
      'amount': '1000000000000',
      'gas': '2500000000',
      'id': 999,
    };

void main() {
  group('Transfer compatibility', () {
    final publicKey = ClPublicKey.fromHex(_publicKey);
    final accountHash = AccountHashKey.fromPublicKey(publicKey).key;

    test('parses a legacy unwrapped transfer', () {
      final transfer = Transfer.fromJson(_version1Transfer(accountHash));

      expect(transfer.isVersion2, isFalse);
      expect(transfer.deployHash, _deployHash);
      expect(transfer.transactionHash!.deployHash, _deployHash);
      expect(transfer.from.key, accountHash);
      expect(transfer.amount, BigInt.from(1000000000000));
    });

    test('unwraps a Casper v2 Version1 transfer', () {
      final transfer = Transfer.fromJson({
        'Version1': _version1Transfer(accountHash),
      });

      expect(transfer.isVersion2, isFalse);
      expect(transfer.deployHash, _deployHash);
      expect(transfer.initiator!.accountHash!.key, accountHash);
    });

    test('parses Casper v2 Version2 through the RPC result list', () {
      final result = GetBlockTransfersResult.fromJson({
        'api_version': '2.0.0',
        'block_hash': _blockHash,
        'transfers': [
          {
            'Version2': _version2Transfer(
              transactionHash: {'Version1': _transactionHash},
              from: {'AccountHash': accountHash},
            ),
          },
        ],
      });
      final transfer = result.transfers.single;

      expect(result.blockHash, _blockHash);
      expect(transfer.isVersion2, isTrue);
      expect(transfer.transactionHash!.transactionV1Hash, _transactionHash);
      expect(transfer.initiator!.accountHash!.key, accountHash);
      expect(transfer.from.key, accountHash);
      expect(transfer.amount, BigInt.from(1000000000000));
      expect(
        (transfer.toJson()['Version2'] as Map)['transaction_hash'],
        {'Version1': _transactionHash},
      );
    });

    test('parses a Deploy hash and PublicKey initiator in a v2 transfer', () {
      final transfer = Transfer.fromJson({
        'Version2': _version2Transfer(
          transactionHash: {'Deploy': _deployHash},
          from: {'PublicKey': _publicKey},
        ),
      });

      expect(transfer.transactionHash!.deployHash, _deployHash);
      expect(transfer.initiator!.publicKey!.accountHex, publicKey.accountHex);
      expect(transfer.from.key, accountHash);
      expect(
        (transfer.toJson()['Version2'] as Map)['from'],
        {'PublicKey': publicKey.accountHex},
      );
    });
  });
}
