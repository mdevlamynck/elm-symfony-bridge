module Routing.Transpiler exposing (Command, transpileToElm)

{-| Converts a JSON containing routing from Symfony
and turn it into an elm file.

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


type alias Command =
    { urlPrefix : String
    , content : String
    , version : Version
    }


type alias JsonRouting =
    { path : String
    , requirements : Dict String String
    }


{-| Converts a JSON containing routing to an Elm file
-}
transpileToElm : Command -> Result String String
transpileToElm command =
    command.content
        |> readJsonContent
        |> Result.andThen parseRouting
        |> Result.map (convertToElm command.version command.urlPrefix)


readJsonContent : String -> Result String (Dict String JsonRouting)
readJsonContent content =
    content
        |> decodeString (dict decodeRouting)
        |> Result.mapError errorToString


decodeRouting : Decoder JsonRouting
decodeRouting =
    succeed JsonRouting
        |> required "path" string
        |> required "requirements"
            (oneOf
                [ dict string
                , string |> map (\_ -> Dict.empty)
                ]
            )


parseRouting : Dict String JsonRouting -> Result String (Dict String Routing)
parseRouting routings =
    routings
        |> Dict.toList
        |> List.map
            (\( key, value ) ->
                routingFromJson value
                    |> Result.map (\routing -> ( formatName key, routing ))
            )
        |> Result.combine
        |> Result.map
            (Dict.fromList
                >> Dict.filter (\key value -> not (String.startsWith "_" key))
            )


formatName : String -> String
formatName name =
    name
        |> String.toLower
        |> String.toList
        |> List.map
            (\c ->
                if Char.isLower c || Char.isDigit c then
                    c

                else
                    '_'
            )
        |> String.fromList


routingFromJson : JsonRouting -> Result String Routing
routingFromJson json =
    let
        typeFromRequirement name =
            json.requirements
                |> Dict.get name
                |> Maybe.map
                    (\requirement ->
                        if requirement == "\\d+" then
                            Int

                        else
                            String
                    )

        removeLeadingUnderscore name =
            if String.startsWith "_" name then
                String.dropLeft 1 name

            else
                name
    in
    Parser.parsePathContent json.path
        |> Result.map
            (List.map
                (\chunk ->
                    case chunk of
                        Variable argumentType name ->
                            Variable
                                (typeFromRequirement name |> Maybe.withDefault argumentType)
                                (removeLeadingUnderscore name)

                        other ->
                            other
                )
            )


convertToElm : Version -> String -> Dict String Routing -> String
convertToElm version urlPrefix routing =
    Module "Routing"
        (routing
            |> Dict.toList
            |> List.map (routingToElm urlPrefix)
        )
        |> renderElmModule version


routingToElm : String -> ( String, Routing ) -> Function
routingToElm urlPrefix ( routeName, routing ) =
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
