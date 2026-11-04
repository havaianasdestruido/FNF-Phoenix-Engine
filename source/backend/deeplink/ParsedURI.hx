package backend.deeplink;

/**
 * Result of `PhoenixURI.parseEx`.
 */
typedef ParsedURI =
{
	var kind:URIKind;
	var query:Map<String, String>;
}
