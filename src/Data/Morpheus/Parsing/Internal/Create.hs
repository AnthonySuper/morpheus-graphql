{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}

module Data.Morpheus.Parsing.Internal.Create
  ( createField
  , createArgument
  , createType
  , createScalarType
  , createEnumType
  , createUnionType
  , createDataTypeLib
  ) where

import           Data.Morpheus.Types.Internal.Data (DataArguments, DataField (..), DataFingerprint (..),
                                                    DataType (..), DataTyCon (..), DataTypeLib (..),
                                                    DataValidator (..), TypeAlias (..), WrapperD, defineType,
                                                    initTypeLib)
import           Data.Text                         (Text)

createField :: DataArguments -> Text -> ([WrapperD], Text) -> DataField
createField fieldArgs fieldName (aliasWrappers, aliasTyCon) =
  DataField
    { fieldArgs
    , fieldArgsType = Nothing
    , fieldName
    , fieldType = TypeAlias {aliasTyCon, aliasWrappers, aliasArgs = Nothing}
    , fieldHidden = False
    }

createArgument :: Text -> ([WrapperD], Text) -> (Text, DataField)
createArgument fieldName x = (fieldName, createField [] fieldName x)

createType :: Text -> a -> DataTyCon a
createType typeName typeData =
  DataTyCon {typeName, typeDescription = Nothing, typeFingerprint = SystemFingerprint "", typeData}

createScalarType :: Text -> (Text, DataType)
createScalarType typeName = (typeName, DataScalar $ createType typeName (DataValidator pure))

createEnumType :: Text -> [Text] -> (Text, DataType)
createEnumType typeName typeData = (typeName, DataEnum $ createType typeName typeData)

createUnionType :: Text -> [Text] -> (Text, DataType)
createUnionType typeName typeData = (typeName, DataUnion $ createType typeName $ map unionField typeData)
  where
    unionField fieldType = createField [] "" ([], fieldType)

createDataTypeLib :: Monad m => [(Text, DataType)] -> m DataTypeLib
createDataTypeLib types =
  case takeByKey "Query" types of
    (Just query, lib1) ->
      case takeByKey "Mutation" lib1 of
        (mutation, lib2) ->
          case takeByKey "Subscription" lib2 of
            (subscription, lib3) -> pure ((foldr defineType (initTypeLib query) lib3) {mutation, subscription})
    _ -> fail "Query Not Defined"
  ----------------------------------------------------------------------------
  where
    takeByKey key lib =
      case lookup key lib of
        Just (DataObject value) -> (Just (key, value), filter ((/= key) . fst) lib)
        _                       -> (Nothing, lib)
