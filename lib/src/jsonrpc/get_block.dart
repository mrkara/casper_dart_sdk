import 'package:json_annotation/json_annotation.dart';

import 'package:casper_dart_sdk/src/jsonrpc/rpc_result.dart';
import 'package:casper_dart_sdk/src/jsonrpc/rpc_params.dart';
import 'package:casper_dart_sdk/src/types/block.dart';

part 'generated/get_block.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class GetBlockParams extends RpcParams {
  @JsonKey(name: 'block_identifier')
  BlockId blockId;

  factory GetBlockParams.fromJson(Map<String, dynamic> json) =>
      _$GetBlockParamsFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$GetBlockParamsToJson(this);

  GetBlockParams(this.blockId) : super();
}

@JsonSerializable(fieldRename: FieldRename.snake, createFactory: false)
class GetBlockResult extends RpcResult {
  Block? block;

  factory GetBlockResult.fromJson(Map<String, dynamic> json) {
    final apiVersion = json['api_version'] as String;
    final legacyBlock = json['block'];
    if (legacyBlock is Map) {
      return GetBlockResult(
          apiVersion, Block.fromJson(Map<String, dynamic>.from(legacyBlock)));
    }

    final blockWithSignatures = json['block_with_signatures'];
    if (blockWithSignatures is! Map) {
      return GetBlockResult(apiVersion, null);
    }
    final blockWrapper = blockWithSignatures['block'];
    if (blockWrapper is! Map) {
      return GetBlockResult(apiVersion, null);
    }
    final rawProofs = blockWithSignatures['proofs'];
    final proofs = rawProofs is List ? rawProofs : const <dynamic>[];

    final blockV1 = blockWrapper['Version1'];
    if (blockV1 is Map) {
      final normalizedBlock = Map<String, dynamic>.from(blockV1)
        ..['proofs'] = proofs;
      return GetBlockResult(apiVersion, Block.fromJson(normalizedBlock));
    }

    final blockV2 = blockWrapper['Version2'];
    if (blockV2 is Map) {
      final blockProofs = proofs
          .map((proof) =>
              BlockProof.fromJson(Map<String, dynamic>.from(proof as Map)))
          .toList();
      return GetBlockResult(apiVersion,
          BlockV2.fromJson(Map<String, dynamic>.from(blockV2), blockProofs));
    }

    return GetBlockResult(apiVersion, null);
  }

  @override
  Map<String, dynamic> toJson() => _$GetBlockResultToJson(this);

  GetBlockResult(apiVersion, this.block) : super(apiVersion);
}
