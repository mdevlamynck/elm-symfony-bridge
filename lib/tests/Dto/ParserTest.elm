module Dto.ParserTest exposing (suite)

import Dto.Parser exposing (readJsonContent)
import Dto.Types exposing (..)
import Expect
import StringUtil exposing (unindent)
import Test exposing (..)


suite : Test
suite =
    describe "Parser"
        [ test "Handles sample from dto-metadata command" <|
            \_ ->
                let
                    input =
                        unindent """
                            [
                                {
                                    "fqn": "App\\\\Account\\\\UserInterface\\\\RestController\\\\SignInDto",
                                    "fields": {
                                        "somePrimitive": {
                                            "defaultValue": null,
                                            "type": "string",
                                            "isNullable": true,
                                            "canBeAbsent": false
                                        },
                                        "someList": {
                                            "defaultValue": null,
                                            "type": {
                                                "type": "string",
                                                "allowsNull": true
                                            },
                                            "isNullable": false,
                                            "canBeAbsent": false
                                        },
                                        "someDto": {
                                            "defaultValue": null,
                                            "type": {
                                                "fqn": "App\\\\Account\\\\UserInterface\\\\RestController\\\\SomeDto"
                                            },
                                            "isNullable": true,
                                            "canBeAbsent": false
                                        }
                                    }
                                }
                            ]
                            """

                    expected =
                        Ok
                            [ { ref =
                                    { fqn = "Dto.App.Account.SignInDto"
                                    , name = "SignInDto"
                                    }
                              , fields =
                                    [ ( "somePrimitive"
                                      , { canBeAbsent = False
                                        , defaultValue = Nothing
                                        , isNullable = True
                                        , type_ = TypePrimitive String
                                        }
                                      )
                                    , ( "someList"
                                      , { canBeAbsent = False
                                        , defaultValue = Nothing
                                        , isNullable = False
                                        , type_ =
                                            TypeCollection
                                                (C
                                                    { allowsNull = True
                                                    , type_ = TypePrimitive String
                                                    }
                                                )
                                        }
                                      )
                                    , ( "someDto"
                                      , { canBeAbsent = False
                                        , defaultValue = Nothing
                                        , isNullable = True
                                        , type_ =
                                            TypeDtoReference
                                                { fqn = "Dto.App.Account.SomeDto"
                                                , name = "SomeDto"
                                                }
                                        }
                                      )
                                    ]
                              }
                            ]
                in
                Expect.equal expected (readJsonContent input)
        ]
