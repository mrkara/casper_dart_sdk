import 'dart:core';

import 'package:json_annotation/json_annotation.dart';

import 'package:casper_dart_sdk/src/helpers/string_utils.dart';

import 'package:casper_dart_sdk/src/types/cl_public_key.dart';
import 'package:casper_dart_sdk/src/types/cl_signature.dart';
import 'package:casper_dart_sdk/src/types/validator_weight.dart';

part 'generated/block.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Block {
  String hash;

  BlockHeader header;

  BlockBody body;

  List<BlockProof> proofs;

  factory Block.fromJson(Map<String, dynamic> json) => _$BlockFromJson(json);
  Map<String, dynamic> toJson() => _$BlockToJson(this);

  Block(this.hash, this.header, this.body, this.proofs);
}

@JsonSerializable(
    ignoreUnannotated: true, createFactory: false, createToJson: false)
class BlockId {
  dynamic _id; // String (hash) or int (height)

  factory BlockId.fromJson(Map<String, dynamic> json) {
    if (json.containsKey("Hash")) {
      return BlockId.fromHash(json['Hash']);
    } else {
      // Height
      return BlockId.fromHeight(json['Height']);
    }
  }

  Map<String, dynamic> toJson() {
    if (_id is String) {
      return {"Hash": _id};
    } else {
      // Height
      return {"Height": _id};
    }
  }

  String? get hash => _id is String ? _id : null;
  int? get height => _id is int ? _id : null;

  @override
  bool operator ==(other) {
    if (other is BlockId) {
      if (_id is String) {
        return other._id == _id;
      } else {
        // Height
        return other._id == _id;
      }
    } else {
      return false;
    }
  }

  @override
  int get hashCode => _id.hashCode;

  BlockId.fromHash(String hash) {
    _id = hash;
  }

