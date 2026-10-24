import 'package:material_ui/material_ui.dart';

enum ModelCategory { general, image, video, audio, coding }
enum ModelTier { free, pro, elite }

class ModelDef {
  final String id;
  final String label;
  final String short;
  final String desc;
  final ModelTier tier;
  final List<ModelCategory> categories;
  final Color providerColor;
  final bool isMedia;

  const ModelDef({
    required this.id,
    required this.label,
    required this.short,
    required this.desc,
    required this.tier,
    required this.categories,
    required this.providerColor,
    this.isMedia = false,
  });
}

class ModelRoster {
  static Color colorForProvider(String hint) {
    final s = hint.toLowerCase();
    if (s.contains('glm') || s.contains('z-ai') || s.contains('z.ai')) {
      return const Color(0xFF60A5FA);
    }
    if (s.contains('nemotron') || s.contains('nvidia')) {
      return const Color(0xFF4ADE80);
    }
    if (s.contains('gemma') || s.contains('gemini') || s.contains('google') || s.contains('veo') || s.contains('lyria')) {
      return const Color(0xFF7FD8C4);
    }
    if (s.contains('muse') || s.contains('llama') || s.contains('meta')) {
      return const Color(0xFFA78BFA);
    }
    if (s.contains('deepseek')) {
      return const Color(0xFF38BDF8);
    }
    if (s.contains('gpt') || s.contains('openai') || s.contains('sora')) {
      return const Color(0xFF10B981);
    }
    if (s.contains('claude') || s.contains('anthropic')) {
      return const Color(0xFFF59E0B);
    }
    if (s.contains('qwen') || s.contains('alibaba')) {
      return const Color(0xFF818CF8);
    }
    if (s.contains('flux') || s.contains('forest')) {
      return const Color(0xFF22D3EE);
    }
    if (s.contains('grok') || s.contains('xai') || s.contains('fal')) {
      return const Color(0xFFF43F5E);
    }
    if (s.contains('seedream') || s.contains('seedance') || s.contains('bytedance')) {
      return const Color(0xFFEC4899);
    }
    if (s.contains('kling')) {
      return const Color(0xFFFB7185);
    }
    if (s.contains('runway')) {
      return const Color(0xFFC084FC);
    }
    if (s.contains('suno')) {
      return const Color(0xFFF472B6);
    }
    if (s.contains('udio')) {
      return const Color(0xFF2DD4BF);
    }
    if (s.contains('eleven')) {
      return const Color(0xFFFBBF24);
    }
    return const Color(0xFF94A3B8);
  }

