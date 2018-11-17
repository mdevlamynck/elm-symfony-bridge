module Parser.Extra exposing (chomp, oneOf)

{-| Common functions used in the different parsers.

@docs chomp, oneOf

-}

import Parser exposing (..)


{-| A parser that chomp n characters unconditionally.
-}
chomp : Int -> Parser ()
chomp n =
    if n <= 1 then
        chompIf (\_ -> True)

    else
        chompIf (\_ -> True) |. chomp (n - 1)


{-| Redefines oneOf to make all variants backtrackable for simplicity.
-}
oneOf : List (Parser a) -> Parser a
oneOf =
    List.map backtrackable >> Parser.oneOf
