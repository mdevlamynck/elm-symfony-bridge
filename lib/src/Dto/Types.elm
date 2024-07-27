module Dto.Types exposing (..)

import Json.Encode as Json


type Dto
    = D Dto_


type alias Dto_ =
    { fqn : String
    , fields : List ( String, Type )
    }


type Type
    = T Type_


type alias Type_ =
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


type DtoReference
    = DR DtoReference_


type alias DtoReference_ =
    { fqn : String
    }


type Value
    = V Value_


type alias Value_ =
    { value : Json.Value }
