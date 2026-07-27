import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class RideSoundService {
  // Sound players
  final AudioPlayer _incomingRidePlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();

  bool _isIncomingPlaying = false;

  RideSoundService() {
    _initPlayers();
  }

  void _initPlayers() {
    // Configure players for low latency and optimal release modes if needed
    _incomingRidePlayer.setReleaseMode(ReleaseMode.loop);
    _effectPlayer.setReleaseMode(ReleaseMode.release);
  }

  /// Plays the incoming ride loop sound.
  /// This sound will loop continuously until stopped.
  Future<void> playIncomingRide() async {
    if (_isIncomingPlaying) {
      debugPrint('[RideSoundService] Incoming ride sound is already playing.');
      return;
    }

    _isIncomingPlaying = true;
    try {
      debugPrint('[RideSoundService] Playing incoming ride sound loop.');
      // Stop any other active players on this channel just in case
      await _incomingRidePlayer.stop();
      await _incomingRidePlayer.play(AssetSource('sounds/incoming_ride.mp3'), volume: 1.0);
    } catch (e) {
      debugPrint('[RideSoundService] Error playing incoming ride sound: $e');
      _isIncomingPlaying = false;
    }
  }

  /// Stops the incoming ride loop sound.
  Future<void> stopIncomingRide() async {
    if (!_isIncomingPlaying) return;
    
    _isIncomingPlaying = false;
    try {
      debugPrint('[RideSoundService] Stopping incoming ride sound.');
      await _incomingRidePlayer.stop();
    } catch (e) {
      debugPrint('[RideSoundService] Error stopping incoming ride sound: $e');
    }
  }

  /// Plays a short, modern UI notification sound.
  Future<void> playNotification() async {
    await _playEffect('sounds/notification.mp3');
  }

  /// Plays a success chime (e.g., when a ride is accepted).
  Future<void> playSuccess() async {
    await _playEffect('sounds/success.mp3');
  }

  /// Plays an error/cancel buzzer (e.g., when a ride is cancelled).
  Future<void> playCancel() async {
    await _playEffect('sounds/cancel.mp3');
  }

  /// Plays a trip completed bell (e.g., when the trip ends).
  Future<void> playTripCompleted() async {
    await _playEffect('sounds/trip_completed.mp3');
  }

  /// Helper method to play sound effects on the effects player, stopping any active effect first.
  Future<void> _playEffect(String assetPath) async {
    try {
      debugPrint('[RideSoundService] Playing effect: $assetPath');
      await _effectPlayer.stop();
      await _effectPlayer.play(AssetSource(assetPath), volume: 1.0);
    } catch (e) {
      debugPrint('[RideSoundService] Error playing effect $assetPath: $e');
    }
  }

  /// Dispose the players when the service is destroyed to prevent memory leaks.
  void dispose() {
    _incomingRidePlayer.dispose();
    _effectPlayer.dispose();
    debugPrint('[RideSoundService] Disposed sound players.');
  }
}
