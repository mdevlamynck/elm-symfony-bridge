module Routing.TranspilerTest exposing (suite)

import Dict
import Expect
import Routing.Transpiler exposing (transpileToElm)
import StringUtil exposing (..)
import Test exposing (..)


suite : Test
suite =
    describe "Converts a routing json to an elm module"
        [ describe "Invalid json"
            [ test "Invalid json syntax" <|
                \_ ->
                    let
                        input =
                            { urlPrefix = ""
                            , content = unindent """ """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Err <| unindent """
                                Problem with the given value:

                                ""

                                This is not valid JSON! Unexpected end of JSON input
                                """
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Missing path" <|
                \_ ->
                    let
                        input =
                            { urlPrefix = ""
                            , content = unindent """
                                {
                                    "app_front_home": {
                                        "requirements": "NO CUSTOM"
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Err <| unindent """
                                Problem with the value at json['app_front_home']:

                                    {
                                        "requirements": "NO CUSTOM"
                                    }

                                Expecting an OBJECT with a field named `path`
                                """
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Missing requirements" <|
                \_ ->
                    let
                        input =
                            { urlPrefix = ""
                            , content = unindent """
                                {
                                    "app_front_home": {
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Err <| unindent """
                                Problem with the value at json['app_front_home']:

                                    {}

                                Expecting an OBJECT with a field named `requirements`
                                """
                    in
                    Expect.equal expected (transpileToElm input)
            ]
        , describe "Valid Json"
            [ describe "Invalid routing"
                [ test "Invalid path format" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = unindent """
                                    {
                                        "app_rest_user_find_friend": {
                                            "path": "/user/{id/find-friend/{_username}",
                                            "requirements": {
                                                "id": """ ++ "\"\\\\d+\"" ++ """,
                                                "_username": ""
                                            }
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Err "Failed to parse routing path"
                        in
                        Expect.equal expected (transpileToElm input)
                ]
            , describe "Valid routing"
                [ test "Prepends the urlPrefix" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = "/app_dev.php"
                                , content = unindent """
                                    {
                                        "app_front_home": {
                                            "path": "/home",
                                            "requirements": "NO CUSTOM"
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_front_home : String
                                    app_front_home =
                                        "/app_dev.php" ++ "/home"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Invalid function names are prefixed to avoid compilation errors" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = unindent """
                                    {
                                        "9things": {
                                            "path": "/home",
                                            "requirements": "NO CUSTOM"
                                        },
                                        "_ignored_route": {
                                            "path": "/home",
                                            "requirements": "NO CUSTOM"
                                        },
                                        "app_front_home": {
                                            "path": "/home",
                                            "requirements": "NO CUSTOM"
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_front_home : String
                                    app_front_home =
                                        "" ++ "/home"


                                    f_9things : String
                                    f_9things =
                                        "" ++ "/home"


                                    f_ignored_route : String
                                    f_ignored_route =
                                        "" ++ "/home"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Ignores extra fields in the json" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = unindent """
                                    {
                                        "app_front_home": {
                                            "path": "/home",
                                            "requirements": "NO CUSTOM",
                                            "extraField": null
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_front_home : String
                                    app_front_home =
                                        "" ++ "/home"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Rewrite invalid routes name" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = unindent """
                                    {
                                        "aPP_fR@n|_h0m3": {
                                            "path": "/home",
                                            "requirements": "NO CUSTOM"
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_fr_n__h0m3 : String
                                    app_fr_n__h0m3 =
                                        "" ++ "/home"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Handles the simple case" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = unindent """
                                    {
                                        "app_front_home": {
                                            "path": "/home",
                                            "requirements": "NO CUSTOM"
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_front_home : String
                                    app_front_home =
                                        "" ++ "/home"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Handles variables of type int and starting with underscores" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = unindent """
                                    {
                                        "app_rest_user_find_friend": {
                                            "path": "/user/{id}/find-friend/{_username}",
                                            "requirements": {
                                                "id": """ ++ "\"\\\\d+\"" ++ """,
                                                "_username": ""
                                            }
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_rest_user_find_friend : { id : Int, username : String } -> String
                                    app_rest_user_find_friend params_ =
                                        ""
                                            ++ "/user/"
                                            ++ String.fromInt params_.id
                                            ++ "/find-friend/"
                                            ++ params_.username
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Handles variable name conflicting with reserved elm keywords" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = unindent """
                                    {
                                        "app_rest_user_type": {
                                            "path": "/user/types/{type}",
                                            "requirements": {
                                                "type": ""
                                            }
                                        }
                                    }
                                    """
                                , envVariables = Dict.empty
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_rest_user_type : { type_ : String } -> String
                                    app_rest_user_type params_ =
                                        "" ++ "/user/types/" ++ params_.type_
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Handles env variables" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content = addEmptyLineAtEnd <| unindent """
                                    {
                                        "app_rest_user_type": {
                                            "path": "/user/types/{variable}",
                                            "requirements": {
                                                "type": ""
                                            }
                                        }
                                    }
                                    """
                                , envVariables = Dict.fromList [ ( "{variable}", "value" ) ]
                                }

                            expected =
                                Ok <| addEmptyLineAtEnd <| unindent """
                                    module Routing exposing (..)


                                    app_rest_user_type : String
                                    app_rest_user_type =
                                        "" ++ "/user/types/value"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                ]
            ]
        ]