  BlockId.fromHeight(int height) {
    _id = height;
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class BlockHeader {
  late String accumulatedSeed;

  late String bodyHash;

  late EraEnd? eraEnd;

  late int eraId;

  late int height;

  late String parentHash;

  late String protocolVersion;

  late bool randomBit;

  late String stateRootHash;

  @DateTimeJsonConverter()
  late DateTime timestamp;

  factory BlockHeader.fromJson(Map<String, dynamic> json) =>
      _$BlockHeaderFromJson(json);
  Map<String, dynamic> toJson() => _$BlockHeaderToJson(this);

  BlockHeader();
}

@JsonSerializable(fieldRename: FieldRename.snake)
class BlockBody {
  List<String> deployHashes;

  @ClPublicKeyJsonConverter()
  ClPublicKey proposer;

  List<String> transferHashes;

  factory BlockBody.fromJson(Map<String, dynamic> json) =>
      _$BlockBodyFromJson(json);
  Map<String, dynamic> toJson() => _$BlockBodyToJson(this);

  BlockBody(this.deployHashes, this.proposer, this.transferHashes);
}

/// Casper 2.x block body. Legacy deploy and transfer lists are empty for this
/// variant; use [transactions] and [rewardedSignatures] instead.
class BlockBodyV2 extends BlockBody {
  final Map<String, List<dynamic>> transactions;
  final List<List<int>> rewardedSignatures;

  BlockBodyV2(this.transactions, this.rewardedSignatures, ClPublicKey proposer)
      : super(const <String>[], proposer, const <String>[]);

  @override
  Map<String, dynamic> toJson() => {
        'transactions': transactions,
        'rewarded_signatures': rewardedSignatures,
      };
}

/// A Casper 2.x version-2 block normalized to the SDK's common [Block] type.
class BlockV2 extends Block {
  final int currentGasPrice;
  final ClPublicKey proposer;
  final String? lastSwitchBlockHash;
  final Map<String, dynamic>? eraEndV2;

  BlockV2(
    String hash,
    BlockHeader header,
    BlockBodyV2 body,
    List<BlockProof> proofs, {
    required this.currentGasPrice,
    required this.proposer,
    this.lastSwitchBlockHash,
    this.eraEndV2,
  }) : super(hash, header, body, proofs);

  factory BlockV2.fromJson(Map<String, dynamic> json, List<BlockProof> proofs) {
    final rawHeader = Map<String, dynamic>.from(json['header'] as Map);
    final eraEnd = rawHeader['era_end'];
    final normalizedHeader = Map<String, dynamic>.from(rawHeader)
      ..['era_end'] = null;
    final header = BlockHeader.fromJson(normalizedHeader);
    final proposer = const ClPublicKeyJsonConverter()
        .fromJson(rawHeader['proposer'] as String);

    final rawBody = Map<String, dynamic>.from(json['body'] as Map);
    final rawTransactions = rawBody['transactions'] as Map? ?? const {};
    final transactions = <String, List<dynamic>>{};
    rawTransactions.forEach((key, value) {
      transactions[key.toString()] = List<dynamic>.from(value as Iterable);
    });
    final rawRewardedSignatures =
        rawBody['rewarded_signatures'] as List? ?? const [];
    final rewardedSignatures = rawRewardedSignatures
        .map((signature) => List<int>.from(signature as Iterable))
        .toList();

    return BlockV2(
      json['hash'] as String,
      header,
      BlockBodyV2(transactions, rewardedSignatures, proposer),
      proofs,
      currentGasPrice: (rawHeader['current_gas_price'] as num).toInt(),
      proposer: proposer,
      lastSwitchBlockHash: rawHeader['last_switch_block_hash'] as String?,
      eraEndV2: eraEnd is Map ? Map<String, dynamic>.from(eraEnd) : null,
    );
  }

  @override
  Map<String, dynamic> toJson() {
    final headerJson = header.toJson()
      ..['current_gas_price'] = currentGasPrice
      ..['proposer'] = const ClPublicKeyJsonConverter().toJson(proposer)
      ..['last_switch_block_hash'] = lastSwitchBlockHash
      ..['era_end'] = eraEndV2;
    return {
      'hash': hash,
      'header': headerJson,
      'body': body.toJson(),
      'proofs': proofs.map((proof) => proof.toJson()).toList(),
    };
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class BlockProof {
  @ClPublicKeyJsonConverter()
  ClPublicKey publicKey;

  @ClSignatureJsonConverter()
  ClSignature signature;

  factory BlockProof.fromJson(Map<String, dynamic> json) =>
      _$BlockProofFromJson(json);
  Map<String, dynamic> toJson() => _$BlockProofToJson(this);

  BlockProof(this.publicKey, this.signature);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class EraEnd {
  EraReport eraReport;

  @ValidatorWeightJsonListConverter()
  List<ValidatorWeight> nextEraValidatorWeights;

  factory EraEnd.fromJson(Map<String, dynamic> json) => _$EraEndFromJson(json);
  Map<String, dynamic> toJson() => _$EraEndToJson(this);

  EraEnd(this.eraReport, this.nextEraValidatorWeights);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class EraReport {
  @ClPublicKeyJsonListConverter()
  List<ClPublicKey> equivocators;

  @ClPublicKeyJsonListConverter()
  List<ClPublicKey> inactiveValidators;

  List<Reward> rewards;

  factory EraReport.fromJson(Map<String, dynamic> json) =>
      _$EraReportFromJson(json);
  Map<String, dynamic> toJson() => _$EraReportToJson(this);

  EraReport(this.equivocators, this.inactiveValidators, this.rewards);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Reward {
  int amount;

  @ClPublicKeyJsonConverter()
  ClPublicKey validator;

  factory Reward.fromJson(Map<String, dynamic> json) => _$RewardFromJson(json);
  Map<String, dynamic> toJson() => _$RewardToJson(this);

  Reward(this.amount, this.validator);
}

@JsonSerializable(fieldRename: FieldRename.snake)
class BlockInfoShort {
  @ClPublicKeyJsonConverter()
  ClPublicKey creator;

  int eraId;

  String hash;

  int height;

  String stateRootHash;

  @DateTimeJsonConverter()
  DateTime timestamp;

  factory BlockInfoShort.fromJson(Map<String, dynamic> json) =>
      _$BlockInfoShortFromJson(json);
  Map<String, dynamic> toJson() => _$BlockInfoShortToJson(this);

  BlockInfoShort(this.creator, this.eraId, this.hash, this.height,
      this.stateRootHash, this.timestamp);
}
