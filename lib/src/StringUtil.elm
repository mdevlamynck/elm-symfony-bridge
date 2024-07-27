module StringUtil exposing
    ( indent, splitOn
    , trimEmptyLines, unindent
    )

{-| Extra tools on strings.

@docs indent, splitOn

-}

import List.Extra as List exposing (dropWhile, takeWhile)


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


{-| Unindents a multiline string to allow you to embed code (like json) in elm.

It removes indentation on every lines up to the first character of the first line.
Leading and trailing empty lines are removed.

    jsonWithUnindent : String
    jsonWithUnindent =
        unindent """
        {
            "some": "json value",
            "embedded": "in your elm code"
        }
        """

    jsonWithoutUnindent : String
    jsonWithoutUnindent =
        "{\n    \"some\": \"json value\",\n    \"embedded\": \"in your elm code\"\n}"

    jsonWithUnindent == jsonWithoutUnindent
    --> True

-}
unindent : String -> String
unindent text =
    let
        textTrimmedFromEmptyLines =
            text
                |> String.lines
                |> trimList (String.toList >> List.all ((==) ' '))

        nbCharToDrop =
            textTrimmedFromEmptyLines
                |> List.head
                |> Maybe.withDefault ""
                |> String.toList
                |> List.takeWhile ((==) ' ')
                |> List.length
    in
    textTrimmedFromEmptyLines
        |> List.map (String.dropLeft nbCharToDrop)
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


{-| -}
trimEmptyLines : String -> String
trimEmptyLines text =
    text
        |> String.lines
        |> trimList (String.toList >> List.all ((==) ' '))
        |> String.join "\n"


trimList : (a -> Bool) -> List a -> List a
trimList predicate list =
    list
        |> List.dropWhile predicate
        |> List.dropWhileRight predicate
