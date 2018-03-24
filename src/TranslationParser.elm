module TranslationParser exposing (parseAlternatives)

{-| Parser for a Translation

@docs parseAlternatives

-}

import Char
import Result
import List.Extra as List
import List.Unique
import Parser exposing (..)
import Parser.LanguageKit exposing (..)
import Data exposing (..)
import StringUtil exposing (indent)
import Unindent exposing (unindent)


-- Public


{-| Runs the Translation parser on the given string
-}
parseAlternatives : String -> Result String (List Alternative)
parseAlternatives input =
    Parser.run alternativesP input
        >> Result.mapError formatError



-- Error handling


{-| Turns an Error into a beautifull error message
-}
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


{-| Converts nested BadOneOf Problems into a single BadOneOf
-}
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


{-| Renders a Problem into a user friendly message

Works better with flattened BadOneOf Problems, use with flattenOneOf.

-}
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
                    "the end of input"

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
            BadOneOf list ->
                "Expected " ++ (formatOne problem) ++ "."

            _ ->
                "Expected " ++ (formatOne problem) ++ "."


{-| Render when possible a helpfull message to help diagnose the error and provide context.
-}
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

        ( "a list of values", Fail "a non empty list of values" ) ->
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

        ( "a pluralization", Fail "at least two pluralizations" ) ->
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

        ( "a translation", BadOneOf [ Fail "at least two pluralizations", ExpectingEnd ] ) ->
            unindent """
            Hint:
                It seems that either a pluralization is invalid or that a simple message contains a "|".
            """

        _ ->
            ""



-- Parsers


{-| Parses a Translation
-}
alternativesP : Parser (List Alternative)
alternativesP =
    inContext "a translation" <|
        oneOf
            [ pluralizationP
            , singleMessageP
            ]


{-| Parses a Translation as a list of Alternavites
-}
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
            |> failIf
                (\l -> List.length l < 2)
                "at least two pluralizations"
        )


{-| Parses spaces
-}
spacesP : Parser ()
spacesP =
    ignore zeroOrMore ((==) ' ')


{-| Parses a single Alternative
-}
alternativeP : Parser Alternative
alternativeP =
    inContext "a message in a translation with pluralization" <|
        succeed Alternative
            |= appliesToP
            |= messageP


{-| Parses an Alternative prefix (the appliesTo bloc:)
-}
appliesToP : Parser (List Range)
appliesToP =
    inContext "a block specifying when to apply the message" <|
        oneOf
            [ rangeP |> map List.singleton
            , listValueP
            ]


{-| Parses a Range
-}
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


{-| Parses a list of Ranges as a list of values
-}
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
            |> failIf List.isEmpty "a non empty list of values"
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


{-| Parses a Translation as a single message
-}
singleMessageP : Parser (List Alternative)
singleMessageP =
    inContext "a single message"
        (delayedCommitMap (\chunks _ -> Alternative [] chunks) messageP end
            |> map List.singleton
        )


{-| Parses a message
-}
messageP : Parser (List Chunk)
messageP =
    inContext "a message"
        (repeat (AtLeast 1) (oneOf [ placeholderP, textP ])
            |> map
                (List.foldr
                    (\elem acc ->
                        case ( elem, acc ) of
                            ( Text elem, (Text t) :: tail ) ->
                                Text (elem ++ t) :: tail

                            ( elem, acc ) ->
                                elem :: acc
                    )
                    []
                )
        )


{-| Parses a single character of a Text Chunk
-}
textP : Parser Chunk
textP =
    inContext "pure text"
        (keep (Exactly 1) ((/=) '|')
            |> map Text
        )


{-| Parses a placeholder of a Chunk
-}
placeholderP : Parser Chunk
placeholderP =
    inContext "a placeholder"
        (succeed identity
            |. symbol "%"
            |= identifierP
            |. symbol "%"
            |> map Placeholder
        )


{-| Parses an identifier (ex: a variable name)
-}
identifierP : Parser String
identifierP =
    keep oneOrMore isIdentifierChar


{-| Is the given Char allowed to appear in in identifier
-}
isIdentifierChar : Char -> Bool
isIdentifierChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'


{-| Make a parser fail with the given message if the given predicate is True
-}
failIf : (a -> Bool) -> String -> Parser a -> Parser a
failIf predicate message =
    Parser.andThen <|
        \value ->
            if predicate value then
                fail message
            else
                succeed value
