module Dto.ParserTest exposing (suite)

import Dict
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
                                        "email": {
                                            "defaultValue": null,
                                            "type": "string",
                                            "isNullable": true,
                                            "canBeAbsent": false
                                        },
                                        "password": {
                                            "defaultValue": null,
                                            "type": "string",
                                            "isNullable": true,
                                            "canBeAbsent": false
                                        },
                                        "passwordRepeat": {
                                            "defaultValue": null,
                                            "type": "string",
                                            "isNullable": true,
                                            "canBeAbsent": false
                                        }
                                    }
                                }
                            ]
                            """

                    expected =
                        Ok
                            [ D
                                { fqn = "App\\Account\\UserInterface\\RestController\\SignInDto"
                                , fields =
                                    Dict.fromList
                                        [ ( "email", T { type_ = TypePrimitive String, isNullable = True, canBeAbsent = False, defaultValue = Nothing } )
                                        , ( "password", T { type_ = TypePrimitive String, isNullable = True, canBeAbsent = False, defaultValue = Nothing } )
                                        , ( "passwordRepeat", T { type_ = TypePrimitive String, isNullable = True, canBeAbsent = False, defaultValue = Nothing } )
                                        ]
                                }
                            ]
                in
                Expect.equal expected (readJsonContent input)
        ]
