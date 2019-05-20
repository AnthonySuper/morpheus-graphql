module Data.Morpheus.Validation.Arguments
  ( validateArguments
  , resolveArguments
  ) where

import           Data.Morpheus.Error.Arguments          (argumentGotInvalidValue, argumentNameCollision,
                                                         undefinedArgument, unknownArguments)
import           Data.Morpheus.Error.Input              (InputValidation, inputErrorMessage)
import           Data.Morpheus.Error.Internal           (internalUnknownTypeMessage)
import           Data.Morpheus.Schema.Internal.AST      (Field (..), InputField (..), ObjectField (..), TypeLib,
                                                         isFieldNullable)
import           Data.Morpheus.Types.Core               (EnhancedKey (..))
import           Data.Morpheus.Types.Error              (Validation)
import           Data.Morpheus.Types.JSType             (JSType (JSNull))
import           Data.Morpheus.Types.MetaInfo           (Position)
import qualified Data.Morpheus.Types.Query.RawSelection as Raw (RawArguments)
import           Data.Morpheus.Types.Query.Selection    (Argument (..), Arguments)
import           Data.Morpheus.Types.Types              (Variables)
import           Data.Morpheus.Validation.Input.Object  (validateInputValue)
import           Data.Morpheus.Validation.Utils.Utils   (checkForUnknownKeys, checkNameCollision, getInputType)
import           Data.Morpheus.Validation.Variable      (resolveArgumentValue)
import           Data.Text                              (Text)

resolveArguments :: Variables -> Raw.RawArguments -> Validation Arguments
resolveArguments variables' = mapM (resolveArgumentValue variables')

handleInputError :: Text -> Int -> InputValidation a -> Validation ()
handleInputError key' position' (Left error') = Left $ argumentGotInvalidValue key' (inputErrorMessage error') position'
handleInputError _ _ _ = pure ()

validateArgumentValue :: TypeLib -> Field -> (Text, Argument) -> Validation (Text, Argument)
validateArgumentValue lib' Field {fieldType = typeName', fieldTypeWrappers = wrappers'} (key', Argument value' position') =
  getInputType typeName' lib' (internalUnknownTypeMessage typeName') >>= checkType >>
  pure (key', Argument value' position')
  where
    checkType type' = handleInputError key' position' (validateInputValue lib' [] wrappers' type' (key', value'))

validateArgument :: TypeLib -> Position -> Arguments -> (Text, InputField) -> Validation (Text, Argument)
validateArgument types position' requestArgs (key', InputField arg) =
  case lookup key' requestArgs of
    Nothing                   -> handleNullable
    Just (Argument JSNull _)  -> handleNullable
    Just (Argument value pos) -> validateArgumentValue types arg (key', Argument value pos)
  where
    handleNullable =
      if isFieldNullable arg
        then pure (key', Argument JSNull position')
        else Left $ undefinedArgument (EnhancedKey key' position')

checkForUnknownArguments :: (Text, ObjectField) -> Arguments -> Validation [(Text, InputField)]
checkForUnknownArguments (fieldKey', ObjectField fieldArgs _) args' =
  checkForUnknownKeys enhancedKeys' fieldKeys error' >> checkNameCollision enhancedKeys' fieldKeys argumentNameCollision >>
  pure fieldArgs
  where
    error' = unknownArguments fieldKey'
    enhancedKeys' = map argToKey args'
    argToKey (key', Argument _ pos) = EnhancedKey key' pos
    fieldKeys = map fst fieldArgs

validateArguments :: TypeLib -> (Text, ObjectField) -> Position -> Arguments -> Validation Arguments
validateArguments typeLib inputs pos args' =
  checkForUnknownArguments inputs args' >>= mapM (validateArgument typeLib pos args')