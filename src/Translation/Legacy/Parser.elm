module Translation.Legacy.Parser exposing (parseTranslationContent)

{-| Parser for a TranslationContent.

@docs parseTranslationContent

-}

import Char
import ElmOld
import Hex
import Parser exposing (..)
import Parser.Extra exposing (..)
import Result
import Result.Extra as Result
import Translation.Legacy.Data exposing (..)



-- Public


{-| Runs the TranslationContent parser on the given string.
-}
parseTranslationContent : String -> Result String TranslationContent
parseTranslationContent input =
    Parser.run translation input
        |> Result.mapError (\_ -> "Failed to parse translation")



---- Domain parser


{-| Parses a translation.
-}
translation : Parser TranslationContent
translation =
    oneOfBacktrackable
        [ pluralizedMessage
        , singleMessage
        ]


{-| Parses a translation containing several plural variants.
-}
pluralizedMessage : Parser TranslationContent
pluralizedMessage =
    succeed PluralizedMessage
        |= sequenceAtLeastTwoElements
            { item = pluralMessageVariant
            , separator = '|'
            , spaces = spaces
            }


{-| Parses a translation containing a single not pluralized message.
-}
singleMessage : Parser TranslationContent
singleMessage =
    succeed SingleMessage
        |= messageChunks


{-| Parses a single plural variant.
-}
pluralMessageVariant : Parser Alternative
pluralMessageVariant =
    succeed Alternative
        |= appliesTo
        |= messageChunks


{-| Parses an AppliesTo.
-}
appliesTo : Parser AppliesTo
appliesTo =
    oneOfBacktrackable
        [ interval
        , listValue
        , succeed Indexed
            |. oneOfBacktrackable
                [ label
                , succeed ""
                ]
        ]


{-| Parses an Interval.
-}
interval : Parser AppliesTo
interval =
    let
        lowInclusive =
            succeed Included
                |. symbol "["
                |. spaces
                |= integer

        lowExclusive =
            succeed identity
                |. symbol "]"
                |. spaces
                |= oneOfBacktrackable
                    [ succeed Inf
                        |. symbol "-Inf"
                    , succeed Excluded
                        |= integer
                    ]

        highInf =
            succeed Inf
                |. keyword "Inf"
                |. spaces
                |. symbol "["

        highValue =
            succeed (|>)
                |= integer
                |. spaces
                |= oneOfBacktrackable
                    [ succeed Included
                        |. symbol "]"
                    , succeed Excluded
                        |. symbol "["
                    ]

        lowInterval =
            oneOfBacktrackable [ lowInclusive, lowExclusive ]

        highInterval =
            oneOfBacktrackable [ highInf, highValue ]
    in
    succeed (\low high -> Interval low high |> List.singleton |> Intervals)
        |= lowInterval
        |. spaces
        |. symbol ","
        |. spaces
        |= highInterval


{-| Parses a list of Intervals as a list of values.
-}
listValue : Parser AppliesTo
listValue =
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
    succeed listValueConstructor
        |= (sequence
                { start = "{"
                , end = "}"
                , separator = ","
                , spaces = spaces
                , item = integer
                , trailing = Forbidden
                }
                |> failIf List.isEmpty
           )


{-| Parses label.
-}
label : Parser String
label =
    backtrackable <|
        succeed identity
            |= (getChompedString <| chompWhile isLabelChar)
            |. symbol ":"


{-| Parses a translation content.
-}
messageChunks : Parser (List Chunk)
messageChunks =
    let
        merge list string =
            case list of
                (Text constant) :: rest ->
                    Text (constant ++ string) :: rest

                _ ->
                    Text string :: list

        trim chunks =
            chunks
                |> List.indexedMap
                    (\index chunk ->
                        if List.length chunks == 1 then
                            mapText String.trim chunk

                        else if index == 0 then
                            mapText String.trimLeft chunk

                        else if index == List.length chunks - 1 then
                            mapText String.trimRight chunk

                        else
                            chunk
                    )
                |> List.filter
                    (\value ->
                        case value of
                            Text "" ->
                                False

                            _ ->
                                True
                    )
    in
    succeed trim
        |= loop []
            (\revList ->
                oneOfBacktrackable
                    [ succeed (\parsed -> Loop <| parsed :: revList)
                        |= variable
                    , succeed (merge revList >> Loop)
                        |= getChompedString (chomp 1)
                    , succeed (Done <| List.reverse revList)
                    ]
            )


{-| Parses a variable of a Chunk.
-}
variable : Parser Chunk
variable =
    let
        variableConstructor varName =
            if varName == "count" then
                VariableCount

            else if List.member varName ElmOld.keywords then
                Variable (varName ++ "_")

            else
                Variable (String.replace "-" "_" varName)
    in
    backtrackable
        (succeed variableConstructor
            |. symbol "%"
            |= getChompedString
                (succeed ()
                    |. chompIf isVariableChar
                    |. chompIf isVariableChar
                    |. chompWhile isVariableChar
                )
            |. symbol "%"
            |> andThen
                (\var ->
                    case var of
                        Variable varName ->
                            let
                                frontVarName =
                                    varName
                                        |> String.left 2
                                        |> String.filter (\c -> Char.isUpper c || Char.isDigit c)
                                        |> String.toLower
                            in
                            if String.length frontVarName == 2 && Result.isOk (Hex.fromString frontVarName) then
                                problem "percent encoded (a.k.a. url encoded) value, not a variable"

                            else
                                succeed var

                        _ ->
                            succeed var
                )
        )



---- Domain utils


{-| Is the given Char allowed to appear in a variable.
-}
isVariableChar : Char -> Bool
isVariableChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_' || c == '-'


{-| Is the given Char allowed to appear in a label.
-}
isLabelChar : Char -> Bool
isLabelChar c =
    Char.isLower c



---- Basic parsers


{-| Parses spaces.
-}
spaces : Parser ()
spaces =
    chompWhile (\c -> c == ' ')


{-| Parses both positive and negative integers.
-}
integer : Parser Int
integer =
    oneOfBacktrackable
        [ int
        , succeed ((*) -1)
            |. symbol "-"
            |= int
        ]
