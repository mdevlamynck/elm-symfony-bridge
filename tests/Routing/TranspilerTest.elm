module Routing.TranspilerTest exposing (suite)

import Elm exposing (Version(..))
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
                            , version = Elm_0_19
                            }

                        expected =
                            Err <|
                                unindent
                                    """
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
                            , content =
                                unindent """
                                {
                                    "app_front_home": {
                                        "requirements": "NO CUSTOM"
                                    }
                                }
                                """
                            , version = Elm_0_19
                            }

                        expected =
                            Err <|
                                unindent
                                    """
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
                            , content =
                                unindent """
                                {
                                    "app_front_home": {
                                    }
                                }
                                """
                            , version = Elm_0_19
                            }

                        expected =
                            Err <|
                                unindent
                                    """
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
                                , version = Elm_0_19
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
                                , version = Elm_0_19
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                                , version = Elm_0_19
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                                , version = Elm_0_19
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                                , version = Elm_0_19
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                                , version = Elm_0_19
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                                , version = Elm_0_19
                                }

                            expected =
                                Ok <|
                                    unindent """
                                    module Routing exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


                                    app_rest_user_find_friend : { id : Int, username : String } -> String
                                    app_rest_user_find_friend params_ =
                                        "" ++ "/user/" ++ (fromInt params_.id) ++ "/find-friend/" ++ params_.username
                                    """
                        in
                        Expect.equal expected (transpileToElm input)
                ]
            ]
        ]
