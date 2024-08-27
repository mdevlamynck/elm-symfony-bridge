module Routing.Data exposing (Routing, Path(..), ArgumentType(..))

{-| Routing data extracted from symfony's routing.

@docs Routing, Path, ArgumentType

-}


{-| A single route.
-}
type alias Routing =
    List Path


{-| Represents a chunk in a route.

Either a constant string or a variable.

-}
type Path
    = Constant String
    | Variable ArgumentType String


{-| Supported types of `Path` variables.
-}
type ArgumentType
    = Int
    | String
