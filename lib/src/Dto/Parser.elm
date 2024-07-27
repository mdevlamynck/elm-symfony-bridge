module Dto.Parser exposing (readJsonContent)

import Dto.Types exposing (..)
import Json.Decode as Decode exposing (Decoder)
import Json.Decode.Pipeline as Decode


readJsonContent : String -> Result String (List Dto)
readJsonContent =
    Decode.decodeString (Decode.list decodeDto)
        >> Result.mapError Decode.errorToString


decodeDto : Decoder Dto
decodeDto =
    Decode.lazy <|
        \() ->
            Decode.succeed Dto_
                |> Decode.required "fqn" Decode.string
                |> Decode.required "fields" (Decode.dict decodeType)
                |> Decode.map D


decodeType : Decoder Type
decodeType =
    Decode.lazy <|
        \() ->
            Decode.succeed Type_
                |> Decode.required "type" decodeTypeKind
                |> Decode.required "isNullable" Decode.bool
                |> Decode.required "canBeAbsent" Decode.bool
                |> Decode.required "defaultValue" (Decode.nullable decodeValue)
                |> Decode.map T


decodeTypeKind : Decoder TypeKind
decodeTypeKind =
    Decode.lazy <|
        \() ->
            Decode.oneOf
                [ Decode.map TypePrimitive decodePrimitive
                , Decode.map TypeCollection decodeCollection
                , Decode.map TypeDtoReference decodeDtoReference
                ]


decodePrimitive : Decoder Primitive
decodePrimitive =
    Decode.lazy <|
        \() ->
            Decode.string
                |> Decode.andThen
                    (\s ->
                        case s of
                            "bool" ->
                                Decode.succeed Bool

                            "int" ->
                                Decode.succeed Int

                            "float" ->
                                Decode.succeed Float

                            "string" ->
                                Decode.succeed String

                            _ ->
                                Decode.fail <| "Failed to decode Primitive : \"" ++ s ++ "\""
                    )


decodeCollection : Decoder Collection
decodeCollection =
    Decode.lazy <|
        \() ->
            Decode.succeed Collection_
                |> Decode.required "type" decodeTypeKind
                |> Decode.required "allowsNull" Decode.bool
                |> Decode.map C


decodeDtoReference : Decoder DtoReference
decodeDtoReference =
    Decode.lazy <|
        \() ->
            Decode.succeed DtoReference_
                |> Decode.required "fqn" Decode.string
                |> Decode.map DR


decodeValue : Decoder Value
decodeValue =
    Decode.lazy <|
        \() ->
            Decode.succeed Value_
                |> Decode.required "value" Decode.value
                |> Decode.map V
