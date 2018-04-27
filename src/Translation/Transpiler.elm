module Translation.Transpiler exposing (transpileToElm, File)

{-| Converts a JSON containing translations from Symfony
and turn them into an elm file.

@docs transpileToElm, File

-}

import Char
import Dict exposing (Dict)
import Elm exposing (..)
import Json.Decode as Decode exposing (decodeString, oneOf, list, dict, string)
import List.Unique
import Result
import Result.Extra as Result
import String.Extra as String
import Translation.Data exposing (..)
import Translation.Parser as Parser


{-| Represents a file
-}
type alias File =
    { name : String
    , content : String
    }


{-| Converts a JSON containing translations to an Elm file
-}
transpileToElm : String -> Result String File
transpileToElm =
    readJsonContent
        >> Result.andThen parseTranslationDomain
        >> Result.map convertToElm


{-| Represents the content of a JSON translation file
-}
type alias JsonTranslationDomain =
    { lang : String
    , domain : String
    , translations : Dict String String
    }


{-| A parsed translation file
-}
type alias TranslationDomain =
    { lang : String
    , domain : String
    , translations : List Translation
    }


{-| Extracts from the given JSON the domain and the translations
-}
readJsonContent : String -> Result String JsonTranslationDomain
readJsonContent =
    decodeString
        (dict
            (dict
                (dict
                    (oneOf
                        [ list string |> Decode.map (\_ -> Dict.empty)
                        , dict string
                        ]
                    )
                )
            )
        )
        >> Result.andThen
            (Dict.get "translations"
                >> Maybe.andThen dictFirst
                >> Maybe.andThen
                    (\( lang, translations ) ->
                        translations
                            |> dictFirst
                            |> Maybe.map
                                (\( domain, translations ) ->
                                    JsonTranslationDomain lang domain translations
                                )
                    )
                >> Result.fromMaybe "No translations found in this JSON"
            )


dictFirst : Dict comparable value -> Maybe ( comparable, value )
dictFirst =
    Dict.toList >> List.head


{-| Parses the translations into use usable type
-}
parseTranslationDomain : JsonTranslationDomain -> Result String TranslationDomain
parseTranslationDomain { lang, domain, translations } =
    translations
        |> Dict.toList
        |> List.map parseTranslation
        |> Result.combine
        |> Result.map
            (\translations ->
                { lang = lang
                , domain = String.toSentenceCase domain
                , translations = translations
                }
            )


{-| Turns a TranslationDomain into its elm representation
-}
convertToElm : TranslationDomain -> File
convertToElm { lang, domain, translations } =
    { name = "Trans/" ++ domain ++ ".elm"
    , content = renderElmModule <| Module ("Trans." ++ domain) (List.map (translationToElm lang) translations)
    }


{-| Parses the raw translation into a Translation
-}
parseTranslation : ( String, String ) -> Result String Translation
parseTranslation ( name, message ) =
    Parser.parseTranslationContent message
        |> Result.map
            (\translationContent ->
                { name = formatName name
                , variables = extractVariables translationContent
                , content = translationContent
                }
            )


{-| Format the name of a translation to match elm rules on function name
-}
formatName : String -> String
formatName name =
    let
        convertChar c =
            if Char.isLower c || Char.isUpper c || Char.isDigit c then
                Char.toLower c
            else
                '_'
    in
        name
            |> String.toList
            |> List.map convertChar
            |> String.fromList


{-| Extracts the list of variables used in the TranslationContent
-}
extractVariables : TranslationContent -> List String
extractVariables translationContent =
    let
        chunks =
            case translationContent of
                SingleMessage chunks ->
                    chunks

                PluralizedMessage alternatives ->
                    alternatives
                        |> List.concatMap .chunks
    in
        chunks
            |> List.filterMap
                (\e ->
                    case e of
                        Variable v ->
                            Just v

                        _ ->
                            Nothing
                )
            |> List.Unique.filterDuplicates


{-| Turns a translation into an elm function
-}
translationToElm : String -> Translation -> Function
translationToElm lang translation =
    let
        arguments =
            count ++ record

        count =
            if hasCountVariable translation.content then
                [ Primitive "Int" "count" ]
            else
                []

        recordArgs =
            List.map (\arg -> ( "String", arg )) translation.variables

        record =
            if recordArgs == [] then
                []
            else
                [ Record recordArgs ]
    in
        Function translation.name arguments "String" (translationContentToElm lang translation.content)


{-| Does a TranslationContent contains a `count` variable
-}
hasCountVariable : TranslationContent -> Bool
hasCountVariable translationContent =
    case translationContent of
        SingleMessage chunks ->
            chunks
                |> List.any ((==) VariableCount)

        PluralizedMessage _ ->
            True


{-| Turns a TranslationContent into the body of an elm function
-}
translationContentToElm : String -> TranslationContent -> Expr
translationContentToElm lang translationContent =
    case translationContent of
        SingleMessage chunks ->
            Expr (combineChunks chunks)

        PluralizedMessage alternatives ->
            Ifs (alternativesToElm lang alternatives)


alternativesToElm : String -> List Alternative -> List ( Expr, Expr )
alternativesToElm lang alternatives =
    alternatives
        |> List.foldl
            alternativeToElm
            ( indexedConditions lang, [] )
        |> Tuple.second


