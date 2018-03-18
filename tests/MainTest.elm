module MainTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Main exposing (output)
import Unindent exposing (..)


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
                                "button.validate.global": "Ok",
                                "button.validate.save": "Enregistrer"
                            }
                            """

                        expected =
                            unindent """
                            module Trans exposing (..)


                            button_validate_global : String
                            button_validate_global =
                                "Ok"


                            button_validate_save : String
                            button_validate_save =
                                "Enregistrer"
                            """
                    in
                        Expect.equal expected (output [ input ])
            , test "Works with translations containing placeholders" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "user.notifications": "%count% notifications non lues",
                                "user.welcome": "Bonjour %firstname% %lastname% et bienvenu !"
                            }
                            """

                        expected =
                            unindent """
                            module Trans exposing (..)


                            user_notifications : { count : String } -> String
                            user_notifications { count } =
                                count ++ " notifications non lues"


                            user_welcome : { firstname : String, lastname : String } -> String
                            user_welcome { firstname, lastname } =
                                "Bonjour " ++ firstname ++ " " ++ lastname ++ " et bienvenu !"
                            """
                    in
                        Expect.equal expected (output [ input ])
            , test "Works with alternatives translations containing placeholders" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "user.notifications": "{0}Pas de notification|{1}%count% notification non lue|[2, Inf[%count% notifications non lues",
                                "user.account.balance": "]Inf, 0[Negative|[0, Inf[Positive"
                            }
                            """

                        expected =
                            unindent """
                            module Trans exposing (..)


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
                    in
                        Expect.equal expected (output [ input ])
            ]
        , describe "Failed conversion" <|
            [ test "Prints invalid json input" <|
                \_ ->
                    let
                        input =
                            unindent """
                            {
                                "button.validate.global" "Ok"
                            }
                            """

                        expected =
                            unindent "Given an invalid JSON: Unexpected string in JSON at position 31"
                    in
                        Expect.equal expected (output [ input ])
            , describe "Prints invalid message format" <|
                [ describe "Invalid ranges" <|
                    [ test "Invalid range's low side [Inf" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "user.account.balance": "[Inf, 0[Negative|[0, Inf[Positive"
                                    }
                                    """

                                expected =
                                    unindent """
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
                                Expect.equal expected (output [ input ])
                    , test "Invalid range's high side Inf]" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "user.account.balance": "]Inf, 0[Negative|[0, Inf]Positive"
                                    }
                                    """

                                expected =
                                    unindent """
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
                                Expect.equal expected (output [ input ])
                    , test "Missing ," <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "user.account.balance": "]Inf 0[Negative|[0, Inf]Positive"
                                    }
                                    """

                                expected =
                                    unindent """
                                    Failed to parse a translation.

                                    Error while parsing a range:

                                        ]Inf 0[Negative|[0, Inf]Positive
                                             ^

                                    Expected the symbol ",".

                                    Hint:
                                        Ranges must contain two values, a low and a high bound.
                                    """
                            in
                                Expect.equal expected (output [ input ])
                    , test "Too many values" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "user.account.balance": "]Inf, 0, 1[Negative|[0, Inf]Positive"
                                    }
                                    """

                                expected =
                                    unindent """
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
                                Expect.equal expected (output [ input ])
                    , test "Missing values" <|
                        \_ ->
                            let
                                input =
                                    unindent """
                                    {
                                        "user.account.balance": "[0]Negative|[0, Inf]Positive"
                                    }
                                    """

                                expected =
                                    unindent """
                                    Failed to parse a translation.

                                    Error while parsing a range:

                                        [0]Negative|[0, Inf]Positive
                                          ^

                                    Expected the symbol ",".

                                    Hint:
                                        Ranges must contain two values, a low and a high bound.
                                    """
                            in
                                Expect.equal expected (output [ input ])
                    ]
                ]
            ]
        ]
