To make a new release of Hex Fiend on GitHub and update the Sparkle appcast for auto-updates:

1. Make sure `HEXFIEND_VERSION` has been set to a newer version in `version.h` and commit to master if needed.
2. Update `docs/ReleaseNotes.html` for this new version and commit to master if needed. This file gets bundled into Hex Fiend so it should be updated before making the final build.
3. Generate a notarized build with `dist.sh` from master. See that file for details.
4. Tag the build in git as `vX.Y.Z` using 3 version digits and push.
5. Edit the tag in [Releases](https://github.com/HexFiend/HexFiend/releases) on GitHub and attach the `Hex_Fiend_X.Y.Z.dmg` file generated previously. Click "Publish Release".
6. Delete all beta pre-releases on GitHub associated with this version. Make sure to delete the associated tags in git as well, which GitHub does not provide a way to do yet.
7. Add a new `<item>` to `app/appcast.xml` for this version number. To update the `dsaSignature` field, run `sign_update.rb Hex_Fiend_X.Y.Z.dmg dsa_priv.pem`. Note currently only devs with write access to the repository have this file. The script is from Sparkle repository. Commit to master. Test the update with an older version after a few minutes as it takes some time for the file to be updated on GitHub.
8. Update the [website](https://github.com/HexFiend/hexfiend-site) html and copy over the release notes
