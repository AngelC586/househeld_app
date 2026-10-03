# Househeld App

Our senior project application. [ Add description here at some point ]

## Team Members:
Angel Castillo <br>


## Getting started

To begin with development, start by making a clone of the repository:

```bash
git clone https://github.com/AngelC586/househeld_app.git <your-desired-repo-directory>
```

## Branching 

To start wroking, create your own branch: 

```bash
# Replace <your-name> with the name you want for the branch
git checkout -b <your-name>

# Add your name to the "Tean Members" section above, then:
git add README.md
git commit -m "New branch"
git push -u origin your-name
```

You can also use the Source Control tab in VS Code to do this if you prefer.

Then, hop on GitHub and open a pull request for your changes. You may then merge the branches.

For any other time, you can use this command to step into your branch: 

```bash 
git switch <your-name>
# `git checkout <your-name>` also works
```

Our workflow will consist of doing work on your own branch, pushing changes, opening a pull-request, and merging.

## Important !!!

Be sure to pull the latest branch often before you start your work to stay up-to-date!
You should always pull the latest branch in both your local main branch and your local personal branch:

```bash
# Check your current working branch:
git branch --show-current

# Pull changes into that branch:
git pull origin main

# Switch your branch and pull again:
git switch main
git switch <your-name>
```

Also be sure to notify the team whenever you push/merge your work!!! If we're working on the project at the same time 
and one of us pushes changes, we need to announce it so the others can pull those changes before continuing their own work!

## Testing
When testing the app, you MUST have your emulator running because Firebase was only set up for Android/iOS platforms, 
so attempting to run the app on any other platforms, like Windows, MacOS, or Web, WILL NOT WORK!

```bash
# Launch your emulator, then:
flutter run
```

[ I'll add documentation here for testing using the Firebase Emulator Suite later ]

## Troubleshooting
If the app isn't working, it may be because you need to install dependencies or regenerate registrant files.
All of the app's dependencies are kept in `pubspec.yaml` and can be easily fetched with this command:

```bash
flutter pub get
```
NOTE: If you are working on the app and you see files with names such as `Generated_Plugin_Registrant` or similar, 
do NOT stage or push these files!!! Always check your Source Control tab on VS Code to make sure these files aren't being tracked by git!
