import '../core/media/theme_cloud.dart';

class AmbientTrack {
  final int number;
  final String title;
  final String duration;
  final String mood;

  /// The recording itself, for songs that come from the Cloudflare bucket.
  final String? audioUrl;

  const AmbientTrack({
    required this.number,
    required this.title,
    required this.duration,
    this.mood = 'Ambient',
    this.audioUrl,
  });
}

class WallpaperTheme {
  final String id;
  final String name;
  final String assetPath;
  /// Optional looping live wallpaper (mp4 under assets/themes/premium/live/<slug>/).
  final String? videoPath;
  final bool isPremium;
  final String creator;
  final String tier;
  final String collection;
  final List<AmbientTrack> tracks;
  final String? productId;
  final String? priceLabel;

  const WallpaperTheme({
    required this.id,
    required this.name,
    required this.assetPath,
    this.videoPath,
    this.isPremium = false,
    this.creator = 'Studio Nebula',
    this.tier = 'Standard Spatial',
    this.collection = 'Spatial Ambient Series',
    this.productId,
    this.priceLabel,
    this.tracks = const [
      AmbientTrack(number: 1, title: 'Solar Winds Drift', duration: '3:42', mood: 'Calm'),
      AmbientTrack(number: 2, title: 'Ionosphere Resonance', duration: '4:15', mood: 'Deep Focus'),
      AmbientTrack(number: 3, title: 'Celestial Tide', duration: '3:10', mood: 'Atmospheric'),
      AmbientTrack(number: 4, title: 'Orbital Silence', duration: '5:04', mood: 'Meditation'),
      AmbientTrack(number: 5, title: 'Stellar Horizon', duration: '2:58', mood: 'Euphoric'),
    ],
  });
}

