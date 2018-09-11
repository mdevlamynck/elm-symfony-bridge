module Translation.Parser exposing (parseTranslationContent)

{-| Parser for a TranslationContent

@docs parseTranslationContent

-}

import Char
import List.Extra as List
import List.Unique
import Parser exposing (..)
import Result
import String.Extra as String
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
    commitWhenComplete <|
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
    succeed Interval
        |= lowInterval
        |. spaces
        |. symbol ","
        |. spaces
        |= highInterval
        |> map (Intervals << List.singleton)


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
    delayedCommitFirst
        (keep oneOrMore isLabelChar)
        (symbol ":")


{-| Parses a message
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

                ( head, tail ) ->
                    head :: tail

        rec =
            oneOf
                [ succeed [ Text "" ]
                    |. end
                , succeed mergeText
                    |= oneOf
                        [ variable
                        , succeed Text
                            |= keep (Exactly 1) (\_ -> True)
                        ]
                    |= lazy (\_ -> rec)
                ]
    in
    succeed trim
        |= rec


{-| Parses a variable of a Chunk
-}
variable : Parser Chunk
variable =
    let
        variableConstructor variable =
            if variable == "count" then
                VariableCount

            else if List.member variable [ "if", "then", "else", "case", "of", "let", "in", "type", "module", "where", "import", "exposing", "as", "port" ] then
                Variable (variable ++ "_")

            else
                Variable (String.replace "-" "_" variable)
    in
    delayedCommitFirst
        (succeed variableConstructor
            |. symbol "%"
            |= keep (AtLeast 2) isVariableChar
            |. symbol "%"
        )
        (succeed ())



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
    ignore zeroOrMore ((==) ' ')


integer : Parser Int
integer =
    commitWhenComplete <|
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
sequenceAtLeastTwoElements ({ item, separator, spaces } as config) =
    delayedCommitMap (::)
        (succeed identity
            |= itemInSequence
                { item = item
                , separator = separator
                }
            |. ignore (Exactly 1) ((==) '|')
            |. spaces
        )
        (lazy
            (\_ ->
                oneOf
                    [ sequenceAtLeastTwoElements config
                    , succeed List.singleton
                        |= item
                    ]
            )
        )


itemInSequence :
    { item : Parser item
    , separator : Char
    }
    -> Parser item
itemInSequence { item, separator } =
    keep zeroOrMore ((/=) separator)
        |> andThen
            (\content ->
                case Parser.run item content of
                    Ok item ->
                        succeed item

                    Err _ ->
                        fail ""
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


delayedCommitFirst : Parser a -> Parser b -> Parser a
delayedCommitFirst parserKeep parserIgnore =
    delayedCommitMap (\keep _ -> keep)
        parserKeep
        parserIgnore


commitWhenComplete : Parser a -> Parser a
commitWhenComplete parserKeep =
    delayedCommitFirst parserKeep (succeed ())


{-| Makes a parser fail if the given predicate is True
-}
failIf : (a -> Bool) -> Parser a -> Parser a
failIf predicate =
    Parser.andThen <|
        \value ->
            if predicate value then
                fail ""

            else
                succeed value
