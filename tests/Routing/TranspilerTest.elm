module Routing.TranspilerTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Unindent exposing (..)
import Routing.Transpiler exposing (transpileToElm)


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
                                        "method": "ANY",
                                        "defaults": {
                                            "_controller": "AppFrontBundle:Default:index"
                                        },
                                        "requirements": "NO CUSTOM"
                                    }
                                }
                                """
                            }

                        expected =
                            Err """Expecting an object with a field named `path` at _.app_front_home but instead got: {"method":"ANY","defaults":{"_controller":"AppFrontBundle:Default:index"},"requirements":"NO CUSTOM"}"""
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Missing method" <|
                \_ ->
                    let
                        input =
                            { urlPrefix = ""
                            , content =
                                unindent """
                                {
                                    "app_front_home": {
                                        "defaults": {
                                            "_controller": "AppFrontBundle:Default:index"
                                        },
                                        "requirements": "NO CUSTOM"
                                    }
                                }
                                """
                            }

                        expected =
                            Err """Expecting an object with a field named `method` at _.app_front_home but instead got: {"defaults":{"_controller":"AppFrontBundle:Default:index"},"requirements":"NO CUSTOM"}"""
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Missing defaults" <|
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
                            Err """Expecting an object with a field named `defaults` at _.app_front_home but instead got: {"requirements":"NO CUSTOM"}"""
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
                            Err """Expecting an object with a field named `requirements` at _.app_front_home but instead got: {}"""
                    in
                        Expect.equal expected (transpileToElm input)
            ]
        , describe "Valid Json"
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
                                            "method": "ANY",
                                            "defaults": {
                                                "_controller": "AppFrontBundle:Default:index"
                                            },
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
                                    "/app_dev.php/home"
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
                                            "method": "ANY",
                                            "defaults": {
                                                "_controller": "AppFrontBundle:Default:index"
                                            },
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
                                    "/home"
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
                                            "method": "ANY",
                                            "defaults": {
                                                "_controller": "AppFrontBundle:Default:index"
                                            },
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
                                    "/home"
                                """
                    in
                        Expect.equal expected (transpileToElm input)
            ]
        ]
