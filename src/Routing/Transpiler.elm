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
import Result.Extra as Result
import Routing.Data exposing (Routing, Method(..), Path(..), ArgumentType(..))
import Routing.Parser as Parser


type alias Command =
    { urlPrefix : String
    , content : String
    }


type alias JsonRouting =
    { path : String
    , method : String
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


decodeRouting : Decoder JsonRouting
decodeRouting =
    decode JsonRouting
        |> required "path" string
        |> required "method" string
        |> required "requirements"
            (oneOf
                [ dict string
                , string |> map (\_ -> Dict.empty)
                ]
            )


parseRouting : Dict String JsonRouting -> Result String (Dict String Routing)
parseRouting routing =
    routing
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

        formatName name =
            if String.startsWith "_" name then
                String.dropLeft 1 name
            else
                name

        path =
            Parser.parsePathContent json.path
                |> Result.map
                    (List.map
                        (\chunk ->
                            case chunk of
                                Variable name argumentType ->
                                    Variable
                                        (formatName name)
                                        (typeFromRequirement name
                                            |> Maybe.withDefault argumentType
                                        )

                                other ->
                                    other
                        )
                    )

        method =
            case String.toUpper json.method of
                "ANY" ->
                    Ok Any

                "HEAD" ->
                    Ok Head

                "GET" ->
                    Ok Get

                "POST" ->
                    Ok Post

                "PUT" ->
                    Ok Put

                "DELETE" ->
                    Ok Delete

                method ->
                    Err ("Unknown method: " ++ method)
    in
        Result.map2
            (\path method ->
                { path = path
                , method = method
                }
            )
            path
            method


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
    let
        record =
            routing.path
                |> List.filterMap
                    (\chunk ->
                        case chunk of
                            Variable name Int ->
                                Just ( "Int", name )

                            Variable name String ->
                                Just ( "String", name )

                            _ ->
                                Nothing
                    )

        arguments =
            case record of
                [] ->
                    []

                record ->
                    [ Record record ]

        url =
            (Constant urlPrefix :: routing.path)
                |> List.map
                    (\chunk ->
                        case chunk of
                            Constant path ->
                                "\"" ++ path ++ "\""

                            Variable name Int ->
                                "(toString " ++ name ++ ")"

                            Variable name String ->
                                name
                    )
                |> String.join " ++ "
    in
        Function routeName arguments "String" (Expr url)
