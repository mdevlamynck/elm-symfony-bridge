port module Main exposing (main, Msg(..), update, decodeJsValue)

{-| Entry point, receive commands from js, dispatch to elm function and return result to js.

@docs main, Msg, update, decodeJsValue

-}

import Dict exposing (Dict)
import Dict.Extra as Dict
import Elm exposing (Version(..))
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Decode
import Json.Encode as Encode exposing (Value)
import Platform exposing (Program, worker)
import Platform.Cmd exposing (Cmd)
import Platform.Sub exposing (Sub)
import Result.Extra as Result
import Routing.Transpiler as Routing
import Translation.Legacy.Transpiler as Translation exposing (File)


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
    | CommandError String


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

        CommandError error ->
            Encode.object
                [ ( "succeeded", Encode.bool False )
                , ( "error", Encode.string error )
                ]


{-| Decode json commands.
-}
decodeJsValue : Value -> Msg
decodeJsValue =
    Decode.decodeValue commandDecoder
        >> Result.mapError (CommandError << Decode.errorToString)
        >> Result.merge


commandDecoder : Decoder Msg
commandDecoder =
    Decode.oneOf
        [ routingDecoder
        , translationDecoder
        ]


routingDecoder : Decoder Msg
routingDecoder =
    Decode.succeed TranspileRouting
        |> Decode.required "routing"
            (Decode.succeed Routing.Command
                |> Decode.required "urlPrefix" Decode.string
                |> Decode.required "content" Decode.string
                |> Decode.required "version" versionDecoder
                |> Decode.required "envVariables" envVariableDecoder
            )


translationDecoder : Decoder Msg
translationDecoder =
    Decode.succeed TranspileTranslation
        |> Decode.required "translation"
            (Decode.succeed Translation.Command
                |> Decode.required "name" Decode.string
                |> Decode.required "content" Decode.string
                |> Decode.required "version" versionDecoder
                |> Decode.required "envVariables" envVariableDecoder
            )


versionDecoder : Decoder Version
versionDecoder =
    Decode.string
        |> Decode.andThen
            (\versionString ->
                case versionString of
                    "0.18" ->
                        Decode.succeed Elm_0_18

                    "0.19" ->
                        Decode.succeed Elm_0_19

                    _ ->
                        Decode.fail <| "Unsupported version: " ++ versionString
            )


envVariableDecoder : Decoder (Dict String String)
envVariableDecoder =
    Decode.dict (Decode.maybe Decode.string)
        |> Decode.map (Dict.filterMap (\k maybeV -> maybeV))


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
