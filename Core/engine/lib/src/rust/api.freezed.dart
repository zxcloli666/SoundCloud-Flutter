// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'api.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BridgeError {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is BridgeError);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BridgeError()';
  }
}

/// @nodoc
class $BridgeErrorCopyWith<$Res> {
  $BridgeErrorCopyWith(BridgeError _, $Res Function(BridgeError) __);
}

/// Adds pattern-matching-related methods to [BridgeError].
extension BridgeErrorPatterns on BridgeError {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(BridgeError_NotInitialized value)? notInitialized,
    TResult Function(BridgeError_Init value)? init,
    TResult Function(BridgeError_Core value)? core,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BridgeError_NotInitialized() when notInitialized != null:
        return notInitialized(_that);
      case BridgeError_Init() when init != null:
        return init(_that);
      case BridgeError_Core() when core != null:
        return core(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(BridgeError_NotInitialized value) notInitialized,
    required TResult Function(BridgeError_Init value) init,
    required TResult Function(BridgeError_Core value) core,
  }) {
    final _that = this;
    switch (_that) {
      case BridgeError_NotInitialized():
        return notInitialized(_that);
      case BridgeError_Init():
        return init(_that);
      case BridgeError_Core():
        return core(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(BridgeError_NotInitialized value)? notInitialized,
    TResult? Function(BridgeError_Init value)? init,
    TResult? Function(BridgeError_Core value)? core,
  }) {
    final _that = this;
    switch (_that) {
      case BridgeError_NotInitialized() when notInitialized != null:
        return notInitialized(_that);
      case BridgeError_Init() when init != null:
        return init(_that);
      case BridgeError_Core() when core != null:
        return core(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? notInitialized,
    TResult Function(String field0)? init,
    TResult Function(String field0)? core,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case BridgeError_NotInitialized() when notInitialized != null:
        return notInitialized();
      case BridgeError_Init() when init != null:
        return init(_that.field0);
      case BridgeError_Core() when core != null:
        return core(_that.field0);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() notInitialized,
    required TResult Function(String field0) init,
    required TResult Function(String field0) core,
  }) {
    final _that = this;
    switch (_that) {
      case BridgeError_NotInitialized():
        return notInitialized();
      case BridgeError_Init():
        return init(_that.field0);
      case BridgeError_Core():
        return core(_that.field0);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? notInitialized,
    TResult? Function(String field0)? init,
    TResult? Function(String field0)? core,
  }) {
    final _that = this;
    switch (_that) {
      case BridgeError_NotInitialized() when notInitialized != null:
        return notInitialized();
      case BridgeError_Init() when init != null:
        return init(_that.field0);
      case BridgeError_Core() when core != null:
        return core(_that.field0);
      case _:
        return null;
    }
  }
}

/// @nodoc

class BridgeError_NotInitialized extends BridgeError {
  const BridgeError_NotInitialized() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BridgeError_NotInitialized);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'BridgeError.notInitialized()';
  }
}

/// @nodoc

class BridgeError_Init extends BridgeError {
  const BridgeError_Init(this.field0) : super._();

  final String field0;

