module Translation.Parser exposing (parseTranslationContent)

{-| Parser for a TranslationContent

@docs parseTranslationContent

-}

import Char
import List.Extra as List
import List.Unique
import Parser exposing (..)
import Parser.Extra exposing (chomp, oneOf)
import Result
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

        mergeText : Chunk -> List Chunk -> List Chunk
        mergeText head tail =
            case ( head, tail ) of
                ( Text t1, (Text t2) :: rest ) ->
                    Text (t1 ++ t2) :: rest

                ( head_, tail_ ) ->
                    head_ :: tail_

        rec _ =
            oneOf
                [ succeed [ Text "" ]
                    |. end
                , succeed mergeText
                    |= oneOf
                        [ variable
                        , succeed Text
                            |= (getChompedString <| chomp 1)
                        ]
                    |= lazy rec
                ]
    in
    succeed trim
        |= rec ()


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
    backtrackable <|
        succeed variableConstructor
            |. symbol "%"
            |= getChompedString
                (succeed ()
                    |. chompIf isVariableChar
                    |. chompIf isVariableChar
                    |. chompWhile isVariableChar
                )
            |. symbol "%"



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


repeat : Parser a -> Parser (List a)
repeat parser =
    succeed (::)
        |= parser
        |= lazy
            (\_ ->
                oneOf
                    [ end |> map (\_ -> [])
                    , repeat parser
                    , succeed []
                    ]
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
