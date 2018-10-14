module Routing.Data exposing (ArgumentType(..), Path(..), Routing)


type alias Routing =
    List Path


type Path
    = Constant String
    | Variable ArgumentType String


type ArgumentType
    = Int
    | String
