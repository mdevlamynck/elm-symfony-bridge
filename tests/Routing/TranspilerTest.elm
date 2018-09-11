module Routing.TranspilerTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Routing.Transpiler exposing (transpileToElm)
import Test exposing (..)
import Unindent exposing (..)


suite : Test
suite =
    describe "Converts a routing json to an elm module"
        [ describe "Invalid json"
            [ test "Invalid json syntax" <|
                \_ ->
                    let
                        input =
                            { urlPrefix = ""
                            , content =
                                unindent """ """
                            }

                        expected =
                            Err "Given an invalid JSON: Unexpected end of JSON input"
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Missing path" <|
                \_ ->
                    let
                        input =
                            { urlPrefix = ""
                            , content =
                                unindent """
                                {
                                    "app_front_home": {
                                        "requirements": "NO CUSTOM"
                                    }
                                }
                                """
                            }

                        expected =
                            Err """Expecting an object with a field named `path` at _.app_front_home but instead got: {"requirements":"NO CUSTOM"}"""
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Missing requirements" <|
                \_ ->
                    let
                        input =
                            { urlPrefix = ""
                            , content =
                                unindent """
                                {
                                    "app_front_home": {
                                    }
                                }
                                """
                            }

                        expected =
                            Err """Expecting an object with a field named `path` at _.app_front_home but instead got: {}"""
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
                                , content =
                                    unindent """
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
                                , content =
                                    unindent """
                                        {
                                            "app_front_home": {
                                                "path": "/home",
                                                "requirements": "NO CUSTOM"
                                            }
                                        }
                                    """
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    app_front_home : String
                                    app_front_home =
                                        "/app_dev.php" ++ "/home"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Ignores routes starting with an underscore" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content =
                                    unindent """
                                        {
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
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    app_front_home : String
                                    app_front_home =
                                        "" ++ "/home"
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                , test "Ignores extra fields in the json" <|
                    \_ ->
                        let
                            input =
                                { urlPrefix = ""
                                , content =
                                    unindent """
                                        {
                                            "app_front_home": {
                                                "path": "/home",
                                                "requirements": "NO CUSTOM",
                                                "extraField": null
                                            }
                                        }
                                    """
                                }

                            expected =
                                Ok <|
                                    unindent """
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
                                , content =
                                    unindent """
                                        {
                                            "aPP_fR@n|_h0m3": {
                                                "path": "/home",
                                                "requirements": "NO CUSTOM"
                                            }
                                        }
                                    """
                                }

                            expected =
                                Ok <|
                                    unindent """
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
                                , content =
                                    unindent """
                                        {
                                            "app_front_home": {
                                                "path": "/home",
                                                "requirements": "NO CUSTOM"
                                            }
                                        }
                                    """
                                }

                            expected =
                                Ok <|
                                    unindent """
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
                                , content =
                                    unindent """
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
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    app_rest_user_find_friend : { id : Int, username : String } -> String
                                    app_rest_user_find_friend { id, username } =
                                        "" ++ "/user/" ++ (String.fromInt id) ++ "/find-friend/" ++ username
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                ]
            ]
        ]
