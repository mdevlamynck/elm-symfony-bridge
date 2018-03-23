port module Main exposing (main)

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Transpiler exposing (File)
import Dict
import Result.Extra as Result
import Platform exposing (Program, program)
import Platform.Cmd exposing (Cmd)
import Platform.Sub exposing (Sub)


main : Program Never () Msg
main =
    program
        { init = ( (), Cmd.none )
        , update = \message _ -> ( (), update message )
        , subscriptions = \_ -> subscriptions
        }


port sendToElm : (Value -> msg) -> Sub msg


port sendToJs : Value -> Cmd msg


type Msg
    = NoOp
    | TranspileTranslation String


update : Msg -> Cmd Msg
update message =
    case message of
        TranspileTranslation translation ->
            translation
                |> Transpiler.transpileTranslationToElm
                |> encodeTranslationResult
                |> sendToJs

        NoOp ->
            Cmd.none


subscriptions : Sub Msg
subscriptions =
    sendToElm decodeJsValue


decodeJsValue : Value -> Msg
decodeJsValue =
    Decode.decodeValue (Decode.dict Decode.string)
        >> Result.toMaybe
        >> Maybe.andThen (Dict.toList >> List.head)
        >> Maybe.andThen
            (\( command, content ) ->
                if command == "transpile" then
                    Just <| TranspileTranslation content
                else
                    Nothing
            )
        >> Maybe.withDefault NoOp


encodeTranslationResult : Result String File -> Value
encodeTranslationResult result =
    Encode.object
        [ ( "succeeded", Encode.bool <| Result.isOk result )
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
