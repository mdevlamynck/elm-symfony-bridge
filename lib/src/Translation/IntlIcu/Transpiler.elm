module Translation.IntlIcu.Transpiler exposing (parseTranslation, translationToElm)

import Dict
import Elm as Gen
import Elm.CodeGen as Gen exposing (Declaration, Expression, Pattern, TypeAnnotation)
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
translationToElm : Translation -> Declaration
translationToElm translation =
    let
        arguments =
            case extractArguments translation.content of
                Just args ->
                    ( Gen.funAnn args Gen.stringAnn, [ Gen.varPattern "params_" ] )

                _ ->
                    ( Gen.stringAnn, [] )

        signature =
            Tuple.first arguments

        patterns =
            Tuple.second arguments
    in
    Gen.funDecl Nothing (Just signature) translation.name patterns <|
        chunksToElm translation.content


extractArguments : Chunks -> Maybe TypeAnnotation
extractArguments chunks =
    let
        toElmType t =
            case t of
                Raw ->
                    Gen.stringAnn

                Number _ ->
                    Gen.intAnn

                Date _ ->
                    Gen.fqTyped [ "Time" ] "Posix" []

                Time _ ->
                    Gen.fqTyped [ "Time" ] "Posix" []

                Duration _ ->
                    Gen.intAnn

                Select _ ->
                    Gen.stringAnn

                Plural _ _ ->
                    Gen.intAnn

        args =
            chunks
                |> collectVariables
                |> List.map (\var -> ( var.name, toElmType var.type_ ))
                |> Dict.fromList
                |> Dict.toList
    in
    if List.isEmpty args then
        Nothing

    else
        Just <| Gen.recordAnn args


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


chunksToElm : Chunks -> Expression
chunksToElm chunks =
    chunks
        |> List.map chunkToElm
        |> Gen.stringConcat


chunkToElm : Chunk -> Expression
chunkToElm chunk =
    case chunk of
        Text string ->
            Gen.string string

        Var var ->
            case var.type_ of
                Raw ->
                    Gen.val <| "params_." ++ var.name

                Number format ->
                    formatNumber format var.name

                Date format ->
                    formatDate format var.name

                Time format ->
                    formatTime format var.name

                Duration format ->
                    formatDuration format var.name

                Select variants ->
                    selectToElm (Gen.val <| "params_." ++ var.name) variants

                Plural _ variants ->
                    pluralToElm (Gen.val <| "params_." ++ var.name) variants


formatNumber : Maybe String -> String -> Expression
formatNumber _ name =
    Gen.val <| "(String.fromInt params_." ++ name ++ ")"


formatDate : Maybe String -> String -> Expression
formatDate _ _ =
    Debug.todo ""


formatTime : Maybe String -> String -> Expression
formatTime _ _ =
    Debug.todo ""


formatDuration : Maybe String -> String -> Expression
formatDuration _ _ =
    Debug.todo ""


selectToElm : Expression -> SelectVariants -> Expression
selectToElm name variants =
    Gen.caseExpr name <|
        List.map
            (\{ pattern, value } ->
                ( selectPatternToElm pattern
                , chunksToElm value
                )
            )
            variants


selectPatternToElm : SelectPattern -> Pattern
selectPatternToElm pattern =
    case pattern of
        SelectText text ->
            Gen.stringPattern text

        SelectOther ->
            Gen.allPattern


pluralToElm : Expression -> PluralVariants -> Expression
pluralToElm name variants =
    Gen.caseExpr name <|
        List.map
            (\{ pattern, value } ->
                ( pluralPatternToElm pattern
                , chunksToElm value
                )
            )
            variants


pluralPatternToElm : PluralPattern -> Pattern
pluralPatternToElm pattern =
    case pattern of
        Value value ->
            Gen.intPattern value

        Zero ->
            Debug.todo ""

        One ->
            Debug.todo ""

        Two ->
            Debug.todo ""

        Few ->
            Debug.todo ""

        Many ->
            Debug.todo ""

        PluralOther ->
            Gen.allPattern
