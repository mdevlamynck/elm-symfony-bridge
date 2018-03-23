module TranslationParser exposing (parseAlternatives)

import Char
import Result
import List.Extra as List
import List.Unique
import Parser exposing (..)
import Parser.LanguageKit exposing (..)
import Data exposing (..)
import StringUtil exposing (indent)
import Unindent exposing (unindent)


parseAlternatives : String -> Result String (List Alternative)
parseAlternatives input =
    Parser.run alternativesP input
        |> Result.mapError formatError


formatError : Error -> String
formatError error =
    let
        mainMessage =
            "Failed to parse a translation."

        context =
            error.context
                |> List.head
                |> Maybe.withDefault { row = error.row, col = error.col, description = "a translation" }

        specificError =
            "Error while parsing " ++ context.description ++ ":"

        source =
            error.source
                |> String.lines
                |> List.getAt (error.row - 1)
                |> Maybe.withDefault ""

        sourceErrorPointer =
            (String.repeat (error.col - 1) " ") ++ "^"

        problem =
            formatProblem <| flattenOneOf error.problem

        hint =
            formatHint context.description <| flattenOneOf error.problem
    in
        [ mainMessage
        , specificError
        , [ source, sourceErrorPointer ] |> String.join "\n" |> indent
        , problem
        , hint
        ]
            |> List.filter (not << ((==) ""))
            |> List.intersperse ""
            |> String.join "\n"


flattenOneOf : Problem -> Problem
flattenOneOf problem =
    let
        flatten problem =
            case problem of
                BadOneOf list ->
                    list
                        |> List.concatMap flatten

                error ->
                    [ error ]
    in
        case problem of
            (BadOneOf list) as badOneOf ->
                BadOneOf
                    (badOneOf
                        |> flatten
                        |> List.Unique.filterDuplicates
                    )

            error ->
                error


formatProblem : Problem -> String
formatProblem problem =
    let
        formatOne problem =
            case problem of
                BadOneOf list ->
                    "one of:\n"
                        ++ (list
                                |> List.map (\p -> "- " ++ formatOne p)
                                |> String.join ";\n"
                                |> indent
                           )

                BadInt ->
                    "a valid integer"

                BadFloat ->
                    "a valid float"

                BadRepeat ->
                    "a valid repeat"

                ExpectingEnd ->
                    "the end the input to parse"

                ExpectingSymbol symbol ->
                    "the symbol \"" ++ symbol ++ "\""

                ExpectingKeyword keyword ->
                    "the keyword \"" ++ keyword ++ "\""

                ExpectingVariable ->
                    "a variable"

                ExpectingClosing symbol ->
                    "the closing symbol \"" ++ symbol ++ "\""

                Fail fail ->
                    fail
    in
        case problem of
            Fail fail ->
                "Error: " ++ fail ++ "."

            BadOneOf list ->
                "Expected " ++ (formatOne problem) ++ "."

            _ ->
                "Expected " ++ (formatOne problem) ++ "."


formatHint : String -> Problem -> String
formatHint description problem =
    case ( description, problem ) of
        ( "a range's low side", BadInt ) ->
            unindent """
            Hint if the input is [Inf:
                In a range's low side, [Inf is invalid as Inf is always exclusive.
                Try ]Inf instead."
            """

        ( "a range's high side", ExpectingSymbol "[" ) ->
            unindent """
            Hint if the input is Inf]:
                In a range's high side, Inf] is invalid as Inf is always exclusive.
                Try Inf[ instead."
            """

        ( "a range's high side", BadOneOf [ ExpectingSymbol "]", ExpectingSymbol "[" ] ) ->
            unindent """
            Hint:
                Ranges can only contain two values, a low and a high bound.
            """

        ( "a range", ExpectingSymbol "," ) ->
            unindent """
            Hint:
                Ranges must contain two values, a low and a high bound.
            """

        ( "a list of values", Fail "empty list of values" ) ->
            unindent """
            Hint:
                A list of values must contain at least one value
            """

        ( "a list of values", BadOneOf [ ExpectingSymbol ",", ExpectingSymbol "}" ] ) ->
            unindent """
            Hint:
                The values must be separated by a ",".
            """

        ( "a list of values", BadOneOf [ BadInt, ExpectingSymbol "}" ] ) ->
            unindent """
            Hint:
                Only integer are allowed in a list of values.
            """

        ( "a list of values", BadInt ) ->
            unindent """
            Hint:
                Only integer are allowed in a list of values.
            """

        ( "a pluralization", Fail "at least two pluralizations are required" ) ->
            unindent """
            Hint:
                Expected to be parsing a pluralization, found only one variant.
                If this is a single message, try removing the prefix (the range or
                the list of values). Otherwise add at least another variant.
            """

        ( "a block specifying when to apply the message", BadOneOf [ ExpectingSymbol "]", ExpectingSymbol "[", ExpectingSymbol "{" ] ) ->
            unindent """
            Hint:
                It seems a pluralization is missing either a range or a list of values
                to specify when to apply this message.
            """

        _ ->
            ""


