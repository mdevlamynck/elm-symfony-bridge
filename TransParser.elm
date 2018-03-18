module TransParser exposing (..)

import Json.Decode exposing (decodeString, dict, string)
import Dict exposing (Dict)
import Char
import Result
import Result.Extra as Result
import List.Extra as List
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
            formatProblem error.problem

        hint =
            formatHint context.description error.problem
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
                                |> (\s -> s ++ ".")
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
                "Failed: " ++ fail ++ "."

            BadOneOf list ->
                "Expected " ++ (formatOne problem)

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

        _ ->
            ""


alternativesP : Parser (List Alternative)
alternativesP =
    inContext "a translation" <|
        oneOf
            [ sequence
                { start = ""
                , end = ""
                , separator = "|"
                , spaces = spacesP
                , item = alternativeP
                , trailing = Forbidden
                }
                |> Parser.andThen
                    (\s ->
                        if List.isEmpty s then
                            fail "empty sequence"
                        else
                            succeed s
                    )
            , messageP
                |> map
                    (\m ->
                        [ { chunks = m
                          , appliesTo = []
                          }
                        ]
                    )
            ]


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
    inContext "a list of value"
        (sequence
            { start = "{"
            , end = "}"
            , separator = ","
            , spaces = spacesP
            , item = int
            , trailing = Forbidden
            }
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
        (keep (Exactly 1) (\c -> c /= '|')
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
