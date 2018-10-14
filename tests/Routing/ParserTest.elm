module Routing.ParserTest exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, string)
import Routing.Parser exposing (parsePathContent)
import Test exposing (..)


longString : String
longString =
    String.fromList <| List.repeat 100000 'a'


suite : Test
suite =
    describe "Parser"
        [ test "Handles very long strings" <|
            \_ ->
                Expect.ok (parsePathContent longString)
        ]
