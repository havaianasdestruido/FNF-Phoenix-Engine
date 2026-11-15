import backend.deeplink.PhoenixURI;
import backend.deeplink.URIKind;

/**
 * Dependency-free parser tests (see `tests/uri/run.sh`, which compiles this
 * against `source/backend/deeplink/*.hx` only, without `source/import.hx`).
 *
 * Two layers are pinned: `parse` must stay the strict v1 menu contract, and
 * `parseEx` must expose exactly the v2 routes the router implements — with the
 * read-only diagnostics route accepted by both spellings and rejected when it
 * carries anything it cannot use, and the input tester route held to the very
 * same rules.
 */
class TestPhoenixURI
{
  static function main()
  {
    for (route in ['main', 'mods', 'options', 'misc', 'audio', 'story', 'freeplay', 'credits'])
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

    // The diagnostics route is a v2 destination: the v1 contract stays
    // menu-only, so the legacy parser must not learn it.
    for (uri in ['phoenix://diagnostics', 'phoenix://screen/diagnostics', 'phoenix://menu/diagnostics'])
      check(uri, null);

    // v2: both spellings of the read-only diagnostics page, case and one
    // trailing slash tolerated exactly like the v1 routes.
    for (uri in ['phoenix://diagnostics', 'phoenix://DIAGNOSTICS', 'phoenix://diagnostics/',
      'phoenix://screen/diagnostics', 'phoenix://SCREEN/Diagnostics/'])
      checkEx(uri, 'Diagnostics');
    // Anything the page cannot use makes the whole link invalid: it has no
    // parameters, no sub-page and no filter, so nothing may be "ignored".
    for (uri in ['phoenix://diagnostics?copy=1', 'phoenix://diagnostics?section=log',
      'phoenix://diagnostics/all', 'phoenix://diagnostics/full/screen',
      'phoenix://diagnostics#copy', 'phoenix://menu/diagnostics', 'phoenix://diagnostic',
      'phoenix://diagnostics..', 'phoenix:///diagnostics', 'phoenix://screen',
      'phoenix://screen/diagnostics/extra', 'phoenix://screen/mods/extra',
      'phoenix://diagnostics\\', 'phoenix:// diagnostics',
      'phoenix://' + [for (_ in 0...300) 'a'].join('') + '/diagnostics'])
      checkEx(uri, null);
    // A malformed link must not clear a pending valid one (queueing is the
    // router's job, but the parser is what decides "valid").
    checkEx('phoenix://diagnostics', 'Diagnostics');

    // The input tester is the second fixed v2 destination, so it gets the same
    // three promises. One: the v1 parser never learns it.
    for (uri in ['phoenix://input', 'phoenix://screen/input', 'phoenix://menu/input'])
      check(uri, null);
    // Two: both spellings land on one kind, with the usual case and slash rules.
    for (uri in ['phoenix://input', 'phoenix://INPUT', 'phoenix://input/',
      'phoenix://screen/input', 'phoenix://SCREEN/Input/'])
      checkEx(uri, 'InputTest');
    // Three: it has no device filter and no sub-page, so a link that asks for
    // one is invalid as a whole instead of opening the page anyway.
    for (uri in ['phoenix://input?device=keyboard', 'phoenix://input?keys', 'phoenix://input/keyboard',
      'phoenix://input/gamepad/1', 'phoenix://input#touch', 'phoenix://menu/input', 'phoenix://inputs',
      'phoenix://input-test', 'phoenix://input..', 'phoenix:///input', 'phoenix://screen/input/extra',
      'phoenix://screen/input?device=touch', 'phoenix://screen/inputs', 'phoenix://input\\',
      'phoenix:// input', 'phoenix://user@input', 'phoenix://input:80',
      'phoenix://' + [for (_ in 0...300) 'a'].join('') + '/input'])
      checkEx(uri, null);
    // The two fixed destinations stay distinct routes.
    checkEx('phoenix://input', 'InputTest');
    checkEx('phoenix://diagnostics', 'Diagnostics');

    // The other v2 hosts keep working next to it.
    checkEx('phoenix://mods', 'Menu(mods)');
    // Options -> Audio is openable by link like Misc (`phoenix://menu/audio`).
    checkEx('phoenix://audio', 'Menu(audio)');
    checkEx('phoenix://menu/audio', 'Menu(audio)');
    checkEx('phoenix://audio/0.5', null);
    checkEx('phoenix://screen/freeplay', 'Screen(freeplay)');
    checkEx('phoenix://song/bopeebo?difficulty=hard', 'Song(bopeebo,hard)');

    Sys.println('URI parser tests passed');
  }

  static function check(uri:String, expected:Null<String>)
  {
    var actual = PhoenixURI.parse(uri);
    if (actual != expected) throw 'For $uri: expected $expected, got $actual';
  }

  static function checkEx(uri:String, expected:Null<String>)
  {
    var actual:String = null;
    var parsed = PhoenixURI.parseEx(uri);
    if (parsed != null) actual = kindName(parsed.kind);
    if (actual != expected) throw 'For $uri: expected $expected, got $actual';
  }

  static function kindName(kind:URIKind):String
  {
    return switch (kind)
    {
      case Menu(route): 'Menu($route)';
      case Screen(route): 'Screen($route)';
      case Song(name, diff): 'Song($name,$diff)';
      case Mod(modId, song): 'Mod($modId,$song)';
      case Diagnostics: 'Diagnostics';
      case InputTest: 'InputTest';
      case Replay(id): 'Replay($id)';
    }
  }
}
