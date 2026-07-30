import 'package:get_it/get_it.dart';
import '../repositories/auth_repository.dart';
import '../repositories/ride_repository.dart';
import '../repositories/notification_repository.dart';
import '../repositories/route_repository.dart';
import '../services/location_service.dart';
import '../services/driver_location_service.dart';
import '../services/app_notification_service.dart';
import '../services/notification_service.dart';
import '../services/route_provider.dart';
import '../services/route_service.dart';
import '../services/trip_navigation_manager.dart';
import '../services/tts_service.dart';
import '../services/ride_sound_service.dart';
import '../controllers/notification_controller.dart';
import '../controllers/navigation_controller.dart';
import '../controllers/navigation_state_manager.dart';
import '../controllers/snap_to_route_controller.dart';
import '../controllers/route_tracking_controller.dart';
import '../controllers/route_controller.dart';
import '../controllers/route_recalculation_controller.dart';
import '../controllers/location_controller.dart';
import '../controllers/map_controller.dart';
import '../../features/auth/presentation/cubit/auth_cubit.dart';
import '../../features/ride_matching/presentation/cubit/ride_matching_cubit.dart';
import '../../features/active_trip/presentation/cubit/active_trip_cubit.dart';
import '../../features/chat/presentation/cubit/chat_cubit.dart';
import '../../features/wallet/presentation/cubit/wallet_cubit.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/domain/usecases/chat_usecases.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Services
  sl.registerLazySingleton<LocationService>(() => LocationService.instance);
  sl.registerLazySingleton<DriverLocationService>(() => DriverLocationService.instance);
  sl.registerLazySingleton<AppNotificationService>(() => AppNotificationService.instance);
  sl.registerLazySingleton<NotificationService>(() => NotificationService.instance);

  // Navigation Services (low-level)
  sl.registerLazySingleton<RouteProvider>(() => OSRMRouteProvider());
  sl.registerLazySingleton<RouteRepository>(() => RouteRepository(provider: sl()));
  sl.registerLazySingleton<RouteService>(() => RouteService(repository: sl()));
  sl.registerLazySingleton<TtsService>(() => TtsService());
  sl.registerLazySingleton<RideSoundService>(() => RideSoundService());

  // Navigation State Manager (central state — registered first)
  sl.registerLazySingleton<NavigationStateManager>(() => NavigationStateManager());

  // Navigation Controllers (each with explicit dependencies)
  sl.registerLazySingleton<SnapToRouteController>(
    () => SnapToRouteController(stateManager: sl()),
  );
  sl.registerLazySingleton<RouteTrackingController>(
    () => RouteTrackingController(stateManager: sl()),
  );
  sl.registerLazySingleton<RouteController>(
    () => RouteController(
      routeService: sl(),
      routeRepository: sl(),
      stateManager: sl(),
    ),
  );
  sl.registerLazySingleton<LocationController>(
    () => LocationController(
      locationService: sl(),
      stateManager: sl(),
    ),
  );
  sl.registerLazySingleton<RouteRecalculationController>(
    () => RouteRecalculationController(
      stateManager: sl(),
      snapController: sl(),
      routeController: sl(),
    ),
  );

  // Navigation Controller (orchestrator — depends on sub-controllers)
  sl.registerLazySingleton<NavigationController>(
    () => NavigationController(
      stateManager: sl(),
      snapController: sl(),
      trackingController: sl(),
      ttsService: sl(),
    ),
  );

  // Map Controller
  sl.registerLazySingleton<MapController>(() => MapController());

  // Trip Navigation Manager (high-level coordinator)
  sl.registerLazySingleton<TripNavigationManager>(
    () => TripNavigationManager(
      navigationController: sl(),
      stateManager: sl(),
      routeController: sl(),
      locationController: sl(),
      reRouteController: sl(),
      locationService: sl(),
    ),
  );

  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => AuthRepository.instance);
  sl.registerLazySingleton<RideRepository>(() => RideRepository.instance);
  sl.registerLazySingleton<NotificationRepository>(() => NotificationRepository.instance);

  // Controllers / State
  sl.registerLazySingleton<NotificationController>(() => NotificationController());

  // Cubits (Factories)
  sl.registerFactory<AuthCubit>(() => AuthCubit(sl()));
  sl.registerFactory<RideMatchingCubit>(() => RideMatchingCubit(sl()));
  sl.registerFactory<ActiveTripCubit>(() => ActiveTripCubit(sl()));
  // Chat Feature Injection
  sl.registerLazySingleton<ChatRepository>(() => ChatRepositoryImpl(Supabase.instance.client));
  sl.registerLazySingleton<GetChatRooms>(() => GetChatRooms(sl()));
  sl.registerLazySingleton<GetMessagesStream>(() => GetMessagesStream(sl()));
  sl.registerLazySingleton<GetOrCreateSupportRoom>(() => GetOrCreateSupportRoom(sl()));
  sl.registerLazySingleton<SendChatMessage>(() => SendChatMessage(sl()));
  sl.registerLazySingleton<SendChatAttachment>(() => SendChatAttachment(sl()));
  sl.registerLazySingleton<MarkMessagesAsRead>(() => MarkMessagesAsRead(sl()));
  sl.registerLazySingleton<UpdateTypingStatus>(() => UpdateTypingStatus(sl()));
  sl.registerLazySingleton<GetTypingIndicator>(() => GetTypingIndicator(sl()));
  sl.registerLazySingleton<DeleteChatMessage>(() => DeleteChatMessage(sl()));

  sl.registerFactory<ChatCubit>(
    () => ChatCubit(
      getMessagesStream: sl(),
      sendChatMessage: sl(),
      sendChatAttachment: sl(),
      markMessagesAsRead: sl(),
      updateTypingStatus: sl(),
      getTypingIndicator: sl(),
    ),
  );
  sl.registerFactory<WalletCubit>(() => WalletCubit());
}
