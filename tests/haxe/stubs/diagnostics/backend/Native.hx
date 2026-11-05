package backend;

typedef HardwareInfo =
{
  var gpuVendor:String;
  var gpuModel:String;
  var gpuDriver:String;
  var cpuVendor:String;
  var cpuModel:String;
  var osName:String;
  var osVersion:String;
  var graphicsApi:String;
  var audioApi:String;
}

/** Same shape as the real GPU/CPU/OS detection the crash log uses. */
class Native
{
  public static var info:HardwareInfo = {
    gpuVendor: 'NVIDIA',
    gpuModel: 'NVIDIA GeForce RTX 3060',
    gpuDriver: '535.104.05',
    cpuVendor: 'Intel',
    cpuModel: 'Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz',
    osName: 'Windows',
    osVersion: '10.0.19045',
    graphicsApi: 'OpenGL 4.6',
    audioApi: 'OpenAL Soft | 1.23.1'
  };

  public static function getSystemInfo():HardwareInfo
    return info;
}
