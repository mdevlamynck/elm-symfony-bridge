module Translation.IntlIcu.TranspilerTest exposing (suite)

import Elm exposing (Version(..))
import Expect exposing (Expectation)
import Test exposing (..)
import Translation.Transpiler exposing (transpileToElm)
import Unindent exposing (..)


suite : Test
suite =
    describe "Converts a translation json to an elm module" <|
        [ describe "Successful conversion" <|
            [ test "Works with empty translation file" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": []
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with a null translation" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {"translation": null}
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {"translation": ""}
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "button.validate.global": "Ok",
                                                    "button.validate.save": "Enregistrer"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "boolean_false": false,
                                                    "boolean_true": true,
                                                    "float": 3.14,
                                                    "integer": 42
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "array": [42, 3.14, null],
                                                    "object": { "invalid": "invalid", "number": 42 },
                                                    "null": null,
                                                    "valid": "valid"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "page.error.503": "Error 503",
                                                    "form.step2.save": "Enregistrer"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "multiline.html.translation": "<a href=\\"{link}\\">\\n</a>\\n"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


                                    multiline_html_translation : { link : String } -> String
                                    multiline_html_translation params_ =
                                        \"\"\"<a href=\"\"\"\" ++ params_.link ++ \"\"\"\">
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
                            { name = ""
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "This value is not valid.": "Cette valeur n'est pas valide."
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "__name__label__": "__name__label__",
                                                    "9things": "9things"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


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
            , test "Works with translations containing raw variables" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "user.welcome": "Bonjour {firstname} {lastname} et bienvenu !"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


                                    user_welcome : { firstname : String, lastname : String } -> String
                                    user_welcome params_ =
                                        "Bonjour " ++ params_.firstname ++ " " ++ params_.lastname ++ " et bienvenu !"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with translations containing number variables" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "user.notifications": "{count, number} notifications non lues"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


                                    user_notifications : { count : Int } -> String
                                    user_notifications params_ =
                                        (fromInt params_.count) ++ " notifications non lues"
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , todo "Works with translations containing date variables"
            , todo "Works with translations containing time variables"
            , todo "Works with translations containing duration variables"
            , test "Works with translations containing select variables" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "global.expression.gender": "{gender, select, female {woman} male {man} other {person}}"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


                                    global_expression_gender : { gender : String } -> String
                                    global_expression_gender params_ =
                                        let
                                            var0 =
                                                case params_.gender of
                                                    "female" ->
                                                        "woman"

                                                    "male" ->
                                                        "man"

                                                    _ ->
                                                        "person"
                                        in
                                        var0
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , test "Works with translations containing plural variables" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content =
                                unindent
                                    """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages+intl-icu": {
                                                    "global.expression.photos": "{numPhotos, plural, =0{no photos} =1{one photo} other{# photos}}"
                                                }
                                            }
                                        }
                                    }
                                    """
                            , version = Elm_0_19
                            }

                        expected =
                            Ok
                                { name = "Trans/MessagesIntlIcu.elm"
                                , content = unindent """
                                    module Trans.MessagesIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int


                                    global_expression_photos : { numPhotos : Int } -> String
                                    global_expression_photos params_ =
                                        let
                                            var0 =
                                                case params_.numPhotos of
                                                    0 ->
                                                        "no photos"

                                                    1 ->
                                                        "one photo"

                                                    _ ->
                                                        (fromInt params_.numPhotos) ++ " photos"
                                        in
                                        var0
                                    """
                                }
                    in
                    Expect.equal expected (transpileToElm input)
            , todo "Works with translations containing plural variables with offset" -- <|

            --\_ ->
            --    let
            --        input =
            --            { name = ""
            --            , content =
            --                unindent
            --                    """
            --                    {
            --                        "translations": {
            --                            "fr": {
            --                                "messages+intl-icu": {
            --                                    "party.guests": "{numGuests, plural, offset:1 =0{no party} one{host and a guest} other{# guests}}"
            --                                }
            --                            }
            --                        }
            --                    }
            --                    """
            --            , version = Elm_0_19
            --            }
            --
            --        expected =
            --            Ok
            --                { name = "Trans/MessagesIntlIcu.elm"
            --                , content = unindent """
            --                    module Trans.MessagesIntlIcu exposing (..)
            --
            --
            --                    fromInt : Int -> String
            --                    fromInt int =
            --                        String.fromInt int
            --
            --
            --                    party_guests : { numGuests : Int } -> String
            --                    party_guests params_ =
            --                        let
            --                            var0 =
            --                                case params_.numGuests - 1 of
            --                                    0 ->
            --                                        "no party"
            --
            --                                    1 ->
            --                                        "host and a guest"
            --
            --                                    _ ->
            --                                        (fromInt <| params_.numGuests - 1) ++ " guests"
            --                        in
            --                        var0
            --                    """
            --                }
            --    in
            --    Expect.equal expected (transpileToElm input)
            , todo "Works with translations containing nested variables" -- <|

            --\_ ->
            --    let
            --        input =
            --            { name = ""
            --            , content =
            --                unindent
            --                    """
            --                    {
            --                        "translations": {
            --                            "fr": {
            --                                "messages+intl-icu": {
            --                                    "party.guests": "{gender_of_host, select,\\nfemale {{num_guests, plural, offset:1\\n=0    {{host} does not give a party.}\\n=1    {{host} invites {guest} to her party.}\\n=2    {{host} invites {guest} and one other person to her party.}\\nother {{host} invites {guest} and # other people to her party.}\\n}}\\nmale {{num_guests, plural, offset:1\\n=0    {{host} does not give a party.}\\n=1    {{host} invites {guest} to his party.}\\n=2    {{host} invites {guest} and one other person to his party.}\\nother {{host} invites {guest} and # other people to his party.}\\n}}\\nother {{num_guests, plural, offset:1\\n=0    {{host} does not give a party.}\\n=1    {{host} invites {guest} to their party.}\\n=2    {{host} invites {guest} and one other person to their party.}\\nother {{host} invites {guest} and # other people to their party.}\\n}}\\n}"
            --                                }
            --                            }
            --                        }
            --                    }
            --                    """
            --            , version = Elm_0_19
            --            }
            --
            --        expected =
            --            Ok
            --                { name = "Trans/MessagesIntlIcu.elm"
            --                , content = unindent """
            --                    module Trans.MessagesIntlIcu exposing (..)
            --
            --
            --                    fromInt : Int -> String
            --                    fromInt int =
            --                        String.fromInt int
            --
            --
            --                    party_guests : { gender_of_host : String, guest : String, host : String, num_guests : Int } -> String
            --                    party_guests params_ =
            --                        let
            --                            var0 =
            --                                case params_.gender_of_host of
            --                                    "female" ->
            --                                        let
            --                                            var1 =
            --                                                case (params_.num_guests - 1) of
            --                                                    0 ->
            --                                                        params_.host ++ " does not give a party."
            --
            --                                                    1 ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " to her party."
            --
            --                                                    2 ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " and one other person to her party."
            --
            --                                                    _ ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " and " ++ (fromInt <| params_.num_guests - 1) ++ " other people to her party."
            --                                        in
            --                                        var1
            --
            --                                    "male" ->
            --                                        let
            --                                            var1 =
            --                                                case (params_.num_guests - 1) of
            --                                                    0 ->
            --                                                        params_.host ++ " does not give a party."
            --
            --                                                    1 ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " to his party."
            --
            --                                                    2 ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " and one other person to his party."
            --
            --                                                    _ ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " and " ++ (fromInt <| params_.num_guests - 1) ++ " other people to his party."
            --                                        in
            --                                        var1
            --
            --                                    _ ->
            --                                        let
            --                                            var1 =
            --                                                case (params_.num_guests - 1) of
            --                                                    0 ->
            --                                                        params_.host ++ " does not give a party."
            --
            --                                                    1 ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " to their party."
            --
            --                                                    2 ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " and one other person to their party."
            --
            --                                                    _ ->
            --                                                        params_.host ++ " invites " ++ params_.guest ++ " and " ++ (fromInt <| params_.num_guests - 1) ++ " other people to their party."
            --                                        in
            --                                        var1
            --                        in
            --                        var0
            --                    """
            --                }
            --    in
            --    Expect.equal expected (transpileToElm input)
            ]
        , test "Works with translation domains not directly mapping to valid elm module name" <|
            \_ ->
                let
                    input =
                        { name = ""
                        , content =
                            unindent
                                """
                                    {
                                        "translations": {
                                            "fr": {
                                                "weird-domain+intl-icu": []
                                            }
                                        }
                                    }
                                    """
                        , version = Elm_0_19
                        }

                    expected =
                        Ok
                            { name = "Trans/WeirdDomainIntlIcu.elm"
                            , content = unindent """
                                    module Trans.WeirdDomainIntlIcu exposing (..)


                                    fromInt : Int -> String
                                    fromInt int =
                                        String.fromInt int
                                    """
                            }
                in
                Expect.equal expected (transpileToElm input)
        , describe "Failed conversion" <|
            [ test "Prints invalid json input" <|
                \_ ->
                    let
                        input =
                            { name = ""
                            , content = """{ "translations": { "fr": { "messages+intl-icu": { "button.validate.global" "Ok" } } } }"""
                            , version = Elm_0_19
                            }

                        expected =
                            Err <|
                                unindent
                                    """
                                    Problem with the given value:

                                    "{ \\"translations\\": { \\"fr\\": { \\"messages+intl-icu\\": { \\"button.validate.global\\" \\"Ok\\" } } } }"

                                    This is not valid JSON! Unexpected string in JSON at position 76
                                    """
                    in
                    Expect.equal expected (transpileToElm input)
            ]
        ]
