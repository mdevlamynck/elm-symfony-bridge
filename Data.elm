module Data exposing (..)


type alias Translation =
    { name : String
    , placeholders : List String
    , alternatives :
        List Alternative
    }


type alias Alternative =
    { appliesTo : List Range
    , chunks : List Chunk
    }


type Chunk
    = Text String
    | Placeholder String


type alias Range =
    { low : RangeBound
    , high : RangeBound
    }


type RangeBound
    = Inf
    | Included Int
    | Excluded Int
