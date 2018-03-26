module Data exposing (..)

{-| Types common to several modules

@docs Translation, TranslationContent, Alternative, Chunk, Range, RangeBound

-}


{-| Represents a Translation

name is the name of the translation
placeholders is the list of variables
content is the actual content of the translation

-}
type alias Translation =
    { name : String
    , placeholders : List String
    , content : TranslationContent
    }


{-| The content of a translation

Can either be a single message or in a pluralized translation a list of
alternatives messages with the conditions to choose one over the others.

-}
type TranslationContent
    = SingleMessage (List Chunk)
    | PluralizedMessage (List Alternative)


{-| A plurilized translation message is constitued of several alternatives, represented by this type

A translation without pluralization is considered to be constitued of a single Alternative.

-}
type alias Alternative =
    { appliesTo : List Range
    , chunks : List Chunk
    }


{-| A translation's message is constant string with placeholder for variables

Text represent the contant part
Placeholder represent the variable name

-}
type Chunk
    = Text String
    | Placeholder String


{-| A range with a minimal value and a maximal value

Used to determine which alternative to use for a given value
by checking in which range the value falls.

-}
type alias Range =
    { low : RangeBound
    , high : RangeBound
    }


{-| Represent either the lower limit or the high limit of a Range

Inf is -infinity or +infinity depending if its present in the low or high bound.
Included means the limit falls in the range
Excluded means the limit falls out of the range

-}
type RangeBound
    = Inf
    | Included Int
    | Excluded Int
