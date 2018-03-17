module MainTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Main exposing (output)
import Unindent exposing (..)


suite : Test
suite =
    describe "Converts a translation json to an elm module" <|
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
                            if False then
                                ""
                            else if True && choice < 0 then
                                "Negative"
                            else if choice >= 0 && True then
                                "Positive"
                            else
                                ""


                        user_notifications : Int -> { count : String } -> String
                        user_notifications choice { count } =
                            if False then
                                ""
                            else if choice >= 0 && choice <= 0 then
                                "Pas de notification"
                            else if choice >= 1 && choice <= 1 then
                                count ++ " notification non lue"
                            else if choice >= 2 && True then
                                count ++ " notifications non lues"
                            else
                                ""
                        """
                in
                    Expect.equal expected (output [ input ])
        ]
