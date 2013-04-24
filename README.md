= Install

1. Download the source to plugins folder in your redmine installation.
2. Apply patches in `plugins/meetings/patches`
3. Run `rake redmine:plugins:migrate`
4. Restart servers

= Functionality

* Creates a new project module called Meetings.
* Create a button Meeting in the application menu that list all projects' meetings where the user is participating or is the author of the meeting.
* Create a button Meeting in the project menu that list all project's meeting where the user is participating or is the author of the meeting.
* It allows to log time, add journals or attachment to the meeting.
* Meetings can be associated to 0 or 1 issue. When there's an issue associated, the logged time to the meeting will be reflected also in the issue. If an update to the meeting change the issue associated, all meeting's time entries will change to the new issue (or no issue if that's the case).
* It changes the form to log time by adding a dropdown list with options "issue" and "meeting".

= Current locales

* English: thanks to Dipan Mehta
* Spanish
* French: thanks to Pierre-Yves Dubreucq
