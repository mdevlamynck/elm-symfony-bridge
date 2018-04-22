module Routing.TranspilerTest exposing (..)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer, int, list, string)
import Test exposing (..)
import Unindent exposing (..)
import Routing.Transpiler exposing (transpileToElm)


suite : Test
suite =
    todo "Converts a routing json to an elm module"
