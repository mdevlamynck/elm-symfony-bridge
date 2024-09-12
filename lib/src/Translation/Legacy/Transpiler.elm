module Translation.Legacy.Transpiler exposing (keynameTranslations, parseTranslation, translationToElm)

import Dict exposing (Dict)
import Dict.Extra as Dict
import Elm as Gen
import Elm.CodeGen as Gen exposing (Declaration, Expression, Import, Pattern, TypeAnnotation)
import List.Extra as List
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
translationToElm : String -> Translation -> Declaration
translationToElm lang translation =
    let
        arguments =
            count ++ keyname ++ record

        signature =
            List.foldr Gen.funAnn Gen.stringAnn (List.map Tuple.first arguments)

        patterns =
            List.map Tuple.second arguments

        count =
            if hasCountVariable translation.content then
                [ ( Gen.intAnn, Gen.varPattern "count" ) ]

            else
                []

        keyname =
            if hasKeynameVariable translation.content then
                [ ( Gen.stringAnn, Gen.varPattern "keyname" ) ]

            else
                []

        record =
            if not <| Dict.isEmpty recordArgs then
                [ ( Gen.recordAnn (Dict.toList recordArgs), Gen.varPattern "params_" ) ]

            else
                []

        recordArgs =
            translation.variables
                |> List.map (\arg -> ( arg, Gen.stringAnn ))
                |> Dict.fromList
    in
    Gen.funDecl Nothing (Just signature) translation.name patterns <|
        translationContentToElm lang translation.content


{-| Does a TranslationContent contains a `count` variable?
-}
hasCountVariable : TranslationContent -> Bool
hasCountVariable translationContent =
    case translationContent of
        SingleMessage chunks ->
            chunks
                |> List.member VariableCount

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


{-| Turns a TranslationContent into the body of an elm function.
-}
translationContentToElm : String -> TranslationContent -> Expression
translationContentToElm lang translationContent =
    case translationContent of
        SingleMessage chunks ->
            combineChunks chunks

        PluralizedMessage alternatives ->
            alternatives
                |> List.foldl alternativeToElm ( indexedConditions lang, [] )
                |> Tuple.second
                |> genIfElse

        Keyname variants ->
            Gen.caseExpr (Gen.val "keyname") (toElmCaseVariants variants)


toElmCaseVariants : List ( String, String ) -> List ( Pattern, Expression )
toElmCaseVariants variants =
    List.map toElmCaseVariant variants
        ++ [ ( Gen.allPattern, Gen.string "" ) ]


toElmCaseVariant : ( String, String ) -> ( Pattern, Expression )
toElmCaseVariant ( name, value ) =
    ( Gen.stringPattern name, Gen.val value )


{-| Indexed variant application conditions depending on the lang.

Source: <https://github.com/symfony/symfony/blob/7.2/src/Symfony/Contracts/Translation/TranslatorTrait.php#L133>

-}
indexedConditions : String -> List Expression
indexedConditions lang =
    let
        locale =
            if "pt_BR" /= lang && "en_US_POSIX" /= lang && String.length lang > 3 then
                String.leftOf "_" lang

            else
                lang
    in
    if List.member locale [ "af", "bn", "bg", "ca", "da", "de", "el", "en", "en_US_POSIX", "eo", "es", "et", "eu", "fa", "fi", "fo", "fur", "fy", "gl", "gu", "ha", "he", "hu", "is", "it", "ku", "lb", "ml", "mn", "mr", "nah", "nb", "ne", "nl", "nn", "no", "oc", "om", "or", "pa", "pap", "ps", "pt", "so", "sq", "sv", "sw", "ta", "te", "tk", "ur", "zu" ] then
        [ Gen.val "count == 1", Gen.val "True" ]

    else if List.member locale [ "am", "bh", "fil", "fr", "gun", "hi", "hy", "ln", "mg", "nso", "pt_BR", "ti", "wa" ] then
        [ Gen.val "count == 0 || count == 1", Gen.val "True" ]

    else if List.member locale [ "be", "bs", "hr", "ru", "sh", "sr", "uk" ] then
        [ Gen.val "count % 10 == 1 && count % 100 /= 11", Gen.val "count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 10 || count % 100 >= 20)", Gen.val "True" ]

    else if List.member locale [ "cs", "sk" ] then
        [ Gen.val "count == 1", Gen.val "count >= 2 && count <= 4", Gen.val "True" ]

    else if locale == "ga" then
        [ Gen.val "count == 1", Gen.val "count == 2", Gen.val "True" ]

    else if locale == "lt" then
        [ Gen.val "count % 10 == 1 && count % 100 /= 11", Gen.val "count % 10 >= 2 && (count % 100 < 10 || count % 100 >= 20)", Gen.val "True" ]

    else if locale == "sl" then
        [ Gen.val "count % 100 == 1", Gen.val "count % 100 == 2", Gen.val "count % 100 == 3 || count % 100 == 4", Gen.val "True" ]

    else if locale == "mk" then
        [ Gen.val "count % 10 == 1", Gen.val "True" ]

    else if locale == "mt" then
        [ Gen.val "count == 1", Gen.val "count == 0 || count % 100 > 1 && count % 100 < 11", Gen.val "count % 100 > 10 && count % 100 < 20", Gen.val "True" ]

    else if locale == "lv" then
        [ Gen.val "count == 0", Gen.val "count % 10 == 1 && count % 100 /= 11", Gen.val "True" ]

    else if locale == "pl" then
        [ Gen.val "count == 1", Gen.val "count % 10 >= 2 && count % 10 <= 4 && (count % 100 < 12 || count % 100 > 14)", Gen.val "True" ]

    else if locale == "cy" then
        [ Gen.val "count == 1", Gen.val "count == 2", Gen.val "count == 8 || count == 11", Gen.val "True" ]

    else if locale == "ro" then
        [ Gen.val "count == 1", Gen.val "count == 0 || (count % 100 > 0 && count % 100 < 20)", Gen.val "True" ]

    else if locale == "ar" then
        [ Gen.val "count == 0", Gen.val "count == 1", Gen.val "count == 2", Gen.val "count % 100 >= 3 && count % 100 <= 10", Gen.val "count % 100 >= 11 && count % 100 <= 99", Gen.val "True" ]

    else
        [ Gen.val "True" ]


