module StringUtil exposing (indent)


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
