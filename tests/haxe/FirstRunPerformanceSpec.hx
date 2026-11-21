import backend.FirstRunPerformance;

class FirstRunPerformanceSpec
{
  static function check(value:Bool, message:String):Void
  {
    if (!value) throw message;
  }

  static function main():Void
  {
    final low = FirstRunPerformance.choose(2.0 * 1024 * 1024 * 1024, 8, 'Adreno 610', 'Mid-range mobile GPU', true);
    check(low.name == 'Performance' && low.framerate == 45 && low.lowQuality && !low.shaders,
      'low RAM selects a reduced-quality 45 FPS setup');
    check(low.dynamicSpawnTime && low.enableGC && low.noRenderGC && low.maxSplashLimit == 4 && !low.cacheOnGPU,
      'performance preset includes spawn, GC, splash and safe cache choices');

    final balanced = FirstRunPerformance.choose(6.0 * 1024 * 1024 * 1024, 8, 'Adreno 660', 'Mid-range mobile GPU', true);
    check(balanced.name == 'Balanced' && balanced.framerate == 60 && !balanced.lowQuality,
      'capable phone uses balanced settings rather than desktop defaults');
    final entryPhone = FirstRunPerformance.choose(4.0 * 1024 * 1024 * 1024, 4, 'Adreno 610', 'Mid-range mobile GPU', true);
    check(entryPhone.name == 'Performance' && entryPhone.lowQuality && !entryPhone.shaders,
      'entry phone hardware receives meaningful quality and effects reductions');

    final integrated = FirstRunPerformance.choose(8.0 * 1024 * 1024 * 1024, 8, 'Intel UHD Graphics', 'Integrated GPU detected', false);
    check(integrated.name == 'Balanced' && integrated.shaders,
      'GPU guidance selects a moderate setup for integrated graphics');

    final high = FirstRunPerformance.choose(16.0 * 1024 * 1024 * 1024, 12, 'NVIDIA GeForce RTX 4070', 'High-end GPU detected', false);
    check(high.name == 'High quality' && high.framerate == 120 && high.maxSplashLimit == 24,
      'strong desktop gets the higher-quality preset');
    check(!high.cacheOnGPU && high.dynamicSpawnTime && high.enableGC && !high.noRenderGC,
      'every preset uses known-safe GPU caching and GC settings');

    final unknown = FirstRunPerformance.choose(0, 0, 'Unknown', 'Unknown GPU', false);
    check(unknown.name == 'Balanced' && unknown.framerate == 60,
      'unavailable hardware data falls back to balanced');
    trace('FirstRunPerformanceSpec passed');
  }
}
