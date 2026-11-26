import 'package:casper_dart_sdk/casper_dart_sdk.dart';
import 'package:test/test.dart';

const _blockHash =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _stateRootHash =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _parentHash =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _bodyHash =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const _seed =
    'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
const _proposer =
    '01d9bf2148748a85c89da5aad8ee0b0fc2d105fd39d41a4c796536354f0ae2900c';

Map<String, dynamic> _header(int height, {bool version2 = false}) => {
      'accumulated_seed': _seed,
      'body_hash': _bodyHash,
      'era_end': null,
      'era_id': 1,
      'height': height,
      'parent_hash': _parentHash,
      'protocol_version': '2.0.0',
      'random_bit': true,
      'state_root_hash': _stateRootHash,
      'timestamp': '2026-01-01T00:00:00.000Z',
      if (version2) 'current_gas_price': 1,
      if (version2) 'proposer': _proposer,
      if (version2) 'last_switch_block_hash': null,
    };

Map<String, dynamic> _version1Block() => {
      'hash': _blockHash,
      'header': _header(10),
      'body': {
        'deploy_hashes': <String>[],
        'proposer': _proposer,
        'transfer_hashes': <String>[],
      },
    };

void main() {
  group('GetBlockResult compatibility', () {
    test('parses the legacy Casper 1.5 block field', () {
      final result = GetBlockResult.fromJson({
        'api_version': '1.5.6',
        'block': {..._version1Block(), 'proofs': <dynamic>[]},
      });

      expect(result.block, isNotNull);
      expect(result.block!.header.height, 10);
    });

    test('unwraps a Casper 2 Version1 block and attaches its proofs', () {
      final result = GetBlockResult.fromJson({
        'api_version': '2.0.0',
        'block_with_signatures': {
          'block': {'Version1': _version1Block()},
          'proofs': <dynamic>[],
        },
      });

      expect(result.block, isNotNull);
      expect(result.block!.header.height, 10);
      expect(result.block!.proofs, isEmpty);
    });

    test('parses a Casper 2 Version2 block', () {
      final result = GetBlockResult.fromJson({
        'api_version': '2.0.0',
        'block_with_signatures': {
          'block': {
            'Version2': {
              'hash': _blockHash,
              'header': _header(20, version2: true),
              'body': {
                'transactions': <String, dynamic>{
                  '1': [
                    {'Version1': _blockHash},
                  ],
                },
                'rewarded_signatures': <List<int>>[],
              },
            },
          },
          'proofs': <dynamic>[],
        },
      });

      expect(result.block, isA<BlockV2>());
      expect(result.block!.header.height, 20);
      expect(
          (result.block!.body as BlockBodyV2).transactions['1'], hasLength(1));
    });
  });
}
