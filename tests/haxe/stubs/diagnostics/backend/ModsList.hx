package backend;

/** Shared shape of the parsed modsList.txt, as in the real engine. */
typedef ModsList =
{
  enabled:Array<String>,
  disabled:Array<String>,
  all:Array<String>
};