  static const List<ModelDef> _seed = [
    // General Models (aligned with live server roster + high-tier reasoning)
    ModelDef(
      id: 'z-ai/glm-5.3',
      label: 'GLM 5.3',
      short: 'GLM5',
      desc: 'Z.ai flagship multi-step analytical & general reasoning model.',
      tier: ModelTier.free,
      categories: [ModelCategory.general, ModelCategory.coding],
      providerColor: Color(0xFF60A5FA),
    ),
    ModelDef(
      id: 'nvidia/nemotron-3.5-lightning',
      label: 'Nemotron 3.5 Lightning',
      short: 'N35L',
      desc: 'NVIDIA ultra-low-latency high-precision synthesis engine.',
      tier: ModelTier.free,
      categories: [ModelCategory.general],
      providerColor: Color(0xFF4ADE80),
    ),
    ModelDef(
      id: 'nvidia/nemotron-3-ultra',
      label: 'Nemotron 3 Ultra',
      short: 'N3U',
      desc: 'NVIDIA deep frontier reasoning & high-consensus verifier.',
      tier: ModelTier.free,
      categories: [ModelCategory.general, ModelCategory.coding],
      providerColor: Color(0xFF84CC16),
    ),
    ModelDef(
      id: 'z-ai/glm-5.3-flash',
      label: 'GLM 5.3 Flash',
      short: 'GLM5F',
      desc: 'Z.ai rapid-response general intelligence model.',
      tier: ModelTier.free,
      categories: [ModelCategory.general],
      providerColor: Color(0xFF38BDF8),
    ),
    ModelDef(
      id: 'meta/muse-glimmer-30b',
      label: 'Muse Glimmer 30B',
      short: 'MG30',
      desc: 'Meta expressive 30B dense reasoning & synthesis architecture.',
      tier: ModelTier.free,
      categories: [ModelCategory.general],
      providerColor: Color(0xFFA78BFA),
    ),
    ModelDef(
      id: 'nvidia/nemotron-3-super-120b-a12b',
      label: 'Nemotron 3 Super',
      short: 'N3S',
      desc: 'NVIDIA 120B MoE hybrid reasoning model.',
      tier: ModelTier.free,
      categories: [ModelCategory.general],
      providerColor: Color(0xFF22C55E),
    ),
    ModelDef(
      id: 'google/gemma-4-31b-it',
      label: 'Gemma 4 31B',
      short: 'Gm4',
      desc: 'Google open-weights 31B instruction-tuned reasoning model.',
      tier: ModelTier.free,
      categories: [ModelCategory.general, ModelCategory.coding],
      providerColor: Color(0xFF7FD8C4),
    ),
    ModelDef(
      id: 'openai/gpt-oss-20b',
      label: 'GPT OSS 20B',
      short: 'G20B',
      desc: 'OpenAI open-weights compact general reasoning engine.',
      tier: ModelTier.free,
      categories: [ModelCategory.general, ModelCategory.coding],
      providerColor: Color(0xFF10B981),
    ),
    ModelDef(
      id: 'deepseek-ai/deepseek-v4.1-flash',
      label: 'DeepSeek V4.1 Flash',
      short: 'DS41',
      desc: 'DeepSeek sparse-attention high-throughput reasoning engine.',
      tier: ModelTier.free,
      categories: [ModelCategory.general, ModelCategory.coding],
      providerColor: Color(0xFF0EA5E9),
    ),

    // Generative Media - Image
    ModelDef(
      id: 'Cloudflare:@cf/black-forest-labs/flux-2-dev',
      label: 'FLUX.2 Dev',
      short: 'FLX2',
      desc: 'Black Forest Labs next-gen photorealistic spatial synthesis.',
      tier: ModelTier.free,
      categories: [ModelCategory.image],
      providerColor: Color(0xFF22D3EE),
      isMedia: true,
    ),
    ModelDef(
      id: 'Cloudflare:@cf/black-forest-labs/flux-1-schnell',
      label: 'FLUX.1 Schnell',
      short: 'FLX1',
      desc: 'Black Forest Labs ultra-fast distilled image generator.',
      tier: ModelTier.free,
      categories: [ModelCategory.image],
      providerColor: Color(0xFF06B6D4),
      isMedia: true,
    ),
    ModelDef(
      id: 'fal:xai/grok-imagine-image',
      label: 'Grok Imagine',
      short: 'Grok',
      desc: 'xAI high-contrast cinematic image synthesis studio.',
      tier: ModelTier.pro,
      categories: [ModelCategory.image],
      providerColor: Color(0xFFF43F5E),
      isMedia: true,
    ),
    ModelDef(
      id: 'fal:fal-ai/flux-2-pro',
      label: 'FLUX.2 Pro',
      short: 'FLXP',
      desc: 'Black Forest Labs studio-grade commercial image synthesis.',
      tier: ModelTier.pro,
      categories: [ModelCategory.image],
      providerColor: Color(0xFF38BDF8),
      isMedia: true,
    ),
    ModelDef(
      id: 'fal:fal-ai/bytedance/seedream/v5/lite/text-to-image',
      label: 'Seedream 5.0 Lite',
      short: 'SD5',
      desc: 'ByteDance high-coherence artistic & editorial image engine.',
      tier: ModelTier.pro,
      categories: [ModelCategory.image],
      providerColor: Color(0xFFEC4899),
      isMedia: true,
    ),

    // Generative Media - Video
    ModelDef(
      id: 'video/veo-3-1',
      label: 'Veo 3.1 Cinema',
      short: 'Veo3',
      desc: 'Google DeepMind 4K cinematic temporal video & physics engine.',
      tier: ModelTier.elite,
      categories: [ModelCategory.video],
      providerColor: Color(0xFF7FD8C4),
      isMedia: true,
    ),
    ModelDef(
      id: 'video/seedance-2-0',
      label: 'Seedance 2.0 Pro',
      short: 'SDnc',
      desc: 'ByteDance fluid motion & multi-shot cinema generator.',
      tier: ModelTier.elite,
      categories: [ModelCategory.video],
      providerColor: Color(0xFFEC4899),
      isMedia: true,
    ),
    ModelDef(
      id: 'video/kling-video',
      label: 'Kling 2.0 Master',
      short: 'Kling',
      desc: 'Temporal cinematic text-to-video & camera motion studio.',
      tier: ModelTier.elite,
      categories: [ModelCategory.video],
      providerColor: Color(0xFFF43F5E),
      isMedia: true,
    ),
    ModelDef(
      id: 'video/runway-gen3',
      label: 'Runway Gen-3 Alpha',
      short: 'Rnwy',
      desc: 'High-fidelity cinematic motion video engine.',
      tier: ModelTier.elite,
      categories: [ModelCategory.video],
      providerColor: Color(0xFF8B5CF6),
      isMedia: true,
    ),

    // Generative Media - Audio & Music
    ModelDef(
      id: 'audio/lyria-3-pro',
      label: 'Lyria 3 Pro',
      short: 'Lyria',
      desc: 'Google DeepMind spatial soundtrack & instrumental composer.',
      tier: ModelTier.pro,
      categories: [ModelCategory.audio],
      providerColor: Color(0xFF7FD8C4),
      isMedia: true,
    ),
    ModelDef(
      id: 'audio/suno-v4',
      label: 'Suno v4.5 Studio',
      short: 'Suno',
      desc: 'Full-track studio song, lyrics, and vocal production.',
      tier: ModelTier.pro,
      categories: [ModelCategory.audio],
      providerColor: Color(0xFFEC4899),
      isMedia: true,
    ),
    ModelDef(
      id: 'audio/udio-1-5',
      label: 'Udio 1.5 Pro',
      short: 'Udio',
      desc: 'High-definition instrumental and vocal music generator.',
      tier: ModelTier.pro,
      categories: [ModelCategory.audio],
      providerColor: Color(0xFF14B8A6),
      isMedia: true,
    ),
    ModelDef(
      id: 'audio/elevenlabs-music',
      label: 'ElevenLabs Spatial Audio',
      short: '11Labs',
      desc: 'Ultra-realistic voice synthesis and ambient soundscape studio.',
      tier: ModelTier.pro,
      categories: [ModelCategory.audio],
      providerColor: Color(0xFFF59E0B),
      isMedia: true,
    ),
  ];

