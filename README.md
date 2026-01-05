# WWPTools (pyRevit Extension)

WWPTools is a pyRevit toolbar extension distributed via GitHub Releases for easy installs and updates.

## For admins (publish updates)
1) Create a GitHub repo named `WWPTools` (public).
2) Publish updates by pushing to `main` (the installer pulls the repo zip from GitHub).

## For users (install or update)
1) Download `Install_WWPTools.bat` from the repo.
2) Double-click it. It installs/updates the extension in:
   `%APPDATA%\pyRevit\Extensions\WWPTools.extension`
   and installs Dynamo packages to `C:\dynpackages`.

## Dynamo packages
The installer adds `C:\dynpackages` to Dynamo's Custom Package Folders (for any
installed Dynamo Revit versions), so users keep their personal packages too.

## Customize the repo owner
Edit `Update_WWPTools.ps1` and set `RepoOwner` to your GitHub org/user name.
