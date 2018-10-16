module Translation.Parser exposing (parseTranslationContent)

{-| Parser for a TranslationContent

@docs parseTranslationContent

-}

import Char
import Hex
import List.Extra as List
import List.Unique
import Parser exposing (..)
import Parser.Extra exposing (chomp, oneOf)
import Result
import Result.Extra as Result
import StringUtil exposing (indent)
import Translation.Data exposing (..)
import Unindent exposing (unindent)



-- Public


{-| Runs the TranslationContent parser on the given string
-}
parseTranslationContent : String -> Result String TranslationContent
parseTranslationContent input =
    Parser.run translation input
        |> Result.mapError (\_ -> "Failed to parse translation")



---- Domain parser


translation : Parser TranslationContent
translation =
    oneOf
        [ pluralizedMessage
        , singleMessage
        ]


pluralizedMessage : Parser TranslationContent
pluralizedMessage =
    succeed PluralizedMessage
        |= sequenceAtLeastTwoElements
            { item = pluralMessageVariant
            , separator = '|'
            , spaces = spaces
            }


singleMessage : Parser TranslationContent
singleMessage =
    succeed SingleMessage
        |= messageChunks


pluralMessageVariant : Parser Alternative
pluralMessageVariant =
    succeed Alternative
        |= appliesTo
        |= messageChunks


appliesTo : Parser AppliesTo
appliesTo =
    oneOf
        [ appliesToInterval
        , appliesToIndexed
        ]


{-| Parses an AppliesTo in its interval form
-}
appliesToInterval : Parser AppliesTo
appliesToInterval =
    oneOf
        [ interval
        , listValue
        ]


{-| Parses an AppliesTo in its indexed form
-}
appliesToIndexed : Parser AppliesTo
appliesToIndexed =
    succeed Indexed
        |. oneOf
            [ label
            , succeed ""
            ]


{-| Parses an Interval
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
                |= oneOf
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
                |= oneOf
                    [ succeed Included
                        |. symbol "]"
                    , succeed Excluded
                        |. symbol "["
                    ]

        lowInterval =
            oneOf [ lowInclusive, lowExclusive ]

        highInterval =
            oneOf [ highInf, highValue ]
    in
    succeed (\low high -> Interval low high |> List.singleton |> Intervals)
        |= lowInterval
        |. spaces
        |. symbol ","
        |. spaces
        |= highInterval


{-| Parses a list of Intervals as a list of values
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


{-| Parses label
-}
label : Parser String
label =
    backtrackable <|
        succeed identity
            |= (getChompedString <| chompWhile isLabelChar)
            |. symbol ":"


{-| Parses a message TODO
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
                oneOf
                    [ succeed (\parsed -> Loop <| parsed :: revList)
                        |= variable
                    , succeed (merge revList >> Loop)
                        |= getChompedString (chomp 1)
                    , succeed (Done <| List.reverse revList)
                    ]
            )


{-| Parses a variable of a Chunk
-}
variable : Parser Chunk
variable =
    let
        variableConstructor varName =
            if varName == "count" then
                VariableCount

            else if List.member varName [ "if", "then", "else", "case", "of", "let", "in", "type", "module", "where", "import", "exposing", "as", "port" ] then
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


{-| Is the given Char allowed to appear in a variable
-}
isVariableChar : Char -> Bool
isVariableChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_' || c == '-'


{-| Is the given Char allowed to appear in a label
-}
isLabelChar : Char -> Bool
isLabelChar c =
    Char.isLower c



---- Basic parsers


{-| Parses spaces
-}
spaces : Parser ()
spaces =
    chompWhile (\c -> c == ' ')


integer : Parser Int
integer =
    oneOf
        [ int
        , succeed ((*) -1)
            |. symbol "-"
            |= int
        ]



---- Utils parsers


sequenceAtLeastTwoElements :
    { item : Parser item
    , separator : Char
    , spaces : Parser ()
    }
    -> Parser (List item)
sequenceAtLeastTwoElements config =
    succeed (::)
        |= (backtrackable <|
                succeed identity
                    |= itemInSequence
                        { item = config.item
                        , separator = config.separator
                        }
                    |. chompIf ((==) '|')
                    |. config.spaces
           )
        |= lazy
            (\_ ->
                oneOf
                    [ sequenceAtLeastTwoElements config
                    , succeed List.singleton
                        |= config.item
                    ]
            )


itemInSequence :
    { item : Parser item
    , separator : Char
    }
    -> Parser item
itemInSequence { item, separator } =
    chompWhile ((/=) separator)
        |> getChompedString
        |> andThen
            (\content ->
                case Parser.run item content of
                    Ok parsedItem ->
                        succeed parsedItem

                    Err _ ->
                        problem ""
            )


{-| Makes a parser fail if the given predicate is True
-}
failIf : (a -> Bool) -> Parser a -> Parser a
failIf predicate =
    Parser.andThen <|
        \value ->
            if predicate value then
                problem ""

            else
                succeed value
