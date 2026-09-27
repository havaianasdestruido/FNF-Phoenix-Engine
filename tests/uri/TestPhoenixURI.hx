import backend.deeplink.PhoenixURI;

class TestPhoenixURI
{
  static function main()
  {
    for (route in ['main', 'mods', 'options', 'misc', 'story', 'freeplay', 'credits'])
      for (uri in ['phoenix://' + route, 'phoenix://menu/' + route,
        'PHOENIX://MENU/' + route.toUpperCase() + '/'])
        check(uri, route);
    check('phoenix://menu', 'main');
    check('phoenix://menu/', 'main');
    for (uri in [null, '', 'https://menu/misc', 'phoenix://', 'phoenix:///mods',
      'phoenix://menu//misc', 'phoenix://menu/misc/extra', 'phoenix://mods/foo',
      'phoenix://menu/%6disc', 'phoenix://menu/../mods', 'phoenix://mods?x=1',
      'phoenix://mods#x', 'phoenix://user@mods', 'phoenix://mods:80',
      ' phoenix://mods', 'phoenix://mods\n', 'phoenix://mods\\',
      'phoenix://song/test', 'phoenix://menu/unknown', 'phoenix://mods" --run'])
      check(uri, null);
    check('phoenix://' + [for (_ in 0...300) 'a'].join(''), null);
    Sys.println('URI parser tests passed');
  }

  static function check(uri:String, expected:Null<String>)
  {
    var actual = PhoenixURI.parse(uri);
    if (actual != expected) throw 'For $uri: expected $expected, got $actual';
  }
}
