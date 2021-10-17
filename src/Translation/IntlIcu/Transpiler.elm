module Translation.IntlIcu.Transpiler exposing (parseTranslation, translationToElm)

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
                , variables = extractVariables translationContent
                , content = translationContent
                }
            )


extractVariables : TranslationContent -> List String
extractVariables translationContent =
    Debug.todo "implement"


{-| Turns a translation into an elm function.
-}
translationToElm : String -> Translation -> Function
translationToElm lang translation =
    Debug.todo "implement"
