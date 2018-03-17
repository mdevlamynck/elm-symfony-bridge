module UnindentTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Unindent exposing (unindent)


suite : Test
suite =
    describe "Unindents multiline strings" <|
        [ test "Removes leading spaces on every lines up to the first character of the first line" <|
            \_ ->
                let
                    input =
                        """
                        {
                            "button.validate.global": "Ok",
                            "button.validate.save": "Enregistrer"
                        }
                        """

                    expected =
                        """{
    "button.validate.global": "Ok",
    "button.validate.save": "Enregistrer"
}"""
                in
                    Expect.equal expected (unindent input)
        , test "Handles first line without line return" <|
            \_ ->
                let
                    input =
                        """{
                            "button.validate.global": "Ok",
                            "button.validate.save": "Enregistrer"
                        }
                        """

                    expected =
                        """{
                            "button.validate.global": "Ok",
                            "button.validate.save": "Enregistrer"
                        }"""
                in
                    Expect.equal expected (unindent input)
        , test "Handles last line without line return" <|
            \_ ->
                let
                    input =
                        """
                        {
                            "button.validate.global": "Ok",
                            "button.validate.save": "Enregistrer"
                        }"""

                    expected =
                        """{
    "button.validate.global": "Ok",
    "button.validate.save": "Enregistrer"
}"""
                in
                    Expect.equal expected (unindent input)
        , test "NoOp on empty string" <|
            \_ -> Expect.equal "" (unindent "")
        ]
