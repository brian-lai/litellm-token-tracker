# Add Local File API Key Store

## Objective

Stop repeated Keychain access prompts during local rebuilds by defaulting the app to a local file-backed API key store at `~/.config/jw_tokens/litellm_api_key`.

## Implementation Steps

- [ ] Add local file API key store
  - Tests: `testLocalFileAPIKeyStoreSaveReadDelete`, `testLocalFileAPIKeyStoreMissingFileMapsToMissingKey`, `testLocalFileAPIKeyStoreUsesPrivatePermissions`
- [ ] Wire app and docs to local file credentials
  - Tests: `swift build`, `swift run JWTokensTests`; README documents how to seed the file.

## Boundaries

- `APIKeyStoring` remains the credential boundary.
- `KeychainAPIKeyStore` remains available in core for future signed/distributed builds.
- `JWTokensApp` chooses `LocalFileAPIKeyStore` for this local-first app.

## Degradation

- Missing or empty file shows the existing `Set API Key` setup flow.
- File read/write failures show the existing unavailable credential-store error path.
