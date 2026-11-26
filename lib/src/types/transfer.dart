import 'dart:core';

import 'package:casper_dart_sdk/src/types/cl_public_key.dart';
import 'package:casper_dart_sdk/src/types/global_state_key.dart';
import 'package:json_annotation/json_annotation.dart';

part 'generated/transfer.g.dart';

/// The versioned hash identifying the transaction that created a transfer.
class TransferTransactionHash {
  final String? deployHash;
  final String? transactionV1Hash;

  const TransferTransactionHash._(this.deployHash, this.transactionV1Hash);

  factory TransferTransactionHash.fromJson(dynamic json) {
    if (json is! Map) {
      throw const FormatException('Expected a versioned transaction hash.');
    }

    final values = Map<String, dynamic>.from(json);
    final deployHash = values['Deploy'];
    if (deployHash is String) {
      return TransferTransactionHash._(deployHash, null);
    }

    final transactionV1Hash = values['Version1'];
    if (transactionV1Hash is String) {
      return TransferTransactionHash._(null, transactionV1Hash);
    }

    throw const FormatException(
        'Expected a Deploy or Version1 transaction hash.');
  }

  factory TransferTransactionHash.fromDeployHash(String hash) =>
      TransferTransactionHash._(hash, null);

  String get hash {
    final value = deployHash ?? transactionV1Hash;
    if (value == null) {
      throw StateError('Transfer transaction hash is not initialized.');
    }
    return value;
  }

  Map<String, dynamic> toJson() {
    if (deployHash != null) {
      return {'Deploy': deployHash};
    }
    final hash = transactionV1Hash;
    if (hash != null) {
      return {'Version1': hash};
    }
    throw StateError('Transfer transaction hash is not initialized.');
  }
}

/// A transfer initiator, represented by either a public key or account hash.
class TransferInitiator {
  final AccountHashKey? accountHash;
  final ClPublicKey? publicKey;

  const TransferInitiator._({this.accountHash, this.publicKey});

  factory TransferInitiator.fromJson(dynamic json) {
    if (json is String) {
      return TransferInitiator._(
          accountHash: AccountHashKey.fromPrefixedKey(json));
    }
    if (json is Map) {
      final values = Map<String, dynamic>.from(json);
      final accountHash = values['AccountHash'] ?? values['accountHash'];
      if (accountHash is String) {
        return TransferInitiator._(
            accountHash: AccountHashKey.fromPrefixedKey(accountHash));
      }
      final publicKey = values['PublicKey'] ?? values['publicKey'];
      if (publicKey is String) {
        return TransferInitiator._(publicKey: ClPublicKey.fromHex(publicKey));
      }
    }
    throw const FormatException(
        'Expected a transfer initiator account hash or public key.');
  }

  factory TransferInitiator.fromAccountHash(AccountHashKey accountHash) =>
      TransferInitiator._(accountHash: accountHash);

  /// Returns the account hash for the initiator, deriving it from a public key
  /// when the v2 response uses the PublicKey variant.
  AccountHashKey get normalizedAccountHash {
    final accountHash = this.accountHash;
    if (accountHash != null) {
      return accountHash;
    }
    final publicKey = this.publicKey;
    if (publicKey != null) {
      return AccountHashKey.fromPublicKey(publicKey);
    }
    throw StateError('Transfer initiator is not initialized.');
  }

  Map<String, dynamic> toJson() {
    final accountHash = this.accountHash;
    if (accountHash != null) {
      return {'AccountHash': accountHash.key};
    }
    final publicKey = this.publicKey;
    if (publicKey != null) {
      return {'PublicKey': publicKey.accountHex};
    }
    throw StateError('Transfer initiator is not initialized.');
  }
}

@JsonSerializable(fieldRename: FieldRename.snake)
class Transfer {
  late BigInt amount;

  /// Legacy accessor retained for compatibility. For v2 transfers this is the
  /// underlying transaction hash; use [transactionHash] to distinguish its type.
  late String deployHash;

  @AccountHashKeyJsonConverter()
  late AccountHashKey from;

  late BigInt gas;

  late int? id;

  @UrefJsonConverter()
  late Uref source;

  @UrefJsonConverter()
  late Uref target;

  @AccountHashKeyJsonConverter()
  late String? to;

  @JsonKey(includeFromJson: false, includeToJson: false)
  TransferTransactionHash? transactionHash;

  @JsonKey(includeFromJson: false, includeToJson: false)
  TransferInitiator? initiator;

  @JsonKey(includeFromJson: false, includeToJson: false)
  bool isVersion2 = false;

  factory Transfer.fromJson(Map<String, dynamic> json) {
    final version2 = json['Version2'];
    if (version2 is Map) {
      return Transfer._fromVersion2(Map<String, dynamic>.from(version2));
    }

    final version1 = json['Version1'];
    if (version1 is Map) {
      return Transfer._fromVersion1(Map<String, dynamic>.from(version1));
    }

    if (json.containsKey('transaction_hash')) {
      return Transfer._fromVersion2(json);
    }
    return Transfer._fromVersion1(json);
  }

  static Transfer _fromVersion1(Map<String, dynamic> json) {
    final transfer = _$TransferFromJson(json);
    transfer.transactionHash =
        TransferTransactionHash.fromDeployHash(transfer.deployHash);
    transfer.initiator = TransferInitiator.fromAccountHash(transfer.from);
    return transfer;
  }

  static Transfer _fromVersion2(Map<String, dynamic> json) {
    final transactionHash =
        TransferTransactionHash.fromJson(json['transaction_hash']);
    final initiator = TransferInitiator.fromJson(json['from']);
    final transfer = Transfer()
      ..amount = _parseTransferBigInt(json['amount'], 'amount')
      // Keep the old non-null field usable for existing callers while exposing
      // the actual hash variant through transactionHash.
      ..deployHash = transactionHash.hash
      ..from = initiator.normalizedAccountHash
      ..gas = _parseTransferBigInt(json['gas'], 'gas')
      ..id = (json['id'] as num?)?.toInt()
      ..source = const UrefJsonConverter().fromJson(json['source'] as String)
      ..target = const UrefJsonConverter().fromJson(json['target'] as String)
      ..to = json['to'] as String?
      ..transactionHash = transactionHash
      ..initiator = initiator
      ..isVersion2 = true;
    return transfer;
  }

  Map<String, dynamic> toJson() {
    if (!isVersion2) {
      return _$TransferToJson(this);
    }

    return {
      'Version2': {
        'transaction_hash': transactionHash!.toJson(),
        'from': initiator!.toJson(),
        'to': to,
        'source': const UrefJsonConverter().toJson(source),
        'target': const UrefJsonConverter().toJson(target),
        'amount': amount.toString(),
        'gas': gas.toString(),
        'id': id,
      },
    };
  }

  Transfer();
}

BigInt _parseTransferBigInt(dynamic value, String field) {
  if (value is String) {
    return BigInt.parse(value);
  }
  if (value is int) {
    return BigInt.from(value);
  }
  if (value is BigInt) {
    return value;
  }
  throw FormatException('Expected $field to be an integer or decimal string.');
}
