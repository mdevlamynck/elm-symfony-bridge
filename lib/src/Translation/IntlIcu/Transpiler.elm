module Translation.IntlIcu.Transpiler exposing (parseTranslation, translationToElm)

import Dict
import Elm exposing (..)
import Result
import Translation.IntlIcu.Data exposing (..)
import Translation.IntlIcu.Parser as Parser


{-| Parses the raw translation into a Translation.
-}
parseTranslation : ( String, String ) -> Result String Translation
parseTranslation ( name, message ) =
    Parser.parseTranslationContent message
        |> Result.map
            (\translationContent ->
                { name = name
                , content = translationContent
                }
            )


{-| Turns a translation into an elm function.
-}
translationToElm : Translation -> Function
translationToElm translation =
    Function translation.name (extractArguments translation.content) "String" <|
        chunksToElm translation.content


extractArguments : Chunks -> List Arg
extractArguments chunks =
    let
        toElmType t =
            case t of
                Raw ->
                    "String"

                Number _ ->
                    "Int"

                Date _ ->
                    "Posix"

                Time _ ->
                    "Posix"

                Duration _ ->
                    "Int"

                Select _ ->
                    "String"

                Plural _ _ ->
                    "Int"

        args =
            chunks
                |> collectVariables
                |> List.map (\var -> ( var.name, toElmType var.type_ ))
                |> Dict.fromList
    in
    if Dict.isEmpty args then
        []

    else
        [ Record args ]


collectVariables : Chunks -> List Variable
collectVariables =
    List.concatMap <|
        \chunk ->
            case chunk of
                Text _ ->
                    []

                Var var ->
                    case var.type_ of
                        Select variants ->
                            var :: List.concatMap (\variant -> collectVariables variant.value) variants

                        Plural _ variants ->
                            var :: List.concatMap (\variant -> collectVariables variant.value) variants

                        _ ->
                            [ var ]


chunksToElm : Chunks -> Expr
chunksToElm chunks =
    chunks
        |> List.map chunkToElm
        |> mergeExprs


mergeExprs : List Expr -> Expr
mergeExprs exprs =
    let
        varExprs =
            exprs
                |> indexedFilterMap convertToVarExpr

        body =
            exprs
                |> List.indexedMap replaceWithLetVariable
                |> mergeIntoExpr
    in
    LetIn varExprs <|
        Expr body


convertToVarExpr : Int -> Expr -> Maybe ( String, Expr )
convertToVarExpr index expr =
    case expr of
        Expr _ ->
            Nothing

        _ ->
            Just ( "var" ++ String.fromInt index, expr )


replaceWithLetVariable : Int -> Expr -> String
replaceWithLetVariable index expr =
    case expr of
        Expr content ->
            content

        _ ->
            "var" ++ String.fromInt index


mergeIntoExpr : List String -> String
mergeIntoExpr exprs =
    if List.isEmpty exprs then
        quote ""

    else
        exprs
            |> List.intersperse "++"
            |> String.join " "


chunkToElm : Chunk -> Expr
chunkToElm chunk =
    case chunk of
        Text string ->
            Expr <| quote string

        Var var ->
            case var.type_ of
                Raw ->
                    Expr <| "params_." ++ var.name

                Number _ ->
                    Expr <| "(fromInt params_." ++ var.name ++ ")"

                Date _ ->
                    Debug.todo ""

                Time _ ->
                    Debug.todo ""

                Duration _ ->
                    Debug.todo ""

                Select variants ->
                    selectToElm ("params_." ++ var.name) variants

                Plural opts variants ->
                    pluralToElm ("params_." ++ var.name) variants


selectToElm : String -> SelectVariants -> Expr
selectToElm name variants =
    Case name <|
        List.map
            (\{ pattern, value } ->
                ( selectPatternToElm pattern
                , chunksToElm value
                )
            )
            variants


selectPatternToElm : SelectPattern -> String
selectPatternToElm pattern =
    case pattern of
        SelectText text ->
            quote text

        SelectOther ->
            "_"


pluralToElm : String -> PluralVariants -> Expr
pluralToElm name variants =
    Case name <|
        List.map
            (\{ pattern, value } ->
                ( pluralPatternToElm pattern
                , chunksToElm value
                )
            )
            variants


pluralPatternToElm : PluralPattern -> String
pluralPatternToElm pattern =
    case pattern of
        Value value ->
            String.fromInt value

        Zero ->
            String.fromInt 0

        One ->
            String.fromInt 1

        Two ->
            String.fromInt 2

        Few ->
            Debug.todo ""

        Many ->
            Debug.todo ""

        PluralOther ->
            "_"


indexedFilterMap : (Int -> a -> Maybe b) -> List a -> List b
indexedFilterMap f =
    List.indexedMap f >> List.filterMap identity
