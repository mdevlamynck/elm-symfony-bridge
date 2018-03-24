module TranspilerTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Unindent exposing (..)
import Transpiler exposing (transpileTranslationToElm)


suite : Test
suite =
    describe "Converts a translation json to an elm module" <|
        [ describe "Succeesfull conversion" <|
            [ test "Works with plain constant translations" <|
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
                                { name = "TransMessages.elm"
                                , content = unindent """
                                    module TransMessages exposing (..)


                                    button_validate_global : String
                                    button_validate_global =
                                        "Ok"


                                    button_validate_save : String
                                    button_validate_save =
                                        "Enregistrer"
                                    """
                                }
                    in
                        Expect.equal expected (transpileTranslationToElm input)
            , test "Works with translations containing placeholders" <|
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
                                { name = "TransMessages.elm"
                                , content = unindent """
                                    module TransMessages exposing (..)


                                    user_notifications : { count : String } -> String
                                    user_notifications { count } =
                                        count ++ " notifications non lues"


                                    user_welcome : { firstname : String, lastname : String } -> String
                                    user_welcome { firstname, lastname } =
                                        "Bonjour " ++ firstname ++ " " ++ lastname ++ " et bienvenu !"
                                    """
                                }
                    in
                        Expect.equal expected (transpileTranslationToElm input)
            , test "Works with alternatives translations containing placeholders" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "translations": {
                                    "fr": {
                                        "messages": {
                                            "user.notifications": "{0}Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues",
                                            "user.account.balance": "]Inf, 0[Negative|[0, Inf[Positive"
                                        }
                                    }
                                }
                            }
                            """

                        expected =
                            Ok
                                { name = "TransMessages.elm"
                                , content = unindent """
                                    module TransMessages exposing (..)


                                    user_account_balance : Int -> String
                                    user_account_balance choice =
                                        if choice < 0 then
                                            "Negative"
                                        else
                                            "Positive"


                                    user_notifications : Int -> { count : String } -> String
                                    user_notifications choice { count } =
                                        if choice == 0 then
                                            "Pas de notification"
                                        else if choice == 1 then
                                            count ++ " notification non lue"
                                        else
                                            count ++ " notifications non lues"
                                    """
                                }
                    in
                        Expect.equal expected (transpileTranslationToElm input)
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
                        Expect.equal expected (transpileTranslationToElm input)
            , describe "Prints invalid message format" <|
                [ describe "Invalid ranges" <|
                    [ test "Invalid range's low side [Inf" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.account.balance": "[Inf, 0[Negative|[0, Inf[Positive"
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

                                            Error while parsing a range's low side:

                                                [Inf, 0[Negative|[0, Inf[Positive
                                                 ^

                                            Expected a valid integer.

                                            Hint if the input is [Inf:
                                                In a range's low side, [Inf is invalid as Inf is always exclusive.
                                                Try ]Inf instead."
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Invalid range's high side Inf]" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.account.balance": "]Inf, 0[Negative|[0, Inf]Positive"
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

                                            Error while parsing a range's high side:

                                                ]Inf, 0[Negative|[0, Inf]Positive
                                                                        ^

                                            Expected the symbol "[".

                                            Hint if the input is Inf]:
                                                In a range's high side, Inf] is invalid as Inf is always exclusive.
                                                Try Inf[ instead."
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Missing ," <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.account.balance": "]Inf 0[Negative|[0, Inf]Positive"
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

                                            Error while parsing a range:

                                                ]Inf 0[Negative|[0, Inf]Positive
                                                     ^

                                            Expected the symbol ",".

                                            Hint:
                                                Ranges must contain two values, a low and a high bound.
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Too many values" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.account.balance": "]Inf, 0, 1[Negative|[0, Inf]Positive"
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

                                            Error while parsing a range's high side:

                                                ]Inf, 0, 1[Negative|[0, Inf]Positive
                                                       ^

                                            Expected one of:
                                                - the symbol "]";
                                                - the symbol "[".

                                            Hint:
                                                Ranges can only contain two values, a low and a high bound.
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Missing high value" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.account.balance": "[0]Negative|[0, Inf]Positive"
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

                                            Error while parsing a range:

                                                [0]Negative|[0, Inf]Positive
                                                  ^

                                            Expected the symbol ",".

                                            Hint:
                                                Ranges must contain two values, a low and a high bound.
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Missing values" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.account.balance": "[]Negative|[0, Inf]Positive"
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

                                            Error while parsing a range's low side:

                                                []Negative|[0, Inf]Positive
                                                 ^

                                            Expected a valid integer.

                                            Hint if the input is [Inf:
                                                In a range's low side, [Inf is invalid as Inf is always exclusive.
                                                Try ]Inf instead."
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Missing values with ," <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.account.balance": "[,]Negative|[0, Inf]Positive"
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

                                            Error while parsing a range's low side:

                                                [,]Negative|[0, Inf]Positive
                                                 ^

                                            Expected a valid integer.

                                            Hint if the input is [Inf:
                                                In a range's low side, [Inf is invalid as Inf is always exclusive.
                                                Try ]Inf instead."
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    ]
                , describe "Invalid list of values" <|
                    [ test "Empty list of values" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.notifications": "{}Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues"
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

                                            Error while parsing a list of values:

                                                {}Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues
                                                  ^

                                            Expected a non empty list of values.

                                            Hint:
                                                A list of values must contain at least one value
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Missing ," <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.notifications": "{0 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues"
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

                                            Error while parsing a list of values:

                                                {0 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues
                                                   ^

                                            Expected one of:
                                                - the symbol ",";
                                                - the symbol "}".

                                            Hint:
                                                The values must be separated by a ",".
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Invalid value in first position" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.notifications": "{Inf, 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues"
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

                                            Error while parsing a list of values:

                                                {Inf, 1}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues
                                                 ^

                                            Expected one of:
                                                - a valid integer;
                                                - the symbol "}".

                                            Hint:
                                                Only integer are allowed in a list of values.
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Invalid value" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.notifications": "{0, Inf}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues"
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

                                            Error while parsing a list of values:

                                                {0, Inf}Pas de notification|{2}%count% notification non lue|[3, Inf[%count% notifications non lues
                                                    ^

                                            Expected a valid integer.

                                            Hint:
                                                Only integer are allowed in a list of values.
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    ]
                , describe "Invalid pluralization" <|
                    [ test "Only one pluralization" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.notifications": "{0, 1}Pas de notification"
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

                                            Error while parsing a pluralization:

                                                {0, 1}Pas de notification
                                                                         ^

                                            Expected at least two pluralizations.

                                            Hint:
                                                Expected to be parsing a pluralization, found only one variant.
                                                If this is a single message, try removing the prefix (the range or
                                                the list of values). Otherwise add at least another variant.
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Missing prefix" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.notifications": "{0}Pas de notification|%count% notification non lue|[2, Inf[%count% notifications non lues"
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

                                            Error while parsing a block specifying when to apply the message:

                                                {0}Pas de notification|%count% notification non lue|[2, Inf[%count% notifications non lues
                                                                       ^

                                            Expected one of:
                                                - the symbol "]";
                                                - the symbol "[";
                                                - the symbol "{".

                                            Hint:
                                                It seems a pluralization is missing either a range or a list of values
                                                to specify when to apply this message.
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    , test "Missing prefix in the first message" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "translations": {
                                            "fr": {
                                                "messages": {
                                                    "user.notifications": "Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues"
                                                }
                                            }
                                        }
                                    }
                                    """

                                expected =
                                    Err <|
                                        unindent """
                                            Failed to parse a translation.

                                            Error while parsing a translation:

                                                Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues
                                                ^

                                            Expected one of:
                                                - at least two pluralizations;
                                                - the end of input.

                                            Hint:
                                                It seems that either a pluralization is invalid or that a simple message contains a "|".
                                            """
                            in
                                Expect.equal expected (transpileTranslationToElm input)
                    ]
                ]
            ]
        ]
