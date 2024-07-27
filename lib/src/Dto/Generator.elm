module Dto.Generator exposing (Command, File, generateElm)

import Dto.Parser exposing (readJsonContent)
import Dto.Types exposing (Collection(..), Dto(..), DtoReference(..), Primitive(..), Type(..), TypeKind(..))
import Elm.CodeGen as Gen exposing (Declaration, Expression, TypeAnnotation)
import Elm.Pretty as Gen
import StringUtil exposing (trimEmptyLines)


{-| Parameters to the generate.
-}
type alias Command =
    { content : String
    }


{-| Represents a file.
-}
type alias File =
    { name : String
    , content : String
    }


{-| Converts a JSON containing dto metadata to an Elm file.
-}
generateElm : Command -> Result String File
generateElm command =
    command.content
        |> readJsonContent
        |> Result.map generateElmModule


generateElmModule : List Dto -> File
generateElmModule dtos =
    { name = "Dto.elm"
    , content =
        Gen.file
            (Gen.normalModule [ "Dto" ] [])
            [ Gen.importStmt [ "Json", "Decode" ] (Just [ "Decode" ]) Nothing
            , Gen.importStmt [ "Json", "Decode", "Pipeline" ] (Just [ "Decode" ]) Nothing
            , Gen.importStmt [ "Json", "Encode" ] (Just [ "Encode" ]) Nothing
            , Gen.importStmt [ "Json", "Encode", "Extra" ] (Just [ "Encode" ]) Nothing
            ]
            (List.concatMap generateDto dtos)
            Nothing
            |> Gen.pretty 80
            |> trimEmptyLines
    }


generateDto : Dto -> List Declaration
generateDto dto =
    [ generateType dto
    , generateDecoder dto
    , generateEncoder dto
    ]


generateType : Dto -> Declaration
generateType dto =
    Gen.aliasDecl Nothing (alias dto).name [] (generateRecord dto)


generateRecord : Dto -> TypeAnnotation
generateRecord (D dto) =
    Gen.recordAnn
        (dto.fields
            |> (List.map << Tuple.mapSecond) generateRecordField
        )


generateRecordField : Type -> TypeAnnotation
generateRecordField (T type_) =
    let
        wrapMaybeIfNullable =
            if type_.isNullable then
                Gen.maybeAnn

            else
                identity
    in
    wrapMaybeIfNullable <| generateTypeKind type_.type_


generateTypeKind : TypeKind -> TypeAnnotation
generateTypeKind type_ =
    case type_ of
        TypePrimitive Bool ->
            Gen.boolAnn

        TypePrimitive Int ->
            Gen.intAnn

        TypePrimitive Float ->
            Gen.floatAnn

        TypePrimitive String ->
            Gen.stringAnn

        TypeCollection (C collection) ->
            let
                wrapMaybeIfNullable =
                    if collection.allowsNull then
                        Gen.maybeAnn

                    else
                        identity
            in
            Gen.listAnn (wrapMaybeIfNullable (generateTypeKind collection.type_))

        TypeDtoReference (DR dto) ->
            Gen.fqTyped [] (toAlias dto.fqn) []


generateDecoder : Dto -> Declaration
generateDecoder dto =
    let
        dtoData =
            alias dto
    in
    Gen.funDecl Nothing (Just dtoData.decoderSig) dtoData.decoder [] <|
        Gen.binOpChain (Gen.apply [ Gen.fqFun [ "Decode" ] "succeed", Gen.val dtoData.name ])
            Gen.piper
            (generateFieldsDecoder dto)


generateFieldsDecoder : Dto -> List Expression
generateFieldsDecoder (D dto) =
    dto.fields
        |> List.map generateFieldDecoder


generateFieldDecoder : ( String, Type ) -> Expression
generateFieldDecoder ( name, type_ ) =
    Gen.apply
        [ Gen.fqFun [ "Decode" ] "required"
        , Gen.string name
        , generateFieldTypeDecoder type_
        ]


generateFieldTypeDecoder : Type -> Expression
generateFieldTypeDecoder (T type_) =
    let
        wrapMaybeIfNullable decoder =
            if type_.isNullable then
                Gen.apply [ Gen.fqFun [ "Decode" ] "maybe", decoder ]

            else
                decoder
    in
    wrapMaybeIfNullable <| generateTypeKindDecoder type_.type_