{-| Indexed variant application conditions depending on the lang.

Source: <https://github.com/symfony/translation/blob/master/PluralizationRules.php>

-}
indexedConditions : String -> List Expr
indexedConditions lang =
    if List.member lang [ "az", "bo", "dz", "id", "ja", "jv", "ka", "km", "kn", "ko", "ms", "th", "tr", "vi", "zh" ] then
        [ Expr ("True") ]
    else if List.member lang [ "af", "bn", "bg", "ca", "da", "de", "el", "en", "eo", "es", "et", "eu", "fa", "fi", "fo", "fur", "fy", "gl", "gu", "ha", "he", "hu", "is", "it", "ku", "lb", "ml", "mn", "mr", "nah", "nb", "ne", "nl", "nn", "no", "om", "or", "pa", "pap", "ps", "pt", "so", "sq", "sv", "sw", "ta", "te", "tk", "ur", "zu" ] then
        [ Expr ("count == 1"), Expr ("True") ]
    else if List.member lang [ "am", "bh", "fil", "fr", "gun", "hi", "hy", "ln", "mg", "nso", "xbr", "ti", "wa" ] then
        [ Expr ("count == 0 || count == 1"), Expr ("True") ]
    else if List.member lang [ "be", "bs", "hr", "ru", "sr", "uk" ] then
        [ Expr ("count % 10 == 1 && count % 100 /= 11"), Expr ("count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)"), Expr "True" ]
    else if List.member lang [ "cs", "sk" ] then
        [ Expr ("count == 1"), Expr ("count >= 2 && count <= 4"), Expr "True" ]
    else if List.member lang [ "ga" ] then
        [ Expr ("count == 1"), Expr ("count == 2"), Expr "True" ]
    else if List.member lang [ "lt" ] then
        [ Expr ("count % 10 == 1 && count % 100 /= 11"), Expr ("count % 10 >= 2 && (count % 100 < 10 || count % 100 >= 20)"), Expr "True" ]
    else if List.member lang [ "sl" ] then
        [ Expr ("count % 100 == 1"), Expr ("count % 100 == 2"), Expr ("count % 100 == 3 || count % 100 == 4"), Expr "True" ]
    else if List.member lang [ "mk" ] then
        [ Expr ("count % 10 == 1"), Expr "True" ]
    else if List.member lang [ "mt" ] then
        [ Expr ("count == 1"), Expr ("count == 0 || count % 100 > 1 && count % 100 < 11"), Expr ("count % 100 > 10 && count % 100 < 20"), Expr "True" ]
    else if List.member lang [ "lv" ] then
        [ Expr ("count == 0"), Expr ("count % 10 == 1 && count % 100 /= 11"), Expr "True" ]
    else if List.member lang [ "pl" ] then
        [ Expr ("count == 1"), Expr ("count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 12 || count % 100 > 14)"), Expr "True" ]
    else if List.member lang [ "cy" ] then
        [ Expr ("count == 1"), Expr ("count == 2"), Expr ("count == 8 || count == 11"), Expr "True" ]
    else if List.member lang [ "ro" ] then
        [ Expr ("count == 1"), Expr ("count == 0 || (count % 100 > 0 && count % 100 < 20)"), Expr "True" ]
    else if List.member lang [ "ar" ] then
        [ Expr ("count == 0"), Expr ("count == 1"), Expr ("count == 2"), Expr ("count % 100 >= 3 && count % 100 <= 10"), Expr ("count % 100 >= 11 && count % 100 <= 99"), Expr "True" ]
    else
        [ Expr "True" ]


alternativeToElm : Alternative -> ( List Expr, List ( Expr, Expr ) ) -> ( List Expr, List ( Expr, Expr ) )
alternativeToElm { appliesTo, chunks } ( indexedCondition, content ) =
    case appliesTo of
        Intervals intervals ->
            ( indexedCondition
            , content ++ [ ( Expr (combineIntervals intervals), Expr (combineChunks chunks) ) ]
            )

        Indexed ->
            case indexedCondition of
                head :: tail ->
                    ( tail
                    , content ++ [ ( head, Expr (combineChunks chunks) ) ]
                    )

                [] ->
                    ( []
                    , content ++ [ ( Expr "False", Expr (combineChunks chunks) ) ]
                    )


{-| Turns a list of Intervals into an elm expression usable in a if
-}
combineIntervals : List Interval -> String
combineIntervals intervals =
    case intervals of
        head :: [] ->
            intervalToCondExpr head

        intervals ->
            let
                conditions =
                    intervals
                        |> List.map intervalToCondExpr
                        |> String.join ") || ("
            in
                "(" ++ conditions ++ ")"


{-| Turns a Interval into an elm expression usable in a if
-}
intervalToCondExpr : Interval -> String
intervalToCondExpr interval =
    let
        isLowEqualToHigh =
            case ( interval.low, interval.high ) of
                ( Included low, Included high ) ->
                    if low == high then
                        Just <| "count == " ++ (toString low)
                    else
                        Nothing

                _ ->
                    Nothing

        lowBound =
            case interval.low of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "count >= " ++ (toString bound)

                Excluded bound ->
                    Just <| "count > " ++ (toString bound)

        highBound =
            case interval.high of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "count <= " ++ (toString bound)

                Excluded bound ->
                    Just <| "count < " ++ (toString bound)
    in
        case ( isLowEqualToHigh, lowBound, highBound ) of
            ( Just value, _, _ ) ->
                value

            ( _, Just low, Just high ) ->
                low ++ " && " ++ high

            ( _, Just low, Nothing ) ->
                low

            ( _, Nothing, Just high ) ->
                high

            _ ->
                "True"


{-| Turns a list of Chunks into an elm expression usable in the body of a function
-}
combineChunks : List Chunk -> String
combineChunks =
    List.map chunkToString >> String.join " ++ "


{-| Turns a Chunk into an elm expression usable in the body of a function
-}
chunkToString : Chunk -> String
chunkToString chunk =
    let
        escape =
            String.replace "\"" "\\\""
    in
        case chunk of
            Text text ->
                "\"\"\"" ++ (escape text) ++ "\"\"\""

            Variable variable ->
                variable

            VariableCount ->
                "(toString count)"
