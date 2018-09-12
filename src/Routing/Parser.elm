module Routing.Parser exposing (parsePathContent)

import Char
import Parser exposing (..)
import Parser.Extra exposing (stringsOrContainedP)
import Routing.Data exposing (ArgumentType(..), Path(..))


parsePathContent : String -> Result String (List Path)
parsePathContent input =
    Parser.run pathP input
        |> Result.mapError (\_ -> "Failed to parse routing path")


pathP : Parser (List Path)
pathP =
    stringsOrContainedP variableP
        { parsedTagger = \name -> Variable name String
        , stringTagger = Constant
        }


variableP : Parser String
variableP =
    succeed identity
        |. symbol "{"
        |= (getChompedString <|
                succeed ()
                    |. chompIf isIdentifierChar
                    |. chompWhile isIdentifierChar
           )
        |. symbol "}"


isIdentifierChar : Char -> Bool
isIdentifierChar c =
    Char.isLower c || Char.isUpper c || Char.isDigit c || c == '_'