alternativesP : Parser (List Alternative)
alternativesP =
    inContext "a translation" <|
        oneOf
            [ pluralizationP
            , messageP
                |> map
                    (\m ->
                        [ { chunks = m
                          , appliesTo = []
                          }
                        ]
                    )
            ]


pluralizationP : Parser (List Alternative)
pluralizationP =
    inContext "a pluralization" <|
        (sequence
            { start = ""
            , end = ""
            , separator = "|"
            , spaces = spacesP
            , item = alternativeP
            , trailing = Forbidden
            }
            |> Parser.andThen
                (failIf
                    (\l -> List.length l <= 1)
                    "at least two pluralizations are required"
                )
        )


spacesP : Parser ()
spacesP =
    ignore zeroOrMore ((==) ' ')


alternativeP : Parser Alternative
alternativeP =
    inContext "a message in a translation with pluralization" <|
        succeed Alternative
            |= appliesToP
            |= messageP


appliesToP : Parser (List Range)
appliesToP =
    inContext "a block specifying when to apply the message" <|
        oneOf
            [ rangeP |> map List.singleton
            , listValueP
            ]


rangeP : Parser Range
rangeP =
    let
        lowInf =
            symbol "]"
                |. spacesP
                |. keyword "Inf"
                |> map (\_ -> Inf)

        highInf =
            keyword "Inf"
                |. spacesP
                |. symbol "["
                |> map (\_ -> Inf)

        lowValue =
            oneOf
                [ symbol "]" |> map (\_ -> Excluded)
                , symbol "[" |> map (\_ -> Included)
                ]
                |. spacesP
                |= int

        highValue =
            succeed (|>)
                |= int
                |= oneOf
                    [ symbol "]" |> map (\_ -> Included)
                    , symbol "[" |> map (\_ -> Excluded)
                    ]

        lowRangeP =
            inContext "a range's low side" <|
                oneOf [ lowInf, lowValue ]

        highRangeP =
            inContext "a range's high side" <|
                oneOf [ highInf, highValue ]
    in
        inContext "a range" <|
            succeed Range
                |= lowRangeP
                |. spacesP
                |. symbol ","
                |. spacesP
                |= highRangeP


listValueP : Parser (List Range)
listValueP =
    inContext "a list of values"
        (sequence
            { start = "{"
            , end = "}"
            , separator = ","
            , spaces = spacesP
            , item = int
            , trailing = Forbidden
            }
            |> Parser.andThen (failIf List.isEmpty "empty list of values")
            |> map
                (\list ->
                    list
                        |> List.sort
                        |> List.map
                            (\v ->
                                { low = Included v
                                , high = Included v
                                }
                            )
                )
        )


messageP : Parser (List Chunk)
messageP =
    inContext "a message"
        (repeat (AtLeast 1) (oneOf [ placeholderP, textP ])
            |> map
                (List.foldr
                    (\elem acc ->
                        case ( elem, acc ) of
                            ( Text elem, (Text t) :: tail ) ->
                                (Text (elem ++ t)) :: tail

                            ( elem, c :: tail ) ->
                                elem :: c :: tail

                            ( elem, acc ) ->
                                elem :: acc
                    )
                    []
                )
        )


textP : Parser Chunk
textP =
    inContext "pure text"
        (keep (Exactly 1) ((/=) '|')
            |> map Text
        )


placeholderP : Parser Chunk
placeholderP =
    inContext "a placeholder"
        (succeed identity
            |. symbol "%"
            |= identifierP
            |. symbol "%"
            |> map Placeholder
        )


identifierP : Parser String
identifierP =
    keep oneOrMore isIdentifierChar


isIdentifierChar : Char -> Bool
isIdentifierChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'


failIf : (a -> Bool) -> String -> a -> Parser a
failIf predicate message value =
    if predicate value then
        fail message
    else
        succeed value
