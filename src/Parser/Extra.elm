module Parser.Extra exposing (stringsOrContainedP)

import Parser exposing (..)


stringsOrContainedP : Parser a -> { parsedTagger : a -> b, stringTagger : String -> b } -> Parser (List b)
stringsOrContainedP parser ({ parsedTagger, stringTagger } as config) =
    let
        constructor ( s, a ) list =
            if s == "" then
                parsedTagger a :: list

            else
                stringTagger s :: parsedTagger a :: list
    in
    oneOf
        [ backtrackable <|
            succeed constructor
                |= withLeadingRawStringP parser
                |= lazy (\_ -> stringsOrContainedP parser config)
        , succeed (parsedTagger >> List.singleton)
            |= parser
        ]


withLeadingRawStringP : Parser a -> Parser ( String, a )
withLeadingRawStringP parser =
    oneOf
        [ backtrackable <|
            succeed (\a -> ( "", a ))
                |= parser
        , succeed (\headString ( restString, a ) -> ( headString ++ restString, a ))
            |= getChompedString (chompIf (\_ -> True))
            |= lazy (\_ -> withLeadingRawStringP parser)
        ]
