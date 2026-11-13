# Publishing to GitHub

[中文](PUBLISH_CN.md)

Maintainer target: new public repository `yilongzhao1122/garmin-badminton-score`. The supplied script refuses to overwrite an existing repository.

## Windows script

1. Install [Git](https://git-scm.com/downloads) and [GitHub CLI](https://cli.github.com/).
2. Sign in using GitHub's own browser flow; never paste passwords/tokens into chat:

```powershell
gh auth login --hostname github.com --git-protocol https --web --scopes repo,workflow
```

3. Extract the complete source ZIP, read PUBLISH.ps1, and run it from the project root:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\PUBLISH.ps1
```

The execution-policy argument applies only to this process. The script checks the account and creates/uploads a new public repository. It preserves local files on failure and never overwrites an existing remote project.

4. Inspect Logic checks and Source release in Actions. The latter runs 196 checks before packaging the source, both offline guides and SHA256, and creates the versioned Release. An existing Release is preserved. Disabled workflows or missing permissions must be resolved from the actual GitHub error; starting a workflow does not prove publication.
5. Verify Release assets, download and checksums. No precompiled PRG is provided.

The script has been statically inspected, but was not executed against an authenticated GitHub repository in the preparation environment. If publication partly succeeds, keep the repository and local project, and use the non-sensitive error to continue rather than rerunning blindly.

## Continue with an agent

Alternatively, create the public repository in your GitHub account, name it garmin-badminton-score and enable Add a README file. Ensure the connected GitHub app can access it, then give the repository URL to the agent. The initial README provides an existing branch for upload; final project files replace that starter content.

GitHub source publication and Connect IQ store review are separate processes. Watch setup is covered in [Installation](INSTALL_EN.md).
