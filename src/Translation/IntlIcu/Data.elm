module Translation.IntlIcu.Data exposing (..)


type alias Translation =
    { name : String
    , content : Chunks
    }


type alias TranslationContent =
    Chunks


type alias Chunks =
    List Chunk


type Chunk
    = Text String
    | Var Variable


type alias Variable =
    { name : String
    , type_ : Type
    }


type Type
    = -- no type, elm String
      Raw
    | -- number, ordinal, spellout, elm number
      Number Format
    | -- date, elm Posix
      Date Format
    | -- time, elm Posix
      Time Format
    | -- duration, elm number
      Duration Format
    | -- select, elm String
      Select SelectVariants
    | -- plural, selectordinal, elm Int
      Plural PluralOption PluralVariants


type alias Format =
    Maybe String


type alias SelectVariants =
    List SelectVariant


type alias SelectVariant =
    { pattern : SelectPattern
    , value : Chunks
    }


type SelectPattern
    = SelectText String
    | SelectOther


type alias PluralVariants =
    List PluralVariant


type alias PluralVariant =
    { pattern : PluralPattern
    , value : Chunks
    }


type PluralPattern
    = Value Int
    | Zero
    | One
    | Two
    | Few
    | Many
    | PluralOther


type alias PluralOption =
    { offset : Int
    }


defaultPluralOption : PluralOption
defaultPluralOption =
    { offset = 0
    }