genIfElse : List ( Expression, Expression ) -> Expression
genIfElse conditions =
    case List.reverse conditions of
        ( _, last ) :: rest ->
            List.foldl (\( cond, val ) -> Gen.ifExpr cond val)
                last
                rest

        _ ->
            Gen.string ""


{-| Turns a pluralization variant into an elm expression.
-}
alternativeToElm : Alternative -> ( List Expression, List ( Expression, Expression ) ) -> ( List Expression, List ( Expression, Expression ) )
alternativeToElm { appliesTo, chunks } ( indexedCondition, content ) =
    case appliesTo of
        Intervals intervals ->
            ( indexedCondition
            , content ++ [ ( combineIntervals intervals, combineChunks chunks ) ]
            )

        Indexed ->
            case indexedCondition of
                head :: tail ->
                    ( tail
                    , content ++ [ ( head, combineChunks chunks ) ]
                    )

                [] ->
                    ( []
                    , content ++ [ ( Gen.val "False", combineChunks chunks ) ]
                    )


{-| Turns a list of Intervals into an elm expression usable in a if.
-}
combineIntervals : List Interval -> Expression
combineIntervals intervals =
    intervals
        |> List.map intervalToCondExpr
        |> List.foldl1 (\l r -> Gen.applyBinOp l Gen.or r)
        |> Maybe.map Gen.parens
        |> Maybe.withDefault (Gen.string "")


{-| Turns a Interval into an elm expression usable in a if.
-}
intervalToCondExpr : Interval -> Expression
intervalToCondExpr interval =
    let
        isLowEqualToHigh =
            case ( interval.low, interval.high ) of
                ( Included low, Included high ) ->
                    if low == high then
                        Just <| Gen.applyBinOp (Gen.val "count") Gen.equals (Gen.int low)

                    else
                        Nothing

                _ ->
                    Nothing

        lowBound =
            case interval.low of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| Gen.applyBinOp (Gen.val "count") Gen.gte (Gen.int bound)

                Excluded bound ->
                    Just <| Gen.applyBinOp (Gen.val "count") Gen.gt (Gen.int bound)

        highBound =
            case interval.high of
                Inf ->
                    Nothing

                Included bound ->
                    Just <| Gen.applyBinOp (Gen.val "count") Gen.lte (Gen.int bound)

                Excluded bound ->
                    Just <| Gen.applyBinOp (Gen.val "count") Gen.lt (Gen.int bound)
    in
    case ( isLowEqualToHigh, lowBound, highBound ) of
        ( Just value, _, _ ) ->
            value

        ( _, Just low, Just high ) ->
            Gen.applyBinOp low Gen.and high

        ( _, Just low, Nothing ) ->
            low

        ( _, Nothing, Just high ) ->
            high

        _ ->
            Gen.val "True"


{-| Turns a list of Chunks into an elm expression usable in the body of a function.
-}
combineChunks : List Chunk -> Expression
combineChunks list =
    Gen.stringConcat (List.map chunkToString list)


{-| Turns a Chunk into an elm expression usable in the body of a function.
-}
chunkToString : Chunk -> Expression
chunkToString chunk =
    case chunk of
        Text text ->
            Gen.string text

        Variable variable ->
            Gen.access (Gen.val "params_") variable

        VariableCount ->
            Gen.apply [ Gen.fqFun [ "String" ] "fromInt", Gen.val "count" ]


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
