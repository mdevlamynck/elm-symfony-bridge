module Dto.GeneratorTest exposing (suite)

import Dto.Generator exposing (generateElm)
import Expect
import StringUtil exposing (addOneEmptyLineAtEnd, unindent)
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
                                            "isNullable": true,
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
                            [ { name = "Dto/App/Account/SignInDto.elm"
                              , content = addOneEmptyLineAtEnd <| unindent """
                                  module Dto.App.Account.SignInDto exposing (..)

                                  import Dto.App.Account.SomeDto
                                  import Json.Decode as Decode
                                  import Json.Decode.Pipeline as Decode
                                  import Json.Encode as Encode
                                  import Json.Encode.Extra as Encode


                                  type alias SignInDto =
                                      { somePrimitive : Maybe String
                                      , someList : Maybe (List (Maybe String))
                                      , someDto : Maybe Dto.App.Account.SomeDto.SomeDto
                                      }


                                  decode : Decode.Decoder SignInDto
                                  decode =
                                      Decode.succeed SignInDto
                                          |> Decode.required "somePrimitive" (Decode.maybe Decode.string)
                                          |> Decode.required
                                              "someList"
                                              (Decode.maybe (Decode.list (Decode.maybe Decode.string)))
                                          |> Decode.required
                                              "someDto"
                                              (Decode.maybe Dto.App.Account.SomeDto.decode)


                                  encode : SignInDto -> Encode.Value
                                  encode dto =
                                      Encode.object
                                          [ ( "somePrimitive", Encode.maybe Encode.string dto.somePrimitive )
                                          , ( "someList"
                                            , Encode.maybe (Encode.list (Encode.maybe Encode.string)) dto.someList
                                            )
                                          , ( "someDto", Encode.maybe Dto.App.Account.SomeDto.encode dto.someDto )
                                          ]
                                  """
                              }
                            ]
                in
                Expect.equal expected (generateElm input)
        ]
