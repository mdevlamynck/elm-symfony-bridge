module Dto.Generator exposing (Command, File, generateElm)

import Dict
import Dto.Graph as Graph
import Dto.Parser exposing (readJsonContent)
import Dto.Types exposing (Collection(..), Context, Dto, DtoReference, Primitive(..), Type, TypeKind(..))
import Elm.CodeGen as Gen exposing (Declaration, Expression, Import, TypeAnnotation)
import Elm.Pretty as Gen
import Set
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
generateElm : Command -> Result String (List File)
generateElm command =
    command.content
        |> readJsonContent
        |> Result.map buildContext
        |> Result.map generateElmModules


buildContext : List Dto -> Context
buildContext dtos =
    let
        graph : Graph.Graph
        graph =
            dtos
                |> List.map
                    (\dto ->
                        ( dto.ref.fqn
                        , dto.fields
                            |> List.filterMap (Tuple.second >> .type_ >> extractType)
                            |> Set.fromList
                        )
                    )
                |> Dict.fromList
    in
    { cycles = Graph.findNodesInCycles graph
    , references = graph
    , dtos = dtos
    }


extractType : TypeKind -> Maybe String
extractType type_ =
    case type_ of
        TypeCollection (C collection) ->
            extractType collection.type_

        TypeDtoReference dto ->
            Just dto.fqn

        _ ->
            Nothing


generateElmModules : Context -> List File
generateElmModules context =
    List.map (generateElmModule context) context.dtos


generateElmModule : Context -> Dto -> File
generateElmModule context dto =
    { name = String.replace "." "/" dto.ref.fqn ++ ".elm"
    , content =
        Gen.file
            (Gen.normalModule (String.split "." dto.ref.fqn) [])
            (generateImports context dto
                ++ decode.imports
                ++ encode.imports
            )
            [ generateType dto
            , generateDecoder dto
            , generateEncoder dto
            ]
            Nothing
            |> Gen.pretty 80
            |> trimEmptyLines
    }


generateImports : Context -> Dto -> List Import
generateImports context dto =
    let
        buildImport path =
            Gen.importStmt path Nothing Nothing
    in
    context.references
        |> Dict.get dto.ref.fqn
        |> Maybe.withDefault Set.empty
        |> Set.toList
        |> List.map (String.split "." >> buildImport)


generateType : Dto -> Declaration
generateType dto =
    Gen.aliasDecl Nothing dto.ref.name [] <|
        Gen.recordAnn
            (dto.fields
                |> (List.map << Tuple.mapSecond) generateRecordField
            )


generateRecordField : Type -> TypeAnnotation
generateRecordField type_ =
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

        TypeDtoReference dto ->
            toType dto


generateDecoder : Dto -> Declaration
generateDecoder dto =
    Gen.funDecl Nothing (Just (decode.decoder dto.ref.name)) "decode" [] <|
        Gen.binOpChain (Gen.apply [ decode.succeed, toConstruct dto.ref ])
            Gen.piper
            (dto.fields |> List.map generateFieldDecoder)


generateFieldDecoder : ( String, Type ) -> Expression
generateFieldDecoder ( name, type_ ) =
    Gen.apply [ decode.required, Gen.string name, generateFieldTypeDecoder type_ ]


generateFieldTypeDecoder : Type -> Expression
generateFieldTypeDecoder type_ =
    let
        wrapMaybeIfNullable decoder =
            if type_.isNullable then
                Gen.apply [ decode.maybe, decoder ]

            else
                decoder
    in
    wrapMaybeIfNullable (generateTypeKindDecoder type_.type_)


generateTypeKindDecoder : TypeKind -> Expression
generateTypeKindDecoder type_ =
    case type_ of
        TypePrimitive Bool ->
            decode.bool

        TypePrimitive Int ->
            decode.int

        TypePrimitive Float ->
            decode.float

        TypePrimitive String ->
            decode.string

        TypeCollection (C collection) ->
            let
                wrapMaybeIfNullable decoder =
                    if collection.allowsNull then
                        Gen.apply [ decode.maybe, decoder ]

                    else
                        decoder
            in
            Gen.apply [ decode.list, wrapMaybeIfNullable (generateTypeKindDecoder collection.type_) ]

        TypeDtoReference dto ->
            toDecoder dto


