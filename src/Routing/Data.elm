module Routing.Data exposing (..)


type alias Routing =
    { path : List Path
    , method : Method
    }


type Path
    = Constant String
    | Variable String ArgumentType


type Method
    = Any
    | Get
    | Post
    | Put
    | Delete


type ArgumentType
    = Int
    | String
