module Translation.TranspilerTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Unindent exposing (..)
import Translation.Transpiler exposing (transpileToElm)


suite : Test
suite =
    describe "Converts a translation json to an elm module" <|
        [ describe "Succeesfull conversion" <|
            [ test "Works with empty translation file" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": []
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)
                                    """
                                }
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Works with plain constant translations" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "button.validate.global": "Ok",
                                            "button.validate.save": "Enregistrer"
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)


                                    button_validate_global : String
                                    button_validate_global =
                                        \"\"\"Ok\"\"\"


                                    button_validate_save : String
                                    button_validate_save =
                                        \"\"\"Enregistrer\"\"\"
                                    """
                                }
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Works with plain translations containing double quotes, line returns and anti slashes" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "multiline.html.translation": "<a href=\\"%link%\\">\\n</a>\\n"
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)


                                    multiline_html_translation : { link : String } -> String
                                    multiline_html_translation { link } =
                                        \"\"\"<a href=\\\"\"\"\" ++ link ++ \"\"\"\\">
                                        </a>
                                        \"\"\"
                                    """
                                }
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Works with weird translation names" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "This value is not valid.": "Cette valeur n'est pas valide."
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)


                                    this_value_is_not_valid_ : String
                                    this_value_is_not_valid_ =
                                        \"\"\"Cette valeur n'est pas valide.\"\"\"
                                    """
                                }
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Works with translations containing variables" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "user.notifications": "%count% notifications non lues",
                                            "user.welcome": "Bonjour %firstname% %lastname% et bienvenu !"
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)


                                    user_notifications : Int -> String
                                    user_notifications count =
                                        (toString count) ++ \"\"\" notifications non lues\"\"\"


                                    user_welcome : { firstname : String, lastname : String } -> String
                                    user_welcome { firstname, lastname } =
                                        \"\"\"Bonjour \"\"\" ++ firstname ++ \"\"\" \"\"\" ++ lastname ++ \"\"\" et bienvenu !\"\"\"
                                    """
                                }
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Works with pluralized translations containing variables" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "user.notifications": "{0}%user%, pas de notification|{1}%user%, %count% notification non lue|[2, Inf[%user%, %count% notifications non lues",
                                            "user.account.balance": "]-Inf, 0[Negative|[0, Inf[Positive"
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)


                                    user_account_balance : Int -> String
                                    user_account_balance count =
                                        if count < 0 then
                                            \"\"\"Negative\"\"\"
                                        else
                                            \"\"\"Positive\"\"\"


                                    user_notifications : Int -> { user : String } -> String
                                    user_notifications count { user } =
                                        if count == 0 then
                                            user ++ \"\"\", pas de notification\"\"\"
                                        else if count == 1 then
                                            user ++ \"\"\", \"\"\" ++ (toString count) ++ \"\"\" notification non lue\"\"\"
                                        else
                                            user ++ \"\"\", \"\"\" ++ (toString count) ++ \"\"\" notifications non lues\"\"\"
                                    """
                                }
                    in
                        Expect.equal expected (transpileToElm input)
            ]
        , describe "Failed conversion" <|
            [ test "Prints invalid json input" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "button.validate.global" "Ok"
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Err "Given an invalid JSON: Unexpected string in JSON at position 107"
                    in
                        Expect.equal expected (transpileToElm input)
            , test "Prints invalid message format" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "user.account.balance": "[-Inf, 0[Negative|[0, Inf[Positive"
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Err <|
                                unindent
                                    """
                                    Failed to parse a translation.
                                        Error while parsing an interval's low side (2, 1):

                                            [-Inf, 0[Negative|[0, Inf[Positive
                                             ^

                                        Expected a valid integer.

                                        Hint if the input is [-Inf:
                                            In an interval's low side, [-Inf is invalid as Inf is always exclusive.
                                            Try ]-Inf instead."
                                    """
                    in
                        Expect.equal expected (transpileToElm input)
            ]
        ]
