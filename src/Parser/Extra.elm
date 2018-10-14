module Parser.Extra exposing (chomp, oneOf)

import Parser exposing (..)


chomp : Int -> Parser ()
chomp n =
    if n <= 1 then
        chompIf (\_ -> True)

    else
        chompIf (\_ -> True) |. chomp (n - 1)


oneOf : List (Parser a) -> Parser a
oneOf parsers =
    Parser.oneOf <| List.map backtrackable parsers
