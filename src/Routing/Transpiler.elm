module Routing.Transpiler exposing (Command, transpileToElm)

{-| Converts a JSON containing routing from Symfony and turn it into an elm file.

@docs Command, transpileToElm

-}

import Char
import Dict exposing (Dict)
import Elm exposing (..)
import Json.Decode exposing (Decoder, decodeString, dict, errorToString, map, oneOf, string, succeed)
import Json.Decode.Pipeline exposing (required)
import Result.Extra as Result
import Routing.Data exposing (ArgumentType(..), Path(..), Routing)
import Routing.Parser as Parser


{-| Parameters to the transpile command.
-}
type alias Command =
    { urlPrefix : String
    , content : String
    , version : Version
    }


{-| Converts a JSON containing routing to an Elm file.
-}
transpileToElm : Command -> Result String String
transpileToElm command =
    command.content
        |> readJsonContent
        |> Result.andThen parseRouting
        |> Result.map (convertToElm command.version command.urlPrefix)


{-| Represents the content of a JSON routing.
-}
type alias JsonRouting =
    { path : String
    , requirements : Dict String String
    }


{-| Extracts from the given JSON the routing information.
-}
readJsonContent : String -> Result String (Dict String JsonRouting)
readJsonContent content =
    content
        |> decodeString (dict decodeRouting)
        |> Result.mapError errorToString


{-| Parses one route.
-}
decodeRouting : Decoder JsonRouting
decodeRouting =
    succeed JsonRouting
        |> required "path" string
        |> required "requirements"
            (oneOf
                [ dict string
                , -- empty routing is allowed
                  succeed Dict.empty
                ]
            )


{-| Turns the raw extracted data into our internal representation.
-}
parseRouting : Dict String JsonRouting -> Result String (Dict String Routing)
parseRouting routings =
    routings
        |> Dict.toList
        |> List.map
            (\( key, value ) ->
                routingFromJson value
                    |> Result.map (\routing -> ( normalizeFunctionName key, routing ))
            )
        |> Result.combine
        |> Result.map Dict.fromList


{-| Turns one json route into our internal representation.
-}
routingFromJson : JsonRouting -> Result String Routing
routingFromJson json =
    Parser.parseRoutingContent json.path
        |> (Result.map << List.map)
            (\chunk ->
                case chunk of
                    Variable argumentType name ->
                        Variable
                            (typeFromRequirement json name |> Maybe.withDefault argumentType)
                            (removeLeadingUnderscore name)

                    other ->
                        other
            )


{-| Returns the correct variable type based on the requirement.

Currently only `'\d+'` is recognized and considered as a `Int`.

-}
typeFromRequirement : JsonRouting -> String -> Maybe ArgumentType
typeFromRequirement json name =
    json.requirements
        |> Dict.get name
        |> Maybe.map
            (\requirement ->
                if requirement == "\\d+" then
                    Int

                else
                    String
            )


{-| Removes one `_` character from the beginning of the String if any.
-}
removeLeadingUnderscore : String -> String
removeLeadingUnderscore name =
    if String.startsWith "_" name then
        String.dropLeft 1 name

    else
        name


{-| Turns the routing information into an elm module.
-}
convertToElm : Version -> String -> Dict String Routing -> String
convertToElm version urlPrefix routing =
    Module "Routing"
        (routing
            |> Dict.toList
            |> List.map (routeToElmFunction urlPrefix)
        )
        |> renderElmModule version


{-| Turns one route into an elm function.
-}
routeToElmFunction : String -> ( String, Routing ) -> Function
routeToElmFunction urlPrefix ( routeName, routing ) =
    let
        record =
            routing
                |> List.filterMap
                    (\chunk ->
                        case chunk of
                            Variable Int name ->
                                Just ( "Int", name )

                            Variable String name ->
                                Just ( "String", name )

                            _ ->
                                Nothing
                    )

        arguments =
            case record of
                [] ->
                    []

                record_ ->
                    [ Record record_ ]

        url =
            (Constant urlPrefix :: routing)
                |> List.map
                    (\chunk ->
                        case chunk of
                            Constant path ->
                                "\"" ++ path ++ "\""

                            Variable Int name ->
                                "(fromInt params_." ++ name ++ ")"

                            Variable String name ->
                                "params_." ++ name
                    )
                |> String.join " ++ "
    in
    Function routeName arguments "String" (Expr url)
