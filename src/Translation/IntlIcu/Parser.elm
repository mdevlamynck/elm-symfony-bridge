module Translation.IntlIcu.Parser exposing (..)

import Parser exposing (..)
import Parser.Extra exposing (..)
import Translation.IntlIcu.Data exposing (..)


parseTranslationContent : String -> Result String Chunks
parseTranslationContent input =
    run chunks input
        |> Result.mapError (\_ -> "Failed to parse translation")


chunks : Parser Chunks
chunks =
    many chunk


chunk : Parser Chunk
chunk =
    map (replaceShorthand Nothing) <|
        oneOfBacktrackable
            [ shorthand
            , variable
            , text
            ]


text : Parser Chunk
text =
    succeed Text
        |= string


shorthand : Parser Chunk
shorthand =
    succeed (Var <| Variable "#" (Number Nothing))
        |. symbol "#"


variable : Parser Chunk
variable =
    succeed Var
        |= (succeed Variable
                |. symbol "{"
                |. spaces
                |= variableName
                |= variableType
                |. spaces
                |. symbol "}"
           )


variableName : Parser String
variableName =
    ensureProgress <| getChompedString <| chompWhile isVariableChar


variableType : Parser Type
variableType =
    oneOfBacktrackable
        [ typeBasic
        , typeSelect
        , typePlural
        , typeRaw
        ]


typeRaw : Parser Type
typeRaw =
    succeed Raw


typeBasic : Parser Type
typeBasic =
    succeed (<|)
        |. spaces
        |. symbol ","
        |. spaces
        |= oneOfBacktrackable
            [ succeed Number |. keyword "number"
            , succeed Date |. keyword "date"
            , succeed Time |. keyword "time"
            , succeed Duration |. keyword "duration"
            ]
        |= oneOfBacktrackable
            [ succeed Just
                |. spaces
                |. symbol ","
                |. spaces
                |= format
            , succeed Nothing
            ]


typeSelect : Parser Type
typeSelect =
    succeed Select
        |. spaces
        |. symbol ","
        |. spaces
        |. keyword "select"
        |. spaces
        |. symbol ","
        |= many selectVariant


selectVariant : Parser SelectVariant
selectVariant =
    succeed SelectVariant
        |. spaces
        |= oneOfBacktrackable
            [ succeed SelectOther |. keyword "other"
            , succeed SelectText |= getChompedString (chompWhile isPatternChar)
            ]
        |= variantValue


typePlural : Parser Type
typePlural =
    succeed Plural
        |. spaces
        |. symbol ","
        |. spaces
        |. oneOfBacktrackable
            [ keyword "plural"
            , keyword "selectordinal"
            ]
        |= pluralOptions
        |. spaces
        |= many pluralVariant


pluralOptions : Parser PluralOption
pluralOptions =
    oneOfBacktrackable
        [ succeed PluralOption
            |. spaces
            |. symbol ","
            |. spaces
            |. keyword "offset"
            |. symbol ":"
            |= int
        , succeed defaultPluralOption
            |. spaces
            |. symbol ","
        ]


pluralVariant : Parser PluralVariant
pluralVariant =
    succeed PluralVariant
        |. spaces
        |= oneOfBacktrackable
            [ succeed Value |. symbol "=" |= int
            , succeed Zero |. keyword "zero"
            , succeed One |. keyword "one"
            , succeed Two |. keyword "two"
            , succeed Few |. keyword "few"
            , succeed Many |. keyword "many"
            , succeed PluralOther |. keyword "other"
            ]
        |= variantValue


variantValue : Parser Chunks
variantValue =
    succeed identity
        |. spaces
        |. symbol "{"
        |= lazy (\() -> chunks)
        |. symbol "}"
        |. spaces


string : Parser String
string =
    map String.concat <|
        many <|
            oneOfBacktrackable
                [ escaped
                , getChompedString <|
                    chompWhile (\c -> not <| List.member c [ '{', '}', '#' ])
                ]


format : Parser String
format =
    map (String.trim << String.concat) <|
        many <|
            oneOfBacktrackable
                [ escaped
                , getChompedString <|
                    chompWhile ((/=) '}')
                ]


escaped : Parser String
escaped =
    oneOfBacktrackable
        [ emptyEscape
        , nonEmptyEscape
        ]


emptyEscape : Parser String
emptyEscape =
    succeed "'"
        |. chompIf ((==) '\'')
        |. chompIf ((==) '\'')


nonEmptyEscape : Parser String
nonEmptyEscape =
    succeed identity
        |. chompIf ((==) '\'')
        |= (getChompedString <| chompWhile ((/=) '\''))
        |. chompIf ((==) '\'')


spaces : Parser ()
spaces =
    chompWhile (\c -> List.member c (String.toList " \t\u{000D}\n\u{0085}\u{00A0}\u{180E}\u{2001}\u{2028}\u{2029}\u{202F}\u{205F}\u{2060}␋\u{3000}\u{FEFF}"))


isVariableChar : Char -> Bool
isVariableChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_' || c == '-'


isPatternChar : Char -> Bool
isPatternChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_' || c == '-'


replaceShorthand : Maybe String -> Chunk -> Chunk
replaceShorthand replaceWith c =
    let
        replaceShorthandInVariant replaceWith_ v =
            { v | value = List.map (replaceShorthand replaceWith_) v.value }
    in
    case c of
        Var var ->
            case ( replaceWith, var.name, var.type_ ) of
                ( Just name, "#", Number Nothing ) ->
                    Var { var | name = name }

                ( _, _, Select variants ) ->
                    Var { var | type_ = Select <| List.map (replaceShorthandInVariant replaceWith) variants }

                ( _, _, Plural opts variants ) ->
                    Var { var | type_ = Plural opts <| List.map (replaceShorthandInVariant (Just var.name)) variants }

                _ ->
                    Var var

        _ ->
            c