generateEncoder : Dto -> Declaration
generateEncoder dto =
    Gen.funDecl Nothing (Just (encode.encoder dto.ref.name)) "encode" [ Gen.varPattern "dto" ] <|
        Gen.apply [ encode.object, Gen.list (generateFieldsEncoder dto) ]


generateFieldsEncoder : Dto -> List Expression
generateFieldsEncoder dto =
    dto.fields
        |> List.map
            (\( name, type_ ) ->
                Gen.tuple [ Gen.string name, generateFieldEncoder name type_ ]
            )


generateFieldEncoder : String -> Type -> Expression
generateFieldEncoder name type_ =
    let
        wrapMaybeIfNullable encoders =
            if type_.isNullable then
                if List.length encoders > 1 then
                    encode.maybe :: [ Gen.parens (Gen.apply encoders) ]

                else
                    encode.maybe :: encoders

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
            [ encode.bool ]

        TypePrimitive Int ->
            [ encode.int ]

        TypePrimitive Float ->
            [ encode.float ]

        TypePrimitive String ->
            [ encode.string ]

        TypeCollection (C collection) ->
            let
                wrapMaybeIfNullable encoders =
                    if collection.allowsNull then
                        [ Gen.parens <|
                            Gen.apply (encode.maybe :: encoders)
                        ]

                    else
                        encoders
            in
            encode.list :: wrapMaybeIfNullable (generateTypeKindEncoder collection.type_)

        TypeDtoReference dto ->
            [ toEncoder dto ]


toType : DtoReference -> TypeAnnotation
toType ref =
    let
        fullPath =
            [ ref.fqn
            , ref.name
            ]
                |> String.join "."
    in
    Gen.fqTyped [] fullPath []


toConstruct : DtoReference -> Expression
toConstruct ref =
    Gen.val ref.name


toDecoder : DtoReference -> Expression
toDecoder ref =
    Gen.val (ref.fqn ++ ".decode")


toEncoder : DtoReference -> Expression
toEncoder ref =
    Gen.val (ref.fqn ++ ".encode")


decode :
    { succeed : Expression
    , map : Expression
    , required : Expression
    , bool : Expression
    , int : Expression
    , float : Expression
    , string : Expression
    , maybe : Expression
    , list : Expression
    , decoder : String -> TypeAnnotation
    , imports : List Import
    }
decode =
    let
        fn =
            Gen.fqFun [ "Decode" ]

        val =
            Gen.fqFun [ "Decode" ]
    in
    { succeed = fn "succeed"
    , map = fn "map"
    , required = fn "required"
    , bool = val "bool"
    , int = val "int"
    , float = val "float"
    , string = val "string"
    , maybe = fn "maybe"
    , list = fn "list"
    , decoder = \t -> Gen.fqTyped [ "Decode" ] "Decoder" [ Gen.typeVar t ]
    , imports =
        [ Gen.importStmt [ "Json", "Decode" ] (Just [ "Decode" ]) Nothing
        , Gen.importStmt [ "Json", "Decode", "Pipeline" ] (Just [ "Decode" ]) Nothing
        ]
    }


encode :
    { object : Expression
    , bool : Expression
    , int : Expression
    , float : Expression
    , string : Expression
    , maybe : Expression
    , list : Expression
    , encoder : String -> TypeAnnotation
    , imports : List Import
    }
encode =
    let
        fn =
            Gen.fqFun [ "Encode" ]

        val =
            Gen.fqFun [ "Encode" ]
    in
    { object = fn "object"
    , bool = val "bool"
    , int = val "int"
    , float = val "float"
    , string = val "string"
    , maybe = fn "maybe"
    , list = fn "list"
    , encoder = \t -> Gen.funAnn (Gen.typeVar t) (Gen.fqTyped [ "Encode" ] "Value" [])
    , imports =
        [ Gen.importStmt [ "Json", "Encode" ] (Just [ "Encode" ]) Nothing
        , Gen.importStmt [ "Json", "Encode", "Extra" ] (Just [ "Encode" ]) Nothing
        ]
    }
