module Routing.Transpiler exposing (Command, transpileToElm)

{-| Converts a JSON containing routing from Symfony
and turn it into an elm file.

@docs Command, transpileToElm

-}

import Elm exposing (..)
import Unindent


type alias Command =
    { urlPrefix : String
    , content : String
    }


{-| Converts a JSON containing routing to an Elm file
-}
transpileToElm : Command -> Result String String
transpileToElm command =
    Module "Routing"
        [ Function "prefix" [] "String" (Expr command.urlPrefix)
        ]
        |> renderElmModule
        |> Ok
