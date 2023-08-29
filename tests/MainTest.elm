module MainTest exposing (suite)

import Dict
import Expect exposing (Expectation)
import Json.Encode as Encode exposing (Value)
import Main exposing (Msg(..), decodeJsValue, update)
import StringUtil exposing (..)
import Test exposing (..)


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
                                        , ( "envVariables", Encode.object [ ( "key", Encode.string "value" ) ] )
                                        ]
                                  )
                                ]

                        expected =
                            TranspileTranslation { name = "fileName", content = "{}", envVariables = Dict.fromList [ ( "key", "value" ) ] }
                    in
                    Expect.equal expected (decodeJsValue input)
            , test "Valid transpile routing command" <|
                \_ ->
                    let
                        input =
                            Encode.object
                                [ ( "routing"
                                  , Encode.object
                                        [ ( "urlPrefix", Encode.string "/" )
                                        , ( "content", Encode.string "{}" )
                                        , ( "envVariables", Encode.object [ ( "key", Encode.string "value" ) ] )
                                        ]
                                  )
                                ]

                        expected =
                            TranspileRouting { urlPrefix = "/", content = "{}", envVariables = Dict.fromList [ ( "key", "value" ) ] }
                    in
                    Expect.equal expected (decodeJsValue input)
            ]
        , describe "Commands" <|
            [ describe "NoOp" <|
                [ test "NoOp does nothing" <|
                    \_ ->
                        let
                            expected =
                                Encode.object
                                    [ ( "succeeded", Encode.bool False )
                                    , ( "error", Encode.string "Invalid command" )
                                    ]
                        in
                        Expect.equal expected (update NoOp)
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
                                    , envVariables = Dict.empty
                                    }

                            expected =
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
                                TranspileTranslation <|
                                    { name = "fileName"
                                    , content = """{ "translations": { "fr": { "messages": { "button.validate.global" "Ok" } } } }"""
                                    , envVariables = Dict.empty
                                    }

                            expected =
                                Encode.object
                                    [ ( "succeeded", Encode.bool False )
                                    , ( "type", Encode.string "translation" )
                                    , ( "error"
                                      , Encode.string <|
                                            unindent
                                                """
                                                    Error fileName: Problem with the given value:

                                                    "{ \\"translations\\": { \\"fr\\": { \\"messages\\": { \\"button.validate.global\\" \\"Ok\\" } } } }"

                                                    This is not valid JSON! Expected ':' after property name in JSON at position 67
                                                    """
                                      )
                                    ]
                        in
                        Expect.equal
                            (Encode.encode 0 expected)
                            (Encode.encode 0 (update input))
                ]
            ]
        ]
