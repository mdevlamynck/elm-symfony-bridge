module StringUtil exposing (indent)

{-| Extra tools on strings.

@docs indent

-}


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
