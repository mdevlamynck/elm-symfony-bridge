module Routing.Transpiler exposing (Command, transpileToElm)

{-| Converts a JSON containing routing from Symfony
and turn it into an elm file.

@docs Command, transpileToElm

-}

import Char
import Dict exposing (Dict)
import Elm exposing (..)
import Json.Decode exposing (Decoder, decodeString, string, dict, oneOf, map)
import Json.Decode.Pipeline exposing (decode, required)
import Unindent


type alias Command =
    { urlPrefix : String
    , content : String
    }


type alias JsonRouting =
    { path : String
    , method : String
    , defaults : Dict String String
    , requirements : Dict String String
    }


type alias Routing =
    { path : String
    , method : String
    , defaults : Dict String String
    , requirements : Dict String String
    }


{-| Converts a JSON containing routing to an Elm file
-}
transpileToElm : Command -> Result String String
transpileToElm command =
    command.content
        |> readJsonContent
        |> Result.andThen parseRouting
        |> Result.map (convertToElm command.urlPrefix)


readJsonContent : String -> Result String (Dict String JsonRouting)
readJsonContent content =
    content
        |> decodeString (dict decodeRouting)


decodeRouting : Decoder Routing
decodeRouting =
    decode Routing
        |> required "path" string
        |> required "method" string
        |> required "defaults" (dict string)
        |> required "requirements"
            (oneOf
                [ dict string
                , string |> map (\_ -> Dict.empty)
                ]
            )


parseRouting : Dict String JsonRouting -> Result String (Dict String Routing)
parseRouting routing =
    routing
        |> Dict.filter (\key value -> isValidRouteName key)
        |> Ok


isValidRouteName : String -> Bool
isValidRouteName name =
    let
        nameDoesntStartWithUnderscore =
            not (String.startsWith "_" name)

        validChar c =
            Char.isLower c || Char.isUpper c || c == '_'

        nameContainsOnlyValidChars =
            name
                |> String.toList
                |> List.all validChar
    in
        nameDoesntStartWithUnderscore && nameContainsOnlyValidChars


convertToElm : String -> Dict String Routing -> String
convertToElm urlPrefix routing =
    Module "Routing"
        (routing
            |> Dict.toList
            |> List.map (routingToElm urlPrefix)
        )
        |> renderElmModule


routingToElm : String -> ( String, Routing ) -> Function
routingToElm urlPrefix ( routeName, routing ) =
    Function routeName [] "String" (Expr ("\"" ++ urlPrefix ++ routing.path ++ "\""))
