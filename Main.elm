port module Main exposing (main)

import Json.Decode as Decode exposing (Value, string)
import Transpiler
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


port sendToJs : String -> Cmd msg


type Msg
    = NoOp
    | TranspileTranslation String


update : Msg -> Cmd Msg
update message =
    case message of
        TranspileTranslation translation ->
            translation
                |> Transpiler.transpileTranslationToElm
                |> sendToJs

        NoOp ->
            Cmd.none


subscriptions : Sub Msg
subscriptions =
    sendToElm decodeJsValue


decodeJsValue : Value -> Msg
decodeJsValue value =
    Decode.decodeValue string value
        |> Result.map TranspileTranslation
        |> Result.withDefault NoOp
