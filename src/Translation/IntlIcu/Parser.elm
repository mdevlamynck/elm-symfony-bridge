module Translation.IntlIcu.Parser exposing (..)

import Parser exposing (Parser)
import Translation.IntlIcu.Data exposing (..)


parseTranslationContent : String -> Result String Chunks
parseTranslationContent input =
    Parser.run translation input
        |> Result.mapError (\_ -> "Failed to parse translation")


translation : Parser Chunks
translation =
    Parser.succeed []
