# Add Local File API Key Store Summary

## What Changed

- Added `LocalFileAPIKeyStore`, which stores the LiteLLM API key at `~/.config/jw_tokens/litellm_api_key`.
- Wired the local app to use the file store by default instead of Keychain.
- Kept `KeychainAPIKeyStore` available in the core package for future signed/distributed builds.
- Updated README instructions for seeding the local credential file.

## Security Behavior

- The store creates `~/.config/jw_tokens` with `0700` permissions.
- The key file is written with `0600` permissions.
- Missing or empty files map to the existing setup flow.

## Verification

- `swift build`
- `swift run JWTokensTests`

## Notes

This avoids repeated Keychain prompts caused by local rebuilds changing the app binary identity. The tradeoff is that the local credential file is plaintext and protected by filesystem permissions rather than Keychain access controls.
