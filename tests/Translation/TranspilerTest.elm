module Translation.TranspilerTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Translation.Transpiler exposing (transpileToElm)
import Unindent exposing (..)


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
            , test "Works with a null translation" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {"translation": null}
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)


                                    translation : String
                                    translation =
                                        \"\"\"\"\"\"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with an empty translation" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {"translation": ""}
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = unindent """
                                    module Trans.Messages exposing (..)


                                    translation : String
                                    translation =
                                        \"\"\"\"\"\"
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
                                        </a>\"\"\"
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
                                        (String.fromInt count) ++ \"\"\" notifications non lues\"\"\"


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
                                            user ++ \"\"\", \"\"\" ++ (String.fromInt count) ++ \"\"\" notification non lue\"\"\"
                                        else
                                            user ++ \"\"\", \"\"\" ++ (String.fromInt count) ++ \"\"\" notifications non lues\"\"\"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with pluralized translations containing indexed variant in french" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "apples": "{0} Il n'y a pas de pomme|one: Il y a une pomme|{5} Il y a cinq pommes|more: Il y a %count% pommes"
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


                                    apples : Int -> String
                                    apples count =
                                        if count == 0 then
                                            \"\"\"Il n'y a pas de pomme\"\"\"
                                        else if count == 0 || count == 1 then
                                            \"\"\"Il y a une pomme\"\"\"
                                        else if count == 5 then
                                            \"\"\"Il y a cinq pommes\"\"\"
                                        else
                                            \"\"\"Il y a \"\"\" ++ (String.fromInt count) ++ \"\"\" pommes\"\"\"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with pluralized translations containing indexed variant in english" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "en": {
                                        "messages": {
                                            "apples": "{0} There are no apples|one: There is one apple|{5}There are five apples|more: There are %count% apples"
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


                                    apples : Int -> String
                                    apples count =
                                        if count == 0 then
                                            \"\"\"There are no apples\"\"\"
                                        else if count == 1 then
                                            \"\"\"There is one apple\"\"\"
                                        else if count == 5 then
                                            \"\"\"There are five apples\"\"\"
                                        else
                                            \"\"\"There are \"\"\" ++ (String.fromInt count) ++ \"\"\" apples\"\"\"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Allow getting a translation from a keyname (only for translation containing key 'keyname')" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "honorific_title.keyname.miss": "Miss",
                                            "honorific_title.keyname.mister": "Mister"
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


                                    honorific_title_keyname_miss : String
                                    honorific_title_keyname_miss =
                                        \"\"\"Miss\"\"\"


                                    honorific_title_keyname_mister : String
                                    honorific_title_keyname_mister =
                                        \"\"\"Mister\"\"\"


                                    honorific_title_keyname : String -> String
                                    honorific_title_keyname keyname =
                                        case keyname of
                                            "miss" ->
                                                honorific_title_keyname_miss

                                            "mister" ->
                                                honorific_title_keyname_mister

                                            _ ->
                                                Debug.log ("Keyname not found: " ++ keyname) ""
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
            ]
        ]
