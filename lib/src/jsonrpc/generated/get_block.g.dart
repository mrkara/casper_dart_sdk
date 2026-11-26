// GENERATED CODE - DO NOT MODIFY BY HAND

part of '../get_block.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GetBlockParams _$GetBlockParamsFromJson(Map<String, dynamic> json) =>
    GetBlockParams(
      BlockId.fromJson(json['block_identifier'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$GetBlockParamsToJson(GetBlockParams instance) =>
    <String, dynamic>{
      'block_identifier': instance.blockId.toJson(),
    };

Map<String, dynamic> _$GetBlockResultToJson(GetBlockResult instance) =>
    <String, dynamic>{
      'api_version': instance.apiVersion,
      'block': instance.block?.toJson(),
    };