  static const Map<String, ModelDef> _legacyModels = {
    'moonshotai/kimi-k3': ModelDef(
      id: 'moonshotai/kimi-k3',
      label: 'Kimi K3',
      short: 'Kimi',
      desc: 'Moonshot AI long-context reasoning model.',
      tier: ModelTier.free,
      categories: [ModelCategory.general],
      providerColor: Color(0xFF38BDF8),
    ),
    'mistralai/mistral-nemotron': ModelDef(
      id: 'mistralai/mistral-nemotron',
      label: 'Mistral Nemotron',
      short: 'MNem',
      desc: 'Mistral & NVIDIA joint instruction model.',
      tier: ModelTier.free,
      categories: [ModelCategory.general],
      providerColor: Color(0xFFF97316),
    ),
  };

  /// Live roster. Starts from the full seed (including General, Image, Video, Audio).
  static List<ModelDef> allModels = List<ModelDef>.from(_seed);

  /// Live text & picture models from the Collider server replace General/Image while preserving Video, Audio & Coding categories.
  static void setLive(List<ModelDef> live) {
    final enrichedLive = [
      for (final m in live)
        if (!m.isMedia &&
            !m.categories.contains(ModelCategory.coding) &&
            RegExp(r'glm|deepseek|qwen|claude|gpt|nemotron|gemma|coder', caseSensitive: false).hasMatch(m.id))
          ModelDef(
            id: m.id,
            label: m.label,
            short: m.short,
            desc: m.desc,
            tier: m.tier,
            categories: [...m.categories, ModelCategory.coding],
            providerColor: m.providerColor,
            isMedia: m.isMedia,
          )
        else
          m,
    ];
    final hasImage = enrichedLive.any((m) => m.categories.contains(ModelCategory.image));
    final hasVideo = enrichedLive.any((m) => m.categories.contains(ModelCategory.video));
    final hasAudio = enrichedLive.any((m) => m.categories.contains(ModelCategory.audio));
    final hasCoding = enrichedLive.any((m) => m.categories.contains(ModelCategory.coding));
    final merged = <ModelDef>[
      ...enrichedLive,
      if (!hasImage) ..._seed.where((m) => m.categories.contains(ModelCategory.image)),
      if (!hasVideo) ..._seed.where((m) => m.categories.contains(ModelCategory.video)),
      if (!hasAudio) ..._seed.where((m) => m.categories.contains(ModelCategory.audio)),
      if (!hasCoding) ..._seed.where((m) => m.categories.contains(ModelCategory.coding)),
    ];
    final seen = <String>{};
    allModels = [
      for (final m in merged)
        if (seen.add(m.id)) m,
    ];
  }

  static List<ModelDef> forCategory(ModelCategory category) {
    return allModels.where((m) => m.categories.contains(category)).toList();
  }

  static ModelDef? byId(String id) {
    for (final m in allModels) {
      if (m.id == id) return m;
    }
    for (final m in _seed) {
      if (m.id == id) return m;
    }
    if (_legacyModels.containsKey(id)) return _legacyModels[id];
    if (id.isEmpty) return null;
    final rawName = id.contains('/') ? id.split('/').last : id;
    final cleanLabel = rawName
        .split(RegExp(r'[-_]'))
        .where((s) => s.isNotEmpty)
        .map((s) => s.length <= 3 ? s.toUpperCase() : '${s[0].toUpperCase()}${s.substring(1)}')
        .join(' ');
    return ModelDef(
      id: id,
      label: cleanLabel,
      short: cleanLabel.split(' ').map((w) => w.isEmpty ? '' : w[0]).take(4).join(),
      desc: id.contains('/') ? id.split('/').first : 'Collider Model',
      tier: ModelTier.free,
      categories: const [ModelCategory.general],
      providerColor: colorForProvider(id),
    );
  }
}
