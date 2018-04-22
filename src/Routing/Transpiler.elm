module Routing.Transpiler exposing (transpileToElm)

{-| Converts a JSON containing routing from Symfony
and turn it into an elm file.

@docs transpileToElm

-}

import Elm exposing (..)
import Json.Decode as Decode exposing (decodeString, oneOf, list, dict, string)


{-| Converts a JSON containing routing to an Elm file
-}
transpileToElm : String -> Result String String
transpileToElm =
    Ok
