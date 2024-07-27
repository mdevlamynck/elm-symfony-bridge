module Dto.GeneratorTest exposing (suite)

import Dto.Generator exposing (generateElm)
import Expect
import StringUtil exposing (trimEmptyLines, unindent)
import Test exposing (..)


suite : Test
suite =
    describe "Parser"
        [ test "Handles sample from dto-metadata command" <|
            \_ ->
                let
                    input =
                        { content = unindent """
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
                        }

                    expected =
                        Ok
                            { name = "Dto.elm"
                            , content = unindent """
                                module Dto exposing (..)

                                import Json.Decode as Decode
                                import Json.Decode.Pipeline as Decode
                                import Json.Encode as Encode
                                import Json.Encode.Extra as Encode


                                type alias AppAccountSignInDto =
                                    { somePrimitive : Maybe String
                                    , someList : List (Maybe String)
                                    , someDto : Maybe AppAccountSomeDto
                                    }


                                decodeAppAccountSignInDto : Decode.Decoder AppAccountSignInDto
                                decodeAppAccountSignInDto =
                                    Decode.succeed AppAccountSignInDto
                                        |> Decode.required "somePrimitive" (Decode.maybe Decode.string)
                                        |> Decode.required "someList" (Decode.list (Decode.maybe Decode.string))
                                        |> Decode.required "someDto" (Decode.maybe decodeAppAccountSomeDto)


                                encodeAppAccountSignInDto : AppAccountSignInDto -> Encode.Value
                                encodeAppAccountSignInDto dto =
                                    Encode.object
                                        [ ( "somePrimitive", Encode.maybe Encode.string dto.somePrimitive )
                                        , ( "someList", Encode.list (Encode.maybe Encode.string) dto.someList )
                                        , ( "someDto", Encode.maybe encodeAppAccountSomeDto dto.someDto )
                                        ]
                                """
                            }
                in
                Expect.equal expected (generateElm input)
        ]
