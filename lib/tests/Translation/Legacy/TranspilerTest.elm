module Translation.Legacy.TranspilerTest exposing (suite)

import Dict
import Expect
import StringUtil exposing (..)
import Test exposing (..)
import Translation.Transpiler exposing (transpileToElm)


suite : Test
suite =
    describe "Converts a translation json to an elm module"
        [ describe "Successful conversion"
            [ test "Works with empty translation file" <|
                \_ ->
                    let
                        input =
                            { name = "+"
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": []
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addEmptyLinesAtEnd 3 <| unindent """
                                    module Trans.Messages exposing (..)
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with a null translation" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {"translation": null}
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    translation : String
                                    translation =
                                        ""
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with an empty translation" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {"translation": ""}
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    translation : String
                                    translation =
                                        ""
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with plain constant translations" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    button_validate_global : String
                                    button_validate_global =
                                        "Ok"


                                    button_validate_save : String
                                    button_validate_save =
                                        "Enregistrer"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with translations containing a non string message" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {
                                                "boolean_false": false,
                                                "boolean_true": true,
                                                "float": 3.14,
                                                "integer": 42
                                            }
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    boolean_false : String
                                    boolean_false =
                                        "false"


                                    boolean_true : String
                                    boolean_true =
                                        "true"


                                    float : String
                                    float =
                                        "3.14"


                                    integer : String
                                    integer =
                                        "42"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Invalid translations are ignored and don't make the parser fail" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {
                                                "array": [42, 3.14, null],
                                                "object": { "invalid": "invalid", "number": 42 },
                                                "null": null,
                                                "valid": "valid"
                                            }
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    array : String
                                    array =
                                        ""


                                    null : String
                                    null =
                                        ""


                                    object : String
                                    object =
                                        ""


                                    valid : String
                                    valid =
                                        "valid"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with translation name containing numbers" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {
                                                "page.error.503": "Error 503",
                                                "form.step2.save": "Enregistrer"
                                            }
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    form_step2_save : String
                                    form_step2_save =
                                        "Enregistrer"


                                    page_error_503 : String
                                    page_error_503 =
                                        "Error 503"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with plain translations containing double quotes, line returns and anti slashes" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    multiline_html_translation : { link : String } -> String
                                    multiline_html_translation params_ =
                                        "<a href=\\"" ++ params_.link ++ "\\">\\n</a>"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with weird translation names" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    this_value_is_not_valid_ : String
                                    this_value_is_not_valid_ =
                                        "Cette valeur n'est pas valide."
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Invalid function names are prefixed to avoid compilation errors" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {
                                                "__name__label__": "__name__label__",
                                                "9things": "9things"
                                            }
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    f_9things : String
                                    f_9things =
                                        "9things"


                                    f__name__label__ : String
                                    f__name__label__ =
                                        "__name__label__"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with translations containing variables" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    user_notifications : Int -> String
                                    user_notifications count =
                                        String.fromInt count ++ " notifications non lues"


                                    user_welcome : { firstname : String, lastname : String } -> String
                                    user_welcome params_ =
                                        "Bonjour "
                                            ++ params_.firstname
                                            ++ " "
                                            ++ params_.lastname
                                            ++ " et bienvenu !"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with pluralized translations containing variables" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    user_account_balance : Int -> String
                                    user_account_balance count =
                                        if count < 0 then
                                            "Negative"

                                        else
                                            "Positive"


                                    user_notifications : Int -> { user : String } -> String
                                    user_notifications count params_ =
                                        if count == 0 then
                                            params_.user ++ ", pas de notification"

                                        else if count == 1 then
                                            params_.user ++ ", " ++ String.fromInt count ++ " notification non lue"

                                        else
                                            params_.user
                                                ++ ", "
                                                ++ String.fromInt count
                                                ++ " notifications non lues"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with pluralized translations containing indexed variant in french" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    apples : Int -> String
                                    apples count =
                                        if count == 0 then
                                            "Il n'y a pas de pomme"

                                        else if count == 0 || count == 1 then
                                            "Il y a une pomme"

                                        else if count == 5 then
                                            "Il y a cinq pommes"

                                        else
                                            "Il y a " ++ String.fromInt count ++ " pommes"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with pluralized translations containing indexed variant in english" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    apples : Int -> String
                                    apples count =
                                        if count == 0 then
                                            "There are no apples"

                                        else if count == 1 then
                                            "There is one apple"

                                        else if count == 5 then
                                            "There are five apples"

                                        else
                                            "There are " ++ String.fromInt count ++ " apples"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Allow getting a translation from a keyname (only for translation containing key 'keyname')" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
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
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    honorific_title_keyname_miss : String
                                    honorific_title_keyname_miss =
                                        "Miss"


                                    honorific_title_keyname_mister : String
                                    honorific_title_keyname_mister =
                                        "Mister"


                                    honorific_title_keyname : String -> String
                                    honorific_title_keyname keyname =
                                        case keyname of
                                            "miss" ->
                                                honorific_title_keyname_miss

                                            "mister" ->
                                                honorific_title_keyname_mister

                                            _ ->
                                                ""
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with translation domains not directly mapping to valid elm module name" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "weird-domain": []
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.empty
                            }

                        expected =
                            Ok
                                { name = "Trans/WeirdDomain.elm"
                                , content = addEmptyLinesAtEnd 3 <| unindent """
                                    module Trans.WeirdDomain exposing (..)
                                        """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Handles env variables" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = unindent """
                                {
                                    "translations": {
                                        "fr": {
                                            "messages": {
                                                "env.variable": "une %variable% remplaçée"
                                            }
                                        }
                                    }
                                }
                                """
                            , envVariables = Dict.fromList [ ( "%variable%", "value" ) ]
                            }

                        expected =
                            Ok
                                { name = "Trans/Messages.elm"
                                , content = addOneEmptyLineAtEnd <| unindent """
                                    module Trans.Messages exposing (..)


                                    env_variable : String
                                    env_variable =
                                        "une value remplaçée"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            ]
        , describe "Failed conversion"
            [ test "Prints invalid json input" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = """{ "translations": { "fr": { "messages": { "button.validate.global" "Ok" } } } }"""
                            , envVariables = Dict.empty
                            }

                        expected =
                            Err <| unindent """
                                Problem with the given value:

                                "{ \\"translations\\": { \\"fr\\": { \\"messages\\": { \\"button.validate.global\\" \\"Ok\\" } } } }"

                                This is not valid JSON! Expected ':' after property name in JSON at position 67
                                """
                    in
                    Expect.equal expected (transpileToElm input)
            ]
        ]