class WallpaperCatalog {
  static const List<WallpaperTheme> freeThemes = [
    WallpaperTheme(
      id: 'visionos_living_room',
      name: 'VisionOS Spatial Room',
      assetPath: 'assets/themes/free/visionos_living_room.png',
      creator: 'Apple Design Lab',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Spatial Living Room', duration: '3:20', mood: 'Domestic Calm'),
        AmbientTrack(number: 2, title: 'Window Reflection', duration: '4:02', mood: 'Acoustic Glass'),
        AmbientTrack(number: 3, title: 'Morning Light Inflow', duration: '3:45', mood: 'Airy'),
        AmbientTrack(number: 4, title: 'Quiet Architecture', duration: '4:30', mood: 'Warm Minimal'),
        AmbientTrack(number: 5, title: 'Evening Dusk Shadow', duration: '3:12', mood: 'Gentle'),
      ],
    ),
    WallpaperTheme(
      id: 'starbridge',
      name: 'Star Bridge',
      assetPath: 'assets/themes/free/starbridge.jpg',
      creator: 'Studio Nebula',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Bridge Over Constellations', duration: '4:12', mood: 'Cosmic'),
        AmbientTrack(number: 2, title: 'Gravity Well Echo', duration: '3:38', mood: 'Deep Space'),
        AmbientTrack(number: 3, title: 'Photon Stream', duration: '4:50', mood: 'Flow'),
        AmbientTrack(number: 4, title: 'Starlight Traverse', duration: '3:15', mood: 'Calm'),
        AmbientTrack(number: 5, title: 'Pulsar Beacons', duration: '5:02', mood: 'Hypnotic'),
      ],
    ),
    WallpaperTheme(
      id: 'sanctuary_free',
      name: 'Sanctuary Still',
      assetPath: 'assets/themes/free/sanctuary.jpg',
      creator: 'Aethelgard Audio',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Temple of Stillness', duration: '3:50', mood: 'Serene'),
        AmbientTrack(number: 2, title: 'Candlelight Chant', duration: '4:22', mood: 'Choral'),
        AmbientTrack(number: 3, title: 'Stone Vault Resonance', duration: '3:40', mood: 'Deep Focus'),
        AmbientTrack(number: 4, title: 'Incense Smoke', duration: '4:05', mood: 'Dream'),
        AmbientTrack(number: 5, title: 'Dawn Bell', duration: '2:45', mood: 'Peaceful'),
      ],
    ),
    WallpaperTheme(
      id: 'observatory_free',
      name: 'Observatory',
      assetPath: 'assets/themes/free/observatory.jpg',
      creator: 'Kepler Dynamics',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Dome Rotation', duration: '4:10', mood: 'Mechanical Calm'),
        AmbientTrack(number: 2, title: 'Spectroscopic Drift', duration: '3:35', mood: 'Scientific'),
        AmbientTrack(number: 3, title: 'Deep Sky Survey', duration: '5:12', mood: 'Vast'),
        AmbientTrack(number: 4, title: 'Atmospheric Lens', duration: '3:58', mood: 'Refractive'),
        AmbientTrack(number: 5, title: 'Midnight Zenith', duration: '4:20', mood: 'Solitude'),
      ],
    ),
    WallpaperTheme(
      id: 'ocean_free',
      name: 'Deep Ocean Still',
      assetPath: 'assets/themes/free/ocean.jpg',
      creator: 'Abyssal Sound',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Bioluminescent Trench', duration: '4:40', mood: 'Aquatic'),
        AmbientTrack(number: 2, title: 'Currents Below 1000m', duration: '5:15', mood: 'Submerged'),
        AmbientTrack(number: 3, title: 'Whale Call Distance', duration: '3:30', mood: 'Echoing'),
        AmbientTrack(number: 4, title: 'Thermal Vent Pulse', duration: '4:02', mood: 'Low Frequency'),
        AmbientTrack(number: 5, title: 'Surface Light Filter', duration: '3:48', mood: 'Drift'),
      ],
    ),
    WallpaperTheme(
      id: 'garden',
      name: 'Ethereal Garden',
      assetPath: 'assets/themes/free/garden.jpg',
      creator: 'Flora Sonics',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Morning Dew Drops', duration: '3:15', mood: 'Organic'),
        AmbientTrack(number: 2, title: 'Canopy Breeze', duration: '4:08', mood: 'Whispering'),
        AmbientTrack(number: 3, title: 'Spore Bloom Drift', duration: '3:52', mood: 'Lush'),
        AmbientTrack(number: 4, title: 'Moss Floor Reverberation', duration: '4:35', mood: 'Earthy'),
        AmbientTrack(number: 5, title: 'Twilight Pollen', duration: '3:04', mood: 'Delicate'),
      ],
    ),
    WallpaperTheme(
      id: 'neoncity_free',
      name: 'Neon City Still',
      assetPath: 'assets/themes/free/neoncity.jpg',
      creator: 'Synthwave Matrix',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Rain on Hologram', duration: '3:45', mood: 'Cybernetic'),
        AmbientTrack(number: 2, title: 'Skyline Overpass Hum', duration: '4:20', mood: 'Futuristic'),
        AmbientTrack(number: 3, title: 'Alley Neon Flicker', duration: '3:18', mood: 'Moody'),
        AmbientTrack(number: 4, title: 'Autonomous Air Taxi', duration: '4:05', mood: 'Smooth'),
        AmbientTrack(number: 5, title: 'Rooftop Dawn Synth', duration: '3:50', mood: 'Nostalgic'),
      ],
    ),
    WallpaperTheme(
      id: 'rainfall',
      name: 'Night Rainfall',
      assetPath: 'assets/themes/free/rainfall.jpg',
      creator: 'Hydrophonic Labs',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Windowpane Droplets', duration: '5:00', mood: 'Sleep / Focus'),
        AmbientTrack(number: 2, title: 'Distant Thunder Peal', duration: '4:15', mood: 'Rolling Low'),
        AmbientTrack(number: 3, title: 'Asphalt Puddle Ripples', duration: '3:40', mood: 'Steady'),
        AmbientTrack(number: 4, title: 'Roof Gutter Stream', duration: '4:30', mood: 'Trickling'),
        AmbientTrack(number: 5, title: 'Storm Passing North', duration: '3:25', mood: 'Peace'),
      ],
    ),
    WallpaperTheme(
      id: 'transit',
      name: 'Hyper Transit',
      assetPath: 'assets/themes/free/transit.jpg',
      creator: 'MagLev Acoustics',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Magnetic Levitation Hum', duration: '3:55', mood: 'Gliding'),
        AmbientTrack(number: 2, title: 'Tunnel Light Streaks', duration: '4:12', mood: 'Velocity'),
        AmbientTrack(number: 3, title: 'Station Terminal Chime', duration: '3:30', mood: 'Modern'),
        AmbientTrack(number: 4, title: 'Sub-Orbital Descent', duration: '4:45', mood: 'Weightless'),
        AmbientTrack(number: 5, title: 'Concourse Solitude', duration: '3:18', mood: 'Spacious'),
      ],
    ),
    WallpaperTheme(
      id: 'dunehall',
      name: 'Dune Hall',
      assetPath: 'assets/themes/free/dunehall.jpg',
      creator: 'Arrakis Wind Collective',
      tier: 'Free Spatial Canvas',
      tracks: [
        AmbientTrack(number: 1, title: 'Desert Wind Sieve', duration: '4:30', mood: 'Arid Meditation'),
        AmbientTrack(number: 2, title: 'Stone Arch Shade', duration: '3:50', mood: 'Echoing'),
        AmbientTrack(number: 3, title: 'Sand Grain Shimmer', duration: '4:15', mood: 'Granular'),
        AmbientTrack(number: 4, title: 'Oasis Night Air', duration: '3:40', mood: 'Cooling'),
        AmbientTrack(number: 5, title: 'Caravan Mirage', duration: '5:10', mood: 'Mystic'),
      ],
    ),
  ];

  /// The live wallpapers: David's Cloudflare bucket "collider-themes" (ThemeCloud). Nothing is built into the app;
  /// the last list read is kept on the device so the market opens at once.
  static List<WallpaperTheme> get premiumThemes => ThemeCloud.instance.themes;



  static WallpaperTheme defaultTheme = freeThemes[1];
}
