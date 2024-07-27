module Dto.GeneratorTest exposing (suite)

import Dto.Generator exposing (generateElm)
import Expect
import StringUtil exposing (unindent)
import Test exposing (..)


suite : Test
suite =
    describe "Parser"
        [ todo "Handles sample from dto-metadata command" -- <|

        --\_ ->
        --    let
        --        input =
        --            { content = unindent """
        --                [
        --                    {
        --                        "fqn": "App\\\\Account\\\\UserInterface\\\\RestController\\\\SignInDto",
        --                        "fields": {
        --                            "email": {
        --                                "defaultValue": null,
        --                                "type": "string",
        --                                "isNullable": true,
        --                                "canBeAbsent": false
        --                            },
        --                            "password": {
        --                                "defaultValue": null,
        --                                "type": "string",
        --                                "isNullable": true,
        --                                "canBeAbsent": false
        --                            },
        --                            "passwordRepeat": {
        --                                "defaultValue": null,
        --                                "type": "string",
        --                                "isNullable": true,
        --                                "canBeAbsent": false
        --                            }
        --                        }
        --                    }
        --                ]
        --                """
        --            }
        --
        --        expected =
        --            Ok
        --                { name = "Dto.elm"
        --                , content = unindent """
        --                    module Dto exposing (..)
        --
        --                    import Json.Decode as Decode
        --                    import Json.Decode.Pipeline as Decode
        --                    import Json.Encode as Encode
        --                    import Json.Encode.Extra as Encode
        --
        --
        --                    type alias App_Account_SignInDto =
        --                        { email : Maybe String
        --                        , password : Maybe String
        --                        , passwordRepeat : Maybe String
        --                        }
        --
        --
        --                    decode_App_Account_SignInDto : Json.Decode.Decoder App_Account_SignInDto
        --                    decode_App_Account_SignInDto =
        --                        Decode.succeed App_Account_SignInDto
        --                            |> Decode.succeed "email" (Decode.maybe Decode.string)
        --                            |> Decode.succeed "password" (Decode.maybe Decode.string)
        --                            |> Decode.succeed "passwordRepeat" (Decode.maybe Decode.string)
        --
        --
        --                    encode_App_Account_SignInDto : App_Account_SignInDto -> Encode.Value
        --                    encode_App_Account_SignInDto dto =
        --                        Encode.object
        --                            [ ( "email", Encode.maybe Encode.string dto.email )
        --                            , ( "password", Encode.maybe Encode.string dto.password )
        --                            , ( "passwordRepeat", Encode.maybe Encode.string dto.passwordRepeat )
        --                            ]
        --                    """
        --                }
        --    in
        --    Expect.equal expected (generateElm input)
        ]
