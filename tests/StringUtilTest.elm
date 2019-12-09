module StringUtilTest exposing (suite)

import Expect exposing (Expectation)
import StringUtil exposing (indent)
import Test exposing (..)


suite : Test
suite =
    test "Add 4 spaces at the beginning of every line" <|
        \_ ->
            let
                input =
                    "test\n    test\ntest\n"

                expected =
                    "    test\n        test\n    test\n"
            in
            Expect.equal expected (indent input)
