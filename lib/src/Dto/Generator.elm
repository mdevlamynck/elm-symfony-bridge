module Dto.Generator exposing (Command, File, generateElm)

import Dto.Parser exposing (readJsonContent)
import Dto.Types exposing (Collection(..), Dto(..), DtoReference(..), Primitive(..), Type(..), TypeKind(..))


{-| Parameters to the generate.
-}
type alias Command =
    { content : String
    }


{-| Represents a file.
-}
type alias File =
    { name : String
    , content : String
    }


{-| Converts a JSON containing dto metadata to an Elm file.
-}
generateElm : Command -> Result String File
generateElm command =
    command.content
        |> readJsonContent
        |> Result.map generateElmModule


generateElmModule : List Dto -> File
generateElmModule dtos =
    { name = "Dto.elm"
    , content = ""
    }
