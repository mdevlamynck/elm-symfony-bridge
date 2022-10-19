module Translation.Legacy.Transpiler exposing (keynameTranslations, parseTranslation, translationToElm)

import Dict exposing (Dict)
import Dict.Extra as Dict
import Elm
import Elm.Annotation
import Elm.Case
import ElmOld exposing (..)
import List.Unique
import Result
import String.Extra as String
import Translation.Legacy.Data exposing (..)
import Translation.Legacy.Parser as Parser


{-| Parses the raw translation into a Translation.
-}
parseTranslation : ( String, String ) -> Result String Translation
parseTranslation ( name, message ) =
    Parser.parseTranslationContent message
        |> Result.map
            (\translationContent ->
                { name = name
                , variables = extractVariables translationContent
                , content = translationContent
                }
            )


{-| Extracts the list of variables used in the TranslationContent.
-}
extractVariables : TranslationContent -> List String
extractVariables translationContent =
    let
        chunks =
            case translationContent of
                SingleMessage chunks_ ->
                    chunks_

                PluralizedMessage alternatives ->
                    alternatives
                        |> List.concatMap .chunks

                Keyname _ ->
                    []
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


{-| Turns a translation into an elm function.
-}
translationToElm : String -> Translation -> Elm.Declaration
translationToElm lang translation =
    Elm.declaration translation.name <|
        case translation.content of
            SingleMessage chunks ->
                Elm.string ""

            PluralizedMessage alternatives ->
                Elm.string ""

            Keyname variants ->
                Elm.fn ( "keyname", Just Elm.Annotation.string ) <|
                    \keyname ->
                        Elm.Case.string keyname
                            { cases = List.map (\( k, v ) -> ( k, Elm.apply (Elm.val v) [] )) variants
                            , otherwise = Elm.string ""
                            }



--let
--    arguments =
--        count ++ record
--
--    count =
--        if hasCountVariable translation.content then
--            [ Primitive "Int" "count" ]
--
--        else
--            []
--
--    recordArgs =
--        translation.variables
--            |> List.map (\arg -> ( arg, "String" ))
--            |> Dict.fromList
--
--    record =
--        if Dict.isEmpty recordArgs then
--            []
--
--        else
--            [ Record recordArgs ]
--in
--    Elm.fn
--        Function
--        translation.name
--        arguments
--        "String"
--        (translationContentToElm lang translation.content)


{-| Does a TranslationContent contains a `count` variable?
-}
hasCountVariable : TranslationContent -> Bool
hasCountVariable translationContent =
    case translationContent of
        SingleMessage chunks ->
            chunks
                |> List.any ((==) VariableCount)

        PluralizedMessage _ ->
            True

        Keyname _ ->
            False


{-| Does a TranslationContent contains a `keyname` variable?
-}
hasKeynameVariable : TranslationContent -> Bool
hasKeynameVariable translationContent =
    case translationContent of
        Keyname _ ->
            True

        _ ->
            False



--{-| Turns a TranslationContent into the body of an elm function.
---}
--translationContentToElm : String -> TranslationContent -> Expr
--translationContentToElm lang translationContent =
--    case translationContent of
--        SingleMessage chunks ->
--            Expr (combineChunks chunks)
--
--        PluralizedMessage alternatives ->
--            Ifs
--                (alternatives
--                    |> List.foldl alternativeToElm ( indexedConditions lang, [] )
--                    |> Tuple.second
--                )


