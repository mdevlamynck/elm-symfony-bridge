module MainTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Json.Encode as Encode exposing (Value)
import Main exposing (Msg(..), decodeJsValue, update)
import Test exposing (..)
import Unindent exposing (..)


suite : Test
suite =
    describe "Main" <|
        [ describe "Command parser" <|
            [ test "Valid transpile translation command" <|
                \_ ->
                    let
                        input =
                            Encode.object
                                [ ( "translation"
                                  , Encode.object
                                        [ ( "name", Encode.string "fileName" )
                                        , ( "content", Encode.string "{}" )
                                        ]
                                  )
                                ]

                        expected =
                            TranspileTranslation { name = "fileName", content = "{}" }
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
                                    { name = "fileName"
                                    , content =
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
                                    }

                            expected =
                                Just <|
                                    Encode.object
                                        [ ( "succeeded", Encode.bool True )
                                        , ( "type", Encode.string "translation" )
                                        , ( "file"
                                          , Encode.object
                                                [ ( "name", Encode.string "Trans/Messages.elm" )
                                                , ( "content"
                                                  , Encode.string <| unindent """
                                            module Trans.Messages exposing (..)


                                            button_validate_global : String
                                            button_validate_global =
                                                \"\"\"Ok\"\"\"
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
                                TranspileTranslation <|
                                    { name = "fileName"
                                    , content = """{ "translations": { "fr": { "messages": { "button.validate.global" "Ok" } } } }"""
                                    }

                            expected =
                                Just <|
                                    Encode.object
                                        [ ( "succeeded", Encode.bool False )
                                        , ( "type", Encode.string "translation" )
                                        , ( "error"
                                          , Encode.string <|
                                                unindent
                                                    """
                                                    Error fileName: Problem with the given value:

                                                    "{ \\"translations\\": { \\"fr\\": { \\"messages\\": { \\"button.validate.global\\" \\"Ok\\" } } } }"
                                                    
                                                    This is not valid JSON! Unexpected string in JSON at position 67
                                                    """
                                          )
                                        ]
                        in
                        Expect.equal
                            (Maybe.map (Encode.encode 0) expected)
                            (Maybe.map (Encode.encode 0) (update input))
                ]
            ]
        ]
