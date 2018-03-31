module TranslationParser exposing (parseTranslationContent)

{-| Parser for a TranslationContent

@docs parseTranslationContent

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


{-| Runs the TranslationContent parser on the given string
-}
parseTranslationContent : String -> Result String TranslationContent
parseTranslationContent input =
    Parser.run alternativesP input
        |> Result.mapError formatError



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
        ( "a interval's low side", BadInt ) ->
            unindent """
            Hint if the input is [Inf:
                In a interval's low side, [Inf is invalid as Inf is always exclusive.
                Try ]Inf instead."
            """

        ( "a interval's high side", ExpectingSymbol "[" ) ->
            unindent """
            Hint if the input is Inf]:
                In a interval's high side, Inf] is invalid as Inf is always exclusive.
                Try Inf[ instead."
            """

        ( "a interval's high side", BadOneOf [ ExpectingSymbol "]", ExpectingSymbol "[" ] ) ->
            unindent """
            Hint:
                Intervals can only contain two values, a low and a high bound.
            """

        ( "a interval", ExpectingSymbol "," ) ->
            unindent """
            Hint:
                Intervals must contain two values, a low and a high bound.
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
                If this is a single message, try removing the prefix (the interval or
                the list of values). Otherwise add at least another variant.
            """

        ( "a block specifying when to apply the message", BadOneOf [ ExpectingSymbol "]", ExpectingSymbol "[", ExpectingSymbol "{" ] ) ->
            unindent """
            Hint:
                It seems a pluralization is missing either a interval or a list of values
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


{-| Parses a TranslationContent
-}
alternativesP : Parser TranslationContent
alternativesP =
    inContext "a translation" <|
        oneOf
            [ pluralizedMessageP
            , singleMessageP
            ]


{-| Parses a TranslationContent as a PluralizedMessage
-}
pluralizedMessageP : Parser TranslationContent
pluralizedMessageP =
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
            |> map PluralizedMessage
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


{-| Parses an Alternative prefix (the appliesTo block)
-}
appliesToP : Parser (List Interval)
appliesToP =
    inContext "a block specifying when to apply the message" <|
        oneOf
            [ intervalP |> map List.singleton
            , listValueP
            ]


{-| Parses a Interval
-}
intervalP : Parser Interval
intervalP =
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

        lowIntervalP =
            inContext "a interval's low side" <|
                oneOf [ lowInf, lowValue ]

        highIntervalP =
            inContext "a interval's high side" <|
                oneOf [ highInf, highValue ]
    in
        inContext "a interval" <|
            succeed Interval
                |= lowIntervalP
                |. spacesP
                |. symbol ","
                |. spacesP
                |= highIntervalP


{-| Parses a list of Intervals as a list of values
-}
listValueP : Parser (List Interval)
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


{-| Parses a TranslationContent as a SingleMessage
-}
singleMessageP : Parser TranslationContent
singleMessageP =
    inContext "a single message" <|
        delayedCommitMap (\chunks _ -> SingleMessage chunks) messageP end


{-| Parses a message
-}
messageP : Parser (List Chunk)
messageP =
    inContext "a message"
        (repeat (AtLeast 1) (oneOf [ variableP, textP ])
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


{-| Parses a variable of a Chunk
-}
variableP : Parser Chunk
variableP =
    inContext "a variable"
        (succeed identity
            |. symbol "%"
            |= identifierP
            |. symbol "%"
            |> map
                (\variable ->
                    if variable == "count" then
                        VariableCount
                    else
                        Variable variable
                )
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