{-| Indexed variant application conditions depending on the lang.

Source: <https://github.com/symfony/translation/blob/master/PluralizationRules.php>

-}
indexedConditions : String -> List Expr
indexedConditions lang =
    if List.member lang [ "az", "bo", "dz", "id", "ja", "jv", "ka", "km", "kn", "ko", "ms", "th", "tr", "vi", "zh" ] then
        [ Expr "True" ]

    else if List.member lang [ "af", "bn", "bg", "ca", "da", "de", "el", "en", "eo", "es", "et", "eu", "fa", "fi", "fo", "fur", "fy", "gl", "gu", "ha", "he", "hu", "is", "it", "ku", "lb", "ml", "mn", "mr", "nah", "nb", "ne", "nl", "nn", "no", "om", "or", "pa", "pap", "ps", "pt", "so", "sq", "sv", "sw", "ta", "te", "tk", "ur", "zu" ] then
        [ Expr "count == 1", Expr "True" ]

    else if List.member lang [ "am", "bh", "fil", "fr", "gun", "hi", "hy", "ln", "mg", "nso", "xbr", "ti", "wa" ] then
        [ Expr "count == 0 || count == 1", Expr "True" ]

    else if List.member lang [ "be", "bs", "hr", "ru", "sr", "uk" ] then
        [ Expr "count % 10 == 1 && count % 100 /= 11", Expr "count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)", Expr "True" ]

    else if List.member lang [ "cs", "sk" ] then
        [ Expr "count == 1", Expr "count >= 2 && count <= 4", Expr "True" ]

    else if List.member lang [ "ga" ] then
        [ Expr "count == 1", Expr "count == 2", Expr "True" ]

    else if List.member lang [ "lt" ] then
        [ Expr "count % 10 == 1 && count % 100 /= 11", Expr "count % 10 >= 2 && (count % 100 < 10 || count % 100 >= 20)", Expr "True" ]

    else if List.member lang [ "sl" ] then
        [ Expr "count % 100 == 1", Expr "count % 100 == 2", Expr "count % 100 == 3 || count % 100 == 4", Expr "True" ]

    else if List.member lang [ "mk" ] then
        [ Expr "count % 10 == 1", Expr "True" ]

    else if List.member lang [ "mt" ] then
        [ Expr "count == 1", Expr "count == 0 || count % 100 > 1 && count % 100 < 11", Expr "count % 100 > 10 && count % 100 < 20", Expr "True" ]

    else if List.member lang [ "lv" ] then
        [ Expr "count == 0", Expr "count % 10 == 1 && count % 100 /= 11", Expr "True" ]

    else if List.member lang [ "pl" ] then
        [ Expr "count == 1", Expr "count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 12 || count % 100 > 14)", Expr "True" ]

    else if List.member lang [ "cy" ] then
        [ Expr "count == 1", Expr "count == 2", Expr "count == 8 || count == 11", Expr "True" ]

    else if List.member lang [ "ro" ] then
        [ Expr "count == 1", Expr "count == 0 || (count % 100 > 0 && count % 100 < 20)", Expr "True" ]

    else if List.member lang [ "ar" ] then
        [ Expr "count == 0", Expr "count == 1", Expr "count == 2", Expr "count % 100 >= 3 && count % 100 <= 10", Expr "count % 100 >= 11 && count % 100 <= 99", Expr "True" ]

    else
        [ Expr "True" ]


{-| Turns a pluralization variant into an elm expression.
-}
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


{-| Turns a list of Intervals into an elm expression usable in a if.
-}
combineIntervals : List Interval -> String
combineIntervals intervals =
    case intervals of
        head :: [] ->
            intervalToCondExpr head

        intervals_ ->
            let
                conditions =
                    intervals_
                        |> List.map intervalToCondExpr
                        |> String.join ") || ("
            in
            "(" ++ conditions ++ ")"


{-| Turns a Interval into an elm expression usable in a if.
-}
intervalToCondExpr : Interval -> String
intervalToCondExpr interval =
    let
        isLowEqualToHigh =
            case ( interval.low, interval.high ) of
                ( Included low, Included high ) ->
                    if low == high then
                        Just <| "count == " ++ String.fromInt low

                    else
                        Nothing

                _ ->
                    Nothing

        lowBound =
            case interval.low of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "count >= " ++ String.fromInt bound

                Excluded bound ->
                    Just <| "count > " ++ String.fromInt bound

        highBound =
            case interval.high of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| "count <= " ++ String.fromInt bound

                Excluded bound ->
                    Just <| "count < " ++ String.fromInt bound
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


{-| Turns a list of Chunks into an elm expression usable in the body of a function.
-}
combineChunks : List Chunk -> String
combineChunks list =
    let
        string =
            list
                |> List.map chunkToString
                |> String.join " ++ "
    in
    if String.isEmpty string then
        quote string

    else
        string


{-| Turns a Chunk into an elm expression usable in the body of a function.
-}
chunkToString : Chunk -> String
chunkToString chunk =
    case chunk of
        Text text ->
            quote text

        Variable variable ->
            "params_." ++ variable

        VariableCount ->
            "(String.fromInt count)"


{-| Creates all extra keyname translation functions.
-}
keynameTranslations : List Translation -> List Translation
keynameTranslations translations =
    translations
        |> groupByKeyname
        |> Dict.toList
        |> List.map createAKeynameTranslation


{-| Groups together functions with a common same name from the beginning up to `_keyname_`.
Filters out functions not containing `_keyname_` in their name.
-}
groupByKeyname : List Translation -> Dict String (List Translation)
groupByKeyname =
    Dict.filterGroupBy <|
        \{ name, variables } ->
            let
                base =
                    String.leftOfBack "_keyname_" name

                keyname =
                    String.rightOfBack "_keyname_" name

                isKeynameCorrect =
                    keyname /= "" && (keyname |> not << String.contains ".")
            in
            if isKeynameCorrect && List.isEmpty variables then
                Just (base ++ "_keyname")

            else
                Nothing


{-| Creates a translation function delegating to existing translation,
choosing the correct one based on a keyname parameter.
-}
createAKeynameTranslation : ( String, List Translation ) -> Translation
createAKeynameTranslation ( baseName, translations ) =
    Translation baseName
        []
        (Keyname <|
            List.map
                (\{ name } -> ( String.rightOfBack "_keyname_" name, name ))
                translations
        )
