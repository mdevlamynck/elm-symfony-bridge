module StringUtilTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import StringUtil exposing (indent)
import Test exposing (..)
import Unindent exposing (unindent)


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
