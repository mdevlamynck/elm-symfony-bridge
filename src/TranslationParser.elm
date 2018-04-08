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

        errorMessage =
            "Error while parsing "
                ++ context.description
                ++ " ("
                ++ (toString error.col)
                ++ ", "
                ++ (toString error.row)
                ++ "):"

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
        , [ errorMessage
          , [ source, sourceErrorPointer ]
                |> String.join "\n"
                |> indent
          , problem
          , hint
          ]
            |> List.filter (not << ((==) ""))
            |> List.intersperse ""
            |> String.join "\n"
            |> indent
        ]
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
        ( "an interval's low side", BadInt ) ->
            unindent """
            Hint if the input is [-Inf:
                In an interval's low side, [-Inf is invalid as Inf is always exclusive.
                Try ]-Inf instead."
            """

        ( "an interval's high side", ExpectingSymbol "[" ) ->
            unindent """
            Hint if the input is Inf]:
                In an interval's high side, Inf] is invalid as Inf is always exclusive.
                Try Inf[ instead."
            """

        ( "an interval's high side", BadOneOf [ ExpectingSymbol "]", ExpectingSymbol "[" ] ) ->
            unindent """
            Hint:
                Intervals can only contain two values, a low and a high bound.
            """

        ( "an interval", ExpectingSymbol "," ) ->
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

        _ ->
            ""



-- Parsers


{-| Parses a TranslationContent
-}
alternativesP : Parser TranslationContent
alternativesP =
    let
        alternativesConstructor alternatives =
            case alternatives of
                alternative :: [] ->
                    SingleMessage alternative.chunks

                alternatives ->
                    PluralizedMessage alternatives
    in
        inContext "a translation" <|
            succeed alternativesConstructor
                |= sequence
                    { start = ""
                    , end = ""
                    , separator = "|"
                    , spaces = spacesP
                    , item = alternativeP
                    , trailing = Forbidden
                    }
                |. end


{-| Parses spaces
-}
spacesP : Parser ()
spacesP =
    ignore zeroOrMore ((==) ' ')


{-| Parses a single Alternative
-}
alternativeP : Parser Alternative
alternativeP =
    inContext "a message in a translation" <|
        succeed Alternative
            |. spacesP
            |= oneOf
                [ appliesToIntervalP
                , appliesToIndexedP
                ]
            |. spacesP
            |= messageP
            |. spacesP


{-| Parses an AppliesTo in its interval form
-}
appliesToIntervalP : Parser AppliesTo
appliesToIntervalP =
    inContext "a block specifying when to apply the message" <|
        oneOf
            [ intervalP
            , listValueP
            ]


{-| Parses an AppliesTo in its indexed form
-}
appliesToIndexedP : Parser AppliesTo
appliesToIndexedP =
    succeed Indexed
        |. oneOf
            [ labelP
            , succeed ""
            ]


{-| Parses an Interval
-}
intervalP : Parser AppliesTo
intervalP =
    let
        lowInclusive =
            succeed Included
                |. symbol "["
                |. spacesP
                |= int

        lowExclusive =
            succeed identity
                |. symbol "]"
                |. spacesP
                |= oneOf
                    [ succeed Inf
                        |. symbol "-Inf"
                    , succeed Excluded
                        |= int
                    ]

        highInf =
            succeed Inf
                |. keyword "Inf"
                |. spacesP
                |. symbol "["

        highValue =
            succeed (|>)
                |= int
                |. spacesP
                |= oneOf
                    [ succeed Included
                        |. symbol "]"
                    , succeed Excluded
                        |. symbol "["
                    ]

        lowIntervalP =
            inContext "an interval's low side" <|
                oneOf [ lowInclusive, lowExclusive ]

        highIntervalP =
            inContext "an interval's high side" <|
                oneOf [ highInf, highValue ]
    in
        inContext "an interval"
            (succeed Interval
                |= lowIntervalP
                |. spacesP
                |. symbol ","
                |. spacesP
                |= highIntervalP
                |> map (Intervals << List.singleton)
            )


{-| Parses a list of Intervals as a list of values
-}
listValueP : Parser AppliesTo
listValueP =
    let
        listValueConstructor =
            List.sort
                >> List.map
                    (\v ->
                        { low = Included v
                        , high = Included v
                        }
                    )
                >> Intervals
    in
        inContext "a list of values" <|
            succeed listValueConstructor
                |= (sequence
                        { start = "{"
                        , end = "}"
                        , separator = ","
                        , spaces = spacesP
                        , item = int
                        , trailing = Forbidden
                        }
                        |> failIf List.isEmpty "a non empty list of values"
                   )


{-| Parses a message
-}
messageP : Parser (List Chunk)
messageP =
    let
        messageConstructor =
            List.foldr
                (\elem acc ->
                    case ( elem, acc ) of
                        ( elem, (Text " ") :: [] ) ->
                            [ elem ]

                        ( Text elem, (Text t) :: tail ) ->
                            Text (elem ++ t) :: tail

                        ( elem, acc ) ->
                            elem :: acc
                )
                []
    in
        inContext "a message" <|
            succeed messageConstructor
                |= repeat (AtLeast 1) (oneOf [ variableP, textP ])


{-| Parses a single character of a Text Chunk
-}
textP : Parser Chunk
textP =
    inContext "pure text" <|
        succeed Text
            |= keep (Exactly 1) ((/=) '|')


{-| Parses a variable of a Chunk
-}
variableP : Parser Chunk
variableP =
    let
        variableConstructor variable =
            if variable == "count" then
                VariableCount
            else
                Variable variable
    in
        inContext "a variable" <|
            succeed variableConstructor
                |. symbol "%"
                |= keep oneOrMore isIdentifierChar
                |. symbol "%"


{-| Parses label
-}
labelP : Parser String
labelP =
    inContext "a label" <|
        delayedCommitMap (\label _ -> label)
            (keep oneOrMore isLabelChar)
            (symbol ":")


{-| Is the given Char allowed to appear in an identifier
-}
isIdentifierChar : Char -> Bool
isIdentifierChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'


{-| Is the given Char allowed to appear in a label
-}
isLabelChar : Char -> Bool
isLabelChar c =
    Char.isLower c


{-| Makes a parser fail with the given message if the given predicate is True
-}
failIf : (a -> Bool) -> String -> Parser a -> Parser a
failIf predicate message =
    Parser.andThen <|
        \value ->
            if predicate value then
                fail message
            else
                succeed value
