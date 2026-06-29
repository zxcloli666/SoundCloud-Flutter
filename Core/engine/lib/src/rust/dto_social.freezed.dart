// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'dto_social.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SpotlightItemDto {
  Object get field0;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotlightItemDto &&
            const DeepCollectionEquality().equals(other.field0, field0));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, const DeepCollectionEquality().hash(field0));

  @override
  String toString() {
    return 'SpotlightItemDto(field0: $field0)';
  }
}

/// @nodoc
class $SpotlightItemDtoCopyWith<$Res> {
  $SpotlightItemDtoCopyWith(
      SpotlightItemDto _, $Res Function(SpotlightItemDto) __);
}

/// Adds pattern-matching-related methods to [SpotlightItemDto].
extension SpotlightItemDtoPatterns on SpotlightItemDto {
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
    TResult Function(SpotlightItemDto_Artist value)? artist,
    TResult Function(SpotlightItemDto_Album value)? album,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SpotlightItemDto_Artist() when artist != null:
        return artist(_that);
      case SpotlightItemDto_Album() when album != null:
        return album(_that);
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
    required TResult Function(SpotlightItemDto_Artist value) artist,
    required TResult Function(SpotlightItemDto_Album value) album,
  }) {
    final _that = this;
    switch (_that) {
      case SpotlightItemDto_Artist():
        return artist(_that);
      case SpotlightItemDto_Album():
        return album(_that);
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
    TResult? Function(SpotlightItemDto_Artist value)? artist,
    TResult? Function(SpotlightItemDto_Album value)? album,
  }) {
    final _that = this;
    switch (_that) {
      case SpotlightItemDto_Artist() when artist != null:
        return artist(_that);
      case SpotlightItemDto_Album() when album != null:
        return album(_that);
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
    TResult Function(ArtistCardDto field0)? artist,
    TResult Function(AlbumCardDto field0)? album,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SpotlightItemDto_Artist() when artist != null:
        return artist(_that.field0);
      case SpotlightItemDto_Album() when album != null:
        return album(_that.field0);
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
    required TResult Function(ArtistCardDto field0) artist,
    required TResult Function(AlbumCardDto field0) album,
  }) {
    final _that = this;
    switch (_that) {
      case SpotlightItemDto_Artist():
        return artist(_that.field0);
      case SpotlightItemDto_Album():
        return album(_that.field0);
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
    TResult? Function(ArtistCardDto field0)? artist,
    TResult? Function(AlbumCardDto field0)? album,
  }) {
    final _that = this;
    switch (_that) {
      case SpotlightItemDto_Artist() when artist != null:
        return artist(_that.field0);
      case SpotlightItemDto_Album() when album != null:
        return album(_that.field0);
      case _:
        return null;
    }
  }
}

/// @nodoc

class SpotlightItemDto_Artist extends SpotlightItemDto {
  const SpotlightItemDto_Artist(this.field0) : super._();

  @override
  final ArtistCardDto field0;

  /// Create a copy of SpotlightItemDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SpotlightItemDto_ArtistCopyWith<SpotlightItemDto_Artist> get copyWith =>
      _$SpotlightItemDto_ArtistCopyWithImpl<SpotlightItemDto_Artist>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotlightItemDto_Artist &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'SpotlightItemDto.artist(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $SpotlightItemDto_ArtistCopyWith<$Res>
    implements $SpotlightItemDtoCopyWith<$Res> {
  factory $SpotlightItemDto_ArtistCopyWith(SpotlightItemDto_Artist value,
          $Res Function(SpotlightItemDto_Artist) _then) =
      _$SpotlightItemDto_ArtistCopyWithImpl;
  @useResult
  $Res call({ArtistCardDto field0});
}

/// @nodoc
class _$SpotlightItemDto_ArtistCopyWithImpl<$Res>
    implements $SpotlightItemDto_ArtistCopyWith<$Res> {
  _$SpotlightItemDto_ArtistCopyWithImpl(this._self, this._then);

  final SpotlightItemDto_Artist _self;
  final $Res Function(SpotlightItemDto_Artist) _then;

  /// Create a copy of SpotlightItemDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(SpotlightItemDto_Artist(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as ArtistCardDto,
    ));
  }
}

/// @nodoc

class SpotlightItemDto_Album extends SpotlightItemDto {
  const SpotlightItemDto_Album(this.field0) : super._();

  @override
  final AlbumCardDto field0;

  /// Create a copy of SpotlightItemDto
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SpotlightItemDto_AlbumCopyWith<SpotlightItemDto_Album> get copyWith =>
      _$SpotlightItemDto_AlbumCopyWithImpl<SpotlightItemDto_Album>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SpotlightItemDto_Album &&
            (identical(other.field0, field0) || other.field0 == field0));
  }

  @override
  int get hashCode => Object.hash(runtimeType, field0);

  @override
  String toString() {
    return 'SpotlightItemDto.album(field0: $field0)';
  }
}

/// @nodoc
abstract mixin class $SpotlightItemDto_AlbumCopyWith<$Res>
    implements $SpotlightItemDtoCopyWith<$Res> {
  factory $SpotlightItemDto_AlbumCopyWith(SpotlightItemDto_Album value,
          $Res Function(SpotlightItemDto_Album) _then) =
      _$SpotlightItemDto_AlbumCopyWithImpl;
  @useResult
  $Res call({AlbumCardDto field0});
}

/// @nodoc
class _$SpotlightItemDto_AlbumCopyWithImpl<$Res>
    implements $SpotlightItemDto_AlbumCopyWith<$Res> {
  _$SpotlightItemDto_AlbumCopyWithImpl(this._self, this._then);

  final SpotlightItemDto_Album _self;
  final $Res Function(SpotlightItemDto_Album) _then;

  /// Create a copy of SpotlightItemDto
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? field0 = null,
  }) {
    return _then(SpotlightItemDto_Album(
      null == field0
          ? _self.field0
          : field0 // ignore: cast_nullable_to_non_nullable
              as AlbumCardDto,
    ));
  }
}

// dart format on
