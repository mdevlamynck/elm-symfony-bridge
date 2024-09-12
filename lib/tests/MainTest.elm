module MainTest exposing (suite)

import Dict
import Expect
import Json.Encode as Encode
import Main exposing (Msg(..), decodeJsValue, update)
import StringUtil exposing (..)
import Test exposing (..)


suite : Test
suite =
    describe "Main"
        [ describe "Command parser"
            [ test "Valid transpile translation command" <|
                \_ ->
                    let
                        input =
                            Encode.object
                                [ ( "id", Encode.string "id" )
                                , ( "translation"
                                  , Encode.object
                                        [ ( "name", Encode.string "fileName" )
                                        , ( "content", Encode.string "{}" )
                                        , ( "envVariables", Encode.object [ ( "key", Encode.string "value" ) ] )
                                        ]
                                  )
                                ]

                        expected =
                            TranspileTranslation "id" { name = "fileName", content = "{}", envVariables = Dict.fromList [ ( "key", "value" ) ] }
                    in
                    Expect.equal expected (decodeJsValue input)
            , test "Valid transpile routing command" <|
                \_ ->
                    let
                        input =
                            Encode.object
                                [ ( "id", Encode.string "id" )
                                , ( "routing"
                                  , Encode.object
                                        [ ( "urlPrefix", Encode.string "/" )
                                        , ( "content", Encode.string "{}" )
                                        , ( "envVariables", Encode.object [ ( "key", Encode.string "value" ) ] )
                                        ]
                                  )
                                ]

                        expected =
                            TranspileRouting "id" { urlPrefix = "/", content = "{}", envVariables = Dict.fromList [ ( "key", "value" ) ] }
                    in
                    Expect.equal expected (decodeJsValue input)
            , test "Valid generate dto with encoders / decoders" <|
                \_ ->
                    let
                        input =
                            Encode.object
                                [ ( "id", Encode.string "id" )
                                , ( "dto"
                                  , Encode.object
                                        [ ( "content", Encode.string "{}" )
                                        ]
                                  )
                                ]

                        expected =
                            GenerateDto "id" { content = "{}" }
                    in
                    Expect.equal expected (decodeJsValue input)
            ]
        , describe "Commands"
            [ describe "NoOp"
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
            , describe "TranspileTranslation"
                [ test "Works with valid command that should succeed" <|
                    \_ ->
                        let
                            input =
                                TranspileTranslation "id" <|
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
                                    [ ( "id", Encode.string "id" )
                                    , ( "succeeded", Encode.bool True )
                                    , ( "file"
                                      , Encode.object
                                            [ ( "name", Encode.string "Trans/Messages.elm" )
                                            , ( "content"
                                              , Encode.string <| addOneEmptyLineAtEnd <| unindent """
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
                                TranspileTranslation "id" <|
                                    { name = "fileName"
                                    , content = """{ "translations": { "fr": { "messages": { "button.validate.global" "Ok" } } } }"""
                                    , envVariables = Dict.empty
                                    }

                            expected =
                                Encode.object
                                    [ ( "id", Encode.string "id" )
                                    , ( "succeeded", Encode.bool False )
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
