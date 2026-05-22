import 'package:aed_map/models/aed.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_map/flutter_map.dart';

class PointsState extends Equatable {
  @override
  List<Object?> get props => [];
}

class PointsLoadInProgress extends PointsState {}

class PointsLoadSuccess extends PointsState {
  final List<Defibrillator> defibrillators;
  final int defibrillatorsCount;
  final Defibrillator selected;
  final Defibrillator closest;
  final List<Marker> markers;
  final String hash;
  final DateTime lastUpdateTime;
  final bool refreshing;
  final String selectedHash;
  final Set<int> pendingIds;

  @override
  List<Object?> get props => [
        defibrillators,
        defibrillatorsCount,
        selected,
        closest,
        markers,
        hash,
        lastUpdateTime,
        refreshing,
        pendingIds,
        selectedHash
      ];

  PointsLoadSuccess({
    required this.defibrillators,
    required this.defibrillatorsCount,
    required this.selected,
    required this.closest,
    required this.markers,
    required this.hash,
    required this.lastUpdateTime,
    required this.refreshing,
    this.selectedHash = '',
    this.pendingIds = const {},
  });

  PointsLoadSuccess copyWith({
    List<Defibrillator>? defibrillators,
    int? defibrillatorsCount,
    Defibrillator? selected,
    Defibrillator? closest,
    List<Marker>? markers,
    String? hash,
    String? selectedHash,
    DateTime? lastUpdateTime,
    bool? refreshing,
    Set<int>? pendingIds,
  }) {
    return PointsLoadSuccess(
      defibrillators: defibrillators ?? this.defibrillators,
      defibrillatorsCount: defibrillatorsCount ?? this.defibrillatorsCount,
      selected: selected ?? this.selected,
      closest: closest ?? this.closest,
      markers: markers ?? this.markers,
      hash: hash ?? this.hash,
      selectedHash: selectedHash ?? this.selectedHash,
      lastUpdateTime: lastUpdateTime ?? this.lastUpdateTime,
      refreshing: refreshing ?? this.refreshing,
      pendingIds: pendingIds ?? this.pendingIds,
    );
  }
}
