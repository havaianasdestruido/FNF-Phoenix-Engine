package headers;

// REFACTOR: categorization header re-exporting the states.helpers group
typedef ModState = states.ModState;
typedef ModSubState = states.substates.ModSubState;
typedef FreeplayStateHelpers = states.helpers.FreeplayStateHelpers;
#if MODS_ALLOWED
typedef ModsMenuHelpers = states.helpers.ModsMenuHelpers;
#end
typedef GameplayChangersHelpers = states.helpers.GameplayChangersHelpers;