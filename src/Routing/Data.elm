module Routing.Data exposing (..)


type alias Routing =
    List Path


type Path
    = Constant String
    | Variable String ArgumentType


type ArgumentType
    = Int
    | String
