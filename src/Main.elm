port module Main exposing (Msg(..), decodeJsValue, main, update)

{-| Entry point, receive commands from js, dispatch to elm function and return result to js

@docs main, Msg, update, decodeJsValue

-}

import Dict
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Platform exposing (Program, program)
import Platform.Cmd exposing (Cmd)
import Platform.Sub exposing (Sub)
import Result.Extra as Result
import Routing.Transpiler as Routing
import Translation.Transpiler as Translation exposing (File)


{-| Entry point
-}
main : Program Never () Msg
main =
    program
        { init = ( (), Cmd.none )
        , update =
            \msg _ ->
                msg
                    |> update
                    |> Maybe.map sendToJs
                    |> Maybe.withDefault Cmd.none
                    |> (\cmd -> ( (), cmd ))
        , subscriptions = always <| sendToElm decodeJsValue
        }


{-| Allows receiving json values from js
-}
port sendToElm : (Value -> msg) -> Sub msg


{-| Allows sending json values to js
-}
port sendToJs : Value -> Cmd msg


{-| Handled commands
-}
type Msg
    = NoOp
    | TranspileRouting Routing.Command
    | TranspileTranslation File


{-| Run received commands
-}
update : Msg -> Maybe Value
update message =
    case message of
        NoOp ->
            Nothing

        TranspileRouting routing ->
            routing
                |> Routing.transpileToElm
                |> formatResult "Routing"
                |> encodeRoutingResult
                |> Just

        TranspileTranslation translation ->
            translation.content
                |> Translation.transpileToElm
                |> formatResult translation.name
                |> encodeTranslationResult
                |> Just


{-| Decode json commands
-}
decodeJsValue : Value -> Msg
decodeJsValue =
    Decode.decodeValue (Decode.dict (Decode.dict Decode.string))
        >> Result.toMaybe
        >> Maybe.andThen (Dict.toList >> List.head)
        >> Maybe.andThen
            (\( command, commandArgs ) ->
                let
                    fileName =
                        Dict.get "name" commandArgs

                    content =
                        Dict.get "content" commandArgs

                    urlPrefix =
                        Dict.get "urlPrefix" commandArgs
                in
                    case ( command, fileName, content, urlPrefix ) of
                        ( "routing", Nothing, Just content, Just urlPrefix ) ->
                            Just <| TranspileRouting { content = content, urlPrefix = urlPrefix }

                        ( "translation", Just fileName, Just content, Nothing ) ->
                            Just <| TranspileTranslation { name = fileName, content = content }

                        _ ->
                            Nothing
            )
        >> Maybe.withDefault NoOp


{-| Encode transpile routing results
-}
encodeRoutingResult : Result String String -> Value
encodeRoutingResult result =
    Encode.object
        [ ( "succeeded", Encode.bool <| Result.isOk result )
        , ( "type", Encode.string "routing" )
        , result
            |> Result.map (\content -> ( "content", Encode.string content ))
            |> Result.mapError (\err -> ( "error", Encode.string err ))
            |> Result.merge
        ]


{-| Encode transpile translation results
-}
encodeTranslationResult : Result String File -> Value
encodeTranslationResult result =
    Encode.object
        [ ( "succeeded", Encode.bool <| Result.isOk result )
        , ( "type", Encode.string "translation" )
        , result
            |> Result.map
                (\file ->
                    ( "file"
                    , Encode.object
                        [ ( "name", Encode.string file.name )
                        , ( "content", Encode.string file.content )
                        ]
                    )
                )
            |> Result.mapError (\err -> ( "error", Encode.string err ))
            |> Result.merge
        ]


formatResult : String -> Result String a -> Result String a
formatResult fileName result =
    result
        |> Result.mapError (\error -> "Error " ++ fileName ++ ": " ++ error)
