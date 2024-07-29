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
    Decode.succeed Dto
        |> Decode.required "fqn" (Decode.string |> Decode.map buildDtoReference)
        |> Decode.required "fields" (Decode.keyValuePairs decodeType)


decodeType : Decoder Type
decodeType =
    Decode.succeed Type
        |> Decode.required "type" decodeTypeKind
        |> Decode.required "isNullable" Decode.bool
        |> Decode.required "canBeAbsent" Decode.bool
        |> Decode.required "defaultValue" (Decode.nullable decodeValue)


decodeTypeKind : Decoder TypeKind
decodeTypeKind =
    Decode.oneOf
        [ Decode.map TypePrimitive decodePrimitive
        , Decode.map TypeCollection decodeCollection
        , Decode.map TypeDtoReference decodeDtoReference
        ]


decodePrimitive : Decoder Primitive
decodePrimitive =
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
    Decode.succeed buildDtoReference
        |> Decode.required "fqn" Decode.string


decodeValue : Decoder Value
decodeValue =
    Decode.succeed Value
        |> Decode.required "value" Decode.value


buildDtoReference : String -> DtoReference
buildDtoReference fqn =
    let
        chunks =
            String.split "\\" fqn
                -- filter some parts out? like App\Account\UserInterface\RestController\SignInDto -> ["App", "Account", "SignInDto"]
                |> List.filter (\part -> not <| List.member part [ "UserInterface", "RestController" ])
                |> (::) "Dto"

        last =
            List.reverse chunks |> List.head |> Maybe.withDefault ""
    in
    { fqn = chunks |> String.join "."
    , name = last
    }