  /// Create a copy of BridgeError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BridgeError_InitCopyWith<BridgeError_Init> get copyWith =>
      _$BridgeError_InitCopyWithImpl<BridgeError_Init>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BridgeError_Init &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'BridgeError.init(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $BridgeError_InitCopyWith<$Res>
    implements $BridgeErrorCopyWith<$Res> {
  factory $BridgeError_InitCopyWith(
          BridgeError_Init value, $Res Function(BridgeError_Init) _then) =
      _$BridgeError_InitCopyWithImpl;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class _$BridgeError_InitCopyWithImpl<$Res>
    implements $BridgeError_InitCopyWith<$Res> {
  _$BridgeError_InitCopyWithImpl(this._self, this._then);

  final BridgeError_Init _self;
  final $Res Function(BridgeError_Init) _then;

  /// Create a copy of BridgeError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(BridgeError_Init(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc

class BridgeError_Core extends BridgeError {
  const BridgeError_Core(this.field0) : super._();

  final String field0;

  /// Create a copy of BridgeError
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BridgeError_CoreCopyWith<BridgeError_Core> get copyWith =>
      _$BridgeError_CoreCopyWithImpl<BridgeError_Core>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BridgeError_Core &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'BridgeError.core(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $BridgeError_CoreCopyWith<$Res>
    implements $BridgeErrorCopyWith<$Res> {
  factory $BridgeError_CoreCopyWith(
          BridgeError_Core value, $Res Function(BridgeError_Core) _then) =
      _$BridgeError_CoreCopyWithImpl;
  @useResult
  $Res call({String field0});
}

/// @nodoc
class _$BridgeError_CoreCopyWithImpl<$Res>
    implements $BridgeError_CoreCopyWith<$Res> {
  _$BridgeError_CoreCopyWithImpl(this._self, this._then);

  final BridgeError_Core _self;
  final $Res Function(BridgeError_Core) _then;

  /// Create a copy of BridgeError
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(BridgeError_Core(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$PlaybackEventDto {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is PlaybackEventDto);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'PlaybackEventDto()';
  }
}

/// @nodoc
class $PlaybackEventDtoCopyWith<$Res> {
  $PlaybackEventDtoCopyWith(
      PlaybackEventDto _, $Res Function(PlaybackEventDto) __);
}

/// Adds pattern-matching-related methods to [PlaybackEventDto].
extension PlaybackEventDtoPatterns on PlaybackEventDto {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(PlaybackEventDto_Ended value)? ended,
    TResult Function(PlaybackEventDto_TrackChanged value)? trackChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case PlaybackEventDto_Ended() when ended != null:
        return ended(_that);
      case PlaybackEventDto_TrackChanged() when trackChanged != null:
        return trackChanged(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(PlaybackEventDto_Ended value) ended,
    required TResult Function(PlaybackEventDto_TrackChanged value) trackChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PlaybackEventDto_Ended():
        return ended(_that);
      case PlaybackEventDto_TrackChanged():
        return trackChanged(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(PlaybackEventDto_Ended value)? ended,
    TResult? Function(PlaybackEventDto_TrackChanged value)? trackChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PlaybackEventDto_Ended() when ended != null:
        return ended(_that);
      case PlaybackEventDto_TrackChanged() when trackChanged != null:
        return trackChanged(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function()? ended,
    TResult Function(String urn)? trackChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case PlaybackEventDto_Ended() when ended != null:
        return ended();
      case PlaybackEventDto_TrackChanged() when trackChanged != null:
        return trackChanged(_that.urn);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function() ended,
    required TResult Function(String urn) trackChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PlaybackEventDto_Ended():
        return ended();
      case PlaybackEventDto_TrackChanged():
        return trackChanged(_that.urn);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function()? ended,
    TResult? Function(String urn)? trackChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PlaybackEventDto_Ended() when ended != null:
        return ended();
      case PlaybackEventDto_TrackChanged() when trackChanged != null:
        return trackChanged(_that.urn);
      case _:
        return null;
    }
  }
}

/// @nodoc

class PlaybackEventDto_Ended extends PlaybackEventDto {
  const PlaybackEventDto_Ended() : super._();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is PlaybackEventDto_Ended);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'PlaybackEventDto.ended()';
  }
}

/// @nodoc

class PlaybackEventDto_TrackChanged extends PlaybackEventDto {
  const PlaybackEventDto_TrackChanged({required this.urn}) : super._();

  final String urn;

  /// Create a copy of PlaybackEventDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PlaybackEventDto_TrackChangedCopyWith<PlaybackEventDto_TrackChanged>
      get copyWith => _$PlaybackEventDto_TrackChangedCopyWithImpl<
          PlaybackEventDto_TrackChanged>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PlaybackEventDto_TrackChanged &&
            (identical(other.urn, urn) || other.urn == urn));
  }

  @override
  int get hashCode => Object.hash(runtimeType, urn);

  @override
  String toString() {
    return 'PlaybackEventDto.trackChanged(urn: $urn)';
  }
}

/// @nodoc
abstract mixin class $PlaybackEventDto_TrackChangedCopyWith<$Res>
    implements $PlaybackEventDtoCopyWith<$Res> {
  factory $PlaybackEventDto_TrackChangedCopyWith(
          PlaybackEventDto_TrackChanged value,
          $Res Function(PlaybackEventDto_TrackChanged) _then) =
      _$PlaybackEventDto_TrackChangedCopyWithImpl;
  @useResult
  $Res call({String urn});
}

/// @nodoc
class _$PlaybackEventDto_TrackChangedCopyWithImpl<$Res>
    implements $PlaybackEventDto_TrackChangedCopyWith<$Res> {
  _$PlaybackEventDto_TrackChangedCopyWithImpl(this._self, this._then);

  final PlaybackEventDto_TrackChanged _self;
  final $Res Function(PlaybackEventDto_TrackChanged) _then;

  /// Create a copy of PlaybackEventDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? urn = null,
  }) {
    return _then(PlaybackEventDto_TrackChanged(
      urn: null == urn
          ? _self.urn
          : urn // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
