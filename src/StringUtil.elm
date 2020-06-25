module StringUtil exposing (indent, splitOn)

{-| Extra tools on strings.

@docs indent, splitOn

-}

import List.Extra exposing (dropWhile, span, takeWhile)


{-| Add one level of indentation (4 spaces) to the given string.

    indent "test\n    testing"
    --> "    test\n        testing"

-}
indent : String -> String
indent lines =
    String.lines lines
        |> List.map
            (\l ->
                if String.length l > 0 then
                    "    " ++ l

                else
                    ""
            )
        |> String.join "\n"


{-| Split a string on separator (skipping the separators) using a predicate to detect separators.

    splitOn ((==) ' ') " some  words "
    --> ["some", "words"]

-}
splitOn : (Char -> Bool) -> String -> List String
splitOn predicate string =
    let
        rec chars =
            if List.isEmpty chars then
                []

            else
                let
                    firstPart =
                        takeWhile (not << predicate) chars

                    remainingParts =
                        chars
                            |> dropWhile (not << predicate)
                            |> dropWhile predicate
                            |> rec
                in
                if List.isEmpty firstPart then
                    remainingParts

                else
                    String.fromList firstPart :: remainingParts
    in
    rec (String.toList string)
