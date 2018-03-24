port module Main exposing (main, Msg(..), update, decodeJsValue)

{-| Entry point, receive commands from js, dispatch to elm function and return result to js

@docs main, Msg, update, decodeJsValue

-}

import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode exposing (Value)
import Transpiler exposing (File)
import Dict
import Result.Extra as Result
import Platform exposing (Program, program)
import Platform.Cmd exposing (Cmd)
import Platform.Sub exposing (Sub)


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
                    |> \cmd -> ( (), cmd )
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
    | TranspileTranslation String


{-| Run received commands
-}
update : Msg -> Maybe Value
update message =
    case message of
        TranspileTranslation translation ->
            translation
                |> Transpiler.transpileTranslationToElm
                |> encodeTranslationResult
                |> Just

        NoOp ->
            Nothing


{-| Decode json commands
-}
decodeJsValue : Value -> Msg
decodeJsValue =
    Decode.decodeValue (Decode.dict Decode.string)
        >> Result.toMaybe
        >> Maybe.andThen (Dict.toList >> List.head)
        >> Maybe.andThen
            (\( command, content ) ->
                if command == "translation" then
                    Just <| TranspileTranslation content
                else
                    Nothing
            )
        >> Maybe.withDefault NoOp


{-| Encode transpile translation results
-}
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