generateTypeKindDecoder : TypeKind -> Expression
generateTypeKindDecoder type_ =
    case type_ of
        TypePrimitive Bool ->
            Gen.fqVal [ "Decode" ] "bool"

        TypePrimitive Int ->
            Gen.fqVal [ "Decode" ] "int"

        TypePrimitive Float ->
            Gen.fqVal [ "Decode" ] "float"

        TypePrimitive String ->
            Gen.fqVal [ "Decode" ] "string"

        TypeCollection (C collection) ->
            let
                wrapMaybeIfNullable decoder =
                    if collection.allowsNull then
                        Gen.apply [ Gen.fqFun [ "Decode" ] "maybe", decoder ]

                    else
                        decoder
            in
            Gen.apply [ Gen.fqFun [ "Decode" ] "list", wrapMaybeIfNullable (generateTypeKindDecoder collection.type_) ]

        TypeDtoReference (DR dto) ->
            Gen.val (toDecoder <| toAlias dto.fqn)


generateEncoder : Dto -> Declaration
generateEncoder dto =
    let
        dtoData =
            alias dto
    in
    Gen.funDecl Nothing (Just dtoData.encoderSig) dtoData.encoder [ Gen.varPattern "dto" ] <|
        Gen.apply
            [ Gen.fqFun [ "Encode" ] "object"
            , Gen.list (generateFieldsEncoder dto)
            ]


generateFieldsEncoder : Dto -> List Expression
generateFieldsEncoder (D dto) =
    dto.fields
        |> List.map
            (\( name, type_ ) ->
                Gen.tuple
                    [ Gen.string name
                    , generateFieldEncoder name type_
                    ]
            )


generateFieldEncoder : String -> Type -> Expression
generateFieldEncoder name (T type_) =
    let
        wrapMaybeIfNullable encoders =
            if type_.isNullable then
                if List.length encoders > 1 then
                    Gen.fqFun [ "Encode" ] "maybe" :: [ Gen.parens (Gen.apply encoders) ]

                else
                    Gen.fqFun [ "Encode" ] "maybe" :: encoders

            else
                encoders
    in
    Gen.apply <|
        List.concat
            [ wrapMaybeIfNullable (generateTypeKindEncoder type_.type_)
            , [ Gen.access (Gen.val "dto") name ]
            ]


generateTypeKindEncoder : TypeKind -> List Expression
generateTypeKindEncoder type_ =
    case type_ of
        TypePrimitive Bool ->
            [ Gen.fqVal [ "Encode" ] "bool" ]

        TypePrimitive Int ->
            [ Gen.fqVal [ "Encode" ] "int" ]

        TypePrimitive Float ->
            [ Gen.fqVal [ "Encode" ] "float" ]

        TypePrimitive String ->
            [ Gen.fqVal [ "Encode" ] "string" ]

        TypeCollection (C collection) ->
            let
                wrapMaybeIfNullable encoders =
                    if collection.allowsNull then
                        [ Gen.parens <|
                            Gen.apply (Gen.fqFun [ "Encode" ] "maybe" :: encoders)
                        ]

                    else
                        encoders
            in
            Gen.fqFun [ "Encode" ] "list" :: wrapMaybeIfNullable (generateTypeKindEncoder collection.type_)

        TypeDtoReference (DR dto) ->
            [ Gen.val (toEncoder <| toAlias dto.fqn) ]


alias : Dto -> { name : String, decoder : String, encoder : String, decoderSig : TypeAnnotation, encoderSig : TypeAnnotation }
alias (D dto) =
    let
        name =
            toAlias dto.fqn
    in
    { name = name
    , decoder = toDecoder name
    , encoder = toEncoder name
    , decoderSig = Gen.fqTyped [ "Decode" ] "Decoder" [ Gen.typeVar name ]
    , encoderSig = Gen.funAnn (Gen.typeVar name) (Gen.typeVar "Encode.Value")
    }


toAlias : String -> String
toAlias fqn =
    String.split "\\" fqn
        -- filter some parts out? like App\Account\UserInterface\RestController\SignInDto -> App_Account_SignInDto
        |> List.filter (\part -> not <| List.member part [ "UserInterface", "RestController" ])
        |> String.join ""


toDecoder : String -> String
toDecoder name =
    "decode" ++ name


toEncoder : String -> String
toEncoder name =
    "encode" ++ name
