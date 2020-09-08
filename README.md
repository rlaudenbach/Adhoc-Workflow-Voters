# Adhoc Workflow Voters v1
- This solution adds assignments to the current activity accessed from the "Worflow Completion Dialog".  Assignments are called voters here.
- From an extra button "View other Voters" the current list of assignments can be viewed.
- If a user is Owner of the workflow controlled item (i.e. an ECO), he/she will see additional buttons to add, delete or change assignments.
- Newly added assignments, different from the workflow map, will be flagged "adhoc". These can be edited. Others can not.
- Non-adhoc assignments can be deleted, however, after confirming a warning.
- Closed assignments cannot be deleted, nor edited.

## Pre-requisites
Aras Innovator Release: 12SP5; 12SP8; 12SP9


## Implementation Details
This package installs on top of standard core. It extends these elements. 

- A server side method "AddOrDelete_AdHoc_WFassignments" is introduced to process add, update, and delete of assignments as "Super User" (to avoid permission conflicts)
- Relationship "Activity Assignment" gets a new property "is_adhoc"
- In the code tree under Client/scripts/InBasket. The aspx file "InBasket-VoteDialog.aspx" gets replaced.

NOTE: 
This introduces a dependency on the aras core releases.  Make sure you backup the current "InBasket-VoteDialog.aspx" file before overwriting it !
With new releases of Aras Innovator the "InBasket-VoteDialog.aspx" must be merged with the logic introduced by this add-on solution !

## Improvements
- The messages from the additions to “.aspx” are not multi language. These could be added to corresponding language resources files (code tree)
- Deleted rows could be greyed out instead of removed from the grid. More investigation in grid’s API required. (currently used calls did not work !)
- Use grid dialogHelper known form standard grids to start search dialog. Shows as […] button in grid cell.
- Use “StartEditCell” approach to prevent cell edits in certain conditions. Would make current logic simpler and more robust.

## Installation

The installation can be done in 2 ways:

1. Automated: Using the Aras Update tool (recommended) - Update version 1.9 or higher
2. Manually: Using the packages import tool 

NOTE:
1. Backup your database and store the BAK file in a safe place.
2. this solutions overwrites ".../Client/scripts/InBasket/InBasket-VoteDialog.aspx" in your code tree. Please make a backup of this file before installing !!!

### Automated: Using Aras Update

Log on as "admin"

1. start the Aras Update Tool
2. choose "local"
3. Click on "Add package reference"
4. On file dialog find installation folder "Installation" (where you extracted the solution installation package locally) and click "OK"
5. Click on "install"
6. Review the install selection. Click on "Next"
7. Select "Detailed logging" and click on "Next"
8. Click on "Browse" and select your Aras installation folder (choose folder "Innovator")
9. Click on "Import into Innovator DB" and enter your connect parameters for "Innvator URL, Database, Innovator user (admin), User Password"
10. Click "Install" - wait until success message appears

NOTE: you must clear the browser cache of all clients after deploying the code tree patches.


### Manual Code Tree and Import Steps

#### Deploy Code Tree Changes
CodeTree patches are located in folder "...Installation\CodeTree\Innovator" of this solution

1. Select folder "Innovator" and copy it
2. Navigate to the root folder of your Aras installation.  (i.e. "C:\Program Files (x86)\Aras_Innovator")
3. Paste the copied folder to the Aras installation root.
4. Confirm "Overwrite" warning.

NOTE: you must restart the IIS server and you must clear the browser cache of all clients after installation.

#### Import Packages
Import must be done in 4 steps in the indicated sequence.

Import packages are located in folder "...Installation\imports" of this solution

Use Package Utilities and log on as "admin"

1. select path to mf file "imports.mf"  --> click import button	- imports "Core extension and Adhoc Worflow Voters solution"


## Usage
If using the Makerbot demo database, and after installing this solutions, do these steps:
- log on as mmiller
- Go to MyInBasket. There open completion dialog of "ECO-00001017"
- Click on button "View other Voters"
- Click on "add row" button. And select "Terry Adams" from Identities search.
- Click on "save changes" button. Open the ECO and go to the "Signoffs" tab to see Terry has been added.
- log on as tadams
- Go to MyInBasket. There open completion dialog of "ECO-00001017"
- Click on button "View other Voters"
- NOTE: Terry cannot edit the voters list.
- Click on back.
- Choose Vote: "Close Change", provide your password and click on "Complete" button.
- log on as mmiller
- Go to MyInBasket. There open completion dialog of "ECO-00001017"
- Click on button "View other Voters"
- NOTE: in the list you can see Terry has voted already. You cannot delete this row any longer.


## Credits
The solution is a rework of an existing community solution "Adhoc Workflow Assignments".
which is a bit misleading since this older solution does not add assignments, but starts new adhoc workflows to invite other people to help.

## License
This project is published under the MIT license. See the [LICENSE file](./LICENSE.md) for license rights and limitations.)
