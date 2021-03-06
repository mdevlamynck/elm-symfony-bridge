port module Main exposing (main, Msg(..), update, decodeJsValue)

{-| Entry point, receive commands from js, dispatch to elm function and return result to js.

@docs main, Msg, update, decodeJsValue

-}

import Dict
import Elm exposing (Version(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Platform exposing (Program, worker)
import Platform.Cmd exposing (Cmd)
import Platform.Sub exposing (Sub)
import Result.Extra as Result
import Routing.Transpiler as Routing
import Translation.Transpiler as Translation exposing (File)


{-| Entry point.
-}
main : Program () () Msg
main =
    worker
        { init = \_ -> ( (), Cmd.none )
        , update =
            \msg _ ->
                msg
                    |> update
                    |> sendToJs
                    |> (\cmd -> ( (), cmd ))
        , subscriptions = always <| sendToElm decodeJsValue
        }


{-| Allows receiving json values from js.
-}
port sendToElm : (Value -> msg) -> Sub msg


{-| Allows sending json values to js.
-}
port sendToJs : Value -> Cmd msg


{-| Handled commands.
-}
type Msg
    = NoOp
    | TranspileRouting Routing.Command
    | TranspileTranslation Translation.Command


{-| Run received commands.
-}
update : Msg -> Value
update message =
    case message of
        NoOp ->
            Encode.object
                [ ( "succeeded", Encode.bool False )
                , ( "error", Encode.string "Invalid command" )
                ]

        TranspileRouting routing ->
            routing
                |> Routing.transpileToElm
                |> formatResult "Routing"
                |> encodeRoutingResult

        TranspileTranslation translation ->
            translation
                |> Translation.transpileToElm
                |> formatResult translation.name
                |> encodeTranslationResult


{-| Decode json commands.
-}
decodeJsValue : Value -> Msg
decodeJsValue =
    Decode.decodeValue ((Decode.dict << Decode.dict) Decode.string)
        >> Result.toMaybe
        >> Maybe.andThen (Dict.toList >> List.head)
        >> Maybe.andThen
            (\( command, commandArgs ) ->
                let
                    urlPrefix =
                        Dict.get "urlPrefix" commandArgs

                    fileName =
                        Dict.get "name" commandArgs

                    content =
                        Dict.get "content" commandArgs

                    version =
                        Dict.get "version" commandArgs
                            |> Maybe.andThen
                                (\versionString ->
                                    case versionString of
                                        "0.18" ->
                                            Just Elm_0_18

                                        "0.19" ->
                                            Just Elm_0_19

                                        _ ->
                                            Nothing
                                )
                in
                case command of
                    "routing" ->
                        Maybe.map3 Routing.Command urlPrefix content version
                            |> Maybe.map TranspileRouting

                    "translation" ->
                        Maybe.map3 Translation.Command fileName content version
                            |> Maybe.map TranspileTranslation

                    _ ->
                        Nothing
            )
        >> Maybe.withDefault NoOp


{-| Encode transpiled routing results.
-}
encodeRoutingResult : Result String String -> Value
encodeRoutingResult result =
    Encode.object
        [ ( "succeeded", Encode.bool <| Result.isOk result )
        , ( "type", Encode.string "routing" )
        , case result of
            Ok content ->
                ( "content", Encode.string content )

            Err err ->
                ( "error", Encode.string err )
        ]


{-| Encode transpiled translation results.
-}
encodeTranslationResult : Result String File -> Value
encodeTranslationResult result =
    Encode.object
        [ ( "succeeded", Encode.bool <| Result.isOk result )
        , ( "type", Encode.string "translation" )
        , case result of
            Ok file ->
                ( "file"
                , Encode.object
                    [ ( "name", Encode.string file.name )
                    , ( "content", Encode.string file.content )
                    ]
                )

            Err err ->
                ( "error", Encode.string err )
        ]


{-| Add filename to error message if any.
-}
formatResult : String -> Result String a -> Result String a
formatResult fileName result =
    result
        |> Result.mapError (\error -> "Error " ++ fileName ++ ": " ++ error)
