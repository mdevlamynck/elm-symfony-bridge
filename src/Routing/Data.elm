module Routing.Data exposing (ArgumentType(..), Path(..), Routing)


type alias Routing =
    List Path


type Path
    = Constant String
    | Variable String ArgumentType


type ArgumentType
    = Int
    | String
