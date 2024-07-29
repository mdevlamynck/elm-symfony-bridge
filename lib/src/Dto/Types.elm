module Dto.Types exposing (..)

import Dict exposing (Dict)
import Json.Encode as Json
import Set exposing (Set)


type alias Context =
    { cycles : Set String
    , references : Dict String (Set String)
    , dtos : List Dto
    }


type alias Dto =
    { ref : DtoReference
    , fields : List ( String, Type )
    }


type alias Type =
    { type_ : TypeKind
    , isNullable : Bool
    , canBeAbsent : Bool
    , defaultValue : Maybe Value
    }


type TypeKind
    = TypePrimitive Primitive
    | TypeCollection Collection
    | TypeDtoReference DtoReference


type Primitive
    = Bool
    | Int
    | Float
    | String


type Collection
    = C Collection_


type alias Collection_ =
    { type_ : TypeKind
    , allowsNull : Bool
    }


type alias DtoReference =
    { fqn : String
    , name : String
    }


type alias Value =
    { value : Json.Value }
