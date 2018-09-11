module Unindent exposing (unindent)

{-| Unindents a multiline string to allow you to embed code (like json) in elm.

@docs unindent

-}

import List.Extra as List


{-| Unindents a multiline string to allow you to embed code (like json) in elm.

It removes indentation on every lines up to the first character of the first line.
Leading and trailing empty lines are removed.

    let
        jsonWithUnindent =
            unindent """
            {
                "some": "json value",
                "embedded": "in your elm code"
            }
            """

        jsonWithoutUnindent =
            "{\n    \"some\": \"json value\",\n    \"embedded\": \"in your elm code\"\n}"
    in
        jsonWithUnindent == jsonWithoutUnindent

    --> True

-}
unindent : String -> String
unindent text =
    let
        textTrimmedFromEmptyLines =
            text
                |> String.lines
                |> List.dropWhile (String.toList >> List.all ((==) ' '))
                |> List.dropWhileRight (String.toList >> List.all ((==) ' '))

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
