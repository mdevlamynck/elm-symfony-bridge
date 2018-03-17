module TransParser exposing (..)

import Json.Decode exposing (decodeString, dict, string)
import Dict exposing (Dict)
import Char
import Result
import Result.Extra as Result
import Parser exposing (..)
import Parser.LanguageKit exposing (..)
import Data exposing (..)


alternativesP : Parser (List Alternative)
alternativesP =
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
    succeed Alternative
        |= appliesToP
        |= messageP


appliesToP : Parser (List Range)
appliesToP =
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
    in
        succeed Range
            |= oneOf [ lowInf, lowValue ]
            |. spacesP
            |. symbol ","
            |. spacesP
            |= oneOf [ highInf, highValue ]


listValueP : Parser (List Range)
listValueP =
    sequence
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


messageP : Parser (List Chunk)
messageP =
    repeat (AtLeast 1) (oneOf [ placeholderP, textP ])
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


textP : Parser Chunk
textP =
    keep (Exactly 1) (\c -> c /= '|')
        |> map Text


placeholderP : Parser Chunk
placeholderP =
    succeed identity
        |. symbol "%"
        |= identifierP
        |. symbol "%"
        |> map Placeholder


identifierP : Parser String
identifierP =
    keep oneOrMore isIdentifierChar


isIdentifierChar : Char -> Bool
isIdentifierChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'
