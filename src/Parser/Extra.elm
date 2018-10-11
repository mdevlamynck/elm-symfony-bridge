module Parser.Extra exposing (chomp, oneOf, stringsOrContainedP)

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
        [ succeed constructor
            |= withLeadingRawStringP parser
            |= lazy (\_ -> stringsOrContainedP parser config)
        , succeed (parsedTagger >> List.singleton)
            |= parser
        ]


withLeadingRawStringP : Parser a -> Parser ( String, a )
withLeadingRawStringP parser =
    oneOf
        [ succeed (\a -> ( "", a ))
            |= parser
        , succeed (\headString ( restString, a ) -> ( headString ++ restString, a ))
            |= getChompedString (chomp 1)
            |= lazy (\_ -> withLeadingRawStringP parser)
        ]


chomp : Int -> Parser ()
chomp n =
    if n <= 1 then
        chompIf (\_ -> True)

    else
        chompIf (\_ -> True) |. chomp (n - 1)


oneOf : List (Parser a) -> Parser a
oneOf parsers =
    Parser.oneOf <| List.map backtrackable parsers
