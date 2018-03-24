module MainTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Unindent exposing (..)
import Main exposing (Msg(..), update, decodeJsValue)
import Json.Encode as Encode exposing (Value)


suite : Test
suite =
    describe "Main" <|
        [ describe "Command parser" <|
            [ test "Valid transpile translation command" <|
                \_ ->
                    let
                        input =
                            Encode.object [ ( "translation", Encode.string "{}" ) ]

                        expected =
                            TranspileTranslation "{}"
                    in
                        Expect.equal expected (decodeJsValue input)
            ]
        , describe "Commands" <|
            [ describe "NoOp" <|
                [ test "NoOp does nothing" <|
                    \_ ->
                        Expect.equal Nothing (update NoOp)
                ]
            , describe "TranspileTranslation" <|
                [ test "Works with valid command that should succeed" <|
                    \_ ->
                        let
                            input =
                                TranspileTranslation <|
                                    unindent """
                                        {
                                            "translations": {
                                                "fr": {
                                                    "messages": {
                                                        "button.validate.global": "Ok"
                                                    }
                                                }
                                            }
                                        }
                                        """

                            expected =
                                Just <|
                                    Encode.object
                                        [ ( "succeeded", Encode.bool True )
                                        , ( "file"
                                          , Encode.object
                                                [ ( "name", Encode.string "TransMessages.elm" )
                                                , ( "content"
                                                  , Encode.string <| unindent """
                                            module TransMessages exposing (..)


                                            button_validate_global : String
                                            button_validate_global =
                                                "Ok"
                                            """
                                                  )
                                                ]
                                          )
                                        ]
                        in
                            Expect.equal expected (update input)
                , test "Works with valid command that should fail" <|
                    \_ ->
                        let
                            input =
                                TranspileTranslation <| unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {
                                                "button.validate.global" "Ok"
                                            }
                                        }
                                    }
                                }
                                """

                            expected =
                                Just <|
                                    Encode.object
                                        [ ( "succeeded", Encode.bool False )
                                        , ( "error", Encode.string "Given an invalid JSON: Unexpected string in JSON at position 107" )
                                        ]
                        in
                            Expect.equal expected (update input)
                ]
            ]
        ]
